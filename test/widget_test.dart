import 'dart:io';

import 'package:chesswarss/src/app.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(const ProviderScope(child: ChessWarssApp()));
  await tester.pumpAndSettle();
}

Future<void> _enterCasusBelliSetup(WidgetTester tester) async {
  await tester.ensureVisible(find.text('CASUS BELLI'));
  await tester.tap(find.text('CASUS BELLI'));
  await tester.pumpAndSettle();
}

void main() {
  test('external docs direction stays README and TODO only', () {
    final root = Directory.current;
    final docsDir = Directory('${root.path}/docs');
    final readme = File('${root.path}/README.md').readAsStringSync();
    final todo = File('${root.path}/TODO.md').readAsStringSync();

    expect(docsDir.existsSync(), isFalse);
    expect(readme, contains('Execution plan: `TODO.md`'));
    expect(
      readme,
      contains('Simple, optimized, interesting, and chess-styled'),
    );
    expect('$readme\n$todo', isNot(contains('docs/GAME_WIKI.md')));
    expect('$readme\n$todo', isNot(contains('docs/GAME_VISION.md')));
    expect('$readme\n$todo', isNot(contains('check_docs_consistency.sh')));
  }, skip: kIsWeb);

  testWidgets('mode menu loads with Eterna and Casus Belli', (
    WidgetTester tester,
  ) async {
    await _pumpApp(tester);

    expect(find.text('Select Your Campaign'), findsOneWidget);
    expect(find.text('ETERNA'), findsOneWidget);
    expect(find.text('Eternal'), findsOneWidget);
    expect(find.text('CASUS BELLI'), findsOneWidget);
    expect(find.text('Cause for War'), findsOneWidget);
    expect(find.text('TABULAE PROBATIONIS'), findsOneWidget);
    expect(find.text('Test Tables'), findsOneWidget);
  });

  testWidgets('tabulae probationis shows prototype direction', (
    WidgetTester tester,
  ) async {
    await _pumpApp(tester);

    await tester.ensureVisible(find.text('TABULAE PROBATIONIS'));
    await tester.tap(find.text('TABULAE PROBATIONIS'));
    await tester.pumpAndSettle();

    expect(find.text('Tabulae Probationis'), findsOneWidget);
    expect(find.text('Logistics & Siege Simulation'), findsOneWidget);
    expect(find.text('Standard Grid (Square)'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Hexagonal (6-Edged)'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Hexagonal (6-Edged)'), findsOneWidget);
    expect(find.textContaining('Works now:'), findsWidgets);
    expect(find.textContaining('Not proven:'), findsWidgets);
    expect(find.textContaining('Direction:'), findsWidgets);
  });

  testWidgets('can start Casus Belli and reach world map', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpApp(tester);

    await _enterCasusBelliSetup(tester);
    expect(find.text('ChessWarss - Casus Belli Setup'), findsOneWidget);
    expect(find.text('AI Difficulty'), findsOneWidget);

    final startCasusBelli = find.widgetWithText(
      FilledButton,
      'Start Casus Belli',
    );
    await tester.ensureVisible(startCasusBelli);
    await tester.tap(startCasusBelli);
    await tester.pumpAndSettle();

    expect(find.text('ChessWarss - Casus Belli Campaign'), findsOneWidget);
    expect(find.text('End Turn'), findsOneWidget);
    expect(find.text('Raise Camp (-1 food)'), findsOneWidget);
    expect(find.text('Outlook'), findsOneWidget);
    expect(find.text('Spare'), findsOneWidget);
  });

  testWidgets('field manual is the in-game player action guide', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpApp(tester);
    await _enterCasusBelliSetup(tester);

    await tester.tap(find.byTooltip('Field Manual'));
    await tester.pumpAndSettle();

    expect(find.text('Field Manual'), findsOneWidget);
    expect(
      find.text(
        'Quick reference for what each player action does and why it matters.',
      ),
      findsOneWidget,
    );
    expect(find.text('First Minute'), findsOneWidget);
    expect(find.text('Logistics Orders'), findsOneWidget);
    expect(find.text('Camps and Settlements'), findsOneWidget);
    expect(find.text('Battle Actions'), findsOneWidget);
    expect(find.text('Victory and Policy'), findsOneWidget);
  });

  testWidgets('logistics prototype states what works and what is unproven', (
    WidgetTester tester,
  ) async {
    await _pumpApp(tester);

    await tester.ensureVisible(find.text('TABULAE PROBATIONIS'));
    await tester.tap(find.text('TABULAE PROBATIONIS'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Logistics & Siege Simulation'));
    await tester.pumpAndSettle();

    expect(find.text('Prototype Status'), findsOneWidget);
    expect(find.textContaining('Works: one-hex movement'), findsOneWidget);
    expect(find.textContaining('Not proven: balance'), findsOneWidget);
    expect(find.textContaining('Direction: keep logistics'), findsOneWidget);
    expect(find.text('Pillage Local Tile'), findsOneWidget);
  });
}
