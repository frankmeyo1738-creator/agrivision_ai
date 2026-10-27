import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/models/analysis.dart';
import '../core/services/agrivision_api.dart';
import '../core/services/leaf_picker.dart';

enum BackendConnection { checking, ready, modelUnavailable, offline }

class AnalysisController extends ChangeNotifier {
  AnalysisController({required this.api, required this.picker});

  final AgriVisionApi api;
  final LeafPicker picker;
  BackendConnection connection = BackendConnection.checking;
  String? connectionMessage;
  DateTime? lastChecked;
  SelectedLeaf? image;
  LeafPrediction? prediction;
  // Retain the genuine global output for presentation of a crop mismatch.
  // It remains separate from a permitted diagnosis; no scores are filtered.
  LeafPrediction? cropMismatch;
  String? error;
  bool choosing = false;
  bool analyzing = false;
  bool checkingHealth = false;
  int completedAnalyses = 0;
  bool tomatoConfirmed = false;
  String selectedCrop = 'Tomato';
  List<String> classLabels = tomatoClasses;
  double? testAccuracy;
  double? macroF1;
  bool get isMultiCrop => classLabels.length == 14;
  List<String> get supportedCrops =>
      isMultiCrop ? cropLabels : const ['Tomato'];

  void selectCrop(String crop) {
    if (analyzing || choosing || !supportedCrops.contains(crop)) return;
    selectedCrop = crop;
    tomatoConfirmed = false;
    prediction = null;
    cropMismatch = null;
    error = null;
    _notify();
  }

  int _selectionVersion = 0;

  bool get isOnDevice => api is OnDeviceAgriVisionApi;
  bool get canCapture => picker is CameraLeafPicker;

  void confirmTomato(bool value) {
    tomatoConfirmed = value;
    _notify();
  }

  Timer? _healthTimer;
  bool _disposed = false;

  bool get canAnalyze =>
      image != null &&
      (!isOnDevice || tomatoConfirmed) &&
      !choosing &&
      !analyzing &&
      connection == BackendConnection.ready;

  void start() {
    refreshHealth();
    _recoverImage();
    if (!isOnDevice) {
      _healthTimer = Timer.periodic(
        const Duration(seconds: 15),
        (_) => refreshHealth(),
      );
    }
  }

  Future<void> refreshHealth() async {
    if (checkingHealth || _disposed) return;
    checkingHealth = true;
    _notify();
    try {
      final health = await api.health();
      if (_disposed) return;
      if (!listEquals(health.classLabels, tomatoClasses) &&
          !listEquals(health.classLabels, multiCropClasses)) {
        throw const FormatException('Unsupported class mapping.');
      }
      classLabels = health.classLabels;
      testAccuracy = health.testAccuracy;
      macroF1 = health.macroF1;
      if (!supportedCrops.contains(selectedCrop)) selectCrop('Tomato');
      connection = health.modelLoaded
          ? BackendConnection.ready
          : BackendConnection.modelUnavailable;
      connectionMessage = health.modelLoaded
          ? null
          : health.message ??
                (isOnDevice
                    ? 'The bundled model is unavailable. Reinstall the APK.'
                    : 'The backend is online, but the trained model is not loaded.');
      lastChecked = DateTime.now();
    } on ApiException catch (exception) {
      if (_disposed) return;
      connection = BackendConnection.offline;
      connectionMessage = exception.message;
    } catch (_) {
      if (_disposed) return;
      connection = BackendConnection.offline;
      connectionMessage = isOnDevice
          ? 'Could not load the on-device model. Please retry.'
          : 'Could not check the backend. Please retry.';
    } finally {
      checkingHealth = false;
      _notify();
    }
  }

  Future<void> _recoverImage() async {
    if (picker is! RecoverableLeafPicker) return;
    final version = _selectionVersion;
    try {
      final recovered = await (picker as RecoverableLeafPicker).recover();
      if (!_disposed && _selectionVersion == version && recovered != null) {
        image = recovered;
        tomatoConfirmed = false;
        _notify();
      }
    } on ImageSelectionException catch (exception) {
      if (!_disposed && _selectionVersion == version) {
        error = exception.message;
        _notify();
      }
    } catch (_) {
      if (!_disposed && _selectionVersion == version) {
        error = "Could not restore the previous photo. Choose it again.";
        _notify();
      }
    }
  }

  Future<void> chooseImage() => _chooseImage(false);

  Future<void> captureImage() => _chooseImage(true);

  Future<void> _chooseImage(bool camera) async {
    if (choosing || analyzing || _disposed) return;
    if (camera && !canCapture) return;
    _selectionVersion++;
    choosing = true;
    error = null;
    _notify();
    try {
      final selected = camera
          ? await (picker as CameraLeafPicker).capture()
          : await picker.pick();
      if (_disposed) return;
      if (selected != null) {
        image = selected;
        tomatoConfirmed = false;
        prediction = null;
        cropMismatch = null;
      }
    } on ImageSelectionException catch (exception) {
      if (!_disposed) error = exception.message;
    } catch (_) {
      if (!_disposed) {
        error = isOnDevice
            ? 'Could not open the photo selector. Please try again.'
            : 'Could not open the file picker. Please try again.';
      }
    } finally {
      choosing = false;
      _notify();
    }
  }

  void clearImage() {
    if (analyzing || choosing) return;
    _selectionVersion++;
    tomatoConfirmed = false;
    image = null;
    prediction = null;
    cropMismatch = null;
    error = null;
    _notify();
  }

  void dismissError() {
    error = null;
    _notify();
  }

  Future<void> analyze() async {
    if (!canAnalyze || _disposed) return;
    analyzing = true;
    error = null;
    prediction = null;
    cropMismatch = null;
    _notify();
    try {
      final result = await api.predict(image!);
      if (_disposed) return;
      if (!classLabels.contains(result.className) ||
          result.topThree.any((score) => !classLabels.contains(score.name))) {
        throw const ApiException('The model returned an unsupported class.');
      }
      if (result.crop != selectedCrop) {
        cropMismatch = result;
        error =
            'Selected crop: $selectedCrop. The model closest match was ${result.className} (${result.percentage}). '
            'No diagnosis is shown. Check the selected crop and photograph. Crop selection does not verify plant identity.';
        return;
      }
      prediction = result;
      completedAnalyses++;
    } on ApiException catch (exception) {
      if (_disposed) return;
      error = exception.message;
      if (exception.statusCode == 503) {
        connection = BackendConnection.modelUnavailable;
        connectionMessage = exception.message;
      }
      // A prediction failure can signal lost connectivity; check independently.
      refreshHealth();
    } catch (_) {
      if (!_disposed) error = 'Analysis could not complete. Please try again.';
    } finally {
      analyzing = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _healthTimer?.cancel();
    api.close();
    super.dispose();
  }
}
