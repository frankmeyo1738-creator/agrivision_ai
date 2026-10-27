# Phase 5.2 — Evergreen Field Guide

## Scope and recovery

Branch: `codex/phase5-2-field-guide`. All earlier uncommitted work was retained. The pre-change and completed-source archives, tracked patch, Git state and protected hashes are in `artifacts/phase5_2_baseline/`. Restore the archive into a separate directory for comparison; do not extract it over later user changes. No push, remote configuration, unrelated repository access, model replacement or retraining was performed.

The last known-good release remains `artifacts/releases/AgriVision-AI-Evergreen-arm64.apk`. Phase 3 and Phase 4 copies also remain. The new release has a separate filename, `artifacts/releases/AgriVision-AI-Evergreen-Field-Guide-arm64.apk`, version 0.3.2+4. It retains the existing demo signing key and can upgrade the installed app without uninstalling it.

Protected files: original model artifacts, fourteen-class checkpoint, bundled ONNX and manifest, backend, training and conversion sources, native classifier/preprocessor/activity, ProGuard rules, Flutter core models/services/pickers and AnalysisController. Their baseline hashes are checked separately from the generated APK. The Android manifest adds only INTERNET permission for optional educational RSS. That permission is not used by health, image handling or inference.

## Implemented experience

Explore is a local editorial library using Evergreen colors, system typography, spacious reading layouts and original SVG crop illustrations. Home and Scan retain their design and handlers. macOS retains its existing FastAPI workspace.

Six searchable crop profiles cover Tomato, Maize, ordinary Potato, Bell Pepper, Cabbage and Collard Greens. The first four retain their original fourteen leaf classes. Cabbage/collards can be read and bookmarked but cannot start diagnosis. A brassica relationship is not evidence of interchangeable crop images. Ordinary potato is explicitly Solanum tuberosum; sweet potato is unsupported.

The 16-entry collection includes seven supported disease guides, brassica black rot, a brassica caterpillar educational guide and a growing-observation article. Crop profiles include growing tips. Existing condition descriptions and management/prevention text are read directly from the unchanged model manifest, with the previously documented Evergreen display correction for the old Tomato Healthy “five classes” phrase. No new pesticide products, doses, efficacy statistics or trained classes were introduced.

Search works offline across titles, crop names, scientific names, symptoms, supported class labels and article text. Categories, crop filters, saved reading and empty states are supported. Bookmarks persist as stable article IDs in Android local preferences; failed writes do not show false saves. Optional cache corruption does not disable the library or bookmarks.

Successful, crop-consistent scan results have “Read the field guide,” routed by an explicit fourteen-entry table: healthy matches open the corresponding crop profile; disease matches open the corresponding guide. The original result remains intact on return. Mismatch screens do not gain a treatment/article shortcut. Existing safety tests remain in the suite.

Reading pages include scientific identity, symptom clues, linked related reading, locally stored source metadata, editorial source-check date, rights and a bookmark action. Body text is selectable and respects system text scaling. External links open a clear sheet before the user chooses to visit the publisher in a browser; the locally bundled article needs no connection.

## Freshness without an online dependency

