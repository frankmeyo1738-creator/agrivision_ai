"""Compute held-out metrics from actual model outputs, with no canned results."""

import argparse
import json
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import torch
from sklearn.metrics import accuracy_score, classification_report, confusion_matrix
from torch.utils.data import DataLoader

from backend.app.ml.classes import CLASS_NAMES
from backend.app.ml.inference import InferenceEngine
from backend.app.ml.model import inference_transform
from training.data import LeafDataset, load_manifest


def calculate_metrics(labels: list[int], predictions: list[int]) -> dict:
    if not labels or len(labels) != len(predictions):
        raise ValueError("Evaluation requires equally sized nonempty labels and predictions.")
    valid = set(range(len(CLASS_NAMES)))
    if not set(labels).issubset(valid) or not set(predictions).issubset(valid):
        raise ValueError("Evaluation labels and predictions must use the five class indices.")
    report = classification_report(
        labels,
        predictions,
        labels=list(range(len(CLASS_NAMES))),
        target_names=list(CLASS_NAMES),
        output_dict=True,
        zero_division=0,
    )
    return {
        "test_samples": len(labels),
        "accuracy": float(accuracy_score(labels, predictions)),
        "precision_macro": report["macro avg"]["precision"],
        "recall_macro": report["macro avg"]["recall"],
        "f1_macro": report["macro avg"]["f1-score"],
        "per_class": {name: report[name] for name in CLASS_NAMES},
        "weighted_average": report["weighted avg"],
        "confusion_matrix": confusion_matrix(
            labels, predictions, labels=list(range(len(CLASS_NAMES)))
        ).tolist(),
        "class_order": list(CLASS_NAMES),
    }


def evaluate_model(model, loader: DataLoader, device: torch.device, output_dir: Path) -> dict:
    model.eval()
    labels = []
    predictions = []
    with torch.inference_mode():
        for images, targets in loader:
            logits = model(images.to(device))
            if not torch.isfinite(logits).all():
                raise RuntimeError("Non-finite evaluation output.")
            predictions.extend(logits.argmax(dim=1).cpu().tolist())
            labels.extend(targets.tolist())
    metrics = calculate_metrics(labels, predictions)
    output_dir.mkdir(parents=True, exist_ok=True)
    (output_dir / "evaluation.json").write_text(json.dumps(metrics, indent=2) + "\n")
    figure, axis = plt.subplots(figsize=(9, 7))
    matrix = metrics["confusion_matrix"]
    axis.imshow(matrix, cmap="Greens")
    short_names = [name.removeprefix("Tomato ") for name in CLASS_NAMES]
    axis.set_xticks(range(5), short_names, rotation=35, ha="right")
    axis.set_yticks(range(5), short_names)
    axis.set_xlabel("Predicted class")
    axis.set_ylabel("True class")
    axis.set_title("Held-out test confusion matrix")
    for row in range(5):
        for column in range(5):
            axis.text(column, row, matrix[row][column], ha="center", va="center")
    figure.tight_layout()
    figure.savefig(output_dir / "confusion_matrix.png", dpi=160)
    plt.close(figure)
    return metrics


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--model-dir", type=Path, default=Path("artifacts/run"))
    parser.add_argument(
        "--manifest", type=Path, default=Path("artifacts/prepared/split_manifest.json")
    )
    parser.add_argument("--dataset-root", type=Path)
    parser.add_argument("--output-dir", type=Path)
    args = parser.parse_args()
    try:
        torch.set_num_threads(4)
        manifest, root = load_manifest(args.manifest, args.dataset_root)
        engine = InferenceEngine(args.model_dir)
        engine.load()
        dataset = LeafDataset(manifest["splits"]["test"], root, inference_transform())
        result = evaluate_model(
            engine.model,
            DataLoader(dataset, batch_size=32),
            torch.device("cpu"),
            args.output_dir or args.model_dir,
        )
        print(json.dumps(result, indent=2))
    except (OSError, ValueError, RuntimeError) as exc:
        parser.exit(1, f"Evaluation failed: {exc}\n")


if __name__ == "__main__":
    main()
