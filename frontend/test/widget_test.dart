import 'package:flutter_test/flutter_test.dart';
import 'package:quantis_stock/main.dart';

void main() {
  testWidgets('App starts and shows navigation', (WidgetTester tester) async {
    await tester.pumpWidget(const QuantisStockApp());
    expect(find.text('Dashboard'), findsOneWidget);
  });
}
