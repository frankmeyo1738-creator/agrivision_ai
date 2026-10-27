# Project Evergreen — Phase 5

## Scope and recovery

Branch: `codex/phase5-evergreen`. Prior uncommitted work was preserved; no reset, remote configuration, push or global Git changes were performed. `artifacts/phase5_baseline/source_before.tar.gz`, `git_status.txt` and `git_diff.patch` provide a recoverable pre-redesign baseline. The known-good Phase 4 APK is preserved as `artifacts/releases/AgriVision-AI-Phase4-arm64.apk`; Phase 3 remains alongside it.

`artifacts/phase5_baseline/protected_hashes.json` records all model files, backend/training/conversion sources, native Android sources, ProGuard configuration, Flutter API/model/picker interfaces and bundled guidance. These remain unchanged. The generated Flutter build APK path is intentionally reused by the build system; the preserved Phase 4 release copy retains its original hash.

The only controller addition retains a genuine crop-mismatch output separately from a permitted diagnosis, and resets it when a new crop/photo/analysis is selected. Crop-mismatch withholding, class validation, duplicate-request guards, confirmation, image limits, class ordering, softmax and preprocessing are unchanged.

## Design and implementation

Android now uses an independent presentation layer in `frontend/lib/features/evergreen/`. macOS retains the existing Workspace and FastAPI route. Home, Scan and Explore share an editorial typography system, restrained forest/sage tones, responsive spacing, original crop illustrations and a soft bottom navigation. The illustrations are original CustomPainter vectors; no downloaded photos/fonts, new packages, analytics or server dependencies were added.

Light and deliberately composed dark themes follow the system preference. Body text uses a darker secondary shade than the decorative #748178 token to improve contrast. Buttons have comfortable targets; crop selection includes an explicit checkmark and semantics rather than relying on colour. System text scaling is retained, and reduced-motion preferences remove presentation transitions and animated loading.

Home provides factual readiness, crop guides and scanning access. Scan preserves the original camera/gallery handlers, image bytes, preview aspect ratio, crop confirmation and readiness checks. Analysis uses an honest indeterminate state with safe tab navigation; there are no invented percentages or delays. Results reveal from the top, retain global cross-crop scores, qualify disease matches and preserve original care text. Crop mismatch displays no diagnosis or treatment, with the original comparison available in an expandable panel. Explore loads conditions, recommendations, metrics and attribution from the unchanged local manifest. Cabbage and Collard Greens are labelled planned/untrained and cannot initiate scanning.

System back returns a secondary destination to Home without losing a selected photo. Detail pages use normal Navigator back behavior. There is no inference cancellation button: leaving a tab is safe, and the ongoing result waits in Scan. Photos/results remain session state, matching the existing architecture.

## Automated and visual verification

See the final machine-readable verification report for actual results. Widget screenshots under `artifacts/phase5_visual/` are captured from rendered Flutter UI using explicit test-only fixtures and locally available SDK Roboto/Material Icons. They are visual-state tests, not real disease predictions. Real-device screenshots and inference evidence are kept separately under `artifacts/phase5_device/`.

Coverage includes readiness/loading/unavailable, Home/navigation, supported/future crops, guides, camera/gallery actions, selected image, cancellation, Analyze availability, duplicate request blocking, healthy/disease results, confidence formatting, crop mismatch, errors, repeated scans, system back, dark mode, 320×640 and 390×844 viewports, and 200% text scaling. Existing controller/API/image-validation/mapping regressions remain in the suite.

## Limitations

The UI redesign does not improve the classifier’s generalization. Controlled PlantVillage accuracy is not field accuracy; ordinary potato and sweet potato are different species. Potato Healthy has limited held-out support. Confidence remains an uncalibrated global model comparison. Unsupported conditions can receive confident scores even when the selected crop agrees.

The Android demonstration APK continues using the existing development/demo signing key; it is not a Play Store release. Camera captures may remain in the application cache. No sharing/export, persisted scan history or unsupported crop model was added. Physical testing leaves cellular tethering enabled; no airplane-mode claim should be inferred from this phase’s tests.

## Documented wording correction

Physical review found the preserved Tomato Healthy description still said “outside the five classes”, inherited from the tomato-only release. Evergreen presents that phrase as “outside this crop’s supported conditions”, clarifying the five tomato conditions within the fourteen-class model. This changes only display wording; the original manifest and all management/prevention recommendations remain byte-identical.

## Final results and installation

- Flutter analysis: no issues found.
- Flutter tests: **47 passed** (existing regressions plus 19 Evergreen state/accessibility tests).
- ARM64 release built and installed on the physical **Pixel 8**, version **0.3.0**, split version code **2003**.
- Native parity: **40/40 cases passed** on the final APK; zero tensor difference, maximum same-input logit error 5.72205e-5.
- Actual normal gallery workflow: selected the named local held-out tomato image, obtained **Healthy — model match 99.6%**, and viewed local care.
- Actual camera workflow: capture accepted and returned a valid preview; crop confirmation reset and Analyze stayed disabled. The camera scene was not classified. Canceling a second capture preserved the selected image.
- Actual crop mismatch: changing the crop to Maize for the tomato photo showed the friendly mismatch screen and withheld diagnosis/care.
- Pixel 8 Home, Scan, image review, real result, care, Explore and mismatch screenshots captured and inspected. Widget visual states used locally loaded SDK fonts; small screens and 200% text scaling also passed.
- No INTERNET permission in the release. Cellular tethering was never disabled; no airplane-mode device test is claimed.
- All **82 protected source/model/guidance files** remain byte-identical. The Phase 4 APK copy retains the baseline hash. No backend-related source was changed, so Python retraining/backend tests were not rerun for this presentation-only phase.

Install `artifacts/releases/AgriVision-AI-Evergreen-arm64.apk` on an ARM64 Android 7.0+ device. It upgrades the existing demo-signed app. The previous version is `artifacts/releases/AgriVision-AI-Phase4-arm64.apk`. Android may require uninstalling or explicitly allowing a downgrade to reinstall that older version; uninstalling clears application data. No downgrade was performed.

APK bytes: **41,814,295**. SHA-256: `0b84482f98f7368129512ba99d11002ad24a3cb8ebd812e37e2bb649eaf7d866`. The exact machine-readable build/test record is `docs/phase5_verification.json`. Native and UI workflow evidence is under `artifacts/phase5_device/`.