“From the wider field” is an **optional, default-off** live RSS feature. Enabling it fetches genuine title/date/link metadata from [UMN Extension Crop News](https://blog-crop-news.extension.umn.edu/). It retains at most eight records and the actual check timestamp. With consent enabled, entering Explore checks at most once per 24 hours, including persisted failed-attempt timing; manual refresh remains available. No scheduled/background worker runs. Updates can be turned off while retaining previously cached headlines.

The production Dart fetcher was exercised against the real RSS endpoint; evidence is `artifacts/phase5_2_live_feed.json`. Requests are bounded to one fixed HTTPS feed, 512 KiB and ten seconds, with no redirects. Feed parsing ignores HTML bodies, embedded photos and scripts, rejects DTD/entity declarations, checks publisher article URLs and de-duplicates records. Failures preserve the previous cache and show an honest unavailable-refresh message.

Publisher articles are **not** downloaded for offline reading. Only their headline metadata is cached. The feed focuses on Minnesota/US agriculture and can include crops outside AgriVision’s model; it is labelled regional and separate from the locally source-checked library. It is not a Zambia-specific pest alert or validated treatment service. News dates are publisher dates, not disease forecasts.

The request for periodically fresh imagery is deliberately limited: no third-party live photos are fetched because their reuse rights are not established by an RSS URL. The local illustrations remain fixed, original artwork. The news titles/dates are genuinely refreshed; the app does not pretend its bundled articles or illustrations are newly published news. Offline content updates currently ship through a reviewed APK update.

## Content, references and licensing

See [content inventory, primary sources and image rights](field_guide/CONTENT_AND_LICENSES.md). Nineteen primary extension references were checked on 14 October 2026. Last-reviewed metadata means an editorial source check, not an agronomist’s approval. It does not establish the accuracy of a scan.

`frontend/assets/field_guide/library.json` is the versioned local data source. It records stable IDs, kind, crop scope, scientific names, summaries, symptoms, source-linked sections, related IDs, exact model-class associations, source-check metadata and image provenance. Runtime validation fails closed on missing references, broken links between articles or inconsistent scan routes. It never changes inference labels. Seven small SVGs are bundled under documented CC0-1.0 terms. No Wikipedia scraping, third-party photographs, remote fonts, analytics, accounts or server backend is added.

Added dependencies are shared_preferences, flutter_svg, xml and url_launcher. Their license copies are in `docs/field_guide/`. Existing dependency notices remain applicable; Flutter includes package licenses in its generated notices.

## Verification and limitations

Actual final test/build/device outcomes and hashes are recorded in `docs/phase5_2_verification.json`. Automated visual captures are under `artifacts/phase5_2_visual/`; these use presentation fixtures, not invented production predictions. Physical device captures and inference evidence, when performed, are recorded separately under `artifacts/phase5_2_device/`.

The redesign does not improve disease-classification generalization, calibration, field accuracy or species recognition. PlantVillage metrics remain controlled held-out metrics. Article symptoms are educational clues with overlapping possible causes. No pests or brassica classes are diagnosed. Reference seasons, products and practices require local adaptation; no professional local review is claimed.

The small first edition is intentionally limited and English-only. News depends on one external publisher while enabled; source websites need internet. Bookmarks/cache can be lost when app data is cleared or the app is uninstalled. Photos and scan results remain session state; no scan-history feature was added. The release continues using a classroom/demo signing key, not a Play Store production key.

Physical testing must keep the Pixel’s tethering enabled because it connects this Mac. No airplane-mode claim is made for this phase. To test full offline independence later, use a separate internet connection for the Mac, stop FastAPI, disable headline updates, disconnect the phone, then check cold launch, gallery/camera, inference, local reading, saved articles and related links in airplane mode. Cached headline metadata may remain visible, but opening a publisher article needs connectivity.

## Build and install

```sh
cd frontend
flutter analyze
flutter test
flutter build apk --release --split-per-abi --target-platform android-arm64
cd ..
adb -s YOUR_DEVICE_SERIAL install -r artifacts/releases/AgriVision-AI-Evergreen-Field-Guide-arm64.apk
```

ARM64 Android 7.0/API 24 or newer. The lecturer needs only the APK. No model conversion, model download, Python, MacBook or FastAPI is required for scanning or the bundled field guide.

## Recorded completion results

- Flutter analysis: **no issues found**.
- macOS debug build: **passed** after installing the added plugins; the existing FastAPI workspace compiles. No new macOS interactive inference run is claimed.
- Flutter tests: **69 passed**, zero failed. Existing inference, class mapping, crop-mismatch and camera/gallery tests remain in the suite.
- ARM64 Android release built and installed on the **physical Pixel 8**, version 0.3.2, split version code 2004.
- Final APK native parity: **40/40 passed**, zero input tensor difference; maximum same-input logit error **5.72205e-5**. This confirms preservation of the existing model output, not field accuracy.
- Final release normal gallery workflow: named local held-out tomato photo returned **Tomato Healthy, model match 99.6%**. “Read the field guide” opened `crop-tomato`; return preserved the result in the tested workflow.
- Offline local search for “pustules” opened the common-rust guide. Cabbage was educational only, with no scan action. Its bookmark survived a force-stop/relaunch and subsequent APK update.
- Optional headlines were fetched through the actual Android app and through the production Dart fetcher: genuine UMN publisher titles with a check date. News updates were turned off again after verification, retaining the local cache.
- Widget screenshots and physical Pixel screenshots were captured and inspected. A filter scroll issue found on the device was corrected and covered by an additional viewport assertion. Light/dark, 320-pixel width and 200% text scaling were checked in rendered widget tests.
- All **75 protected files** matched baseline hashes. APK-packaged ONNX and manifest were compared directly against source bytes. The previous Evergreen APK retains its original SHA-256.
- No new physical camera capture or airplane-mode test was performed in this phase. The camera handlers and native preprocessing are unchanged and their automated tests pass. Cellular tethering stayed enabled.

Final APK: **43,772,920 bytes** (about 43.8 MB), roughly 1.96 MB above the previous Evergreen release. SHA-256: `4aee8432517ece7d13ee6b17fa1a8629f6d6a05e22e7c4ff84174f64c239f0bc`.

Exact location: `artifacts/releases/AgriVision-AI-Evergreen-Field-Guide-arm64.apk`. Previous release: `artifacts/releases/AgriVision-AI-Evergreen-arm64.apk`. No Git push was performed.
