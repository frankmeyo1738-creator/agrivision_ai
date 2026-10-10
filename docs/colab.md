# Google Colab: training and export

1. From the project root run `python3.11 -m training.package_colab`. This produces
   `artifacts/agrivision_colab_source.zip` containing only Python source, the notebook,
   requirements, and documentation. It includes no Flutter build, virtual environment,
   dataset, Git metadata, or weights.
2. Visit https://colab.research.google.com and choose **File → Upload notebook**.
   Select `training/AgriVision_Training.ipynb` from this project.
3. Choose **Runtime → Change runtime type → Python 3 → T4 GPU**, if a free GPU is
   offered. Save. CPU also works but takes longer. Available runtime Python may be
   newer than the local 3.11; use the notebook's environment report to record it.
4. Run the source upload cell and select `artifacts/agrivision_colab_source.zip`.
   It extracts into `/content/agrivision-ai` and changes the working directory there.
5. Run the installation cell. It installs the pinned shared requirements. If Colab
   requests a session restart, restart and rerun the upload/extraction cell before
   continuing. Do not import Torch before package installation.
6. Run the environment cell. It prints Python, Torch, and whether CUDA is available.
   The training command selects CUDA automatically when available, otherwise CPU.
7. Read the dataset source and licensing note. The dataset cell's default
   `USE_EXISTING_DATASET = False` downloads only the five relevant original
   PlantVillage color folders and leaf-grouping metadata using sparse Git checkout.
   This requires internet and may take several minutes. The source URL, revision,
   and reported license are saved. No credentials or paid service are needed.
8. If the dataset is already in Drive instead, set `USE_EXISTING_DATASET = True`,
   mount Drive in a separate cell with `from google.colab import drive; drive.mount('/content/drive')`,
   and set `EXISTING_DATASET_ROOT` to the color-folder root or original dataset root.
   See `docs/dataset.md` for accepted layouts. Keep grouping metadata beside the data
   or set `LEAF_GROUPS` in the training cell to its JSON path.
9. Set `EPOCHS = 8` in the training cell for the initial run. The remaining defaults
   are in `training/config.yaml`. Run the cell. It prepares audited grouped splits,
   prints class counts, trains, saves the best validation-loss checkpoint, reloads
   it, and evaluates the untouched test set. No success or accuracy is assumed.
10. Run the results cell. Inspect the actual evaluation JSON, training curves,
    confusion matrix, and dataset report. If many images lack reliable leaf IDs,
    audit related images and explain the limitation in your report.
11. Run the export cell. It downloads `agrivision_model_export.zip` containing the
    checkpoint, mapping, evaluation, metadata, history, plots, split manifest,
    dataset report, and source provenance. If browser downloads are blocked, select
    the archive in Colab's Files panel and use **Download**.
12. Extract that archive on your Mac. Copy `best_model.pt` and `class_mapping.json`
    together into this project's `models/` directory. Preserve all evaluation
    evidence separately. Start/restart the backend and verify `/health` reports
    `model_loaded: true`. Test a real held-out image using the CLI and `/predict`.

Each run writes to `RUN_DIR`. If a checkpoint already exists there, choose another
directory such as `/content/agrivision_run_2` before training; the pipeline prevents
accidental checkpoint overwrite. Colab's `/content` is temporary: download the
archive before the runtime disconnects, or copy it to Drive. A completed epoch
checkpoint may remain after a failure, but an export is ready for academic reporting
only when the held-out evaluation and all metadata have completed.
