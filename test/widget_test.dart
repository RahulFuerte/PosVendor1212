// This is a basic Flutter widget test for the POS application.

// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:pos/main.dart';

void main() {
  testWidgets('POS App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Wait for initial frame
    await tester.pump();

    // Verify that the app loads without crashing
    // The app should show some UI elements (this is a basic smoke test)
    expect(find.byType(MaterialApp), findsOneWidget);
    
    // Cancel any pending timers to avoid test failures
    await tester.pump(const Duration(seconds: 5));
  });
}
