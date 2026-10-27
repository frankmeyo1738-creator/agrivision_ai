import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_selector/file_selector.dart';

import '../models/analysis.dart';

const maxImageBytes = 10 * 1024 * 1024;
const maxImagePixels = 20000000;

class ImageSelectionException implements Exception {
  const ImageSelectionException(this.message);
  final String message;
}

abstract class LeafPicker {
  Future<SelectedLeaf?> pick();
}

abstract interface class CameraLeafPicker implements LeafPicker {
  Future<SelectedLeaf?> capture();
}

abstract interface class RecoverableLeafPicker implements LeafPicker {
  Future<SelectedLeaf?> recover();
}

class NativeLeafPicker implements LeafPicker {
  @override
  Future<SelectedLeaf?> pick() async {
    final file = await openFile(
      acceptedTypeGroups: [
        const XTypeGroup(
          label: 'Leaf images',
          extensions: ['jpg', 'jpeg', 'png', 'webp'],
          uniformTypeIdentifiers: [
            'public.jpeg',
            'public.png',
            'org.webmproject.webp',
          ],
        ),
      ],
    );
    if (file == null) return null;
    if (await file.length() > maxImageBytes) {
      throw const ImageSelectionException(
        'Choose an image smaller than 10 MiB.',
      );
    }
    return validateLeaf(file.name, await file.readAsBytes());
  }
}

/// Inspect encoded dimensions before decoding a preview to avoid large allocations.
Future<SelectedLeaf> validateLeaf(String name, Uint8List bytes) async {
  if (bytes.isEmpty) {
    throw const ImageSelectionException(
      'This file is empty. Choose another image.',
    );
  }
  if (bytes.length > maxImageBytes) {
    throw const ImageSelectionException('Choose an image smaller than 10 MiB.');
  }
  final mime = detectImageMime(bytes);
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  ui.ImageDescriptor? descriptor;
  try {
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    if (descriptor.width * descriptor.height > maxImagePixels) {
      throw const ImageSelectionException(
        'Choose an image under 20 megapixels.',
      );
    }
    return SelectedLeaf(
      name: name,
      bytes: bytes,
      mimeType: mime,
      width: descriptor.width,
      height: descriptor.height,
    );
  } on ImageSelectionException {
    rethrow;
  } catch (_) {
    throw const ImageSelectionException(
      'This image cannot be opened. Choose another photo.',
    );
  } finally {
    descriptor?.dispose();
    buffer.dispose();
  }
}

String detectImageMime(Uint8List bytes) {
  bool startsWith(List<int> signature) =>
      bytes.length >= signature.length &&
      Iterable<int>.generate(
        signature.length,
      ).every((i) => bytes[i] == signature[i]);
  if (startsWith([0xff, 0xd8, 0xff])) return 'image/jpeg';
  if (startsWith([137, 80, 78, 71, 13, 10, 26, 10])) return 'image/png';
  if (bytes.length >= 12 &&
      startsWith([82, 73, 70, 70]) &&
      bytes[8] == 87 &&
      bytes[9] == 69 &&
      bytes[10] == 66 &&
      bytes[11] == 80) {
    return 'image/webp';
  }
  throw const ImageSelectionException(
    'Use a JPEG, PNG, or WebP photo of a supported leaf.',
  );
}
