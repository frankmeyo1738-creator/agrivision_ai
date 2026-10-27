"""Pinned RGB acquisition, leaf-group splits and genuine Colab GPU training.

This module never writes to models/ or the active Flutter asset directory.
"""

import argparse
import concurrent.futures
import hashlib
import json
import random
import re
import time
import urllib.parse
import urllib.request
from collections import Counter, defaultdict
from pathlib import Path

import numpy as np
import torch
from PIL import Image, ImageOps
from sklearn.metrics import accuracy_score, classification_report, confusion_matrix
from torch import nn
from torch.utils.data import DataLoader, Dataset
from torchvision.models import MobileNet_V3_Small_Weights, mobilenet_v3_small

from backend.app.ml.model import PREPROCESSING, inference_transform, training_transform
from training.prepare_dataset import DisjointSet, normalize_name, source_identifier

HERE = Path(__file__).resolve().parent
CONFIG = json.loads((HERE / "dataset_config.json").read_text())
CLASSES = CONFIG["classes"]
LABELS = [c["label"] for c in CLASSES]
MAPPING = {label: index for index, label in enumerate(LABELS)}
SPLITS = ("train", "validation", "test")


def write_json(path, value):
    Path(path).write_text(json.dumps(value, indent=2) + "\n")


def sha256(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def blob_sha(data):
    return hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()


def inventory():
    if sha256(HERE / "source_inventory.json") != CONFIG["inventory_sha256"]:
        raise ValueError("Pinned inventory integrity mismatch")
    source = json.loads((HERE / "source_inventory.json").read_text())
    if source["source_commit"] != CONFIG["source_commit"]:
        raise ValueError("Source revision mismatch")
    if source["rgb_tree_sha"] != CONFIG["rgb_tree_sha"]:
        raise ValueError("RGB tree revision mismatch")
    for record in source["images"]:
        path = Path(record["path"])
        if path.is_absolute() or ".." in path.parts or len(path.parts) != 2 \
                or path.parts[0] != CLASSES[record["class_index"]]["source_folder"]:
            raise ValueError("Unsafe or mislabeled source inventory path")
    if Counter(r["class_index"] for r in source["images"]) != {
        c["index"]: c["expected_images"] for c in CLASSES
    }:
        raise ValueError("Pinned RGB inventory counts differ")
    return source


def download(root):
    source = inventory()
    root = Path(root).resolve()
    root.mkdir(parents=True, exist_ok=True)

    def fetch(record):
        destination = root / record["path"]
        destination.parent.mkdir(parents=True, exist_ok=True)
        if destination.exists():
            if blob_sha(destination.read_bytes()) == record["blob_sha"]:
                return
            raise ValueError(f"Existing image changed: {destination}; do not overwrite it")
        url = ("https://raw.githubusercontent.com/spMohanty/PlantVillage-Dataset/"
               + CONFIG["source_commit"] + "/raw/color/"
               + urllib.parse.quote(record["path"], safe="/"))
        for attempt in range(5):
            try:
                with urllib.request.urlopen(url, timeout=60) as response:
                    data = response.read()
                if len(data) != record["bytes"] or blob_sha(data) != record["blob_sha"]:
                    raise ValueError(f"Source integrity failure: {record['path']}")
                destination.write_bytes(data)
                return
            except OSError:
                if attempt == 4:
                    raise
                time.sleep(2 ** attempt)

    with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
        for count, _ in enumerate(pool.map(fetch, source["images"]), 1):
            if count % 500 == 0:
                print(f"Verified {count}/{len(source['images'])} original RGB files", flush=True)
    write_json(root / "acquisition.json", {
        "source_commit": CONFIG["source_commit"], "inventory_sha256": sha256(HERE / "source_inventory.json"),
        "license": CONFIG["license"], "images": len(source["images"]),
    })


def filename_leaf(path):
    identity = source_identifier(Path(path))
    # Explicit Leaf 17.1 / Leaf 17.2 and repeated Day photographs share one leaf.
    match = re.match(r"(.*?\bleaf\s*\d+)(?:\.\d+)?(?:\s+day\s+\d+)?$", identity)
    return match.group(1) if match else identity


def leaf_id(record, leaf_map):
    path = Path(record["path"])
    keys = (record["path"].lower(), path.name.lower(), path.stem.lower(), source_identifier(path))
    value = next((leaf_map[k] for k in keys if k in leaf_map), None)
    if isinstance(value, list):
        if len(value) == 1:
            value = value[0]
        else:
            folder = CLASSES[record["class_index"]]["source_folder"]
            matches = [v for v in value if normalize_name(folder) in normalize_name(v)]
            if len(matches) != 1:
                raise ValueError(f"Ambiguous leaf ID: {path}")
            value = matches[0]
    if value is None:
        return f"filename:{record['class_index']}:{filename_leaf(path)}"
    if not isinstance(value, str) or not value:
        raise ValueError(f"Invalid physical-leaf ID: {path}; audit before splitting")
    return value


def split_records(records, seed=42, ratios=(0.7, 0.15, 0.15)):
    if len(ratios) != 3 or min(ratios) <= 0 or abs(sum(ratios) - 1) > 1e-8:
        raise ValueError("Three positive ratios must sum to one")
    sets, seen = DisjointSet(len(records)), {}
    for i, r in enumerate(records):
        for token in (("leaf", r["leaf_id"]), ("pixel", r["pixel_sha256"]),
                      ("source", r["class_index"], r["source_id"])):
            if token in seen:
                sets.union(i, seen[token])
            else:
                seen[token] = i
    groups = defaultdict(list)
    for i, r in enumerate(records):
        groups[sets.find(i)].append(r)
    classes = defaultdict(list)
    for group in groups.values():
        if len({r["class_index"] for r in group}) != 1:
            raise ValueError("Related/identical leaves have conflicting labels; audit source")
        group_id = hashlib.sha256("\n".join(sorted(r["path"] for r in group)).encode()).hexdigest()
        for r in group:
            r["group_id"] = group_id
        classes[group[0]["class_index"]].append(group)
    result = {split: [] for split in SPLITS}
    rng = random.Random(seed)
    for index in range(14):
        candidates = classes[index]
        if len(candidates) < 3:
            raise ValueError(f"{LABELS[index]} needs three independent leaf groups")
        rng.shuffle(candidates)
        candidates.sort(key=len, reverse=True)
        targets = [sum(map(len, candidates)) * ratio for ratio in ratios]
        counts, group_counts = [0] * 3, [0] * 3
        for offset, group in enumerate(candidates):
            empty = [i for i in range(3) if group_counts[i] == 0]
            options = empty if len(candidates) - offset == len(empty) else range(3)
            chosen = min(options, key=lambda i: sum(
                (counts[j] + (len(group) if i == j else 0) - targets[j]) ** 2 for j in range(3)))
            counts[chosen] += len(group)
            group_counts[chosen] += 1
            result[SPLITS[chosen]].extend(group)
    return {k: sorted(v, key=lambda r: r["path"]) for k, v in result.items()}


def prepare(root, output):
    root, output = Path(root).resolve(), Path(output).resolve()
    if output.exists():
        raise ValueError("Use a new preparation output directory")
    source = inventory()
    metadata_bytes = (HERE / "leaf-map.json").read_bytes()
    if blob_sha(metadata_bytes) != CONFIG["leaf_map_blob_sha"]:
        raise ValueError("Official leaf-map integrity mismatch")
    leaves = {k.lower().strip(): v for k, v in json.loads(metadata_bytes).items()}
    records, unique_pixels, removed = [], {}, []
    for item in source["images"]:
        path = root / item["path"]
        if blob_sha(path.read_bytes()) != item["blob_sha"]:
            raise ValueError(f"Image integrity mismatch: {path}")
        with Image.open(path) as original:
            image = ImageOps.exif_transpose(original).convert("RGB")
            digest = hashlib.sha256(str(image.size).encode() + image.tobytes()).hexdigest()
        if digest in unique_pixels:
            original = unique_pixels[digest]
            if original["class_index"] != item["class_index"]:
                raise ValueError("Pixel-identical images have conflicting labels")
            removed.append({"path": item["path"], "duplicate_of": original["path"]})
            continue
        record = {**item, "pixel_sha256": digest, "leaf_id": leaf_id(item, leaves),
                  "source_id": filename_leaf(path)}
        unique_pixels[digest] = record
        records.append(record)
    splits = split_records(records, CONFIG["seed"], tuple(CONFIG["ratios"]))
    output.mkdir(parents=True)
    manifest = {"format_version": 1, "dataset_root": str(root), "class_to_idx": MAPPING,
                "seed": CONFIG["seed"], "source_commit": CONFIG["source_commit"], "splits": splits}
    validate_splits(manifest)
    counts = {label: {s: sum(r["class_index"] == i for r in splits[s]) for s in SPLITS}
              for i, label in enumerate(LABELS)}
    group_counts = {label: {s: len({r["group_id"] for r in splits[s] if r["class_index"] == i})
                          for s in SPLITS} for i, label in enumerate(LABELS)}
    report = {"source_images": len(source["images"]), "retained_images": len(records),
              "official_leaf_metadata_matches": sum(not r["leaf_id"].startswith("filename:") for r in records),
              "filename_leaf_fallbacks": sum(r["leaf_id"].startswith("filename:") for r in records),
              "removed_exact_duplicates": removed, "images_per_class": counts,
              "leaf_groups_per_class": group_counts, "license": CONFIG["license"],
              "inventory_sha256": sha256(HERE / "source_inventory.json"),
              "warnings": ["Unknown near-duplicate/collection relationships may remain.",
                           "Controlled-background test metrics do not establish field robustness.",
                           "Potato Healthy has only 152 original files; inspect held-out leaf support."]}
    write_json(output / "split_manifest.json", manifest)
    write_json(output / "dataset_report.json", report)
    write_json(output / "class_mapping.json", MAPPING)
    print(json.dumps(report, indent=2))


def validate_splits(manifest):
    if manifest["class_to_idx"] != MAPPING:
        raise ValueError("Fourteen-class index ordering mismatch")
    owners = {}
    for split in SPLITS:
        if {r["class_index"] for r in manifest["splits"][split]} != set(range(14)):
            raise ValueError("Every partition must represent all fourteen classes")
        for r in manifest["splits"][split]:
            path = Path(r["path"])
            if path.is_absolute() or ".." in path.parts:
                raise ValueError("Unsafe image path")
            for token in (("path", r["path"]), ("pixel", r["pixel_sha256"]),
                          ("group", r["group_id"]), ("leaf", r["leaf_id"]),
                          ("source", r["class_index"], r["source_id"])):
                if token in owners and owners[token] != split:
                    raise ValueError("Training/validation/test leakage")
                owners[token] = split


class Leaves(Dataset):
    def __init__(self, records, root, transform):
        self.records, self.root, self.transform = records, Path(root), transform

    def __len__(self):
        return len(self.records)

    def __getitem__(self, index):
        record = self.records[index]
        with Image.open(self.root / record["path"]) as source:
            image = ImageOps.exif_transpose(source).convert("RGB")
        return self.transform(image), record["class_index"]


def build_model(pretrained=False):
    model = mobilenet_v3_small(weights=MobileNet_V3_Small_Weights.IMAGENET1K_V1 if pretrained else None)
    model.classifier[-1] = nn.Linear(model.classifier[-1].in_features, 14)
    return model


def calculate_metrics(targets, predictions):
    if not targets or len(targets) != len(predictions) or not set(targets).issubset(range(14)) \
            or not set(predictions).issubset(range(14)):
        raise ValueError("Invalid fourteen-class evaluation inputs")
    report = classification_report(targets, predictions, labels=list(range(14)),
                                   target_names=LABELS, output_dict=True, zero_division=0)
    return {"test_samples": len(targets), "accuracy": accuracy_score(targets, predictions),
            "f1_macro": report["macro avg"]["f1-score"],
            "per_class": {label: report[label] for label in LABELS},
            "confusion_matrix": confusion_matrix(targets, predictions, labels=list(range(14))).tolist(),
            "class_order": LABELS, "crop_filtering": "none; global fourteen-class argmax"}


def train(prepared, output, epochs=30, patience=5, batch_size=64):
    if not torch.cuda.is_available():
        raise RuntimeError("Google Colab CUDA GPU required; choose Runtime > Change runtime type > T4 GPU")
    output = Path(output).resolve()
    if output.exists():
        raise ValueError("Refusing to overwrite any previous run; use a new output directory")
    prepared = Path(prepared)
    manifest = json.loads((prepared / "split_manifest.json").read_text())
    validate_splits(manifest)
    # Recheck all files at the training boundary, rather than trusting an editable manifest.
    pinned = {r["path"]: r for r in inventory()["images"]}
    for records in manifest["splits"].values():
        for record in records:
            original = pinned[record["path"]]
            if record["class_index"] != original["class_index"] or blob_sha(
                (Path(manifest["dataset_root"]) / record["path"]).read_bytes()) != original["blob_sha"]:
                raise ValueError("Training input no longer matches pinned original")
    seed = CONFIG["seed"]
    random.seed(seed)
    np.random.seed(seed)
    torch.manual_seed(seed)
    torch.cuda.manual_seed_all(seed)
    torch.backends.cudnn.benchmark = False
    torch.backends.cudnn.deterministic = True
    torch.use_deterministic_algorithms(True, warn_only=True)
    loaders = {split: DataLoader(Leaves(manifest["splits"][split], manifest["dataset_root"],
                                       training_transform() if split == "train" else inference_transform()),
                                batch_size=batch_size, shuffle=split == "train", num_workers=0,
                                pin_memory=True, generator=torch.Generator().manual_seed(seed))
               for split in SPLITS}
    counts = Counter(r["class_index"] for r in manifest["splits"]["train"])
    weights = torch.tensor([min(4.0, len(loaders["train"].dataset) / (14 * counts[i]))
                            for i in range(14)], device="cuda")
    model = build_model(pretrained=True).cuda()
    # Frozen feature warm-up, then a lower-rate full-network fine-tuning stage.
    for parameter in model.features.parameters():
        parameter.requires_grad_(False)
    optimizer = torch.optim.AdamW(model.classifier.parameters(), lr=1e-3, weight_decay=1e-4)
    train_loss = nn.CrossEntropyLoss(weight=weights)
    validation_loss = nn.CrossEntropyLoss()
    output.mkdir(parents=True)
    best, stale, history = float("inf"), 0, []
    for epoch in range(1, epochs + 1):
        if epoch == 4:
            for parameter in model.features.parameters():
                parameter.requires_grad_(True)
            optimizer = torch.optim.AdamW([
                {"params": model.features.parameters(), "lr": 1e-4},
                {"params": model.classifier.parameters(), "lr": 3e-4}], weight_decay=1e-4)
        metrics = {"epoch": epoch}
        for split in ("train", "validation"):
            training = split == "train"
            model.train(training)
            if training and epoch < 4:
                model.features.eval()
            total_loss, correct, total = 0., 0, 0
            with torch.set_grad_enabled(training):
                for images, targets in loaders[split]:
                    images, targets = images.cuda(), targets.cuda()
                    if training:
                        optimizer.zero_grad(set_to_none=True)
                    logits = model(images)
                    loss = (train_loss if training else validation_loss)(logits, targets)
                    if not torch.isfinite(loss) or not torch.isfinite(logits).all():
                        raise RuntimeError("Non-finite training output")
                    if training:
                        loss.backward()
                        optimizer.step()
                    total_loss += loss.item() * len(targets)
                    correct += (logits.argmax(1) == targets).sum().item()
                    total += len(targets)
            metrics[split + "_loss"] = total_loss / total
            metrics[split + "_accuracy"] = correct / total
        history.append(metrics)
        write_json(output / "history.json", history)
        print(json.dumps(metrics), flush=True)
        if metrics["validation_loss"] < best - 1e-4:
            best, stale = metrics["validation_loss"], 0
            torch.save({"format_version": 1, "architecture": "mobilenet_v3_small",
                        "trained_epochs": epoch, "class_to_idx": MAPPING, "preprocessing": PREPROCESSING,
                        "state_dict": {k: v.cpu() for k, v in model.state_dict().items()},
                        "source_commit": CONFIG["source_commit"], "seed": seed,
                        "split_manifest_sha256": sha256(prepared / "split_manifest.json"),
                        "initialization": "IMAGENET1K_V1", "validation_loss": best},
                       output / "best_model.pt")
        else:
            stale += 1
        if epoch >= 4 and stale >= patience:
            break
    checkpoint = torch.load(output / "best_model.pt", weights_only=True, map_location="cpu")
    model.load_state_dict(checkpoint["state_dict"], strict=True)
    model.eval()
    targets, predictions = [], []
    with torch.inference_mode():
        for images, labels in loaders["test"]:
            logits = model(images.cuda())
            if not torch.isfinite(logits).all():
                raise RuntimeError("Non-finite test outputs")
            targets.extend(labels.tolist())
            predictions.extend(logits.argmax(1).cpu().tolist())
    result = calculate_metrics(targets, predictions)
    result.update(checkpoint_sha256=sha256(output / "best_model.pt"),
                  split_manifest_sha256=sha256(prepared / "split_manifest.json"),
                  source_commit=CONFIG["source_commit"])
    write_json(output / "evaluation.json", result)
    write_json(output / "test_predictions.json", [
        {"path": record["path"], "actual": actual, "predicted": predicted}
        for record, actual, predicted in zip(manifest["splits"]["test"], targets, predictions, strict=True)])
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    figure, axis = plt.subplots(figsize=(14, 12))
    axis.imshow(result["confusion_matrix"], cmap="Greens")
    axis.set_xticks(range(14), LABELS, rotation=70, ha="right")
    axis.set_yticks(range(14), LABELS)
    axis.set_xlabel("Predicted")
    axis.set_ylabel("Actual")
    for row in range(14):
        for col in range(14):
            axis.text(col, row, result["confusion_matrix"][row][col], ha="center", va="center")
    figure.tight_layout()
    figure.savefig(output / "confusion_matrix.png", dpi=140)
    plt.close(figure)
    for name in ("split_manifest.json", "dataset_report.json", "class_mapping.json"):
        (output / name).write_bytes((prepared / name).read_bytes())
    (output / "dataset_config.json").write_bytes((HERE / "dataset_config.json").read_bytes())
    write_json(output / "run_metadata.json", {
        "torch": str(torch.__version__), "torchvision": __import__("torchvision").__version__,
        "gpu": torch.cuda.get_device_name(), "cuda": torch.version.cuda, "seed": seed,
        "completed_epochs": len(history), "best_epoch": checkpoint["trained_epochs"],
        "batch_size": batch_size, "patience": patience, "max_epochs": epochs,
        "preprocessing": PREPROCESSING, "class_weights": weights.cpu().tolist(),
        "loss": "capped inverse-frequency CE for training; unweighted validation CE selects best",
        "checkpoint_sha256": result["checkpoint_sha256"], "crop_filtering": "none"})
    # Fixed parity set: one held-out original per class, selected without consulting predictions.
    selected = [next(r for r in manifest["splits"]["test"] if r["class_index"] == i) for i in range(14)]
    parity_dir = output / "parity_images"
    parity_dir.mkdir()
    parity = []
    for i, record in enumerate(selected):
        source = Path(manifest["dataset_root"]) / record["path"]
        target = parity_dir / (str(i).zfill(2) + source.suffix.lower())
        target.write_bytes(source.read_bytes())
        parity.append({"path": str(target.relative_to(output)), "sha256": sha256(target),
                       "class_index": i, "source_class": CLASSES[i]["source_folder"],
                       "source_path": record["path"]})
    write_json(output / "parity_images.json", {"images": parity})
    print(json.dumps(result, indent=2))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("download", "prepare", "train"))
    parser.add_argument("--dataset-root", type=Path, default=Path("data/phase4_rgb"))
    parser.add_argument("--prepared", type=Path, default=Path("artifacts/phase4_prepared"))
    parser.add_argument("--output", type=Path, default=Path("artifacts/phase4_run"))
    parser.add_argument("--epochs", type=int, default=30)
    parser.add_argument("--patience", type=int, default=5)
    parser.add_argument("--batch-size", type=int, default=64)
    args = parser.parse_args()
    if args.epochs < 1 or args.patience < 1 or args.batch_size < 1:
        parser.error("Epochs, patience and batch size must be positive")
    if args.action == "download":
        download(args.dataset_root)
    elif args.action == "prepare":
        prepare(args.dataset_root, args.prepared)
    else:
        train(args.prepared, args.output, args.epochs, args.patience, args.batch_size)


if __name__ == "__main__":
    main()
