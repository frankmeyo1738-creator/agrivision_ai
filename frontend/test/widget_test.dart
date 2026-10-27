import 'dart:async';

import 'package:agrivision_ai/app.dart';
import 'package:agrivision_ai/core/models/analysis.dart';
import 'package:agrivision_ai/core/services/agrivision_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

void main() {
  Future<void> start(
    WidgetTester tester,
    TestApi api,
    TestPicker picker, {
    Size size = const Size(1280, 820),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(AgriVisionApp(api: api, picker: picker));
    await tester.pumpAndSettle();
  }

  Future<void> openAnalysis(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(ListTile, 'Leaf analysis'));
    await tester.pumpAndSettle();
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  }

  testWidgets(
    'dashboard reflects readiness and contains no prediction before analysis',
    (tester) async {
      await start(tester, TestApi(), TestPicker());
      expect(find.text('Model ready'), findsOneWidget);
      expect(find.text('0 analyses'), findsOneWidget);
      expect(find.byKey(const ValueKey('predicted-class')), findsNothing);
      expect(tester.takeException(), isNull);
      await finish(tester);
    },
  );

  testWidgets(
    'upload, delayed real-response flow, care guidance and repeat analysis',
    (tester) async {
      final api = TestApi();
      final picker = TestPicker();
      await start(tester, api, picker);
      await openAnalysis(tester);
      await tester.tap(find.byKey(const ValueKey('choose-image')));
      await tester.pumpAndSettle();
      expect(find.text('test_image.png'), findsOneWidget);
      final pending = Completer<LeafPrediction>();
      api.prediction = () => pending.future;
      await tester.tap(find.byKey(const ValueKey('analyze-image')));
      await tester.pump();
      expect(find.byKey(const ValueKey('analysis-progress')), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('analyze-image')))
            .onPressed,
        isNull,
      );
      expect(api.predictionCalls, 1);
      pending.complete(testPrediction());
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('predicted-class')), findsOneWidget);
      expect(find.text('91.0% confidence'), findsOneWidget);
      expect(find.text('Water at the base.'), findsOneWidget);
      expect(find.text('Keep tools clean.'), findsOneWidget);
      expect(find.text('6.0%'), findsOneWidget);
      expect(find.text('2.0%'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('choose-image')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('predicted-class')), findsNothing);
      api.prediction = () async => testPrediction();
      await tester.tap(find.byKey(const ValueKey('analyze-image')));
      await tester.pumpAndSettle();
      expect(api.predictionCalls, 2);
      expect(tester.takeException(), isNull);
      await finish(tester);
    },
  );

  testWidgets('failed request shows API error and permits retry', (
    tester,
  ) async {
    final api = TestApi()
      ..prediction = () async =>
          throw const ApiException('Image is corrupt.', statusCode: 400);
    await start(tester, api, TestPicker());
    await openAnalysis(tester);
    await tester.tap(find.byKey(const ValueKey('choose-image')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('analyze-image')));
    await tester.pumpAndSettle();
    expect(find.text('Image is corrupt.'), findsOneWidget);
    expect(find.byKey(const ValueKey('predicted-class')), findsNothing);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('analyze-image')))
          .onPressed,
      isNotNull,
    );
    api.prediction = () async => testPrediction();
    await tester.tap(find.byKey(const ValueKey('analyze-image')));
    await tester.pumpAndSettle();
    expect(find.text('Image is corrupt.'), findsNothing);
    expect(find.byKey(const ValueKey('predicted-class')), findsOneWidget);
    await finish(tester);
  });

  testWidgets(
    'missing model disables prediction without preventing selection',
    (tester) async {
      final api = TestApi()
        ..healthResponse = const BackendHealth(
          modelLoaded: false,
          message: 'Install model weights.',
        );
      await start(tester, api, TestPicker());
      expect(find.text('Model unavailable'), findsOneWidget);
      expect(find.text('Install model weights.'), findsOneWidget);
      await openAnalysis(tester);
      await tester.tap(find.byKey(const ValueKey('choose-image')));
      await tester.pumpAndSettle();
      expect(find.text('test_image.png'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('analyze-image')))
            .onPressed,
        isNull,
      );
      expect(api.predictionCalls, 0);
      await finish(tester);
    },
  );

  testWidgets('compact window and model information render without overflow', (
    tester,
  ) async {
    await start(tester, TestApi(), TestPicker(), size: const Size(640, 600));
    expect(tester.takeException(), isNull);
    await tester.tap(find.widgetWithText(ChoiceChip, 'About the model'));
    await tester.pumpAndSettle();
    expect(find.text('MobileNetV3-Small'), findsOneWidget);
    expect(find.text('http://127.0.0.1:8000'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await finish(tester);
  });

  testWidgets('offline indicator recovers after manual health refresh', (
    tester,
  ) async {
    final api = TestApi()
      ..healthError = const ApiException('Cannot reach the backend.');
    await start(tester, api, TestPicker());
    expect(find.text('Backend offline'), findsOneWidget);
    api.healthError = null;
    await tester.tap(find.byTooltip('Check backend connection'));
    await tester.pumpAndSettle();
    expect(find.text('Model ready'), findsOneWidget);
    expect(find.text('Cannot reach the backend.'), findsNothing);
    await finish(tester);
  });
}
