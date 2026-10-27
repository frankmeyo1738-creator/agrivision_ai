"""Synthetic fixtures test split logic, not disease model performance."""

import copy

import pytest

from backend.app.ml.model import PREPROCESSING, inference_transform
from training.multicrop import pipeline as p


def records():
    return [{"path": f"{i}/photo{j}.jpg", "class_index": i,
             "leaf_id": f"leaf:{i}:{j // 2}", "source_id": f"source:{i}:{j // 2}",
             "pixel_sha256": f"pixels:{i}:{j}"} for i in range(14) for j in range(20)]


def test_exact_taxonomy_and_original_inventory():
    assert p.LABELS == [
        "Tomato Healthy", "Tomato Early Blight", "Tomato Late Blight", "Tomato Bacterial Spot", "Tomato Leaf Mold",
        "Maize Healthy", "Maize Common Rust", "Maize Gray Leaf Spot", "Maize Northern Leaf Blight",
        "Potato Healthy", "Potato Early Blight", "Potato Late Blight", "Bell Pepper Healthy", "Bell Pepper Bacterial Spot"]
    assert list(p.MAPPING.values()) == list(range(14))
    assert len(p.inventory()["images"]) == 16058
    assert p.CLASSES[9]["expected_images"] == 152


def test_leaf_groups_are_indivisible_and_split_is_reproducible():
    first = p.split_records(records())
    assert first == p.split_records(records())
    p.validate_splits({"class_to_idx": p.MAPPING, "splits": first})
    assert sum(map(len, first.values())) == 280
    assert all({r["class_index"] for r in partition} == set(range(14)) for partition in first.values())


def test_cross_class_pixel_duplicates_are_rejected():
    items = records()
    items[20]["pixel_sha256"] = items[0]["pixel_sha256"]
    with pytest.raises(ValueError, match="conflicting"):
        p.split_records(items)


def test_manifest_leakage_and_order_changes_are_rejected():
    manifest = {"class_to_idx": p.MAPPING, "splits": p.split_records(records())}
    leaked = copy.deepcopy(manifest)
    leaked["splits"]["test"].append(leaked["splits"]["train"][0])
    with pytest.raises(ValueError, match="leakage"):
        p.validate_splits(leaked)
    changed = copy.deepcopy(manifest)
    changed["class_to_idx"]["Maize Healthy"] = 6
    with pytest.raises(ValueError, match="ordering"):
        p.validate_splits(changed)


def test_repeated_leaf_day_and_view_names_group_together():
    assert p.filename_leaf("uuid___GH_HL Leaf 259.1.JPG") == p.filename_leaf("other___GH_HL Leaf 259.2.JPG")
    assert p.filename_leaf("uuid___GHLB Leaf 2.1 Day 16.JPG") == p.filename_leaf("uuid___GHLB Leaf 2.2 Day 9.JPG")


def test_metrics_use_actual_supplied_predictions_for_all_fourteen_classes():
    result = p.calculate_metrics(list(range(14)), [0] * 14)
    assert result["accuracy"] == 1 / 14
    assert result["per_class"]["Bell Pepper Bacterial Spot"]["recall"] == 0
    assert len(result["confusion_matrix"]) == 14


def test_preprocessing_reuses_the_original_transform():
    assert p.inference_transform is inference_transform
    assert p.PREPROCESSING == PREPROCESSING
    model = p.build_model()
    assert model.classifier[-1].out_features == 14


def test_training_requires_gpu_and_cannot_fall_back_to_cpu(tmp_path, monkeypatch):
    monkeypatch.setattr(p.torch.cuda, "is_available", lambda: False)
    with pytest.raises(RuntimeError, match="Colab CUDA GPU required"):
        p.train(tmp_path / "prepared", tmp_path / "run")
    assert not (tmp_path / "run").exists()


def test_conversion_rejects_an_untrained_checkpoint(tmp_path):
    from training.multicrop.convert import validate_run
    p.torch.save({"format_version": 1, "architecture": "mobilenet_v3_small", "trained_epochs": 0},
                 tmp_path / "best_model.pt")
    p.write_json(tmp_path / "evaluation.json", {})
    p.write_json(tmp_path / "split_manifest.json", {
        "class_to_idx": p.MAPPING, "splits": p.split_records(records())})
    with pytest.raises(ValueError, match="completed training"):
        validate_run(tmp_path)


def test_notebook_code_compiles_and_package_contains_no_models_or_images(tmp_path):
    import json
    import zipfile
    from training.multicrop.package_colab import package
    notebook = json.loads((p.HERE / "AgriVision_Multicrop_Training.ipynb").read_text())
    for cell in notebook["cells"]:
        if cell["cell_type"] == "code":
            compile("".join(cell["source"]), "colab_cell", "exec")
            assert cell["execution_count"] is None and cell["outputs"] == []
    output = tmp_path / "source.zip"
    package(output)
    with zipfile.ZipFile(output) as archive:
        names = archive.namelist()
        assert "training/multicrop/source_inventory.json" in names
        assert "training/multicrop/leaf-map.json" in names
        assert not any(name.endswith((".pt", ".onnx", ".jpg", ".png", ".apk")) for name in names)
