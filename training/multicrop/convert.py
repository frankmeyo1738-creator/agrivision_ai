"""Convert an evaluated fourteen-class run to staged ONNX; never activate it."""

import argparse
import json
from pathlib import Path

import numpy as np
import onnx
import onnxruntime as ort
import torch
from PIL import Image, ImageOps

from backend.app.ml.model import PREPROCESSING, inference_transform
from training.multicrop.pipeline import CONFIG, LABELS, MAPPING, build_model, sha256, validate_splits, write_json


def validate_run(run):
    run = Path(run)
    checkpoint = torch.load(run / "best_model.pt", weights_only=True, map_location="cpu")
    evaluation = json.loads((run / "evaluation.json").read_text())
    manifest = json.loads((run / "split_manifest.json").read_text())
    validate_splits(manifest)
    if checkpoint.get("architecture") != "mobilenet_v3_small" or checkpoint.get("format_version") != 1 \
            or type(checkpoint.get("trained_epochs")) is not int or checkpoint["trained_epochs"] < 1:
        raise ValueError("A genuinely completed training run is required")
    if checkpoint.get("class_to_idx") != MAPPING or checkpoint.get("preprocessing") != PREPROCESSING:
        raise ValueError("Class mapping or preprocessing mismatch")
    split_hash = sha256(run / "split_manifest.json")
    if checkpoint.get("split_manifest_sha256") != split_hash \
            or evaluation.get("split_manifest_sha256") != split_hash \
            or evaluation.get("checkpoint_sha256") != sha256(run / "best_model.pt"):
        raise ValueError("Evaluation/checkpoint/split provenance mismatch")
    if evaluation.get("class_order") != LABELS or evaluation.get("test_samples") != len(manifest["splits"]["test"]):
        raise ValueError("Held-out evaluation is incomplete")
    if evaluation.get("source_commit") != CONFIG["source_commit"] \
            or checkpoint.get("source_commit") != CONFIG["source_commit"]:
        raise ValueError("Dataset source revision mismatch")
    for metric in ("accuracy", "f1_macro"):
        if not isinstance(evaluation.get(metric), (int, float)) or not 0 <= evaluation[metric] <= 1:
            raise ValueError("Invalid evaluation metrics")
    expected_support = {name: sum(r["class_index"] == i for r in manifest["splits"]["test"])
                        for i, name in enumerate(LABELS)}
    for name in LABELS:
        if evaluation["per_class"][name]["support"] != expected_support[name]:
            raise ValueError("Per-class evaluation support mismatch")
        for metric in ("precision", "recall", "f1-score"):
            if not 0 <= evaluation["per_class"][name][metric] <= 1:
                raise ValueError("Invalid per-class metrics")
    model = build_model()
    model.load_state_dict(checkpoint["state_dict"], strict=True)
    if not all(torch.isfinite(value).all() for value in model.state_dict().values()):
        raise ValueError("Non-finite model weights")
    return model.eval()


def convert(run, output):
    run, output = Path(run).resolve(), Path(output).resolve()
    project = Path(__file__).resolve().parents[2]
    for protected in (project / "models", project / "frontend"):
        if output == protected or protected in output.parents:
            raise ValueError("Conversion must be staged outside active model/application files")
    if output.exists():
        raise ValueError("Use a new conversion directory; previous models are preserved")
    model = validate_run(run)
    cases = json.loads((run / "parity_images.json").read_text())["images"]
    if len(cases) != 14 or {r["class_index"] for r in cases} != set(range(14)):
        raise ValueError("One fixed held-out image per class is required")
    manifest = json.loads((run / "split_manifest.json").read_text())
    held_out = {r["path"]: r for r in manifest["splits"]["test"]}
    inputs = []
    for case in cases:
        relative = Path(case["path"])
        if relative.is_absolute() or ".." in relative.parts:
            raise ValueError("Unsafe parity image path")
        source = held_out[case["source_path"]]
        if source["class_index"] != case["class_index"] or sha256(run / relative) != case["sha256"]:
            raise ValueError("Parity image provenance mismatch")
        with Image.open(run / relative) as image:
            decoded = ImageOps.exif_transpose(image).convert("RGB")
            import hashlib
            if hashlib.sha256(str(decoded.size).encode() + decoded.tobytes()).hexdigest() != source["pixel_sha256"]:
                raise ValueError("Parity photo differs from held-out test record")
            inputs.append(inference_transform()(decoded).unsqueeze(0))
    output.mkdir(parents=True)
    model_path = output / "multicrop_mobilenet_v3_small.onnx"
    torch.onnx.export(model, inputs[0], model_path, input_names=["images"], output_names=["logits"],
                      opset_version=18, dynamo=True, external_data=False)
    onnx.checker.check_model(onnx.load(model_path), full_check=True)
    session = ort.InferenceSession(str(model_path), providers=["CPUExecutionProvider"])
    if session.get_inputs()[0].shape != [1, 3, 224, 224] or session.get_outputs()[0].shape != [1, 14]:
        raise ValueError("Unexpected converted tensor shapes")
    report = {"passed": False, "runtime": "onnxruntime", "runtime_version": ort.__version__,
              "model_sha256": sha256(model_path), "checkpoint_sha256": sha256(run / "best_model.pt"),
              "class_order": LABELS, "preprocessing": PREPROCESSING, "cases": [],
              "android_runtime_tested": False, "physical_device_tested": False}
    for case, tensor in zip(cases, inputs, strict=True):
        with torch.inference_mode():
            expected = model(tensor).numpy()
        actual = session.run(["logits"], {"images": tensor.numpy()})[0]
        expected_probabilities = torch.softmax(torch.from_numpy(expected), 1).numpy()
        actual_probabilities = torch.softmax(torch.from_numpy(actual), 1).numpy()
        logits_error = float(np.max(np.abs(actual - expected)))
        probability_error = float(np.max(np.abs(actual_probabilities - expected_probabilities)))
        expected_top = np.argsort(-expected[0], kind="stable")[:3].tolist()
        actual_top = np.argsort(-actual[0], kind="stable")[:3].tolist()
        passed = bool(np.isfinite(actual).all() and logits_error <= 1e-4
                      and probability_error <= 1e-5 and expected_top == actual_top)
        tensor.numpy().astype("<f4").tofile(output / f"input_{case['class_index']:02d}.f32")
        report["cases"].append({**case, "logits_max_abs_error": logits_error,
                                "probability_max_abs_error": probability_error,
                                "pytorch_logits": expected[0].tolist(), "onnx_logits": actual[0].tolist(),
                                "pytorch_top3": expected_top, "onnx_top3": actual_top, "passed": passed})
    report["passed"] = all(case["passed"] for case in report["cases"])
    write_json(output / "conversion_verification.json", report)
    if not report["passed"]:
        raise ValueError("Conversion parity failed; do not bundle this model")
    write_json(output / "staged_model_manifest.json", {
        "format_version": 1, "model_file": model_path.name, "model_sha256": report["model_sha256"],
        "checkpoint_sha256": report["checkpoint_sha256"], "labels": LABELS,
        "classes": CONFIG["classes"], "supported_crops": ["Tomato", "Maize", "Potato", "Bell Pepper"],
        "preprocessing": PREPROCESSING, "activation_ready": False,
        "remaining": ["Local guidance review", "Native Android 14-output integration and parity",
                      "Crop mismatch interface tests", "Airplane-mode workflow and new APK verification"]})
    print("Desktop ONNX parity passed. Staged only; Android deployment is not yet validated.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    convert(args.run, args.output)
