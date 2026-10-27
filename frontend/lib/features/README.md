# Frontend features

`workspace.dart` implements dashboard/navigation, `leaf_analysis.dart` implements
image preview, request/loading/error states, results and care recommendations, and
`model_page.dart` explains scope and displays live backend readiness.

`analysis_controller.dart` owns the session state using Flutter ChangeNotifier.
Shared typed responses and the production HTTP client live in `core/`. Production
has no fake result path; injected fixtures are restricted to the automated tests.
