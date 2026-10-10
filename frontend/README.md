# AgriVision AI — Flutter foundation

This phase contains a minimal Material 3 application shell and macOS target.
Image selection, HTTP, and theme dependencies are prepared for Phase 2.
The native target requires macOS 12 or newer to match the installed Xcode toolchain.

From this directory:

```sh
flutter pub get
flutter analyze
flutter test
flutter run -d macos --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

The macOS target has user-selected read-only file access and outgoing network
entitlements in debug and release. Keep the backend running on loopback port 8000
when implementing the API client. The current shell does not make API calls.
