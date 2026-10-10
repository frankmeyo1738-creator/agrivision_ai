"""The explicit label order is a contract, never inferred from directory sorting."""

import json
from pathlib import Path

CLASS_NAMES = (
    "Tomato Healthy",
    "Tomato Early Blight",
    "Tomato Late Blight",
    "Tomato Bacterial Spot",
    "Tomato Leaf Mold",
)
PLANTVILLAGE_NAMES = (
    "Tomato___healthy",
    "Tomato___Early_blight",
    "Tomato___Late_blight",
    "Tomato___Bacterial_spot",
    "Tomato___Leaf_Mold",
)
CLASS_TO_IDX = {name: index for index, name in enumerate(CLASS_NAMES)}


def validate_mapping(mapping: object) -> dict[str, int]:
    if not isinstance(mapping, dict) or mapping != CLASS_TO_IDX:
        raise ValueError("Class mapping must match the five documented AgriVision class indices.")
    if any(type(index) is not int for index in mapping.values()):
        raise ValueError("Class indices must be integers.")
    return dict(mapping)


def load_mapping(path: Path) -> dict[str, int]:
    return validate_mapping(json.loads(path.read_text(encoding="utf-8")))


def save_mapping(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(CLASS_TO_IDX, indent=2) + "\n", encoding="utf-8")
