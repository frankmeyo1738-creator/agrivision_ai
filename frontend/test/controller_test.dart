import 'dart:async';

import 'package:agrivision_ai/core/models/analysis.dart';
import 'package:agrivision_ai/core/services/agrivision_api.dart';
import 'package:agrivision_ai/core/services/leaf_picker.dart';
import 'package:agrivision_ai/features/analysis_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

void main() {
  test(
    'readiness gates analysis and prevents overlapping predictions',
    () async {
      final api = TestApi();
      final controller = AnalysisController(api: api, picker: TestPicker());
      addTearDown(controller.dispose);
      await controller.chooseImage();
      expect(controller.canAnalyze, isFalse);
      await controller.refreshHealth();
      final result = Completer<LeafPrediction>();
      api.prediction = () => result.future;
      final first = controller.analyze();
      await controller.analyze();
      controller.clearImage();
      expect(controller.image, isNotNull);
      expect(api.predictionCalls, 1);
      result.complete(testPrediction());
      await first;
      expect(controller.completedAnalyses, 1);
      expect(controller.prediction, isNotNull);
    },
  );

  test(
    'cancelled picker retains result but replacement clears stale scores',
    () async {
      final picker = TestPicker();
      final controller = AnalysisController(api: TestApi(), picker: picker);
      addTearDown(controller.dispose);
      await controller.refreshHealth();
      await controller.chooseImage();
      await controller.analyze();
      picker.selection = null;
      await controller.chooseImage();
      expect(controller.prediction, isNotNull);
      picker.selection = testLeaf();
      await controller.chooseImage();
      expect(controller.prediction, isNull);
      expect(controller.completedAnalyses, 1);
    },
  );

  test(
    'invalid selection preserves image and displays validation error',
    () async {
      final picker = TestPicker();
      final controller = AnalysisController(api: TestApi(), picker: picker);
      addTearDown(controller.dispose);
      await controller.chooseImage();
      picker.error = const ImageSelectionException('Unsupported format.');
      await controller.chooseImage();
      expect(controller.image, isNotNull);
      expect(controller.error, 'Unsupported format.');
    },
  );

  test(
    'model unavailable error updates readiness without returning a prediction',
    () async {
      final api = TestApi();
      final controller = AnalysisController(api: api, picker: TestPicker());
      addTearDown(controller.dispose);
      await controller.refreshHealth();
      await controller.chooseImage();
      api.healthResponse = const BackendHealth(modelLoaded: false);
      api.prediction = () async =>
          throw const ApiException('Model unavailable.', statusCode: 503);
      await controller.analyze();
      await Future<void>.delayed(Duration.zero);
      expect(controller.connection, BackendConnection.modelUnavailable);
      expect(controller.prediction, isNull);
      expect(controller.completedAnalyses, 0);
    },
  );

  test(
    'late completion after disposal does not notify or update results',
    () async {
      final api = TestApi();
      final controller = AnalysisController(api: api, picker: TestPicker());
      await controller.refreshHealth();
      await controller.chooseImage();
      final pending = Completer<LeafPrediction>();
      api.prediction = () => pending.future;
      final operation = controller.analyze();
      controller.dispose();
      pending.complete(testPrediction());
      await operation;
      expect(controller.prediction, isNull);
      expect(api.closed, isTrue);
    },
  );
}
