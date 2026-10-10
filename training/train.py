"""Short, reproducible MobileNetV3-Small head-training run; execute from repo root."""

import argparse
import json
import random
import shutil
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import torch
import yaml
from torch import nn
from torch.utils.data import DataLoader

from backend.app.ml.classes import CLASS_TO_IDX, save_mapping
from backend.app.ml.model import PREPROCESSING, build_model, inference_transform, training_transform
from training.data import LeafDataset, load_manifest
from training.evaluate import evaluate_model
from training.prepare_dataset import prepare_dataset


def seed_everything(seed: int) -> None:
    random.seed(seed)
    np.random.seed(seed)
    torch.manual_seed(seed)
    if torch.cuda.is_available():
        torch.cuda.manual_seed_all(seed)
    torch.backends.cudnn.benchmark = False
    torch.backends.cudnn.deterministic = True
    torch.use_deterministic_algorithms(True, warn_only=True)


def seed_worker(worker_id: int) -> None:
    worker_seed = torch.initial_seed() % 2**32
    random.seed(worker_seed)
    np.random.seed(worker_seed)


def select_device(requested: str) -> torch.device:
    if requested == "auto":
        return torch.device("cuda" if torch.cuda.is_available() else "cpu")
    if requested == "cuda" and not torch.cuda.is_available():
        raise ValueError("CUDA was requested but is unavailable. Select auto or cpu.")
    if requested not in {"cpu", "cuda"}:
        raise ValueError("Device must be auto, cpu, or cuda.")
    return torch.device(requested)


def run_epoch(
    model, loader: DataLoader, device: torch.device, optimizer=None
) -> tuple[float, float]:
    training = optimizer is not None
    model.train(training)
    if training:
        # Freezing parameters alone does not freeze BatchNorm running statistics.
        model.features.eval()
    loss_function = nn.CrossEntropyLoss()
    total_loss = 0.0
    correct = 0
    samples = 0
    context = torch.enable_grad() if training else torch.inference_mode()
    with context:
        for images, labels in loader:
            images, labels = images.to(device), labels.to(device)
            if training:
                optimizer.zero_grad(set_to_none=True)
            logits = model(images)
            loss = loss_function(logits, labels)
            if not torch.isfinite(loss):
                raise RuntimeError("Non-finite loss; check the dataset and learning rate.")
            if training:
                loss.backward()
                optimizer.step()
            samples += len(labels)
            total_loss += loss.item() * len(labels)
            correct += (logits.argmax(1) == labels).sum().item()
    if samples == 0:
        raise ValueError("Cannot train or validate an empty dataset.")
    return total_loss / samples, correct / samples


def save_history(history: list[dict], output_dir: Path) -> None:
    (output_dir / "history.json").write_text(json.dumps(history, indent=2) + "\n")
    figure, axes = plt.subplots(1, 2, figsize=(11, 4))
    epochs = [entry["epoch"] for entry in history]
    for name in ("train_loss", "validation_loss"):
        axes[0].plot(epochs, [entry[name] for entry in history], label=name)
    axes[1].plot(epochs, [entry["validation_accuracy"] for entry in history], label="validation")
    axes[0].set_ylabel("Cross entropy loss")
    axes[1].set_ylabel("Accuracy")
    axes[1].set_ylim(0, 1)
    for axis in axes:
        axis.set_xlabel("Epoch")
        axis.legend()
        axis.grid(alpha=0.2)
    figure.tight_layout()
    figure.savefig(output_dir / "training_curves.png", dpi=160)
    plt.close(figure)


def validate_config(config: dict) -> None:
    for key in ("epochs", "batch_size", "patience"):
        if type(config[key]) is not int or config[key] < 1:
            raise ValueError(f"{key} must be a positive integer.")
    if type(config["num_workers"]) is not int or config["num_workers"] < 0:
        raise ValueError("num_workers must be a nonnegative integer.")
    if not 0 < config["learning_rate"] < 1 or not 0 <= config["weight_decay"] < 1:
        raise ValueError("Invalid learning_rate or weight_decay.")


