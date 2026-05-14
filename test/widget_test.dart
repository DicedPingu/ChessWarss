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
  await tester.tap(find.text('Start War Table Trials'));
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
    expect(find.textContaining('War Table Trials'), findsWidgets);
    expect(find.text('Start Eternal Rome'), findsOneWidget);
  });

  testWidgets('tabulae probationis shows playable map directions', (
    WidgetTester tester,
  ) async {
    await _pumpApp(tester);

    await _enterProvingTables(tester);

    expect(find.text('War Table Trials'), findsOneWidget);
    expect(find.text('TEST'), findsWidgets);
    expect(find.text('Road Tempo'), findsWidgets);
    expect(find.text('Twin Crossing'), findsOneWidget);
    expect(find.text('Crown Hill'), findsOneWidget);
    expect(find.text('Valley Gate'), findsOneWidget);
    expect(find.text('Coastal Landing'), findsOneWidget);
    expect(find.text('Forest Screen'), findsOneWidget);
    expect(find.text('Supply Spine'), findsOneWidget);
    expect(find.text('Siege Ring'), findsOneWidget);
    expect(find.text('Three Approaches'), findsOneWidget);
    expect(find.text('Command Piece'), findsOneWidget);
    expect(find.text('General + Cohort'), findsOneWidget);
    expect(find.text('March Column'), findsOneWidget);
    expect(find.text('Logistics & Siege'), findsNothing);
    expect(find.text('Square Warboard'), findsNothing);
    expect(find.text('Province Web'), findsNothing);
    expect(find.text('Three Fronts'), findsNothing);
    expect(find.text('Island Crossings'), findsNothing);
    expect(find.text('FEEL'), findsOneWidget);
    expect(find.text('OK'), findsOneWidget);
    expect(find.text('CUT?'), findsOneWidget);
  });

  testWidgets('war table menu stays inside a phone viewport', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpApp(tester);

    await _enterProvingTables(tester);

    expect(find.text('CHESSWARSS  |  WAR TABLE TRIALS'), findsOneWidget);
    expect(find.text('Select -> TEST'), findsOneWidget);
    expect(find.text('TEST'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('map test uses direct select and click-to-move orders', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpApp(tester);

    await _enterProvingTables(tester);
    await tester.tap(find.text('Road Tempo').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('war-table-open-test')));
    await tester.pumpAndSettle();

    expect(find.text('Road Tempo Test'), findsOneWidget);
    expect(find.textContaining('Turn 1: Roman Vanguard'), findsOneWidget);
    expect(find.text('Move Here'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('map-test-tile-H41')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Roman Vanguard selected'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('map-test-tile-H30')));
    await tester.pumpAndSettle();

    expect(find.textContaining('moved to 4.1'), findsOneWidget);
    expect(find.textContaining('Turn 2: Hill Host'), findsOneWidget);
    expect(find.textContaining('Turn auto-ended'), findsOneWidget);
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

  testWidgets('siege ring makes fort pressure visible in the test bed', (
    WidgetTester tester,
  ) async {
    await _pumpApp(tester);

    await _enterProvingTables(tester);

    await tester.tap(find.text('Siege Ring').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('war-table-open-test')));
    await tester.pumpAndSettle();

    expect(find.text('Siege Ring Test'), findsOneWidget);
    expect(find.textContaining('encircle'), findsWidgets);
    expect(find.byIcon(Icons.fort_rounded), findsWidgets);
    expect(find.textContaining('Tap active army'), findsOneWidget);
    expect(find.text('Move Here'), findsNothing);
  });

  testWidgets('general cohort test stacks every chess piece on one hex', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpApp(tester);

    await _enterProvingTables(tester);

    await tester.tap(find.text('General + Cohort').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('war-table-open-test')));
    await tester.pumpAndSettle();

    expect(find.text('General + Cohort Test'), findsOneWidget);
    expect(find.textContaining('Livia Varro'), findsOneWidget);
    expect(find.textContaining('full chess army'), findsOneWidget);
    for (final piece in ['K', 'Q', 'R', 'B', 'N', 'P']) {
      expect(find.byKey(ValueKey('stack-piece-rome-$piece')), findsOneWidget);
    }
    expect(find.text('Move Here'), findsNothing);
  });
}
