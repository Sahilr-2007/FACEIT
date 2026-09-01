import 'package:flutter_test/flutter_test.dart';

import 'package:mobile_app/main.dart';

void main() {
  testWidgets('App renders smoke test', (WidgetTester tester) async {
    // Build the Aura app and trigger a frame.
    await tester.pumpWidget(const AuraApp());

    // Verify that the app title is rendered.
    expect(find.text('A U R A'), findsOneWidget);
  });
}