def train(
    config: dict,
    dataset_root: Path,
    prepared_dir: Path,
    output_dir: Path,
    leaf_groups: Path | None = None,
) -> dict:
    validate_config(config)
    if (output_dir / "best_model.pt").exists():
        raise ValueError("Output already contains a checkpoint. Choose a new --output-dir.")
    seed_everything(config["seed"])
    torch.set_num_threads(4)
    device = select_device(config["device"])
    report = prepare_dataset(
        dataset_root,
        prepared_dir,
        seed=config["seed"],
        ratios=tuple(config["split_ratios"]),
        leaf_groups=leaf_groups,
    )
    print(json.dumps(report, indent=2), flush=True)
    manifest, root = load_manifest(prepared_dir / "split_manifest.json", dataset_root)
    generator = torch.Generator().manual_seed(config["seed"])
    loaders = {}
    for split in ("train", "validation", "test"):
        transform = training_transform() if split == "train" else inference_transform()
        dataset = LeafDataset(manifest["splits"][split], root, transform)
        loaders[split] = DataLoader(
            dataset,
            batch_size=config["batch_size"],
            shuffle=split == "train",
            num_workers=config["num_workers"],
            generator=generator,
            worker_init_fn=seed_worker,
            pin_memory=device.type == "cuda",
        )
    # This is the only path which downloads ImageNet weights. Serving never downloads.
    model = build_model(pretrained=True, freeze_features=True).to(device)
    optimizer = torch.optim.AdamW(
        model.classifier.parameters(),
        lr=config["learning_rate"],
        weight_decay=config["weight_decay"],
    )
    output_dir.mkdir(parents=True, exist_ok=True)
    save_mapping(output_dir / "class_mapping.json")
    history = []
    best_loss = float("inf")
    stale_epochs = 0
    best_epoch = 0
    for epoch in range(1, config["epochs"] + 1):
        train_loss, train_accuracy = run_epoch(model, loaders["train"], device, optimizer)
        val_loss, val_accuracy = run_epoch(model, loaders["validation"], device)
        entry = {
            "epoch": epoch,
            "train_loss": train_loss,
            "train_accuracy": train_accuracy,
            "validation_loss": val_loss,
            "validation_accuracy": val_accuracy,
        }
        history.append(entry)
        print(json.dumps(entry), flush=True)
        if val_loss < best_loss:
            best_loss, stale_epochs, best_epoch = val_loss, 0, epoch
            torch.save(
                {
                    "format_version": 1,
                    "architecture": "mobilenet_v3_small",
                    "pretrained_weights": "IMAGENET1K_V1",
                    "trained_epochs": epoch,
                    "class_to_idx": CLASS_TO_IDX,
                    "preprocessing": PREPROCESSING,
                    "seed": config["seed"],
                    "validation_loss": val_loss,
                    "state_dict": {
                        key: value.detach().cpu() for key, value in model.state_dict().items()
                    },
                },
                output_dir / "best_model.pt",
            )
        else:
            stale_epochs += 1
        save_history(history, output_dir)
        if stale_epochs >= config["patience"]:
            print(f"Early stopping at epoch {epoch}.", flush=True)
            break
    checkpoint = torch.load(output_dir / "best_model.pt", map_location=device, weights_only=True)
    model.load_state_dict(checkpoint["state_dict"])
    # The test partition is first used after checkpoint selection, never for optimization.
    metrics = evaluate_model(model, loaders["test"], device, output_dir)
    metadata = {
        "config": config,
        "device": str(device),
        "completed_epochs": len(history),
        "best_epoch": best_epoch,
        "torch_version": str(torch.__version__),
        "preprocessing": PREPROCESSING,
    }
    (output_dir / "run_metadata.json").write_text(json.dumps(metadata, indent=2) + "\n")
    for filename in ("split_manifest.json", "dataset_report.json"):
        shutil.copy2(prepared_dir / filename, output_dir / filename)
    print(json.dumps(metrics, indent=2), flush=True)
    return metrics


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", type=Path, default=Path("training/config.yaml"))
    parser.add_argument("--dataset-root", type=Path)
    parser.add_argument("--output-dir", type=Path)
    parser.add_argument("--leaf-groups", type=Path)
    parser.add_argument("--epochs", type=int)
    parser.add_argument("--device", choices=("auto", "cpu", "cuda"))
    args = parser.parse_args()
    try:
        config = yaml.safe_load(args.config.read_text(encoding="utf-8"))
        for key in ("epochs", "device"):
            if getattr(args, key) is not None:
                config[key] = getattr(args, key)
        base = args.config.resolve().parent
        root = args.dataset_root or base / config["dataset_root"]
        output = args.output_dir or base / config["output_dir"]
        train(
            config,
            root.resolve(),
            (base / config["prepared_dir"]).resolve(),
            output.resolve(),
            args.leaf_groups,
        )
    except (OSError, ValueError, RuntimeError, KeyError) as exc:
        parser.exit(1, f"Training failed: {exc}\n")


if __name__ == "__main__":
    main()
