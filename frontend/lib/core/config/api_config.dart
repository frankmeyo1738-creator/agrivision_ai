abstract final class ApiConfig {
  /// Pass --dart-define=API_BASE_URL=http://127.0.0.1:8000 to override.
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );
}
