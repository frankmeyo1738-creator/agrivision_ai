import 'dart:convert';
import 'dart:io';

import 'package:agrivision_ai/app.dart';
import 'package:agrivision_ai/core/models/analysis.dart';
import 'package:agrivision_ai/core/services/agrivision_api.dart';
import 'package:agrivision_ai/core/services/offline_api.dart';
import 'package:agrivision_ai/features/analysis_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

class LocalTestApi extends TestApi implements OnDeviceAgriVisionApi {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('ai.agrivision/offline');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('local service invokes native runtime with original bytes', () async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return call.method == 'health'
          ? {'status': 'ok', 'model_loaded': true}
          : predictionJson();
    });
    final api = OfflineAgriVisionApi();
    expect((await api.health()).modelLoaded, true);
    expect((await api.predict(testLeaf())).className, 'Tomato Healthy');
    expect(calls.map((call) => call.method), ['health', 'predict']);
    expect(calls[1].arguments['bytes'], testLeaf().bytes);
    api.close();
    await expectLater(api.health(), throwsA(isA<ApiException>()));
  });

  test('native failure is surfaced and never falls back to HTTP', () async {
    messenger.setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(
        code: 'OFFLINE_INFERENCE',
        message: 'Model checksum failed.',
      );
    });
    await expectLater(
      OfflineAgriVisionApi().predict(testLeaf()),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'message',
          'Model checksum failed.',
        ),
      ),
    );
  });

  test(
    'offline controller requires crop confirmation for each new photo',
    () async {
      final api = LocalTestApi();
      final controller = AnalysisController(api: api, picker: TestPicker());
      await controller.refreshHealth();
      await controller.chooseImage();
      expect(controller.canAnalyze, false);
      await controller.analyze();
      expect(api.predictionCalls, 0);
      controller.confirmTomato(true);
      expect(controller.canAnalyze, true);
      await controller.analyze();
      expect(api.predictionCalls, 1);
      await controller.chooseImage();
      expect(controller.tomatoConfirmed, false);
      expect(controller.prediction, isNull);
      controller.dispose();
    },
  );

  test(
    'bundled labels and educational guidance retain all fourteen class indices',
    () {
      final manifest =
          jsonDecode(
                File('assets/models/model_manifest.json').readAsStringSync(),
              )
              as Map<String, dynamic>;
      expect(manifest['labels'], multiCropClasses);
      for (final label in manifest['labels'] as List) {
        final guidance = manifest['guidance'][label];
        expect(guidance['description'], isNotEmpty);
        expect(guidance['management'], isNotEmpty);
        expect(guidance['prevention'], isNotEmpty);
      }
      expect(manifest['preprocessing']['resize_short_edge'], 256);
      expect(manifest['preprocessing']['image_size'], 224);
    },
  );

  testWidgets('mobile offline screens render at narrow width with crop scope', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      AgriVisionApp(api: LocalTestApi(), picker: TestPicker()),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ready to scan offline'), findsOneWidget);
    expect(find.text('Grow with\nconfidence.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Scan').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('choose-image')));
    await tester.tap(find.byKey(const ValueKey('choose-image')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('confirm-tomato')));
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('analyze-image')))
          .onPressed,
      isNull,
    );
    await tester.tap(find.byKey(const ValueKey('confirm-tomato')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('analyze-image')));
    await tester.tap(find.byKey(const ValueKey('analyze-image')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('predicted-class')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Explore').last);
    await tester.runAsync(() async {
      await rootBundle.loadString('assets/field_guide/library.json');
      await rootBundle.loadString('assets/models/model_manifest.json');
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });
    await tester.pumpAndSettle();
    expect(find.text('Intelligence, close to nature.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
