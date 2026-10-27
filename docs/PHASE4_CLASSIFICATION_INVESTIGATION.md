# Phase 4 classification investigation

Investigated on 2026-10-13 against the existing Pixel 8 installation. **No retraining, model replacement, working APK rebuild/reinstallation, or Flutter UI edits were performed during this investigation.** Cellular tethering and Wi-Fi settings were left unchanged. A separate diagnostic instrumentation package executed the native classifier from the installed release APK; it did not substitute a different classifier.

## Conclusion

The tested errors do **not** indicate a swapped class index, incorrect ONNX conversion, or Python/Android preprocessing discrepancy. PyTorch, desktop ONNX Runtime and the installed Android model reproduce the same winning classes on all four supplied files. All fourteen mappings agree. Forty native parity cases pass on the physical Pixel 8.

There are two distinct issues:

- **Unsupported inputs:** Images 1 and 3 originate from sweet-potato articles. AgriVision's Potato labels mean ordinary potato (*Solanum tuberosum*), not sweet potato (*Ipomoea batatas*). Those images cannot be counted as labelled ordinary-potato classification errors. Their confident tomato scores still demonstrate the closed-set model's inability to reject unsupported inputs.
- **Generalization limitations:** Image 2 is a supported-crop field-style potato photo, yet the model strongly prefers Tomato Early Blight. Image 4 is reported as maize Common Rust, yet the model prefers Gray Leaf Spot. These are reproducible model decisions, rather than Android-only errors. The source for Image 2 does not establish a disease label, and the exact maize photo/caption could not be independently confirmed from the full blocked Bayer page.

These four photographs are diagnostic examples, not a statistically representative field accuracy benchmark. No new accuracy estimate is claimed from them.

## Artifact and mapping audit

The installed APK was read back using adb. Its SHA-256 is identical to the local release: `f2d45675610db59efc2691b7829be9ad19f7b0282632ab1e3085816274261acd`. Its embedded model matches the bundled ONNX SHA-256 `f8d7be04e58e34eba947eea4576133f5c899dbe82495283c9e93c6188bcf17b7`. The actual trained checkpoint SHA-256 is `7b8ca047c6032744b13650f2c7116dcbaf518e705268f6dcc05d00200a90719e`.

Checkpoint `class_to_idx`, returned `class_mapping.json`, bundled manifest labels, native Kotlin labels and the installed APK manifest have the same exact order. Potato is not mapped to tomato: its valid zero-based indices are **9, 10 and 11**. Native input is `[1,3,224,224]`, output is `[1,14]`, and softmax ranks all fourteen scores globally.

| Index | Exact label | Mapping |
|---:|---|---|
| 0 | Tomato Healthy | Verified across all artifacts |
| 1 | Tomato Early Blight | Verified across all artifacts |
| 2 | Tomato Late Blight | Verified across all artifacts |
| 3 | Tomato Bacterial Spot | Verified across all artifacts |
| 4 | Tomato Leaf Mold | Verified across all artifacts |
| 5 | Maize Healthy | Verified across all artifacts |
| 6 | Maize Common Rust | Verified across all artifacts |
| 7 | Maize Gray Leaf Spot | Verified across all artifacts |
| 8 | Maize Northern Leaf Blight | Verified across all artifacts |
| 9 | Potato Healthy | Verified across all artifacts |
| 10 | Potato Early Blight | Verified across all artifacts |
| 11 | Potato Late Blight | Verified across all artifacts |
| 12 | Bell Pepper Healthy | Verified across all artifacts |
| 13 | Bell Pepper Bacterial Spot | Verified across all artifacts |

The current controller does not filter or renormalize scores according to crop selection. It checks the predicted crop against the selected crop and withholds the diagnosis/guidance on a mismatch. A mismatch notice can mention the model's global tomato closest match; that does not mean the selected crop changes the classifier's output. Crop selection is user input, not verified crop identity.

[Mapping and preservation hashes](phase4/investigation/mapping_audit.json) record the audit. Source checkpoint, ONNX, bundled manifest and both release APK files were unchanged at completion.

## Held-out evaluation and confusion matrix

The returned Colab evaluation reports **97.46045% accuracy**, **96.92178% macro F1** on **2,402** held-out PlantVillage images. These metrics, per-class values and the full confusion matrix were recomputed from the 2,402 saved target/prediction records and match the evaluation file. This is an audit of saved evaluation outputs, not a fresh rerun on all test images: the return archive contains fourteen parity photos, not the complete held-out image set.

