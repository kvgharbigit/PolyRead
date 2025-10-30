// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:polyread/main.dart';

void main() {
  testWidgets('PolyRead app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: PolyReadApp()));

    // Verify that the app loads
    expect(find.byType(PolyReadApp), findsOneWidget);
    
    // Wait for the app to finish loading
    await tester.pumpAndSettle();
    
    // This is a basic smoke test - just ensure the app doesn't crash
  });
}
