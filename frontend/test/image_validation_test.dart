import 'dart:typed_data';

import 'package:agrivision_ai/core/services/leaf_picker.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'encoded dimensions and MIME come from bytes rather than filename',
    () async {
      final image = await validateLeaf('misleading.jpg', testLeaf().bytes);
      expect(image.mimeType, 'image/png');
      expect(image.width, 48);
      expect(image.height, 32);
    },
  );

  test(
    'empty, oversized, unsupported and corrupt images are rejected',
    () async {
      await expectLater(
        validateLeaf('empty.png', Uint8List(0)),
        throwsA(isA<ImageSelectionException>()),
      );
      await expectLater(
        validateLeaf('large.png', Uint8List(maxImageBytes + 1)),
        throwsA(isA<ImageSelectionException>()),
      );
      await expectLater(
        validateLeaf('text.png', Uint8List.fromList([1, 2, 3])),
        throwsA(isA<ImageSelectionException>()),
      );
      await expectLater(
        validateLeaf(
          'broken.png',
          Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]),
        ),
        throwsA(isA<ImageSelectionException>()),
      );
    },
  );
}
