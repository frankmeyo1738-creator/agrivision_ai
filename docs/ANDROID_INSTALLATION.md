# Current release: Evergreen Field Guide (Phase 5.2)

Install `artifacts/releases/AgriVision-AI-Evergreen-Field-Guide-arm64.apk` for the current four-crop/fourteen-class app and offline Explore library. The previous Evergreen APK is preserved alongside it. Follow [current installation, content and verification notes](PHASE5_2_FIELD_GUIDE.md). Optional headline updates add INTERNET permission; scanning and local articles remain offline. The historical Phase 3 instructions below describe the older tomato-only APK and its original verification state.

# AgriVision AI — offline Android installation

Phase 3, 12 October 2026. This version supports **tomato leaves only**: Healthy, Early Blight, Late Blight, Bacterial Spot and Leaf Mold. It runs the actual converted MobileNetV3-Small checkpoint using ONNX Runtime on the phone.

## APK for the lecturer

The build is saved at `artifacts/releases/AgriVision-AI-Phase3-arm64.apk` inside this project. It targets **ARM64 Android 7.0/API 24 or newer**, including the Pixel 8. A MacBook, Python, FastAPI and internet are **not needed to use the installed app**. The final APK has no Android `INTERNET` permission. The model, exact five labels, descriptions, management and prevention guidance are bundled.

This is a release-mode APK signed with the development machine's **Android debug/demo key** for classroom sideloading. It is not a Play Store production release. Preserve the signing key for compatible future updates; a different signing key requires uninstalling the earlier build first.

1. Transfer the APK to the Pixel 8 by USB, Quick Share or another chosen method. Transfer is separate from inference.
2. Open the APK from the phone's **Files** app. If prompted, allow **Install unknown apps** for that installer, then install AgriVision AI. The lecturer needs only the APK, not the source directory or model files.
3. Open AgriVision AI and wait for **Offline · model ready**.
4. Choose **Analyze**, then **Choose image** to open the Android gallery/photo picker. Select a clear tomato-leaf photo, or use **Take a photo** with an available camera application.
5. Confirm **This is a tomato leaf**, then select **Analyze leaf**. This confirmation is a user scope check; the classifier cannot independently identify unsupported crops.
6. Scroll to the closest supported match, three confidence scores, disease description, management and prevention guidance. Selecting a new image clears previous results and requires new confirmation.

Optional developer installation over USB:

```sh
adb devices
adb -s YOUR_PIXEL_SERIAL install -r artifacts/releases/AgriVision-AI-Phase3-arm64.apk
```

After installation, disconnect USB and use the app independently.

## Exact Pixel 8 acceptance test

**Physical Pixel 8 testing was unavailable during implementation.** The Android emulator was tested; the following physical-device check remains required before handing the phone to the lecturer.

1. Install the APK above and copy at least five known tomato-leaf photos onto the phone. Use actual leaf photos, preferably held-out field photos; conversion parity examples do not establish disease accuracy.
2. Stop FastAPI on the development Mac (`Ctrl+C` in its server terminal), then disconnect the phone from the Mac. No server should be accessible.
3. On the Pixel 8, enable **airplane mode**, and separately ensure **Wi-Fi and mobile data are off**. Wi-Fi can remain enabled independently of airplane mode, so check both.
4. Force-stop AgriVision AI in Android Settings → Apps, then launch it again while still offline. Confirm model readiness without any download or backend connection.
5. Open Analyze → Choose image. Select the first tomato photo. Check preview, confirm tomato scope, run analysis and record the real label/scores. Verify the description and care recommendations render while offline.
6. Repeat for the remaining photos. Check that image replacement removes stale results and that repeated predictions on the same photo are consistent.
7. Use **Take a photo** in the Pixel Camera's standard roughly 12 MP mode; capture a tomato leaf, return to AgriVision and analyze. Cancel one capture and one gallery selection to confirm that cancellation does not corrupt the existing selection.
8. Rotate the phone and test a portrait JPEG with EXIF rotation. Verify the preview and results remain sensible. The inference code applies all eight EXIF orientations before resize/crop.
9. Try a corrupt/unsupported file if available and a file larger than 10 MiB. Confirm an error appears, no invented result is shown, and a valid subsequent image succeeds.
10. Uncheck the tomato confirmation box and confirm Analyze is disabled. Do not use a non-tomato photograph as a valid diagnosis merely because it receives a confident output.
11. Force-stop and relaunch again in airplane mode. Verify first-launch/restart model loading, gallery and recommendations still work. Record device model, Android version, APK SHA-256, photo identifiers, results and any errors.

