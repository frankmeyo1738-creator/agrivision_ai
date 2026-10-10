# Phase 1 completion and verification report

Verified October 10, 2026 on the development Mac. Implementation is complete for
Phase 1. Real PlantVillage training and full frontend implementation remain future
steps; no disease-trained model or disease-performance claim is included.

## Environment and repository

- Apple Silicon arm64, macOS 27.0.1; user hardware: M2 MacBook Air, 8 GB memory.
- Python 3.11.17 installed using Homebrew after the initial network failure.
- Workspace `.venv` contains Torch 2.8.0 and Torchvision 0.23.0 and the pinned
  development requirements. `pip check` reported no broken requirements.
- Flutter 3.41.5, Dart 3.11.3, Git 2.54.0, Xcode command-line tools available.
- Git initialized on `main`; source changes are uncommitted. No remote was created.
- Native deployment target raised from generated 10.15 to 12.0 to match Xcode's
  supported range, including CocoaPods targets.

## Files created

| Area | Main files and purpose |
| --- | --- |
| Repository | README, MIT LICENSE, gitignore, pyproject and development requirements |
| Shared ML | `backend/app/ml/classes.py`, `model.py`, `images.py`, `inference.py` |
| Backend | FastAPI lifespan in `main.py`, routes/schemas, sourced disease guidance |
| Dataset | `training/prepare_dataset.py`, `data.py`; manifests, hashes, group audits |
| Training | `training/train.py`, `evaluate.py`, `config.yaml`, pinned requirements |
| Colab | `AgriVision_Training.ipynb`, source packager, generated source upload ZIP |
| Flutter | Native macOS scaffold, theme/config, minimal app shell, HTTP/file dependencies |
| Tests | Dataset, training, inference, images, API, notebook and Flutter shell tests |
| Documentation | Architecture, methodology, dataset terms, guidance sources, Colab walkthrough |
| Models | Empty artifact destination with installation instructions; no weights |

## Architecture and configuration

Torchvision MobileNetV3-Small with pretrained ImageNet `IMAGENET1K_V1` initialization,
frozen feature extractor and its BatchNorm statistics, trainable classifier head,
and a replacement five-output final linear layer. Fixed indices: healthy 0, early
blight 1, late blight 2, bacterial spot 3, leaf mold 4. Serving reconstructs the
architecture without downloading pretrained weights, checks the checkpoint and
mapping, and uses CPU `torch.inference_mode()` plus softmax and top-three ranking.

Defaults are seed 42, 70/15/15 grouped class-stratified splitting, eight epochs,
batch 32, cross entropy, AdamW learning rate 0.001 and weight decay 0.0001, patience
three on validation loss, zero loader workers, CUDA if available otherwise CPU.
Evaluation/inference use 256 short-edge resize, 224 center crop, RGB/EXIF handling,
and ImageNet normalization. Random augmentation is restricted to training.

## Executed checks

| Check | Actual result |
| --- | --- |
| `python -m pytest` | 40 passed, 15 dependency deprecation warnings, 8.06 seconds |
| Notebook validation after final path fix | One targeted test passed; all code cells compile, schema valid, no saved outputs |
| `python -m ruff check backend training` | All checks passed |
| `python -m ruff format --check backend training` | 26 files already formatted |
| `python -m pip check` | No broken requirements |
| `flutter analyze` | No issues found |
| `flutter test` | One widget test passed |
| `flutter build macos --debug` | Succeeded; `frontend/build/macos/Build/Products/Debug/AgriVision AI.app` |
| Source archive | Required modules present, no environment/data/weights/build, ZIP integrity checked |
| CLI entry points | Help commands execute for preparation, training, evaluation and inference |
| CLI without model | Expected exit 1 with explicit missing-model/export instructions |
| API without model | Health reports false; valid image returns 503, verified in API tests |

Python tests cover deterministic stratification, all-class coverage, transitive
group leakage prevention, duplicate label conflicts, bad data/manifests, frozen
features and BatchNorm, classifier updates, checkpoint validation, actual softmax
ranking, repeated predictions, upload validation, missing-model behavior, and
sanitized internal failures. A complete pipeline smoke test trains one epoch on
synthetic tiny images with pretrained downloads disabled, generates evaluation
artifacts, and loads its temporary checkpoint through the serving engine. This
verifies mechanics only. It is not tomato disease training; its temporary metrics
and weights are never published or installed in `models/`.

## Errors resolved and remaining limitations

Initial Homebrew and sandboxed PyPI attempts failed due to DNS/network access;
approved retries succeeded. The first native build failed on the generated 10.15
deployment target; the 12.0 adjustment resolved it. No failing automated checks
remain. Non-fatal warnings come from Starlette/AnyIO and Matplotlib/Pyparsing
deprecations, the file-selector plugin's deprecated AppKit API, and the standard
Flutter Assemble build script. These did not prevent tests or the debug build.

No PlantVillage images were downloaded locally and no genuine disease training,
CUDA run, or live Colab session was executed. Notebook validation and a local
synthetic smoke test do not prove the external dataset download or a future Colab
runtime will work unchanged. Dataset terms need checking for the obtained copy;
reported licensing and source links are documented. Unknown leaf relationships,
near duplicates, domain shift, class imbalance, and uncalibrated confidence remain
explicit methodological limitations. The UI is intentionally a minimal scaffold.

## Exact handoff and next steps

The source ZIP is already generated at `artifacts/agrivision_colab_source.zip`.
Rebuild it after any edits using `python3.11 -m training.package_colab`. Follow
[the complete Colab walkthrough](colab.md): upload the notebook, choose a T4 GPU
if available, upload the source ZIP, install dependencies, obtain the documented
five-class dataset, train, inspect actual metrics, and run the export cell.

Download `agrivision_model_export.zip`, extract it, and copy `best_model.pt` and
`class_mapping.json` together into `models/`. Keep evaluation, metadata, plots,
dataset source, and split audits for your report. Restart the FastAPI backend;
confirm model readiness and test a held-out leaf through the CLI and HTTP endpoint.
Then implement the Flutter dashboard, image selection/preview, analysis/results,
disease information, and repeated-analysis/error flows in Phase 2.
