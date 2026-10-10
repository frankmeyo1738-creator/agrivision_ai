import json
from pathlib import Path

import nbformat
import pytest
import torch
from torch.utils.data import DataLoader, TensorDataset

from backend.app.ml.inference import InferenceEngine
from backend.app.ml.model import build_model
from training.evaluate import calculate_metrics
from training.train import run_epoch, select_device, validate_config


def test_complete_pipeline_on_synthetic_images_without_network(tiny_dataset, tmp_path, monkeypatch):
    import training.train as pipeline

    # Test plumbing only. Disable pretrained downloads; all outputs stay in pytest's temp folder.
    monkeypatch.setattr(
        pipeline,
        "build_model",
        lambda **kwargs: build_model(pretrained=False, freeze_features=True),
    )
    config = {
        "seed": 42,
        "split_ratios": [0.7, 0.15, 0.15],
        "epochs": 1,
        "batch_size": 32,
        "patience": 3,
        "learning_rate": 0.001,
        "weight_decay": 0.0001,
        "num_workers": 0,
        "device": "cpu",
    }
    output = tmp_path / "run"
    metrics = pipeline.train(config, tiny_dataset, tmp_path / "prepared", output)
    assert metrics["test_samples"] == 15
    assert json.loads((output / "evaluation.json").read_text()) == metrics
    for filename in (
        "best_model.pt",
        "class_mapping.json",
        "history.json",
        "run_metadata.json",
        "training_curves.png",
        "confusion_matrix.png",
        "split_manifest.json",
        "dataset_report.json",
    ):
        assert (output / filename).stat().st_size > 0
    engine = InferenceEngine(output)
    engine.load()
    assert engine.loaded
    with pytest.raises(ValueError, match="already contains"):
        pipeline.train(config, tiny_dataset, tmp_path / "prepared", output)


def test_notebook_is_valid_and_all_cells_compile():
    path = Path(__file__).resolve().parents[1] / "AgriVision_Training.ipynb"
    notebook = nbformat.read(path, as_version=4)
    nbformat.validate(notebook)
    for index, cell in enumerate(notebook.cells):
        if cell.cell_type == "code":
            compile(cell.source, f"notebook-cell-{index}", "exec")
            assert cell.outputs == []
            assert cell.execution_count is None


def test_training_updates_head_but_freezes_features_and_batchnorm():
    torch.set_num_threads(2)
    torch.manual_seed(42)
    model = build_model(pretrained=False, freeze_features=True)
    before = {key: tensor.clone() for key, tensor in model.features.state_dict().items()}
    head_before = model.classifier[-1].weight.detach().clone()
    dataset = TensorDataset(torch.randn(4, 3, 224, 224), torch.tensor([0, 1, 2, 3]))
    optimizer = torch.optim.AdamW(model.classifier.parameters(), lr=0.001)
    loss, accuracy = run_epoch(
        model, DataLoader(dataset, batch_size=2), torch.device("cpu"), optimizer
    )
    assert loss > 0 and 0 <= accuracy <= 1
    assert all(
        torch.equal(value, before[key]) for key, value in model.features.state_dict().items()
    )
    assert not torch.equal(head_before, model.classifier[-1].weight)
    assert all(p.grad is None for p in model.features.parameters())
    assert not model.features.training
    state = {key: value.clone() for key, value in model.state_dict().items()}
    run_epoch(model, DataLoader(dataset, batch_size=2), torch.device("cpu"))
    assert all(torch.equal(value, state[key]) for key, value in model.state_dict().items())


def test_metrics_come_from_supplied_predictions():
    metrics = calculate_metrics([0, 1, 2, 3, 4], [0, 1, 2, 3, 0])
    assert metrics["accuracy"] == pytest.approx(0.8)
    assert metrics["recall_macro"] == pytest.approx(0.8)
    assert metrics["confusion_matrix"][4][0] == 1
    assert metrics["test_samples"] == 5
    with pytest.raises(ValueError):
        calculate_metrics([], [])


def test_device_cpu_and_config_validation():
    assert select_device("cpu") == torch.device("cpu")
    with pytest.raises(ValueError):
        select_device("bad")
    with pytest.raises(ValueError, match="epochs"):
        validate_config({"epochs": 0})
