import 'package:agrivision_ai/app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Phase 1 shell starts with the project identity', (tester) async {
    await tester.pumpWidget(const AgriVisionApp());
    expect(find.text('AgriVision AI'), findsOneWidget);
    expect(find.text('Phase 1 · Project foundation'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
