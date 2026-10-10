import io

import pytest
import torch
from PIL import Image

from backend.app.ml.classes import CLASS_NAMES, CLASS_TO_IDX, validate_mapping
from backend.app.ml.images import (
    MAX_UPLOAD_BYTES,
    ImageTooLargeError,
    InvalidImageError,
    UnsupportedImageError,
    decode_image,
)
from backend.app.ml.inference import InferenceEngine, ModelUnavailableError
from backend.app.ml.model import inference_transform


def test_explicit_mapping_and_invalid_mapping():
    assert CLASS_TO_IDX["Tomato Healthy"] == 0
    assert CLASS_TO_IDX["Tomato Bacterial Spot"] == 3
    with pytest.raises(ValueError):
        validate_mapping(dict(reversed(list(enumerate(CLASS_NAMES)))))
    with pytest.raises(ValueError):
        validate_mapping({**CLASS_TO_IDX, "Tomato Healthy": False})


def test_missing_weights_do_not_generate_predictions(tmp_path, image_bytes):
    engine = InferenceEngine(tmp_path)
    with pytest.raises(ModelUnavailableError, match="missing"):
        engine.load()
    assert not engine.loaded
    with pytest.raises(ModelUnavailableError):
        engine.predict_bytes(image_bytes)


@pytest.mark.parametrize(
    "overrides",
    [
        {"architecture": "other"},
        {"trained_epochs": 0},
        {"class_to_idx": {}},
        {"preprocessing": {}},
        {"state_dict": {}},
    ],
)
def test_checkpoint_contract_rejects_incompatible_files(checkpoint_factory, overrides):
    engine = InferenceEngine(checkpoint_factory(**overrides))
    with pytest.raises(ModelUnavailableError, match="invalid or incompatible"):
        engine.load()
    assert not engine.loaded


def test_corrupt_checkpoint_is_unavailable(tmp_path):
    (tmp_path / "best_model.pt").write_bytes(b"broken")
    (tmp_path / "class_mapping.json").write_text("{}")
    with pytest.raises(ModelUnavailableError):
        InferenceEngine(tmp_path).load()


def test_real_forward_pass_top_three_and_softmax(checkpoint_factory, image_bytes):
    # These synthetic weights only exercise the inference implementation, not accuracy.
    engine = InferenceEngine(checkpoint_factory())
    engine.load()
    result = engine.predict_bytes(image_bytes)
    image = decode_image(image_bytes)
    with torch.inference_mode():
        probabilities = engine.model(engine.transform(image).unsqueeze(0)).softmax(1)[0]
    assert probabilities.sum().item() == pytest.approx(1.0)
    top = result["top_predictions"]
    assert len(top) == 3
    assert len({p["class"] for p in top}) == 3
    assert [p["confidence"] for p in top] == sorted([p["confidence"] for p in top], reverse=True)
    assert result["predicted_class"] == top[0]["class"]
    for prediction in top:
        assert prediction["confidence"] == pytest.approx(
            probabilities[CLASS_TO_IDX[prediction["class"]]].item()
        )
    assert engine.predict_bytes(image_bytes) == result


def test_preprocessing_is_deterministic_rgb_and_224(image_bytes):
    image = decode_image(image_bytes)
    transform = inference_transform()
    tensor = transform(image)
    assert tensor.shape == (3, 224, 224)
    assert torch.equal(tensor, transform(image))
    assert image.mode == "RGB"


@pytest.mark.parametrize("data", [b"", b"not an image"])
def test_invalid_image(data):
    with pytest.raises(InvalidImageError):
        decode_image(data)


def test_upload_size_limit():
    with pytest.raises(ImageTooLargeError):
        decode_image(b"x" * (MAX_UPLOAD_BYTES + 1))


def test_actual_format_is_validated_even_if_named_png():
    buffer = io.BytesIO()
    Image.new("RGB", (10, 10)).save(buffer, format="GIF")
    with pytest.raises(UnsupportedImageError):
        decode_image(buffer.getvalue())


def test_grayscale_decodes_as_rgb():
    buffer = io.BytesIO()
    Image.new("L", (10, 10)).save(buffer, format="PNG")
    assert decode_image(buffer.getvalue()).mode == "RGB"
