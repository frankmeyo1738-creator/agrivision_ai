// Fixtures are restricted to tests. Production uses real HTTP inference on macOS and the real native runtime on Android.
import 'dart:io';

import 'package:agrivision_ai/core/models/analysis.dart';
import 'package:agrivision_ai/core/services/agrivision_api.dart';
import 'package:agrivision_ai/core/services/leaf_picker.dart';

SelectedLeaf testLeaf() => SelectedLeaf(
  name: 'test_image.png',
  bytes: File('test/fixtures/test_image.png').readAsBytesSync(),
  mimeType: 'image/png',
  width: 48,
  height: 32,
);

Map<String, dynamic> predictionJson() => {
  'predicted_class': 'Tomato Healthy',
  'confidence': .91,
  'top_predictions': [
    {'class': 'Tomato Healthy', 'confidence': .91},
    {'class': 'Tomato Early Blight', 'confidence': .06},
    {'class': 'Tomato Late Blight', 'confidence': .02},
  ],
  'disease_information': {
    'description': 'Test fixture description.',
    'management': ['Water at the base.'],
    'prevention': ['Keep tools clean.'],
    'sources': ['https://example.test/guidance'],
  },
  'confidence_note': 'Test fixture: confidence is not diagnostic certainty.',
};

LeafPrediction testPrediction() => LeafPrediction.fromJson(predictionJson());

class TestApi implements AgriVisionApi {
  @override
  String get baseUrl => 'http://127.0.0.1:8000';
  BackendHealth healthResponse = const BackendHealth(modelLoaded: true);
  ApiException? healthError;
  Future<LeafPrediction> Function() prediction = () async => testPrediction();
  int predictionCalls = 0;
  bool closed = false;

  @override
  Future<BackendHealth> health() async {
    if (healthError != null) throw healthError!;
    return healthResponse;
  }

  @override
  Future<LeafPrediction> predict(SelectedLeaf image) {
    predictionCalls++;
    return prediction();
  }

  @override
  void close() => closed = true;
}

class TestPicker implements LeafPicker {
  SelectedLeaf? selection = testLeaf();
  ImageSelectionException? error;

  @override
  Future<SelectedLeaf?> pick() async {
    if (error != null) throw error!;
    return selection;
  }
}
