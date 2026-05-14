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
  await tester.tap(find.text('CASUS BELLI'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Start Cause for War'));
  await tester.pumpAndSettle();
}

Future<void> _enterProvingTables(WidgetTester tester) async {
  await tester.tap(find.text('TABULAE PROBATIONIS'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Start Proving Tables'));
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

    expect(
      find.text('Choose a mode. Tap once for details, then start.'),
      findsOneWidget,
    );
    expect(find.text('ROMA AETERNA'), findsWidgets);
    expect(find.text('Eternal Rome'), findsOneWidget);
    expect(find.text('CASUS BELLI'), findsOneWidget);
    expect(find.textContaining('Cause for War'), findsWidgets);
    expect(find.text('TABULAE PROBATIONIS'), findsOneWidget);
    expect(find.textContaining('Proving Tables'), findsWidgets);
    expect(find.text('Start Eternal Rome'), findsOneWidget);
  });

  testWidgets('tabulae probationis shows playable map directions', (
    WidgetTester tester,
  ) async {
    await _pumpApp(tester);

    await _enterProvingTables(tester);

    expect(find.text('Tabulae Probationis / Proving Tables'), findsOneWidget);
    expect(find.text('Logistics & Siege'), findsWidgets);
    expect(find.text('Square Warboard'), findsWidgets);
    expect(find.text('Hex Campaign'), findsOneWidget);
    expect(find.text('Province Web'), findsOneWidget);
    expect(find.text('Three Fronts'), findsOneWidget);
    expect(find.text('Island Crossings'), findsOneWidget);
    expect(find.textContaining('Works:'), findsWidgets);
    expect(find.textContaining('Not proven:'), findsWidgets);
    expect(find.textContaining('Direction:'), findsWidgets);
  });

  testWidgets('map prototype lets player select and move', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpApp(tester);

    await _enterProvingTables(tester);
    await tester.tap(find.text('Square Warboard').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open Test'));
    await tester.pumpAndSettle();

    expect(find.text('Square Warboard Test'), findsOneWidget);
    expect(find.textContaining('Army: E1'), findsOneWidget);
    expect(find.text('Move Here'), findsOneWidget);

    await tester.tap(find.text('E2'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move Here'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Army: E2'), findsOneWidget);
    expect(find.textContaining('Moves: 1'), findsOneWidget);
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

    await _enterProvingTables(tester);

    await tester.tap(find.text('Logistics & Siege').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open Test'));
    await tester.pumpAndSettle();

    expect(find.text('Prototype Status'), findsOneWidget);
    expect(find.textContaining('Works: one-hex movement'), findsOneWidget);
    expect(find.textContaining('Not proven: balance'), findsOneWidget);
    expect(find.textContaining('Direction: keep logistics'), findsOneWidget);
    expect(find.text('Pillage Local Tile'), findsOneWidget);
  });
}
