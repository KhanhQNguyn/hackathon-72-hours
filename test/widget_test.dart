import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:job_access_assist/app.dart';

// Placeholder smoke test only, per scaffolder.md Step 8 — real widget
// tests come with the actual UI logic (plan.md Workstream B2).
void main() {
  testWidgets('App builds and shows the voice trigger button', (WidgetTester tester) async {
    await tester.pumpWidget(const App());

    expect(find.byIcon(Icons.mic), findsOneWidget);
  });
}
