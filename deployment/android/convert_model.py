"""Export the actual checkpoint; fail if ONNX changes fixed-set predictions.

Run from the repository root. Image manifest entries must contain path + sha256.
Never trains, downloads weights, or modifies models/. Derived artifacts use a
separate destination, and existing outputs are refused unless --replace is given.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import platform
from pathlib import Path

import numpy as np
import onnx
import onnxruntime as ort
import torch
import torchvision

from backend.app.ml.classes import CLASS_NAMES
from backend.app.ml.images import decode_image
from backend.app.ml.inference import InferenceEngine
from backend.app.ml.model import PREPROCESSING
from backend.app.services.diseases import CONFIDENCE_NOTE, DISEASES


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def convert(model_dir: Path, manifest: Path, output: Path, replace: bool = False) -> dict:
    if output.resolve() == model_dir.resolve() or model_dir.resolve() in output.resolve().parents:
        raise ValueError("Derived artifacts must not be written under models/.")
    model_path = output / "tomato_mobilenet_v3_small.onnx"
    if model_path.exists() and not replace:
        raise FileExistsError("Output exists; use a new output directory or --replace.")
    cases = json.loads(manifest.read_text())["images"]
    if not cases:
        raise ValueError("Verification requires a fixed, nonempty image manifest.")
    tensors = []
    for case in cases:
        path = manifest.parent / case["path"]
        if sha256(path) != case["sha256"]:
            raise ValueError(f"Fixed image changed: {path}")
        tensors.append(
            (
                case,
                InferenceEngine(model_dir).transform(decode_image(path.read_bytes())).unsqueeze(0),
            )
        )
    engine = InferenceEngine(model_dir)
    engine.load()
    torch.set_num_threads(2)
    output.mkdir(parents=True, exist_ok=True)
    # Fixed batch/shape matches the Android NCHW float32 contract.
    torch.onnx.export(
        engine.model,
        (tensors[0][1],),
        str(model_path),
        dynamo=True,
        opset_version=18,
        input_names=["images"],
        output_names=["logits"],
        external_data=False,
    )
    onnx.checker.check_model(onnx.load(model_path), full_check=True)
    session = ort.InferenceSession(str(model_path), providers=["CPUExecutionProvider"])
    results = []
    passed = True
    golden = output / "golden"
    golden.mkdir(exist_ok=True)
    for index, (case, tensor) in enumerate(tensors):
        with torch.inference_mode():
            original = engine.model(tensor).numpy()
        converted = session.run(["logits"], {"images": tensor.numpy()})[0]
        torch_scores = torch.softmax(torch.from_numpy(original), dim=1).numpy()[0]
        ort_scores = torch.softmax(torch.from_numpy(converted), dim=1).numpy()[0]
        max_logit_error = float(np.abs(original - converted).max())
        max_score_error = float(np.abs(torch_scores - ort_scores).max())
        original_order = np.argsort(-torch_scores, kind="stable").tolist()
        converted_order = np.argsort(-ort_scores, kind="stable").tolist()
        ok = (
            max_logit_error <= 1e-4
            and max_score_error <= 1e-5
            and original_order[:3] == converted_order[:3]
        )
        passed &= ok
        tensor.numpy().astype("<f4").tofile(golden / f"{index}.nchw.f32")
        results.append(
            {
                **case,
                "pytorch_logits": original[0].tolist(),
                "onnx_logits": converted[0].tolist(),
                "pytorch_probabilities": torch_scores.tolist(),
                "onnx_probabilities": ort_scores.tolist(),
                "pytorch_top_three_indices": original_order[:3],
                "onnx_top_three_indices": converted_order[:3],
                "max_absolute_logit_error": max_logit_error,
                "max_absolute_probability_error": max_score_error,
                "passed": bool(ok),
            }
        )
    report = {
        "purpose": "conversion parity, not disease accuracy or an independent held-out evaluation",
        "source_checkpoint_sha256": sha256(model_dir / "best_model.pt"),
        "source_mapping_sha256": sha256(model_dir / "class_mapping.json"),
        "model_sha256": sha256(model_path),
        "model_bytes": model_path.stat().st_size,
        "environment": {
            "platform": platform.platform(),
            "torch": torch.__version__,
            "torchvision": torchvision.__version__,
            "onnx": onnx.__version__,
            "onnxruntime": ort.__version__,
        },
        "contract": {
            "input": "images",
            "shape": [1, 3, 224, 224],
            "dtype": "float32",
            "output": "logits",
            "opset": 18,
        },
        "preprocessing": PREPROCESSING,
        "labels": list(CLASS_NAMES),
        "thresholds": {
            "absolute_logits": 1e-4,
            "absolute_probabilities": 1e-5,
            "same_top_three": True,
        },
        "cases": results,
        "passed": bool(passed),
    }
    (output / "conversion_verification.json").write_text(json.dumps(report, indent=2) + "\n")
    if not passed:
        raise RuntimeError("Conversion verification failed; do not bundle this model.")
    bundle = {
        "format_version": 1,
        "architecture": "mobilenet_v3_small",
        "runtime": "onnxruntime-android 1.23.2",
        "model_sha256": report["model_sha256"],
        "checkpoint_sha256": report["source_checkpoint_sha256"],
        "labels": list(CLASS_NAMES),
        "preprocessing": PREPROCESSING,
        "guidance": DISEASES,
        "confidence_note": CONFIDENCE_NOTE,
        "crop_scope": "Tomato leaves only",
    }
    (output / "model_manifest.json").write_text(json.dumps(bundle, indent=2) + "\n")
    return report


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--model-dir", type=Path, default=Path("models"))
    parser.add_argument(
        "--images", type=Path, default=Path("artifacts/android_verification/images/manifest.json")
    )
    parser.add_argument("--output", type=Path, default=Path("artifacts/android_export"))
    parser.add_argument("--replace", action="store_true")
    args = parser.parse_args()
    report = convert(args.model_dir, args.images, args.output, args.replace)
    print(
        json.dumps(
            {
                "passed": report["passed"],
                "images": len(report["cases"]),
                "model_bytes": report["model_bytes"],
                "max_logit_error": max(x["max_absolute_logit_error"] for x in report["cases"]),
                "max_probability_error": max(
                    x["max_absolute_probability_error"] for x in report["cases"]
                ),
            }
        )
    )


if __name__ == "__main__":
    main()
