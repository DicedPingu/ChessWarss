import 'package:chesswarss/src/app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('prototype shell loads setup screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ChessWarssApp());

    expect(find.text('ChessWarss Prototype Setup'), findsOneWidget);
    expect(find.text('Start Prototype Match'), findsOneWidget);
  });

  testWidgets('can start a prototype match and reach world map', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ChessWarssApp());

    await tester.tap(find.text('Start Prototype Match'));
    await tester.pumpAndSettle();

    expect(find.text('ChessWarss Prototype - World Map'), findsOneWidget);
    expect(find.text('Pass Turn'), findsOneWidget);
  });
}
