# Phase 3 completion — fully offline Android

Completed implementation on **12 October 2026**, branch **`phase3/offline-android`**. The standalone ARM64 APK contains a genuine ONNX conversion of the existing MobileNetV3-Small checkpoint, all five tomato labels and local disease/care guidance. Android runs native CPU inference; macOS retains FastAPI inference.

## Deliverables

- Installable APK: `artifacts/releases/AgriVision-AI-Phase3-arm64.apk`, **41,633,132 bytes** (~41.6 MB decimal).
- SHA-256: `5fc802a47dde5abac6e44c2f9909189de9cfc2b5e2593be093c221c393880174`.
- ARM64, minimum Android API 24, target API 36; package `ai.agrivision.agrivision_ai`, version `0.1.0`, ABI-split version code `2001`.
- [Installation, rebuilding, Pixel 8 acceptance test and limitations](ANDROID_INSTALLATION.md).
- [Conversion script](../deployment/android/convert_model.py), [guarded bundling](../deployment/android/bundle_model.py), [fixed-image acquisition](../deployment/android/fetch_verification_images.py), [native verification fixture preparation](../deployment/android/prepare_verification.py).
- [Conversion evidence](android/conversion_verification.json), [Android runtime evidence](android/android_verification.json), [preprocessing cases](android/preprocessing_cases.json), [build metadata](android/build_info.json).

The APK is built in release mode and signed with the development Android debug/demo key for classroom installation. APK v2 signature and ZIP alignment passed verification. Its native ELF load segments are aligned to at least 16 KiB; the test emulator itself used 4 KiB pages. **No `INTERNET` permission appears in the final APK.** The generated test images, tensors and instrumentation assets are excluded from it.

## Conversion route decision

