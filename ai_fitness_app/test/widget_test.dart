// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:ai_fitness_app/main.dart';

void main() {
  testWidgets('Home screen loads', (WidgetTester tester) async {
    await tester.pumpWidget(const FitnessApp());

    expect(find.text('Hey Prajwal 👋'), findsOneWidget);
    expect(find.text('Set Goal'), findsOneWidget);
    expect(find.text('Log Workout'), findsOneWidget);
    expect(find.text('Log Diet'), findsOneWidget);
    expect(find.text('AI Coach'), findsOneWidget);
  });
}
