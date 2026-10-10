# AgriVision AI

Intelligent Crop Disease Detection and Management System — university project,
Phase 1, prepared for an October 13, 2026 demonstration.

**Status:** real training/inference code, FastAPI, Colab notebook, and a minimal
Flutter macOS foundation are implemented. A disease model has **not** been trained.
No weights, dataset, or ML evaluation scores are included. Without trained artifacts,
the API reports `model_loaded: false` and valid predictions return an informative 503.

## Repository

```text
backend/app/        FastAPI routes, schemas, CPU inference, shared architecture/labels
backend/tests/      Image, inference, checkpoint, and HTTP tests
training/           Dataset preparation, training, evaluation, config, Colab notebook
training/tests/     Split leakage, mapping, frozen features, and metric tests
frontend/           Minimal Material 3 Flutter shell and native macOS project
models/             Destination for exported weights (ignored by Git)
docs/               Architecture, methodology, dataset provenance, Colab, verification
```

## Install locally

Use Python 3.11, Git, Flutter, and Xcode for the macOS target. On Apple Silicon,
Homebrew's Python can be installed with `brew install python@3.11` if needed.
From this repository directory:

```sh
python3.11 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements-dev.txt
python -m pytest
```

The pinned Torch 2.8.0 / Torchvision 0.23.0 pair supports the intended architecture.
For serving only, install `backend/requirements.txt`; for training, install
`training/requirements.txt`. The complete development set includes testing,
evaluation charts, YAML config, notebook validation, and linting.

Flutter SDK is not on PATH on this development Mac. Add its `bin` directory to PATH
or invoke your installed `flutter` executable directly, then:

```sh
cd frontend
flutter pub get
flutter analyze
flutter test
flutter run -d macos
```

Phase 1 displays a simple project identity shell. The complete detection interface
is planned for Phase 2.

## Train in Google Colab

Follow [the exact Colab and export walkthrough](docs/colab.md). Create the source
upload ZIP with a standard-library-only command:

```sh
python3.11 -m training.package_colab
```

Open `training/AgriVision_Training.ipynb` in Colab, select a T4 GPU if offered, upload
`artifacts/agrivision_colab_source.zip` when prompted, review the documented dataset
source/terms, and run the cells in order. The notebook downloads the selected source
folders, trains the classifier, evaluates held-out images, and downloads a run ZIP.
Free Colab GPU availability is not guaranteed; CPU remains supported.

Defaults: MobileNetV3-Small with ImageNet initialization, frozen features and
BatchNorm, five-class head, 224×224 input, ImageNet normalization, 8 epochs,
AdamW at 0.001, batch 32, 70/15/15 grouped stratification, seed 42, patience 3.
All configuration is in `training/config.yaml`; notebook epochs are configurable.

Local training is also supported after obtaining the dataset:

```sh
python -m training.train --dataset-root data/PlantVillage-Dataset --device cpu --epochs 8
```

Use `--output-dir artifacts/run-2` for a new run; existing checkpoints are protected
from accidental overwriting. Dataset and split limitations are in [dataset.md](docs/dataset.md)
and [methodology.md](docs/methodology.md). Do not report metrics until a genuine
training run has produced `evaluation.json`.

## Export and run

Extract the Colab run ZIP. Copy `best_model.pt` and `class_mapping.json` together
to this repository's `models/` directory. Preserve the other files for your report.
From the repository root with the virtual environment active:

```sh
python -m backend.app.ml.inference path/to/leaf.jpg --model-dir models
python -m uvicorn backend.app.main:app --host 127.0.0.1 --port 8000
```

Use another terminal to inspect health and submit an image:

```sh
curl http://127.0.0.1:8000/health
curl -F 'image=@path/to/leaf.jpg' http://127.0.0.1:8000/predict
```

Interactive API docs: http://127.0.0.1:8000/docs. Set `AGRIVISION_MODEL_DIR` to use a
different artifact directory; restart the backend after installing weights. Uploaded
images are processed transiently and are not stored by this application.

To independently reevaluate a checkpoint on its test manifest:

```sh
python -m training.evaluate --model-dir artifacts/run --manifest artifacts/run/split_manifest.json --dataset-root data/PlantVillage-Dataset
```

Only use trusted checkpoints. Confidence is a softmax score among five possible
classes, **not diagnostic certainty**. This model cannot reject non-leaf uploads
or detect unrepresented diseases. Educational management guidance includes linked
sources; significant symptoms need local agricultural confirmation.

## Checks and next phase

```sh
python -m pytest
python -m ruff check backend training
python -m ruff format --check backend training
```

Dataset-free tests use synthetic images and temporary test weights to verify code
mechanics, never disease accuracy. See [verification report](docs/verification.md)
for the actual checks executed on this Mac.

Next: complete the Colab run, inspect counts/leakage and genuine metrics, install
the exported artifacts, check the CLI and HTTP responses with held-out leaf images,
then implement Flutter upload/preview/results and repeat-analysis flows. No paid API,
Docker, Firebase, authentication, or deployment is required.