## Limits and troubleshooting

- Five tomato classes only; other crops, unrepresented diseases, mixed symptoms and non-leaf images can produce misleading closed-set scores. Confidence is not diagnostic certainty, and “Healthy” does not exclude other disorders. Seek local agricultural confirmation for significant symptoms.
- No model retraining, multi-crop expansion, quantization or independent accuracy evaluation was performed in Phase 3. Conversion checks verify preservation of existing outputs.
- Use **JPEG, PNG or WebP**, at most **10 MiB / 20 megapixels**. Android additionally bounds each edge to 8,192 pixels and aspect ratio to 16:1 to avoid excessive allocations. Pixel 8's 50 MP capture mode can exceed the limit; use standard camera mode or export a smaller image. HEIC/RAW are not supported.
- Source preprocessing is RGB, EXIF transpose, bilinear antialiased short-edge resize to 256, center crop to 224, NCHW float32 and ImageNet normalization. Android/Pillow decoder or color-profile differences may occur on photos outside the tested set; unusual CMYK/wide-gamut files are not validated. Standard phone JPEGs are preferred.
- The camera button invokes an installed Android camera app. If unavailable or denied, use the gallery. Camera captures can remain in the application's temporary cache; Android may clean it. Photos/results are not uploaded, and analysis results are not persisted as a history database.
- The ARM64 APK does not support 32-bit-only or x86 Android devices. Runtime performance, camera behavior and thermal/memory behavior on the physical Pixel 8 still need the acceptance test above.
- If the bundled model fails its integrity check or cannot load, retry once or reinstall the APK. There is no HTTP/cloud fallback or synthetic prediction fallback.
- Guidance text is available offline. Source URLs are citation text; visiting external references is optional and outside offline inference.

## Rebuild without changing the checkpoint

Build-time development dependencies are required only on the developer computer. Keep `models/best_model.pt`, `class_mapping.json` and `evaluation.json` intact.

From the repository root with its Python 3.11 environment:

```sh
.venv/bin/python -m pip install -r deployment/android/requirements.txt
.venv/bin/python -m deployment.android.fetch_verification_images
.venv/bin/python -m deployment.android.convert_model --output artifacts/android-export-new
.venv/bin/python -m deployment.android.bundle_model --source artifacts/android-export-new
```

The fetch command obtains only the five small, hash-pinned parity photos already identified in the conversion report. The export script refuses a previously occupied output unless `--replace` is explicitly supplied; it never writes to the original model directory. Bundle validation checks the passing report, converted model hash, source checkpoint hash, preprocessing and exact class ordering.

Then:

```sh
cd frontend
flutter pub get
flutter analyze
flutter test
flutter build apk --release --target-platform android-arm64 --split-per-abi
```

Output: `frontend/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`. Use ABI split mode to exclude unused ONNX Runtime libraries. On the current Mac, Flutter is installed at `/Users/frankmeyo/Downloads/flutter/bin/flutter`; use that executable if it is not on PATH. Java is available inside Android Studio. The project pins the currently installed NDK `30.0.14904198`; another development machine must install that NDK and the Android SDK build requirements. No global Git changes are necessary.

## Rerun native Android verification

Generate the instrumentation-only assets from the fixed photos:

```sh
.venv/bin/python -m deployment.android.prepare_verification
adb -s emulator-5554 shell cmd connectivity airplane-mode enable
adb -s emulator-5554 shell svc wifi disable
adb -s emulator-5554 shell svc data disable
cd frontend/android
./gradlew :app:connectedDebugAndroidTest
```

Additional packaging safety tests: `.venv/bin/python -m pytest deployment/android/test_conversion.py`.

There are two native tests: actual model/preprocessing parity across 26 cases, and rejection of invalid/oversized images. These test assets are excluded from the release APK. See [Phase 3 completion report](PHASE3_COMPLETION.md), [conversion results](android/conversion_verification.json) and [Android runtime results](android/android_verification.json).

## macOS remains available

The same Flutter source selects `HttpAgriVisionApi` and the existing desktop file picker on macOS. Start FastAPI as before and run `flutter run -d macos`. Android selects the native on-device channel automatically; it does not use the desktop API URL or connectivity polling.
