"""Create a deterministic, per-class stratified split of indivisible image groups.

Only manifests are written: source images are never copied or modified. Union-find
keeps overlapping filename, leaf metadata, and decoded-pixel duplicate groups intact.
"""

import argparse
import hashlib
import json
import random
import re
from collections import defaultdict
from pathlib import Path

from PIL import Image, ImageOps

from backend.app.ml.classes import CLASS_NAMES, CLASS_TO_IDX, PLANTVILLAGE_NAMES, save_mapping

EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp"}
SPLIT_NAMES = ("train", "validation", "test")


def normalize_name(value: str) -> str:
    return re.sub(r"[^a-z0-9]", "", value.lower())


def source_identifier(path: Path) -> str:
    """Strip UUID prefix and common copy/augmentation suffixes, preserving leaf IDs."""
    stem = path.stem.split("___")[-1].lower().strip()
    stem = re.sub(r"_final_masked$", "", stem)
    stem = re.sub(r"(?:[ _-]*(?:copy|aug|rotated|flip)(?:[ _()-]*\d+)?)$", "", stem)
    return stem.strip()


def discover_classes(root: Path) -> dict[str, Path]:
    if not root.is_dir():
        raise ValueError(f"Dataset directory does not exist: {root}. See docs/dataset.md.")
    # Prefer RGB color data and refuse to silently mix color/segmented/grayscale versions.
    candidates = [root / "raw" / "color", root / "color", root / "PlantVillage", root]
    aliases = {
        normalize_name(pv): display
        for pv, display in zip(PLANTVILLAGE_NAMES, CLASS_NAMES, strict=True)
    }
    aliases.update({normalize_name(display): display for display in CLASS_NAMES})
    best = {}
    for candidate in candidates:
        if not candidate.is_dir():
            continue
        found = {}
        for directory in sorted(candidate.iterdir()):
            if directory.is_dir() and normalize_name(directory.name) in aliases:
                display = aliases[normalize_name(directory.name)]
                if display in found:
                    raise ValueError(f"Multiple folders for {display}; select one dataset variant.")
                found[display] = directory
        if len(found) == len(CLASS_NAMES):
            return found
        if len(found) > len(best):
            best = found
    missing = sorted(set(CLASS_NAMES) - set(best))
    raise ValueError("Missing required class folders: " + ", ".join(missing))


def load_leaf_groups(path: Path | None, root: Path) -> tuple[dict, Path | None]:
    if path is None:
        for base in (root, root.parent, root.parent.parent):
            options = (base / "leaf-map.json", base / "leaf_grouping" / "leaf-map.json")
            path = next((p for p in options if p.is_file()), None)
            if path is not None:
                break
    if path is None:
        return {}, None
    mapping = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(mapping, dict):
        raise ValueError("Leaf groups JSON must map filename/source identifiers to group IDs.")
    normalized = {}
    for key, value in mapping.items():
        if not isinstance(key, str) or not isinstance(value, (str, list)):
            raise ValueError("Leaf groups must use string keys and string or list-of-string IDs.")
        if isinstance(value, list) and (not value or any(not isinstance(v, str) for v in value)):
            raise ValueError("Leaf group ID lists must contain strings.")
        if isinstance(value, str) and not value.strip():
            raise ValueError("Leaf group IDs cannot be empty.")
        normalized[key.lower().strip()] = value
    return normalized, path


def metadata_group(path: Path, relative: str, class_name: str, mapping: dict) -> str | None:
    keys = (relative.lower(), path.name.lower(), path.stem.lower(), source_identifier(path))
    value = next((mapping[key] for key in keys if key in mapping), None)
    if value is None:
        return None
    if isinstance(value, str):
        return value
    if len(value) == 1:
        return value[0]
    pv = PLANTVILLAGE_NAMES[CLASS_TO_IDX[class_name]]
    matches = [v for v in value if normalize_name(pv) in normalize_name(v)]
    if len(matches) != 1:
        raise ValueError(f"Ambiguous leaf metadata for {path.name}; provide a resolved group ID.")
    return matches[0]


class DisjointSet:
    def __init__(self, size: int):
        self.parents = list(range(size))

    def find(self, index: int) -> int:
        while self.parents[index] != index:
            self.parents[index] = self.parents[self.parents[index]]
            index = self.parents[index]
        return index

    def union(self, first: int, second: int) -> None:
        self.parents[self.find(second)] = self.find(first)


