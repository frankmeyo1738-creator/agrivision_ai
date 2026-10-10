import pytest
from PIL import Image

from backend.app.ml.classes import PLANTVILLAGE_NAMES


@pytest.fixture
def tiny_dataset(tmp_path):
    """Distinct synthetic images; deliberately not a substitute for PlantVillage."""
    root = tmp_path / "dataset"
    for class_index, folder in enumerate(PLANTVILLAGE_NAMES):
        directory = root / "raw" / "color" / folder
        directory.mkdir(parents=True)
        for index in range(20):
            Image.new("RGB", (24, 24), (class_index * 40, index * 10, 30)).save(
                directory / f"uuid-{index}___leaf-{class_index}-{index}.png"
            )
    return root
