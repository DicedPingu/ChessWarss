import 'package:chesswarss/src/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('mode menu loads with Eterna and Casus Belli', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ChessWarssApp());

    expect(find.text('Choose Campaign'), findsOneWidget);
    expect(find.text('Eterna Mode'), findsOneWidget);
    expect(find.text('Casus Belli'), findsOneWidget);
  });

  testWidgets('can start Casus Belli and reach world map', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ChessWarssApp());

    await tester.drag(find.byType(ListView), const Offset(0, -220));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enter Casus Belli'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('ChessWarss - Casus Belli Setup'), findsOneWidget);
    expect(find.text('AI Difficulty'), findsOneWidget);

    await tester.tap(find.text('Start Casus Belli'));
    await tester.pumpAndSettle();

    expect(find.text('ChessWarss - Casus Belli Map'), findsOneWidget);
    expect(find.text('Pass Turn'), findsOneWidget);
    expect(find.text('Establish Camp (-1 food)'), findsOneWidget);
    expect(find.text('Outlook'), findsOneWidget);
    expect(find.text('Spare'), findsOneWidget);
  });
}
