# Phase 4: fourteen-class training handoff

## Current status

Prepared on 2026-10-13 on branch `codex/phase4-multicrop`. The original five-class backend, training pipeline, Flutter interface, ONNX bundle and tomato-only APK remain intact. Existing Phase 3 changes were already uncommitted when this branch was created and have been retained. No push, remote changes or global Git configuration changes were performed.

**No fourteen-class training, evaluation, conversion, Android deployment or new physical-device test has been completed.** This machine reports CUDA unavailable, and a Colab GPU run has not been executed in this session. The next required step is to run the notebook in your Google Colab GPU session and return its actual training outputs. No untrained fourteen-class model is bundled. The user reports successful Phase 3 Pixel 8 offline inference; this report does not count that as a new Phase 4 device test.

## Preserved inference contract

The existing app uses ONNX Runtime Android 1.23.2, opset 18, float32 input `[1,3,224,224]`, original output `[1,5]`, CPU execution and local guidance. Native `LeafPreprocessor` handles EXIF orientation, RGB, Pillow-compatible bilinear short-edge resize to 256, center crop 224, CHW tensor layout, ImageNet mean `[0.485,0.456,0.406]` and standard deviation `[0.229,0.224,0.225]`. The new pipeline imports the original Python evaluation and augmentation transforms directly. The staged converter uses the same ONNX format with output `[1,14]`; Android integration will still require real native parity checks before activation.

The six working checkpoint/mapping/evaluation/ONNX/manifest/APK artifacts have byte-identical copies and hashes in `artifacts/phase4_preservation/preservation.json`. The original APK remains `artifacts/releases/AgriVision-AI-Phase3-arm64.apk`. No model artifacts were overwritten. The working app continues to advertise tomato-only support.

## Verified source and exact index order

