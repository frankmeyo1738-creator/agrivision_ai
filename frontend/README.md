# AgriVision AI — macOS frontend

A responsive Material 3 crop-health dashboard with a native file picker, photo
preview, actual FastAPI predictions, ranked confidence bars, disease descriptions,
management/prevention guidance, and model information. Photos and results remain
in memory for the session. No production mock predictions or stored photo history.

## Run

Keep the backend running in a separate terminal, from the repository root:

```sh
source .venv/bin/activate
python -m uvicorn backend.app.main:app --host 127.0.0.1 --port 8000
```

From this `frontend` directory, with Flutter on PATH:

```sh
flutter pub get
flutter run -d macos
```

On this development Mac the executable is
`/Users/frankmeyo/Downloads/flutter/bin/flutter` if it is not on PATH. The native
target requires macOS 12 or newer. Release builds target Apple Silicon (arm64),
matching the demonstration hardware. Use the green **Model ready** indicator before
analysis. Choose **Leaf analysis**, select a tomato-leaf photo, and choose **Analyze
leaf**. Replace or remove the photo to clear the previous result. Cmd+O opens the
native picker. The Overview also includes the same analysis flow.

Override the backend address when needed:

```sh
flutter run -d macos --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

Backend readiness uses `/health` on startup, every 15 seconds, and manual refresh.
`/predict` receives a multipart field named `image` with its actual image MIME type.
Health requests time out after five seconds; prediction requests after 45 seconds.
The frontend handles offline/model-unavailable states, malformed responses, timeouts,
invalid image formats, empty/corrupt files, size limits, and backend error details.
Prediction and selection controls prevent overlapping actions. Late responses after
widget disposal are ignored. Choosing a new photo removes stale predictions.

JPEG, PNG, and WebP are accepted, up to 10 MiB and 20 megapixels. MIME signatures
and encoded dimensions are checked before preview/upload. The backend independently
validates the upload. Photos are not sent until analysis is requested. Guidance and
confidence scores come from the returned response; confidence is not diagnostic certainty.

## Structure

- `lib/core/models/`: typed health/prediction/image data and response validation.
- `lib/core/services/`: HTTP multipart client and native image selection/validation.
- `lib/core/theme/`, `widgets/`: agricultural Material 3 palette and shared components.
- `lib/features/analysis_controller.dart`: built-in ChangeNotifier state and readiness polling.
- `lib/features/workspace.dart`: responsive navigation and session dashboard.
- `lib/features/leaf_analysis.dart`: preview, request states, ranked results and care guidance.
- `lib/features/model_page.dart`: scope, limitations and live backend details.

No third-party state management or charting library is used. macOS debug and release
entitlements allow outgoing network connections and user-selected read-only files.

## Verify and build

```sh
flutter analyze
flutter test
flutter build macos --release
```

Tests include protocol parsing and multipart MIME, errors/timeouts, image validation,
state transitions, duplicate-request prevention, cancellation/disposal, responsive
layout, result rendering, retry and readiness recovery. Fixtures live only in `test/`
and are not included as app assets or used by the production API client.

Optional live HTTP check using the same production client:

```sh
dart run tool/check_backend.dart
dart run tool/check_backend.dart path/to/real-tomato-leaf.jpg
```

The second command prints actual predictions without making an accuracy assertion.
See `../docs/frontend-completion.md` for the executed checks and native launch report.


## Phase 3: offline Android

Android automatically selects `OfflineAgriVisionApi` and `AndroidLeafPicker`; macOS
retains `HttpAgriVisionApi` and its existing desktop picker. Native Android Kotlin
code runs the bundled ONNX model on a serial background executor, applies the
verified Python-compatible preprocessing and returns the same prediction schema.
Model readiness is local; Android does not poll FastAPI or fall back to HTTP.

The Android navigation adapts the dashboard for narrow screens. Gallery, camera,
preview, per-photo tomato confirmation, real top-three scores and local care
recommendations work without a server. Unsupported crops are explicitly outside
scope; confirmation does not add crop-recognition capability to this classifier.

Build after preparing the verified model bundle as described in
[Android installation](../docs/ANDROID_INSTALLATION.md):

```sh
flutter build apk --release --target-platform android-arm64 --split-per-abi
```

Install `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`. The app targets
ARM64 Android API 24+, including Pixel 8. Original PyTorch artifacts remain in
`models/`; Android receives only a separately generated and verified ONNX export.
See [Phase 3 report](../docs/PHASE3_COMPLETION.md) for actual test results and limits.

## Evergreen Field Guide (Phase 5.2)

Android Explore now includes a locally bundled six-crop educational library, offline text search, related reading, persisted bookmarks and exact links from successful scan matches. Cabbage and Collard Greens remain education only; diagnosis retains the four-crop/fourteen-class scope. Optional, default-off UMN Extension RSS updates cache only eight headline/date/link records. Publisher articles need internet; local reading and inference do not.

Source schema: `assets/field_guide/library.json`. Presentation/library code: `lib/features/field_guide/`. See [content, rights, testing and installation](../docs/PHASE5_2_FIELD_GUIDE.md). No model/preprocessing files are changed.
