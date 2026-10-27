import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/analysis.dart';
import 'agrivision_api.dart';

/// Android uses only this channel: no HTTP client, server URL or network fallback.
class OfflineAgriVisionApi implements OnDeviceAgriVisionApi {
  OfflineAgriVisionApi({
    MethodChannel? channel,
    this.timeout = const Duration(seconds: 60),
  }) : _channel = channel ?? const MethodChannel('ai.agrivision/offline');

  final MethodChannel _channel;
  final Duration timeout;
  bool _closed = false;

  @override
  String get baseUrl => 'Bundled on-device model · ONNX Runtime';

  Future<Map<String, dynamic>> _invoke(
    String method, [
    Map<String, dynamic>? arguments,
  ]) async {
    if (_closed) throw const ApiException('The on-device session is closed.');
    try {
      final value = await _channel
          .invokeMethod<dynamic>(method, arguments)
          .timeout(timeout);
      // Normalize StandardMessageCodec's nested map types before shared parsing.
      return jsonDecode(jsonEncode(value)) as Map<String, dynamic>;
    } on PlatformException catch (error) {
      throw ApiException(error.message ?? 'The on-device model could not run.');
    } on MissingPluginException {
      throw const ApiException(
        'The Android inference runtime is unavailable. Reinstall the APK.',
      );
    } on TimeoutException {
      throw const ApiException(
        'On-device analysis took too long. Try a smaller photo or reopen the app.',
      );
    } on FormatException {
      throw const ApiException(
        'The on-device runtime returned an invalid result.',
      );
    } on TypeError {
      throw const ApiException(
        'The on-device runtime returned an invalid result.',
      );
    }
  }

  @override
  Future<BackendHealth> health() async =>
      BackendHealth.fromJson(await _invoke('health'));

  @override
  Future<LeafPrediction> predict(SelectedLeaf image) async =>
      LeafPrediction.fromJson(await _invoke('predict', {'bytes': image.bytes}));

  @override
  void close() => _closed = true;
}
