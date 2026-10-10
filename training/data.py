"""Manifest-backed loading without ImageFolder's alphabetical index remapping."""

import json
from pathlib import Path

from PIL import Image, ImageOps
from torch.utils.data import Dataset

from backend.app.ml.classes import CLASS_NAMES, validate_mapping


def load_manifest(path: Path, dataset_root: Path | None = None) -> tuple[dict, Path]:
    manifest = json.loads(path.read_text(encoding="utf-8"))
    if manifest.get("format_version") != 1:
        raise ValueError("Unsupported split manifest version.")
    validate_mapping(manifest.get("class_to_idx"))
    root = (dataset_root or Path(manifest["dataset_root"])).resolve()
    owners = {}
    hashes = {}
    paths = set()
    for split in ("train", "validation", "test"):
        records = manifest["splits"][split]
        if {r["class_index"] for r in records} != set(range(len(CLASS_NAMES))):
            raise ValueError(f"{split} must contain all five classes.")
        for record in records:
            relative = Path(record["path"])
            if relative.is_absolute() or not (root / relative).resolve().is_relative_to(root):
                raise ValueError("Manifest contains an unsafe image path.")
            if record["path"] in paths:
                raise ValueError("An image path appears more than once.")
            paths.add(record["path"])
            for registry, identifier in (
                (owners, record["group_id"]),
                (hashes, record["pixel_sha256"]),
            ):
                if identifier in registry and registry[identifier] != split:
                    raise ValueError("Related/duplicate images overlap between splits.")
                registry[identifier] = split
    return manifest, root


class LeafDataset(Dataset):
    def __init__(self, records: list[dict], root: Path, transform):
        self.records = records
        self.root = root
        self.transform = transform

    def __len__(self) -> int:
        return len(self.records)

    def __getitem__(self, index: int):
        record = self.records[index]
        with Image.open(self.root / record["path"]) as image:
            tensor = self.transform(ImageOps.exif_transpose(image).convert("RGB"))
        return tensor, record["class_index"]