Sixteen thousand forty-four original images remained after removing fourteen exact decoded duplicates. Split ownership checks keep known physical-leaf groups, filename relationships and identical pixels together. Unknown collection relationships/near-duplicates may remain; all maize classes lack official leaf IDs in the selected source map and use filename identities.

| Condition | Train images | Validation images | Test images | Test leaf groups | Precision | Recall | F1 |
|---|---:|---:|---:|---:|---:|---:|---:|
| Potato Healthy | 104 | 24 | 24 | 6 | 100.00% | 100.00% | 100.00% |
| Potato Early Blight | 700 | 152 | 148 | 37 | 99.33% | 100.00% | 99.66% |
| Potato Late Blight | 700 | 152 | 148 | 37 | 95.42% | 98.65% | 97.01% |

Potato-specific confusion:

- Healthy: **24/24** correct; no other test image was predicted Potato Healthy. However, these 24 photos represent only **six known leaf groups**. They do not establish robust performance on unseen cultivars, farms or backgrounds. A binomial interval treating all 24 as independent would overstate the evidence.
- Early Blight: **148/148** correctly classified. One Potato Late Blight image was predicted Potato Early Blight, giving precision 148/149.
- Late Blight: **146/148** correct; one was predicted Tomato Late Blight and one Potato Early Blight. Seven tomato test images were predicted Potato Late Blight: four Tomato Early Blight and three Tomato Late Blight, giving precision 146/153.
- Across all potato test images: **318/320** exact crop-condition matches. **319/320** retain the correct crop identity, because the late-to-early error remains within potato.

Maize Common Rust has precision/recall **100%/100%**, support **179**, in this controlled test set. None was predicted Gray Leaf Spot. Gray Leaf Spot has precision **76.60%**, recall **93.51%**, support **77**: 72 correct, five predicted Northern Leaf Blight. It receives twenty false positives from Northern Leaf Blight and two from Maize Healthy. Northern Leaf Blight recall is **86.49%**, support **148**. This establishes an existing leaf-spot/blight weakness but does not explain the external rust error as a label permutation.

[Full 14×14 confusion matrix CSV](phase4/investigation/confusion_matrix.csv) uses actual classes as rows and predicted classes as columns. [All per-class metrics](phase4/investigation/held_out_evaluation.json) retain precision, recall, F1 and support.

## Actual full prediction scores

The table below contains the **Pixel 8's measured global softmax percentages**, in fixed index order. Very small values use scientific notation where necessary; they are not silently rounded to zero. The [complete numerical CSV](phase4/investigation/all_scores.csv) contains PyTorch, desktop ONNX and Pixel 8 probabilities and logits, and source-image hashes are retained in the JSON evidence.

| Index | Class | Image 1 (%) | Image 2 (%) | Image 3 (%) | Image 4 (%) |
|---:|---|---:|---:|---:|---:|
| 0 | Tomato Healthy | 61.6 | 0.00875352 | 0.000236278 | 0.0172551 |
| 1 | Tomato Early Blight | 10.5652 | 94.4797 | 6.0465 | 2.47479 |
| 2 | Tomato Late Blight | 6.89584 | 5.17114 | 88.007 | 0.0283331 |
| 3 | Tomato Bacterial Spot | 0.00521599 | 0.000557866 | 5.23069e-06 | 1.19183 |
| 4 | Tomato Leaf Mold | 0.00144026 | 0.0127122 | 0.0106211 | 0.0970666 |
| 5 | Maize Healthy | 0.23652 | 0.00124033 | 0.00518409 | 3.06849 |
| 6 | Maize Common Rust | 0.108227 | 0.000227524 | 0.000256657 | 0.353504 |
| 7 | Maize Gray Leaf Spot | 0.18341 | 0.000153992 | 0.0371837 | 68.2047 |
| 8 | Maize Northern Leaf Blight | 0.00170435 | 0.000146359 | 0.0160841 | 9.98615 |
| 9 | Potato Healthy | 0.107392 | 0.000200569 | 0.000307557 | 0.0944477 |
| 10 | Potato Early Blight | 1.76987 | 0.00950353 | 0.000485721 | 0.0887494 |
| 11 | Potato Late Blight | 4.81527 | 0.0309178 | 0.0089983 | 0.0457509 |
| 12 | Bell Pepper Healthy | 3.28846 | 0.279505 | 0.646683 | 0.0145966 |
| 13 | Bell Pepper Bacterial Spot | 10.4215 | 0.00525654 | 5.22044 | 14.3343 |

