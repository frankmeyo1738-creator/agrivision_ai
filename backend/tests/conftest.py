import io

import pytest
import torch
from PIL import Image

from backend.app.ml.classes import CLASS_TO_IDX, save_mapping
from backend.app.ml.model import PREPROCESSING, build_model


@pytest.fixture(scope="session", autouse=True)
def limit_threads():
    torch.set_num_threads(2)


@pytest.fixture
def image_bytes():
    buffer = io.BytesIO()
    Image.new("RGB", (256, 256), (30, 100, 40)).save(buffer, format="PNG")
    return buffer.getvalue()


@pytest.fixture
def checkpoint_factory(tmp_path):
    """Random test-only weights verify serialization; never a disease-trained artifact."""

    def make(**overrides):
        torch.manual_seed(7)
        model = build_model(pretrained=False)
        checkpoint = {
            "format_version": 1,
            "architecture": "mobilenet_v3_small",
            "trained_epochs": 1,
            "class_to_idx": CLASS_TO_IDX,
            "preprocessing": PREPROCESSING,
            "state_dict": model.state_dict(),
        }
        checkpoint.update(overrides)
        save_mapping(tmp_path / "class_mapping.json")
        torch.save(checkpoint, tmp_path / "best_model.pt")
        return tmp_path

    return make
