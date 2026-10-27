import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../config/api_config.dart';
import '../models/analysis.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

abstract class AgriVisionApi {
  String get baseUrl;
  Future<BackendHealth> health();
  Future<LeafPrediction> predict(SelectedLeaf image);
  void close();
}

/// Marker for a local runtime; preserves the existing HTTP interface on macOS.
abstract interface class OnDeviceAgriVisionApi implements AgriVisionApi {}

class HttpAgriVisionApi implements AgriVisionApi {
  HttpAgriVisionApi({
    http.Client? client,
    String baseUrl = ApiConfig.baseUrl,
    this.healthTimeout = const Duration(seconds: 5),
    this.predictionTimeout = const Duration(seconds: 45),
  }) : _client = client ?? http.Client(),
       _baseUri = Uri.parse(baseUrl.endsWith('/') ? baseUrl : '$baseUrl/');

  final http.Client _client;
  final Uri _baseUri;
  final Duration healthTimeout;
  final Duration predictionTimeout;

  @override
  String get baseUrl => _baseUri.toString().replaceFirst(RegExp(r'/$'), '');

  @override
  Future<BackendHealth> health() => _guard(() async {
    final response = await _client.get(_baseUri.resolve('health'));
    return BackendHealth.fromJson(_decode(response));
  }, healthTimeout);

  @override
  Future<LeafPrediction> predict(SelectedLeaf image) => _guard(() async {
    final request = http.MultipartRequest('POST', _baseUri.resolve('predict'))
      ..files.add(
        http.MultipartFile.fromBytes(
          'image',
          image.bytes,
          filename: image.name,
          contentType: MediaType.parse(image.mimeType),
        ),
      );
    final response = await http.Response.fromStream(
      await _client.send(request),
    );
    return LeafPrediction.fromJson(_decode(response));
  }, predictionTimeout);

  Map<String, dynamic> _decode(http.Response response) {
    dynamic json;
    try {
      json = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      if (response.statusCode >= 200 && response.statusCode < 300) {
        throw const ApiException(
          'The backend returned an unreadable response. Please retry.',
        );
      }
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = json is Map ? json['detail'] : null;
      throw ApiException(
        detail is String && detail.isNotEmpty
            ? detail
            : _statusMessage(response.statusCode),
        statusCode: response.statusCode,
      );
    }
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Expected a JSON object.');
    }
    return json;
  }

  String _statusMessage(int status) => switch (status) {
    400 => 'The image could not be decoded. Choose another tomato-leaf photo.',
    413 => 'The image is too large. Use a file under 10 MiB and 20 megapixels.',
    415 => 'Use a JPEG, PNG, or WebP image.',
    422 =>
      'The backend could not validate this upload. Choose the image again.',
    503 =>
      'The trained model is unavailable. Check the backend and model files.',
    _ =>
      'The backend could not complete this request (HTTP $status). Please retry.',
  };

  Future<T> _guard<T>(Future<T> Function() action, Duration timeout) async {
    try {
      return await action().timeout(timeout);
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw const ApiException(
        'The backend took too long to respond. Check it and retry.',
      );
    } on SocketException {
      throw const ApiException(
        'Cannot reach the backend. Start the local server and retry.',
      );
    } on http.ClientException {
      throw const ApiException(
        'Connection interrupted. Check the local backend and retry.',
      );
    } on FormatException {
      throw const ApiException(
        'The backend response has an unexpected format. Please retry.',
      );
    } on TypeError {
      throw const ApiException(
        'The backend response has an unexpected format. Please retry.',
      );
    }
  }

  @override
  void close() => _client.close();
}
