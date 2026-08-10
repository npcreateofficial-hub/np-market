import 'package:flutter_test/flutter_test.dart';
import 'package:np_market/main.dart';

void main() {
  testWidgets('shows the marketplace home screen', (tester) async {
    await tester.pumpWidget(const NpMarketApp());
    await tester.pumpAndSettle();

    expect(find.text('FLASH SALE'), findsOneWidget);
    expect(find.text('Mall'), findsOneWidget);
    expect(find.text('Video'), findsOneWidget);
  });
}