Source: [author PlantVillage repository](https://github.com/spMohanty/PlantVillage-Dataset), pinned revision `7f7ecc7e1eaca78107e3affe7cb5abd9427e139a`, RGB tree `6985a76f66926faf50eeae1299ccc50bc01a0a4a`. Complete individual class trees were verified against the earlier [dataset research](DATASET_RESEARCH.md). `training/multicrop/source_inventory.json` records every selected original filename, byte size and Git blob SHA. The source leaf-map blob is `cb04e3723d2ce15b0411483d71a60b5d536bc7f6`.

| Index | Crop | Condition | Verified original RGB files |
|---|---|---|---:|
| 0 | Tomato | Healthy | 1,591 |
| 1 | Tomato | Early Blight | 1,000 |
| 2 | Tomato | Late Blight | 1,909 |
| 3 | Tomato | Bacterial Spot | 2,127 |
| 4 | Tomato | Leaf Mold | 952 |
| 5 | Maize | Healthy | 1,162 |
| 6 | Maize | Common Rust | 1,192 |
| 7 | Maize | Gray Leaf Spot | 513 |
| 8 | Maize | Northern Leaf Blight | 985 |
| 9 | Potato | Healthy | 152 |
| 10 | Potato | Early Blight | 1,000 |
| 11 | Potato | Late Blight | 1,000 |
| 12 | Bell Pepper | Healthy | 1,478 |
| 13 | Bell Pepper | Bacterial Spot | 997 |
| **Total** | | | **16,058** |

Selected image bytes total **253,121,257**, excluding metadata. These are inventory counts before pixel deduplication; they are not completed split counts or independent leaf counts. The largest class has about 14 times the files of Potato Healthy. That class has only 152 originals, so held-out precision and recall will have limited support; the notebook reports the actual image and independent-group counts rather than promising a particular sample count or accuracy. All fourteen combinations have verified files, but sufficient field coverage is not established by these counts.

Only pinned `raw/color` files are downloaded. No augmented Kaggle copies, segmented images, grayscale images, other datasets or additional crops are added. Augmentation occurs in the training loader only. Every downloaded image is checked against its upstream Git blob digest. Changed local originals cause a failure rather than an overwrite.

Exact decoded RGB duplicates are removed, and conflicting labels cause an audit failure. Official leaf IDs, filename identities and exact pixel hashes create transitive groups before stratification. Explicit repeated `Leaf N.view` and `Leaf N Day D` filenames are grouped. The official map has missing entries for **5,436 selected files** in the pinned inventory; these use documented filename-derived identities. Train/validation/test ownership checks prevent known group and duplicate leakage. Unknown leaf relationships, near-duplicates and collection/site correlations cannot be guaranteed from the available metadata. Split ratios are approximately 70/15/15 with all fourteen classes represented. The preparation report records actual counts after deduplication and group assignment.

## Licensing and provenance limitation

The [author HF card](https://huggingface.co/datasets/mohanty/PlantVillage) declares CC BY-SA 3.0. However, the [author loader at the pinned revision](https://github.com/spMohanty/PlantVillage-Dataset/blob/7f7ecc7e1eaca78107e3affe7cb5abd9427e139a/plant_village.py) explicitly says the license is assumed and should be verified. The repository describes open access, which alone does not establish a specific image redistribution license. Original image redistribution rights therefore remain unresolved; no independent license is invented here. Do not publish dataset photos or the private parity-photo archive as a cleared public dataset release. The source handoff ZIP contains code and metadata, not dataset images.

Cite Mohanty, Hughes and Salathé, *Using Deep Learning for Image-Based Plant Disease Detection*, Frontiers in Plant Science (2016), [DOI 10.3389/fpls.2016.01419](https://doi.org/10.3389/fpls.2016.01419). A paper's own license is not proof of the images' license. Controlled leaf backgrounds also do not establish performance on farmers' phone images.

## Exact Google Colab steps

1. Open [Google Colab](https://colab.research.google.com/), select **File → Upload notebook**, and upload `training/multicrop/AgriVision_Multicrop_Training.ipynb`.
2. Select **Runtime → Change runtime type → T4 GPU**, then save. Another available CUDA GPU is also supported.
3. Run cells in order. The upload cell requests `artifacts/agrivision_phase4_colab_source.zip`. Upload this Phase 4 package, not the old five-class source ZIP.
4. The acquisition cell downloads only the selected original RGB files. The preparation cell computes verified grouped splits. Inspect all per-class image/group counts, especially Potato Healthy, and the reported metadata fallbacks.
5. Run training. It uses ImageNet-initialized MobileNetV3-Small with a fourteen-output classifier, three frozen-feature epochs, then lower-rate full-network fine-tuning, up to 30 epochs and patience 5. Training uses capped inverse-frequency class weights derived only from the training partition. Validation uses unweighted cross entropy to select the best checkpoint. No test images participate in augmentation, optimization or checkpoint selection.
6. If GPU memory is insufficient, rerun the training command with `--batch-size 32 --output artifacts/phase4_run_retry`, after the failed process stops. Update subsequent display/archive cells to that output directory. Existing run directories are never overwritten. If the session disconnects, retain saved outputs where possible; a fresh runtime must redo acquisition/preparation/training. The source ZIP can be regenerated with `python -m training.multicrop.package_colab`.
7. Download `AgriVision-Phase4-trained-run.zip` using the final notebook cell. Keep it intact. It contains `phase4_run/best_model.pt`, `class_mapping.json`, `evaluation.json`, `confusion_matrix.png`, `history.json`, `test_predictions.json`, `run_metadata.json`, `dataset_config.json`, `dataset_report.json`, `split_manifest.json`, `parity_images.json` and fourteen held-out parity photos.
8. Put the ZIP in `artifacts/phase4_colab_return/` inside this project and extract it there, retaining its `phase4_run/` folder. **Do not put any returned files in `models/` or replace the current Flutter assets.**

No training or evaluation cells have saved outputs in the delivered notebook. GPU speed, accuracy and eventual field reliability are intentionally unspecified.

## Conversion after the actual checkpoint returns

From the project root, with the existing `.venv` activated:

```sh
python -m training.multicrop.convert \
  --run artifacts/phase4_colab_return/phase4_run \
  --output artifacts/phase4_android_export
```

This validates fixed class ordering, preprocessing, checkpoint/evaluation/split hashes, held-out support and parity-photo provenance before export. It refuses protected active asset locations and existing output directories. It compares PyTorch and desktop ONNX Runtime using one fixed held-out original from each class: finite outputs, maximum absolute logit error ≤1e-4, probability error ≤1e-5 and identical top-three indices. It produces numerical reports and float32 reference tensors only after actual inference. Passing desktop parity is **not** Android parity or a physical-device test. The staging manifest explicitly declares activation incomplete; the script never bundles a model.

## Remaining deployment work after training

Actual fourteen-class weights and held-out results are required before conversion proof, Android output/metadata integration, local fourteen-class guidance, crop selection and mismatch behavior, updated Overview/Model pages, native inference tests across all crops, airplane-mode testing and a new APK can be validated. The original five-class backend and Android route must remain available through preservation and regression checks.

The planned interface will display the global predicted crop and condition and reject a selected-crop mismatch rather than relabeling it. No crop-specific filtering has been implemented or evaluated in this phase; no conditional renormalized scores or crop-identity validation claims are made. Any later filtering experiment must separately report unrestricted and crop-constrained held-out results, including errors when the user selects the wrong crop.

New device verification must use the new built APK on the Pixel 8: stop FastAPI, enable airplane mode, install the APK, select/capture an image from each of the four crops, verify real predictions and local recommendations, test crop mismatch/cancel/corrupt-image flows, and record APK/model hashes and observed outcomes. Installation without internet must work. Do not mark these checks completed until performed.

## Local preparation verification

Python regression and new pipeline tests: **52 passed**; dependency deprecation warnings only. Flutter analysis: **no issues found**. Existing Flutter tests: **25 passed**. Notebook Python cells compile, contain no saved outputs, and the source ZIP excludes images, trained models and APKs. Original backend/training/model files match the Phase 3 protection hashes; all six preserved deployment artifacts match their working originals. These checks verify preparation and preservation, not a Colab training outcome. Machine-readable results are in `docs/phase4_preparation_verification.json`.
