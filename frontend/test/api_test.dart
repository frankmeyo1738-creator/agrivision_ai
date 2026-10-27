import 'dart:async';
import 'dart:convert';

import 'package:agrivision_ai/core/models/analysis.dart';
import 'package:agrivision_ai/core/services/agrivision_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support.dart';

void main() {
  test('health calls correct endpoint and parses readiness', () async {
    final api = HttpAgriVisionApi(
      client: MockClient((request) async {
        expect(request.url.toString(), 'http://127.0.0.1:8000/health');
        expect(request.method, 'GET');
        return http.Response(
          '{"status":"ok","model_loaded":false,"model_message":"Missing weights"}',
          200,
        );
      }),
    );
    addTearDown(api.close);
    final health = await api.health();
    expect(health.modelLoaded, isFalse);
    expect(health.message, 'Missing weights');
  });

  test(
    'predict sends multipart image with explicit MIME type and uses returned scores',
    () async {
      final api = HttpAgriVisionApi(
        client: MockClient((request) async {
          expect(request.url.path, '/predict');
          expect(request.method, 'POST');
          expect(
            request.headers['content-type'],
            startsWith('multipart/form-data; boundary='),
          );
          final body = latin1.decode(request.bodyBytes);
          expect(body, contains('name="image"; filename="test_image.png"'));
          expect(body.toLowerCase(), contains('content-type: image/png'));
          return http.Response(jsonEncode(predictionJson()), 200);
        }),
      );
      addTearDown(api.close);
      final prediction = await api.predict(testLeaf());
      expect(prediction.className, 'Tomato Healthy');
      expect(prediction.topThree.map((p) => p.confidence), [.91, .06, .02]);
      expect(prediction.information.management, ['Water at the base.']);
    },
  );

  test('server error preserves actionable detail and status', () async {
    final api = HttpAgriVisionApi(
      client: MockClient(
        (_) async =>
            http.Response('{"detail":"Model files are missing."}', 503),
      ),
    );
    addTearDown(api.close);
    await expectLater(
      api.predict(testLeaf()),
      throwsA(
        isA<ApiException>()
            .having((e) => e.statusCode, 'status', 503)
            .having((e) => e.message, 'detail', 'Model files are missing.'),
      ),
    );
  });

  test(
    'malformed success response never becomes a fabricated prediction',
    () async {
      final api = HttpAgriVisionApi(
        client: MockClient((_) async => http.Response('{}', 200)),
      );
      addTearDown(api.close);
      await expectLater(api.predict(testLeaf()), throwsA(isA<ApiException>()));
    },
  );

  test('bad score ranges and inconsistent ranking are rejected', () {
    final json = predictionJson()..['confidence'] = 1.5;
    expect(() => LeafPrediction.fromJson(json), throwsFormatException);
    final inconsistent = predictionJson()
      ..['predicted_class'] = 'Tomato Early Blight';
    expect(() => LeafPrediction.fromJson(inconsistent), throwsFormatException);
  });

  test('timeout is bounded and produces a friendly error', () async {
    final api = HttpAgriVisionApi(
      healthTimeout: const Duration(milliseconds: 5),
      client: MockClient((_) => Completer<http.Response>().future),
    );
    addTearDown(api.close);
    await expectLater(
      api.health(),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          contains('too long'),
        ),
      ),
    );
  });

  test('connection errors are actionable', () async {
    final api = HttpAgriVisionApi(
      client: MockClient(
        (_) async => throw http.ClientException('unreachable'),
      ),
    );
    addTearDown(api.close);
    await expectLater(
      api.health(),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          contains('backend'),
        ),
      ),
    );
  });
}
