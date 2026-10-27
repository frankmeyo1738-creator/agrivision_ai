"""Meaningful safety gates for derived-model packaging (no training)."""

import hashlib
import json
from pathlib import Path

import pytest

from deployment.android.bundle_model import bundle

ROOT = Path(__file__).resolve().parents[2]


def test_real_source_checkpoint_and_bundled_model_match_verified_conversion():
    report = json.loads((ROOT / "docs/android/conversion_verification.json").read_text())
    source = ROOT / "models/best_model.pt"
    converted = ROOT / "frontend/assets/models/tomato_mobilenet_v3_small.onnx"
    if not source.exists() or not converted.exists():
        pytest.skip("Local trained/derived model artifacts are intentionally not tracked in Git.")
    assert hashlib.sha256(source.read_bytes()).hexdigest() == report["source_checkpoint_sha256"]
    assert hashlib.sha256(converted.read_bytes()).hexdigest() == report["model_sha256"]
    assert report["passed"]
    assert len(report["cases"]) == 5
    assert all(case["passed"] for case in report["cases"])


def test_failed_report_cannot_be_bundled(tmp_path):
    source = tmp_path / "source"
    source.mkdir()
    (source / "conversion_verification.json").write_text(json.dumps({"passed": False}))
    (source / "model_manifest.json").write_text("{}")
    with pytest.raises(ValueError, match="passing real conversion"):
        bundle(source, tmp_path / "destination")
    assert not (tmp_path / "destination").exists()
