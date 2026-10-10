import json
import shutil

import pytest
from PIL import Image

from backend.app.ml.classes import CLASS_NAMES, CLASS_TO_IDX, PLANTVILLAGE_NAMES
from training.data import load_manifest
from training.prepare_dataset import discover_classes, prepare_dataset


def test_stratified_deterministic_splits_and_mapping(tiny_dataset, tmp_path):
    output = tmp_path / "prepared"
    report = prepare_dataset(tiny_dataset, output)
    first = (output / "split_manifest.json").read_text()
    prepare_dataset(tiny_dataset, output)
    assert first == (output / "split_manifest.json").read_text()
    manifest, root = load_manifest(output / "split_manifest.json")
    assert root == tiny_dataset.resolve()
    assert manifest["class_to_idx"] == CLASS_TO_IDX
    assert report["total_images"] == 100
    assert json.loads((output / "class_mapping.json").read_text()) == CLASS_TO_IDX
    for name in CLASS_NAMES:
        assert report["images_per_class"][name] == {"train": 14, "validation": 3, "test": 3}
    all_paths = [r["path"] for records in manifest["splits"].values() for r in records]
    assert len(set(all_paths)) == 100
    prepare_dataset(tiny_dataset, tmp_path / "other", seed=100)
    assert first != (tmp_path / "other/split_manifest.json").read_text()


def test_duplicates_and_related_groups_never_cross_splits(tiny_dataset, tmp_path):
    directory = tiny_dataset / "raw/color" / PLANTVILLAGE_NAMES[0]
    original = directory / "uuid-0___leaf-0-0.png"
    shutil.copy2(original, directory / "unrelated-name.png")
    # Filename relation has different pixels, so it is grouped independently of exact hashing.
    Image.new("RGB", (24, 24), (1, 2, 3)).save(directory / "second-uuid___leaf-0-0_copy1.png")
    groups_path = tmp_path / "leaf-map.json"
    groups_path.write_text(json.dumps({"leaf-0-0": "plant-A", "leaf-0-1": "plant-A"}))
    output = tmp_path / "prepared"
    report = prepare_dataset(tiny_dataset, output, leaf_groups=groups_path)
    manifest, _ = load_manifest(output / "split_manifest.json")
    related = {}
    for split, records in manifest["splits"].items():
        for record in records:
            if record["path"].endswith(
                ("leaf-0-0.png", "unrelated-name.png", "leaf-0-0_copy1.png", "leaf-0-1.png")
            ):
                related[record["path"]] = (split, record["group_id"])
    assert len(related) == 4
    assert len(set(related.values())) == 1
    assert report["duplicate_pixel_images"] == 1
    assert report["leaf_metadata_matches"] == 3


def test_folder_aliases_and_color_preference(tiny_dataset):
    selected = discover_classes(tiny_dataset)
    assert all("color" in str(path) for path in selected.values())
    directory = selected[CLASS_NAMES[1]]
    directory.rename(directory.with_name("Tomato_Early_blight"))
    assert discover_classes(tiny_dataset)[CLASS_NAMES[1]].name == "Tomato_Early_blight"


def test_missing_class_fails(tiny_dataset, tmp_path):
    directory = tiny_dataset / "raw/color" / PLANTVILLAGE_NAMES[4]
    directory.rename(directory.with_name("NotSelected"))
    with pytest.raises(ValueError, match="Missing required class"):
        prepare_dataset(tiny_dataset, tmp_path / "prepared")


def test_corrupt_image_fails(tiny_dataset, tmp_path):
    (tiny_dataset / "raw/color" / PLANTVILLAGE_NAMES[0] / "broken.jpg").write_bytes(b"bad")
    with pytest.raises(ValueError, match="Cannot decode"):
        prepare_dataset(tiny_dataset, tmp_path / "prepared")


def test_conflicting_duplicate_labels_fail(tiny_dataset, tmp_path):
    source = tiny_dataset / "raw/color" / PLANTVILLAGE_NAMES[0] / "uuid-0___leaf-0-0.png"
    shutil.copy2(source, tiny_dataset / "raw/color" / PLANTVILLAGE_NAMES[1] / "conflict.png")
    with pytest.raises(ValueError, match="conflicting class labels"):
        prepare_dataset(tiny_dataset, tmp_path / "prepared")


@pytest.mark.parametrize("ratios", [(0.5, 0.3, 0.3), (1.0, 0.0, 0.0), (-0.1, 0.5, 0.6)])
def test_invalid_ratios(tiny_dataset, tmp_path, ratios):
    with pytest.raises(ValueError, match="ratios"):
        prepare_dataset(tiny_dataset, tmp_path / "prepared", ratios=ratios)


def test_insufficient_independent_groups_fail(tiny_dataset, tmp_path):
    groups = {f"leaf-0-{index}": "same-leaf" for index in range(20)}
    path = tmp_path / "groups.json"
    path.write_text(json.dumps(groups))
    with pytest.raises(ValueError, match="at least 3 independent"):
        prepare_dataset(tiny_dataset, tmp_path / "prepared", leaf_groups=path)


def test_manifest_rejects_leakage_and_path_traversal(tiny_dataset, tmp_path):
    output = tmp_path / "prepared"
    prepare_dataset(tiny_dataset, output)
    path = output / "split_manifest.json"
    original = json.loads(path.read_text())
    manifest = json.loads(path.read_text())
    manifest["splits"]["test"][0]["group_id"] = manifest["splits"]["train"][0]["group_id"]
    path.write_text(json.dumps(manifest))
    with pytest.raises(ValueError, match="overlap"):
        load_manifest(path)
    original["splits"]["test"][0]["path"] = "../outside.png"
    path.write_text(json.dumps(original))
    with pytest.raises(ValueError, match="unsafe"):
        load_manifest(path)
