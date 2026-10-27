import 'dart:io';
import 'package:agrivision_ai/features/field_guide/library.dart';
import 'package:agrivision_ai/features/field_guide/storage.dart';

FieldLibrary testLibrary() => FieldLibrary.parse(
  File('assets/field_guide/library.json').readAsStringSync(),
);

class MemoryGuideStore implements GuideStore {
  final Map<String, String> values = {};
  bool fail = false;
  @override
  Future<String?> read(String key) async {
    if (fail) throw const FileSystemException('Test unavailable store');
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    if (fail) throw const FileSystemException('Test failed write');
    values[key] = value;
  }
}
