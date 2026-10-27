import 'package:shared_preferences/shared_preferences.dart';

/// Small preferences only: article IDs, feed consent and bounded headline cache.
/// No leaf photos or inference output is written here.
abstract interface class GuideStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

class LocalGuideStore implements GuideStore {
  late final _preferences = SharedPreferencesAsync();
  @override
  Future<String?> read(String key) =>
      _preferences.getString('field_guide.$key');
  @override
  Future<void> write(String key, String value) =>
      _preferences.setString('field_guide.$key', value);
}
