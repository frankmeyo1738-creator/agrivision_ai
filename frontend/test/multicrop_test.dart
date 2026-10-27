import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:io';
import 'package:agrivision_ai/core/models/analysis.dart';
import 'package:agrivision_ai/features/analysis_controller.dart';
import 'package:agrivision_ai/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support.dart';
import 'offline_test.dart' show LocalTestApi;

void main() {
  test(
    'all fourteen indices and crop identities agree with the bundled manifest',
    () {
      final manifest = jsonDecode(
        File('assets/models/model_manifest.json').readAsStringSync(),
      );
      expect(manifest['labels'], multiCropClasses);
      for (var i = 0; i < 14; i++) {
        expect(manifest['classes'][i]['index'], i);
        expect(manifest['classes'][i]['label'], multiCropClasses[i]);
        expect(
          cropForClass(multiCropClasses[i]),
          manifest['classes'][i]['crop'],
        );
      }
    },
  );
  test(
    'crop mismatch suppresses diagnosis and changing crop clears confirmation',
    () async {
      final api = LocalTestApi()
        ..healthResponse = const BackendHealth(
          modelLoaded: true,
          classLabels: multiCropClasses,
        );
      final controller = AnalysisController(api: api, picker: TestPicker());
      await controller.refreshHealth();
      await controller.chooseImage();
      controller.selectCrop('Maize');
      controller.confirmTomato(true);
      await controller.analyze();
      expect(controller.prediction, isNull);
      expect(controller.error, contains('Tomato Healthy'));
      expect(controller.completedAnalyses, 0);
      controller.selectCrop('Tomato');
      expect(controller.tomatoConfirmed, false);
      controller.confirmTomato(true);
      await controller.analyze();
      expect(controller.prediction!.crop, 'Tomato');
      controller.dispose();
    },
  );
  testWidgets('four-crop picker and model page render on a narrow phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = LocalTestApi()
      ..healthResponse = const BackendHealth(
        modelLoaded: true,
        classLabels: multiCropClasses,
        testAccuracy: .9746044962531224,
        macroF1: .9692177978803732,
      );
    await tester.pumpWidget(AgriVisionApp(api: api, picker: TestPicker()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Scan').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Maize').last);
    await tester.tap(find.text('Maize').last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Explore').last);
    await tester.runAsync(() async {
      await rootBundle.loadString('assets/field_guide/library.json');
      await rootBundle.loadString('assets/models/model_manifest.json');
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });
    await tester.pumpAndSettle();
    expect(find.text('About the model'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