Reproduced winning scores:

| Photo | Reported by user | PyTorch on supplied file | Pixel 8 on supplied file |
|---|---|---|---|
| 1 | 61.6% | Tomato Healthy — 61.6000% | 61.6000% |
| 2 | 94.5% | Tomato Early Blight — 94.4797% | 94.4797% |
| 3 | 88.0% | Tomato Late Blight — 88.0070% | 88.0070% |
| 4 | 70.6% | Maize Gray Leaf Spot — 68.2046% | 68.2047% |

The first three scores round to the user's values. For Image 4, both Python and this Pixel 8 run yield approximately **68.2%**, not 70.6%. That difference is **not reproduced as a runtime discrepancy** on the supplied bytes. A different gallery file, crop, compression version or earlier input state is possible, but its cause is unverified. The predicted class is unchanged.

## Preprocessing and Android parity

The tested contract is: EXIF orientation → RGB conversion → bilinear/antialiased short-edge resize to 256 → center crop 224 → float32 CHW → ImageNet normalization. Neither crop selection nor the original filename changes this pipeline. Android's picker requests no resize or JPEG quality change. Native model integrity and preprocessing metadata are checked before inference.

The physical Pixel 8 (SDK 37) ran the **existing installed release's native class**, model and ONNX Runtime 1.23.2, using a separate Java instrumentation runner. This avoided debug-test dependency assumptions made by the previous AndroidX runner. That previous runner failed because dependencies such as Kotlin Intrinsics and AndroidX Tracing had been stripped from the optimized application; the failure occurred before inference and does not demonstrate a classifier failure. The investigation runner requires neither dependency and leaves the app unchanged.

- **40/40 parity cases passed**: fourteen held-out class examples plus the previous EXIF, RGB/alpha, geometry and image-format fixtures.
- Maximum Android/PyTorch tensor error: **0** on these cases, including the lossless-decoding isolation tests.
- Maximum same-input logit difference: **5.72205×10⁻⁵**, below the existing 1×10⁻⁴ bound.
- Maximum end-to-end probability difference: **3.51647×10⁻⁶**, with the same top-one class in every case.
- The four supplied images also have **zero tensor difference**. Their maximum probability difference is below **8.30×10⁻⁷**.

These are observed parity results for the tested files, not a universal guarantee for every decoder/profile/image format. **No airplane-mode test was performed during this investigation**, and no phone network setting was changed. Inference executes the bundled native model; the APK has no internet inference pathway. [Physical device results](phase4/investigation/scores_android.json) contain all forty checks and the four full score vectors.

The exact 224×224 model crops are saved for inspection under `artifacts/phase4_investigation/image_1_model_crop.png` through `image_4_model_crop.png`. Center cropping removes plant context, and multiple leaves/backgrounds remain in several supplied inputs. Changing this preprocessing without training/validation would itself introduce a new distribution mismatch, so it has not been changed.

## Photo provenance and interpretation

