// Explicit developer verification only; not invoked by the application.
import 'dart:convert';
import 'dart:io';
import 'package:agrivision_ai/features/field_guide/news.dart';

Future<void> main() async {
  final headlines = await ExtensionNewsSource().fetch();
  final result = {
    'source': feedUri.toString(),
    'checked_at_utc': DateTime.now().toUtc().toIso8601String(),
    'count': headlines.length,
    'network_request': 'One HTTPS GET; metadata only',
    'items': headlines.map((n) => n.toJson()).toList(),
  };
  File('../artifacts/phase5_2_live_feed.json').writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(result)}\n',
  );
  stdout.writeln('Verified ${headlines.length} real university RSS headlines.');
}
