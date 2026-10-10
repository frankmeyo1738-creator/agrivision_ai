import io

import pytest
from fastapi.testclient import TestClient
from PIL import Image

from backend.app.main import create_app
from backend.app.ml.images import MAX_UPLOAD_BYTES


def test_health_and_missing_model_503(tmp_path, image_bytes):
    with TestClient(create_app(tmp_path)) as client:
        response = client.get("/health")
        assert response.status_code == 200
        assert response.json()["status"] == "ok"
        assert response.json()["model_loaded"] is False
        assert "Train in Colab" in response.json()["model_message"]
        response = client.post("/predict", files={"image": ("leaf.png", image_bytes, "image/png")})
        assert response.status_code == 503
        assert "missing" in response.json()["detail"]


@pytest.mark.parametrize(
    "filename,data,mime,status",
    [
        ("a.txt", b"text", "text/plain", 415),
        ("a.png", b"corrupt", "image/png", 400),
        ("a.png", b"", "image/png", 400),
        ("a.jpg", b"x" * (MAX_UPLOAD_BYTES + 1), "image/jpeg", 413),
    ],
)
def test_invalid_uploads(tmp_path, filename, data, mime, status):
    with TestClient(create_app(tmp_path)) as client:
        response = client.post("/predict", files={"image": (filename, data, mime)})
        assert response.status_code == status


def test_unsupported_decoded_format(tmp_path):
    buffer = io.BytesIO()
    Image.new("RGB", (10, 10)).save(buffer, format="GIF")
    with TestClient(create_app(tmp_path)) as client:
        response = client.post(
            "/predict", files={"image": ("leaf.png", buffer.getvalue(), "image/png")}
        )
        assert response.status_code == 415


def test_missing_multipart_field(tmp_path):
    with TestClient(create_app(tmp_path)) as client:
        assert client.post("/predict").status_code == 422


def test_contract_and_repeated_requests(checkpoint_factory, image_bytes):
    # Serialization/integration fixture only, not evidence of disease performance.
    with TestClient(create_app(checkpoint_factory())) as client:
        assert client.get("/health").json()["model_loaded"] is True
        for _ in range(2):
            response = client.post(
                "/predict", files={"image": ("leaf.png", image_bytes, "image/png")}
            )
            assert response.status_code == 200
            result = response.json()
            assert 0 <= result["confidence"] <= 1
            assert result["predicted_class"] == result["top_predictions"][0]["class"]
            assert len(result["top_predictions"]) == 3
            assert result["disease_information"]["description"]
            assert result["disease_information"]["management"]
            assert result["disease_information"]["prevention"]
            assert result["disease_information"]["sources"]
            assert "not diagnostic certainty" in result["confidence_note"]


def test_internal_failure_is_sanitized(checkpoint_factory, image_bytes, monkeypatch):
    with TestClient(create_app(checkpoint_factory())) as client:

        def fail(data):
            raise RuntimeError("private stack trace detail")

        monkeypatch.setattr(client.app.state.engine, "predict_bytes", fail)
        response = client.post("/predict", files={"image": ("leaf.png", image_bytes, "image/png")})
        assert response.status_code == 500
        assert "private" not in response.text