| Route | Evidence / outcome |
|---|---|
| **PyTorch → ONNX → ONNX Runtime Android 1.23.2** | **Selected and tested with the actual checkpoint.** Torch 2.8.0's Dynamo exporter, ONNX opset 18, fixed float32 `[1,3,224,224]` input and `[1,5]` logits output; single **6,571,494-byte** ONNX artifact with no external weight file. Python CPU and Android native runtime parity passed. [Official mobile deployment guidance](https://onnxruntime.ai/docs/tutorials/mobile/) |
| **PyTorch → LiteRT/TFLite through LiteRT Torch** | Evaluated; **not converted/tested here**. The [official converter](https://github.com/google-ai-edge/litert-torch) documents Linux support, while this environment is macOS ARM64. A Linux/Colab conversion could be attempted later, but there was no verified reason to replace the working ONNX route for this milestone. |

The initial exporter helper combination (ONNXScript 0.5.6 / ONNX IR 1.0.0) failed in a version-conversion pass. Pinning ONNXScript **0.3.2** and ONNX IR **0.1.12** produced the verified export without changing Torch, checkpoint weights or model architecture. Reproduction dependencies are pinned in `deployment/android/requirements.txt`.

Release smoke testing additionally exposed R8 removal of an ONNX Runtime constructor called through JNI. Explicit `ai.onnxruntime` keep rules were added to `frontend/android/app/proguard-rules.pro`; the corrected release APK was installed and exercised successfully. Preserve these rules: successful debug instrumentation alone does not validate release shrinking.

## Genuine model verification

Five hash-pinned source leaf photographs, one sampled from each of the existing source folders, were used as fixed conversion cases. They may overlap model training data. **These checks measure conversion/runtime parity, not new accuracy, field generalization or an independent held-out evaluation.** No predictions were substituted or mocked in conversion, native tests or the release UI smoke test.

| Check | Actual result |
|---|---|
| PyTorch vs desktop ONNX Runtime, fixed five images | All top-three orders identical; maximum absolute logit difference **0.000027179718**; maximum probability difference **0.000001966953** |
| Android native runtime, 26 cases | All top-one indices identical to PyTorch; maximum same-input logit error **0.000022888184**; maximum probability error **0.000001662748** |
| Android preprocessing vs Python goldens | **Maximum tensor error 0** on the tested cases, including JPEG/lossless leaf pairs, grayscale/RGBA/WebP, all eight EXIF tags and odd/portrait/landscape/downsample/upscale geometry patterns |
| Invalid input handling | Empty, corrupt and oversized byte inputs rejected without a prediction |
| Flutter analysis | No issues |
| Flutter tests | **25 passed**, including existing desktop HTTP behavior, native-channel errors, scope confirmation and narrow mobile layouts |
| Existing Python backend/training tests | **40 passed**; dependency deprecation warnings only |
| Additional export/bundle safety tests | **2 passed** |
| Native Android instrumentation | **2 tests passed**, including the 26-case parity suite |
| macOS release build | Passed; existing HTTP pathway retained |

The production Android implementation decodes bounds before allocating images, applies EXIF orientation, converts/drops alpha to RGB, performs separable bilinear antialiasing with Pillow-compatible rounding, resizes the short edge to 256, uses a 224 center crop with ties-to-even positioning, writes NCHW float32 and applies ImageNet mean/std. It validates the bundled model hash and class ordering. No quantization or retraining occurred.

## Offline release workflow

The **actual corrected release APK**, not an injected test API, was installed on the temporary ARM64 Android emulator (`sdk_gphone64_arm64`, SDK 36). With **airplane mode on, Wi-Fi disabled, mobile data disabled and localhost port 8000 unreachable**:

1. Cold-started the app and reached **Offline · model ready**.
2. Opened the Android gallery and selected the known local tomato-leaf JPEG.
3. Verified that Analyze was disabled until tomato confirmation.
4. Ran the bundled native model. The UI displayed **Healthy / 99.3%**, Early Blight **0.6%**, Late Blight **0.1%**, matching the reference at displayed precision.
5. Viewed the genuine description, management and prevention guidance without a server or network.
6. Force-stopped/restarted and repeated the gallery/prediction flow through the completed automated smoke script.
7. Captured a simulated camera image (1,440×1,920 JPEG), returned to preview, verified that previous predictions/confirmation cleared and Analyze remained disabled. No diagnosis was performed on the non-tomato emulator scene. A second camera launch/cancellation preserved the selection.

The release smoke trace is retained at `artifacts/android_verification/ui_trace.json`; screen captures and UI XML are in the same directory. [Smoke script](../deployment/android/emulator_smoke.py) uses the real app/photo picker and compares its displayed fixed-image result with the reference. It assumes the controlled English-language emulator contains the known test photo; it is not a general physical-device automation harness.

**Physical Pixel 8 testing was unavailable.** No physical-device latency, accuracy, camera-quality or memory/thermal result is claimed. Exact disconnected-phone/airplane-mode steps are supplied in the installation guide. Emulator timings in the native JSON are not Pixel 8 performance measurements.

## Preserved scope and remaining limitations

All **34 original backend/training/model files** checked against pre-Phase-3 hashes were unchanged, including `best_model.pt`, `class_mapping.json` and `evaluation.json`. Prior working macOS frontend changes were retained. The five-class order remains Healthy, Early Blight, Late Blight, Bacterial Spot, Leaf Mold. No unrelated repository, Git remote or global Git configuration was changed, and nothing was pushed.

This remains a **tomato-leaf-only** classifier. The UI states scope, requires per-photo confirmation and explains that confidence is not certainty and crop identity is not independently verified. Unsupported crops, diseases or mixed symptoms must not be treated as reliable diagnoses. Camera capture and cancellation worked with the emulator camera; the physical Pixel 8 capture/return path remains an acceptance-test item. Standard JPEG/PNG/WebP and the documented size bounds apply. Local camera cache, decoder/color-profile differences outside the tested set, demo signing and physical-device validation limits are detailed in [installation instructions](ANDROID_INSTALLATION.md).
