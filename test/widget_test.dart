// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:teamate_mobile/main.dart';

void main() {
  testWidgets('TeaMate dashboard and navigation smoke test', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const TeaMateApp());
    await tester.pumpAndSettle();

    expect(find.text('TeaMate'), findsOneWidget);
    expect(find.text('Yield Optimization Command Center'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Yield'), findsOneWidget);
    expect(find.text('Alerts'), findsOneWidget);

    await tester.tap(find.text('Yield'));
    await tester.pumpAndSettle();
    expect(find.text('Yield Optimization'), findsOneWidget);

    await tester.tap(find.text('Alerts'));
    await tester.pumpAndSettle();
    expect(find.text('Notifications'), findsOneWidget);

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(find.text('Field Routing Priority'), findsOneWidget);
  });
}
