"""CPU inference only. No download, training, or fallback predictions at startup."""

import json
import threading
from pathlib import Path

import torch

from .classes import CLASS_NAMES, load_mapping, validate_mapping
from .images import decode_image
from .model import PREPROCESSING, build_model, inference_transform


class ModelUnavailableError(RuntimeError):
    pass


class InferenceEngine:
    def __init__(self, model_dir: Path):
        self.model_dir = model_dir
        self.model = None
        self.transform = inference_transform()
        self._lock = threading.Lock()

    @property
    def loaded(self) -> bool:
        return self.model is not None

    def load(self) -> None:
        self.model = None
        weights_path = self.model_dir / "best_model.pt"
        mapping_path = self.model_dir / "class_mapping.json"
        if not weights_path.is_file() or not mapping_path.is_file():
            raise ModelUnavailableError(
                "Model files are missing. Train in Colab and place best_model.pt and "
                "class_mapping.json in AGRIVISION_MODEL_DIR (default: models/), then restart."
            )
        try:
            mapping = load_mapping(mapping_path)
            checkpoint = torch.load(weights_path, map_location="cpu", weights_only=True)
            if checkpoint.get("architecture") != "mobilenet_v3_small":
                raise ValueError("Incorrect architecture")
            if checkpoint.get("format_version") != 1 or checkpoint.get("trained_epochs", 0) < 1:
                raise ValueError("Checkpoint has no training provenance")
            if validate_mapping(checkpoint.get("class_to_idx")) != mapping:
                raise ValueError("Incompatible class mapping")
            if checkpoint.get("preprocessing") != PREPROCESSING:
                raise ValueError("Incompatible preprocessing")
            model = build_model(pretrained=False)
            model.load_state_dict(checkpoint["state_dict"], strict=True)
            if not all(torch.isfinite(p).all() for p in model.state_dict().values()):
                raise ValueError("Non-finite model weights")
            model.eval()
            self.model = model
        except Exception as exc:
            raise ModelUnavailableError(
                "Model files are invalid or incompatible. Re-export them using the "
                "AgriVision training pipeline, then restart the backend."
            ) from exc

    def predict_bytes(self, data: bytes) -> dict:
        image = decode_image(data)
        if self.model is None:
            raise ModelUnavailableError("The trained model is unavailable. Check /health.")
        tensor = self.transform(image).unsqueeze(0)
        with self._lock, torch.inference_mode():
            logits = self.model(tensor)
            if logits.shape != (1, len(CLASS_NAMES)) or not torch.isfinite(logits).all():
                raise RuntimeError("Model output is invalid")
            probabilities = torch.softmax(logits, dim=1)[0]
            scores, indices = torch.topk(probabilities, k=3)
        top = [
            {"class": CLASS_NAMES[index], "confidence": float(score)}
            for score, index in zip(scores.tolist(), indices.tolist(), strict=True)
        ]
        return {
            "predicted_class": top[0]["class"],
            "confidence": top[0]["confidence"],
            "top_predictions": top,
        }


def main() -> None:
    import argparse

    parser = argparse.ArgumentParser(description="Predict a tomato leaf with trained weights.")
    parser.add_argument("image", type=Path)
    parser.add_argument("--model-dir", type=Path, default=Path("models"))
    args = parser.parse_args()
    try:
        engine = InferenceEngine(args.model_dir)
        engine.load()
        with args.image.open("rb") as stream:
            result = engine.predict_bytes(stream.read(10 * 1024 * 1024 + 1))
        print(json.dumps(result, indent=2))
    except (OSError, ValueError, ModelUnavailableError) as exc:
        parser.exit(1, f"Prediction failed: {exc}\n")


if __name__ == "__main__":
    main()
