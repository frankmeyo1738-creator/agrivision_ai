// Optional live transport check: no fake predictions and no accuracy assertions.
// dart run tool/check_backend.dart [path/to/image.png]
import 'dart:convert';
import 'dart:io';

import 'package:agrivision_ai/core/models/analysis.dart';
import 'package:agrivision_ai/core/services/agrivision_api.dart';

Future<void> main(List<String> arguments) async {
  final api = HttpAgriVisionApi();
  try {
    final health = await api.health();
    stdout.writeln(
      'Backend ${api.baseUrl}: model_loaded=${health.modelLoaded}',
    );
    if (!health.modelLoaded) {
      throw ApiException(health.message ?? 'Model is not loaded.');
    }
    if (arguments.isNotEmpty) {
      final file = File(arguments.single);
      final suffix = file.path.split('.').last.toLowerCase();
      final mime = switch (suffix) {
        'jpg' || 'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        'webp' => 'image/webp',
        _ => throw const ApiException('Use a JPEG, PNG, or WebP file.'),
      };
      if (await file.length() > 10 * 1024 * 1024) {
        throw const ApiException('File exceeds 10 MiB.');
      }
      final result = await api.predict(
        SelectedLeaf(
          name: file.uri.pathSegments.last,
          bytes: await file.readAsBytes(),
          mimeType: mime,
          width: 0,
          height: 0,
        ),
      );
      stdout.writeln(
        const JsonEncoder.withIndent('  ').convert({
          'predicted_class': result.className,
          'confidence': result.confidence,
          'top_predictions': [
            for (final score in result.topThree)
              {'class': score.name, 'confidence': score.confidence},
          ],
          'description': result.information.description,
          'management': result.information.management,
          'confidence_note': result.confidenceNote,
        }),
      );
      stdout.writeln(
        'Transport verified. This check makes no claim about diagnostic accuracy.',
      );
    }
  } catch (error) {
    stderr.writeln('Backend check failed: $error');
    exitCode = 1;
  } finally {
    api.close();
  }
}
