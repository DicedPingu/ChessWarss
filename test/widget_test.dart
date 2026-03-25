import 'package:chesswarss/src/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(const ProviderScope(child: ChessWarssApp()));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('mode menu loads with Eterna and Casus Belli', (
    WidgetTester tester,
  ) async {
    await _pumpApp(tester);

    expect(find.text('Choose Campaign'), findsOneWidget);
    expect(find.text('Eterna Mode'), findsOneWidget);
    expect(find.text('Casus Belli'), findsOneWidget);
    expect(find.text('World Map Lab'), findsOneWidget);
  });

  testWidgets('can open the world map lab', (WidgetTester tester) async {
    await _pumpApp(tester);

    await tester.tap(find.text('World Map Lab'));
    await tester.pumpAndSettle();

    expect(find.text('Square Legion Grid'), findsOneWidget);
    expect(find.text('Flat Hex'), findsOneWidget);
    expect(find.text('Pointy Hex'), findsOneWidget);
  });

  testWidgets('can start Casus Belli and reach world map', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpApp(tester);

    final enterCasusBelli = find.widgetWithText(
      FilledButton,
      'Enter Casus Belli',
    );
    await tester.scrollUntilVisible(
      enterCasusBelli,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(enterCasusBelli);
    await tester.pumpAndSettle();

    expect(find.text('ChessWarss - Casus Belli Setup'), findsOneWidget);
    expect(find.text('AI Difficulty'), findsOneWidget);

    final startCasusBelli = find.widgetWithText(
      FilledButton,
      'Start Casus Belli',
    );
    await tester.ensureVisible(startCasusBelli);
    await tester.tap(startCasusBelli);
    await tester.pumpAndSettle();

    expect(find.text('ChessWarss - Casus Belli Map'), findsOneWidget);
    expect(find.text('End Turn'), findsOneWidget);
    expect(find.text('Raise Camp (-1 food)'), findsOneWidget);
    expect(find.text('Outlook'), findsOneWidget);
    expect(find.text('Spare'), findsOneWidget);
  });
}
