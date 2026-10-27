"""Bundle only a verified derived model, leaving source checkpoint files untouched."""

import argparse
import hashlib
import json
import shutil
from pathlib import Path

from backend.app.ml.classes import CLASS_NAMES
from backend.app.ml.model import PREPROCESSING


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def bundle(source: Path, destination: Path):
    report = json.loads((source / "conversion_verification.json").read_text())
    manifest = json.loads((source / "model_manifest.json").read_text())
    model = source / "tomato_mobilenet_v3_small.onnx"
    if not report.get("passed") or not report.get("cases"):
        raise ValueError("A passing real conversion verification is required.")
    if digest(model) != report["model_sha256"] or digest(model) != manifest["model_sha256"]:
        raise ValueError("Verified model hash does not match.")
    if manifest["labels"] != list(CLASS_NAMES) or manifest["preprocessing"] != PREPROCESSING:
        raise ValueError("Incorrect class ordering or preprocessing contract.")
    if digest(Path("models/best_model.pt")) != manifest["checkpoint_sha256"]:
        raise ValueError("Source checkpoint differs from the verified export.")
    protected = Path("models").resolve()
    if destination.resolve() == protected or protected in destination.resolve().parents:
        raise ValueError("Cannot bundle into the protected model directory.")
    destination.mkdir(parents=True, exist_ok=True)
    shutil.copy2(model, destination / model.name)
    shutil.copy2(source / "model_manifest.json", destination / "model_manifest.json")
    print("Verified ONNX model and local labels/guidance bundled.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=Path("artifacts/android_export"))
    parser.add_argument("--destination", type=Path, default=Path("frontend/assets/models"))
    args = parser.parse_args()
    bundle(args.source, args.destination)