| Photo | Source supplied by user | Interpretation and limits |
|---|---|---|
| 1 | [Healthier Steps: sweet-potato leaves](https://healthiersteps.com/7-surprising-sweet-potato-leaves-benefits/) | Source context and heart-shaped leaf morphology indicate sweet potato; unsupported crop. No disease ground truth supplied. |
| 2 | [Gardening Know How: potato plants not producing](https://www.gardeningknowhow.com/edible/vegetables/potato/potato-plants-not-producing.htm) | The page captions its photo as potato leaves above soil, credit ermine. Supported ordinary-potato context; multiple field leaves and soil. The article does not diagnose this photo as Early or Late Blight. |
| 3 | [SELF: leafy greens](https://www.self.com/story/vitamin-packed-leafy-green-youve-probably-never-eaten) | Article explicitly concerns sweet-potato greens, photo credit Peter Chadwick. Unsupported species and mixed root/shoot/leaf view; no disease diagnosis. |
| 4 | [Bayer: corn leaf diseases](https://www.cropscience.bayer.us/articles/bayer/general-leaf-diseases-of-corn) | User labels Common Rust. Indexed primary publisher text describes its Figure 2 as common rust; full page is behind a robot check, so the exact photo-to-caption match was not independently established. Rust-like pustules are visible, but a photo alone is not laboratory ground truth. |

Sweet potato's species distinction and heart-shaped leaf morphology are also documented by [NC State Extension](https://plants.ces.ncsu.edu/plants/ipomoea-batatas/) and [UF/IFAS plant identification](https://gardeningsolutions.ifas.ufl.edu/mastergardener/resources/plantid/vegetables/potato-sweet/). Related edible crop names are not interchangeable training labels. Common rust's pustules and gray leaf spot's vein-bounded rectangular lesions are described by [UMN common rust](https://extension.umn.edu/agriculture/crop-production/corn/common-rust-on-corn) and [UMN gray leaf spot](https://extension.umn.edu/agriculture/crop-production/corn/gray-leaf-spot-on-corn).

The leading supported-crop explanation is **controlled-to-field distribution shift**: the model was optimized on detached PlantVillage leaf photos, while the supplied photos contain field backgrounds, overlapping foliage, different lighting, zoom and unsupported organs/species. The original [PlantVillage study](https://www.frontiersin.org/journals/plant-science/articles/10.3389/fpls.2016.01419/full) also reports a substantial loss of performance outside its training capture conditions. That study's external accuracy is not AgriVision's measured accuracy.

Small Potato Healthy coverage may contribute, but it is not a proven sole cause: both field-style disease classification and crop identity are involved. Strong softmax scores are not calibrated diagnostic probabilities, and this model has no unknown-crop/unknown-condition output.

## Why forcing Potato filtering is not a fix

No filtering has been implemented. As a diagnostic arithmetic exercise on the unchanged PyTorch vectors:

| Image | Total global probability assigned to all three Potato classes | Top Potato condition if forced | Renormalized within-Potato score |
|---|---:|---|---:|
| 1 | 6.692558% | Potato Late Blight | 71.95% |
| 2 | 0.040622% | Potato Late Blight | 76.11% |
| 3 | 0.009792% | Potato Late Blight | 91.90% |

For Image 2, forcing a crop could manufacture a **76.11% Potato Late Blight** display from only **0.04062% total Potato probability**. This is conditional renormalization, not new evidence of potato identity or disease. Filtering would not solve Image 4 either: its top maize condition is already Gray Leaf Spot. Retain mismatch withholding; do not silently force a diagnosis.

## Improvements ranked by effort, risk and likely benefit

These are proposals only. No model or interface change was made.

| Rank | Improvement | Effort | Risk | Likely benefit / validation required |
|---:|---|---|---|---|
| 1 | Audit demo/evaluation sources and explicitly distinguish ordinary potato from sweet potato; photograph one supported leaf clearly with minimal overlap. Keep crop-mismatch withholding. | Low | Low | Immediate reduction in invalid tests and misleading use; capture guidance is not a guarantee of correct predictions. |
| 2 | Build an expert-labelled external benchmark from independent plants/farms/devices, including healthy ordinary potato, both blights, maize rust/leaf-spot lookalikes and unsupported sweet potato. Preserve originals and grouped provenance; keep an untouched final test set. | Medium | Low if licence/labels audited | Highest immediate benefit for measuring the actual field problem and deciding what to change. Four examples cannot rank field accuracy. |
| 3 | Design an abstention/unsupported-input policy and calibrate it on independent field and negative examples. Evaluate crop mismatch, confidence/margin/entropy and retained-result error rate together. | Medium | Medium | Reduces confidently wrong diagnoses. A single confidence threshold would not catch Image 2's 94.5% failure; field validation is essential. |
| 4 | Fine-tune the existing small architecture using verified field images of the same fourteen conditions, emphasizing healthy potato diversity and maize rust/leaf-spot differences. Rebalance by independent leaf groups, not augmented copy counts. | Medium–high | Medium | Likely strongest improvement to actual supported-crop field performance. Needs new held-out evaluation, conversion/native parity and a separately versioned APK; no benefit is promised in advance. |
| 5 | Evaluate leaf ROI selection/segmentation, framing augmentation and photometric/background variation consistently in training and inference. Compare original preprocessing against the proposal on the untouched field set. | Medium–high | Medium | May reduce background/scale sensitivity. Can remove diagnostic context or lesion detail; changing only inference crops is unsafe. |
| 6 | Investigate a shared-backbone crop/condition hierarchy or crop-specific heads with explicit unknown/mismatch handling, preserving the offline size/latency budget. | High | Medium–high | May separate identity and condition errors, but crop errors can propagate. No justification yet for replacing MobileNetV3-Small or adding unsupported crop labels. |

A larger model, different runtime, or swapping indices is not supported by this investigation. Additional augmentation alone cannot create missing field diversity or turn sweet potato into ordinary potato. The first next step should be a source-audited field benchmark, followed by a controlled adaptation experiment rather than an immediate deployed-model replacement.
