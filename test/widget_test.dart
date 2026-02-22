import 'package:chesswarss/src/app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('alpha shell loads setup screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ChessWarssApp());

    expect(find.text('ChessWarss Alpha Setup'), findsOneWidget);
    expect(find.text('Deploy Alpha Match'), findsOneWidget);
  });

  testWidgets('can start an alpha match and reach world map', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ChessWarssApp());

    await tester.tap(find.text('Deploy Alpha Match'));
    await tester.pumpAndSettle();

    expect(find.text('ChessWarss Alpha - World Map'), findsOneWidget);
    expect(find.text('Pass Turn'), findsOneWidget);
  });
}