def prepare_dataset(
    dataset_root: Path,
    output_dir: Path,
    *,
    seed: int = 42,
    ratios: tuple[float, float, float] = (0.7, 0.15, 0.15),
    leaf_groups: Path | None = None,
) -> dict:
    if len(ratios) != 3 or any(r <= 0 for r in ratios) or abs(sum(ratios) - 1) > 1e-8:
        raise ValueError("Train, validation, and test ratios must be positive and sum to 1.")
    root = dataset_root.resolve()
    folders = discover_classes(root)
    mapping, mapping_path = load_leaf_groups(leaf_groups, root)
    records = []
    metadata_matches = 0
    for class_name in CLASS_NAMES:
        paths = sorted(p for p in folders[class_name].rglob("*") if p.suffix.lower() in EXTENSIONS)
        if not paths:
            raise ValueError(f"No supported images in {folders[class_name]}.")
        for path in paths:
            relative = path.relative_to(root).as_posix()
            try:
                with Image.open(path) as source:
                    if source.width * source.height > 20_000_000:
                        raise ValueError("More than 20 megapixels")
                    image = ImageOps.exif_transpose(source).convert("RGB")
                    digest = hashlib.sha256(
                        str(image.size).encode() + image.tobytes()
                    ).hexdigest()
            except (OSError, ValueError, Image.DecompressionBombError) as exc:
                raise ValueError(f"Cannot decode dataset image: {relative}") from exc
            leaf_id = metadata_group(path, relative, class_name, mapping)
            metadata_matches += leaf_id is not None
            records.append({
                "path": relative,
                "class_index": CLASS_TO_IDX[class_name],
                "pixel_sha256": digest,
                "source_id": source_identifier(path),
                "leaf_id": leaf_id,
            })

    sets = DisjointSet(len(records))
    seen = {}
    for index, record in enumerate(records):
        # Pixel identity is global; related names are scoped to the annotated class.
        tokens = [("pixels", record["pixel_sha256"]),
                  ("source", record["class_index"], record["source_id"])]
        if record["leaf_id"] is not None:
            tokens.append(("leaf", record["leaf_id"]))
        for token in tokens:
            if token in seen:
                sets.union(seen[token], index)
            else:
                seen[token] = index
    groups = defaultdict(list)
    for index, record in enumerate(records):
        groups[sets.find(index)].append(record)
    by_class = defaultdict(list)
    for group in groups.values():
        labels = {r["class_index"] for r in group}
        if len(labels) != 1:
            raise ValueError("Duplicate/related images have conflicting class labels; audit dataset.")
        # Stable group ID survives reordering and records every transitive relationship.
        group_id = hashlib.sha256("\n".join(sorted(r["path"] for r in group)).encode()).hexdigest()
        for record in group:
            record["group_id"] = group_id
        by_class[group[0]["class_index"]].append(group)

    splits = {name: [] for name in SPLIT_NAMES}
    counts = {}
    group_counts = {}
    rng = random.Random(seed)
    for class_index, class_name in enumerate(CLASS_NAMES):
        class_groups = by_class[class_index]
        if len(class_groups) < 3:
            raise ValueError(f"{class_name} requires at least 3 independent groups for three splits.")
        rng.shuffle(class_groups)
        class_groups.sort(key=len, reverse=True)  # Seeded order breaks equal-size ties.
        total = sum(map(len, class_groups))
        targets = [total * ratio for ratio in ratios]
        assigned = [0, 0, 0]
        assigned_groups = [0, 0, 0]
        for offset, group in enumerate(class_groups):
            empty = [i for i, number in enumerate(assigned_groups) if number == 0]
            remaining = len(class_groups) - offset
            options = empty if remaining == len(empty) else range(3)
            # Minimize the squared deviation from desired per-class image counts.
            selected = min(options, key=lambda i: sum(
                (assigned[j] + (len(group) if i == j else 0) - targets[j]) ** 2
                for j in range(3)
            ))
            assigned[selected] += len(group)
            assigned_groups[selected] += 1
            splits[SPLIT_NAMES[selected]].extend(group)
        counts[class_name] = dict(zip(SPLIT_NAMES, assigned, strict=True))
        group_counts[class_name] = dict(zip(SPLIT_NAMES, assigned_groups, strict=True))

    manifest = {
        "format_version": 1,
        "dataset_root": str(root),
        "seed": seed,
        "requested_ratios": dict(zip(SPLIT_NAMES, ratios, strict=True)),
        "class_to_idx": CLASS_TO_IDX,
        "splits": {key: sorted(value, key=lambda r: r["path"]) for key, value in splits.items()},
    }
    report = {
        "images_per_class": counts,
        "groups_per_class": group_counts,
        "total_images": len(records),
        "independent_groups": len(groups),
        "duplicate_pixel_images": len(records) - len({r["pixel_sha256"] for r in records}),
        "leaf_metadata_path": str(mapping_path) if mapping_path else None,
        "leaf_metadata_matches": metadata_matches,
        "warnings": [
            "Unknown related leaves and recompressed/renamed duplicates may remain. "
            "Audit leaf IDs before claiming field generalization.",
            "Split ratios are approximate to keep every group indivisible.",
        ],
    }
    output_dir.mkdir(parents=True, exist_ok=True)
    for name, payload in (("split_manifest.json", manifest), ("dataset_report.json", report)):
        (output_dir / name).write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    save_mapping(output_dir / "class_mapping.json")
    return report


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dataset-root", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, default=Path("artifacts/prepared"))
    parser.add_argument("--leaf-groups", type=Path)
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--ratios", nargs=3, type=float, default=(0.7, 0.15, 0.15))
    args = parser.parse_args()
    try:
        report = prepare_dataset(args.dataset_root, args.output_dir, seed=args.seed,
                                 ratios=tuple(args.ratios), leaf_groups=args.leaf_groups)
        print(json.dumps(report, indent=2))
    except (ValueError, OSError) as exc:
        parser.exit(1, f"Dataset preparation failed: {exc}\n")


if __name__ == "__main__":
    main()
