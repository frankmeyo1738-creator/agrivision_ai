import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../models/analysis.dart';
import 'leaf_picker.dart';

class AndroidLeafPicker implements CameraLeafPicker, RecoverableLeafPicker {
  AndroidLeafPicker({ImagePicker? picker}) : _picker = picker ?? ImagePicker();
  final ImagePicker _picker;

  Future<SelectedLeaf?> _read(XFile? file) async {
    if (file == null) return null;
    if (await file.length() > maxImageBytes) {
      throw const ImageSelectionException(
        'Choose an image smaller than 10 MiB.',
      );
    }
    return validateLeaf(file.name, await file.readAsBytes());
  }

  Future<SelectedLeaf?> _choose(ImageSource source) async {
    try {
      // Keep original bytes/EXIF: resizing and orientation happen in the runtime.
      return await _read(await _picker.pickImage(source: source));
    } on PlatformException catch (error) {
      throw ImageSelectionException(
        source == ImageSource.camera
            ? 'Camera unavailable or access denied. You can choose a gallery photo instead.'
            : error.message ?? 'Could not open the gallery. Please try again.',
      );
    }
  }

  @override
  Future<SelectedLeaf?> pick() => _choose(ImageSource.gallery);

  @override
  Future<SelectedLeaf?> capture() => _choose(ImageSource.camera);

  @override
  Future<SelectedLeaf?> recover() async {
    final response = await _picker.retrieveLostData();
    if (response.isEmpty) return null;
    if (response.exception != null) {
      throw const ImageSelectionException(
        'The previous photo selection could not be restored. Choose it again.',
      );
    }
    return _read(response.files?.firstOrNull);
  }
}
