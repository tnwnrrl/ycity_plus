import 'package:flutter_test/flutter_test.dart';
import 'package:ycity_plus/main.dart';

void main() {
  testWidgets('YCITY+ app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const YCityPlusApp());

    // Verify that our app title appears
    expect(find.text('YCITY+'), findsOneWidget);

    // Verify key UI elements are present
    expect(find.text('차량 정보'), findsOneWidget);
    expect(find.text('동'), findsOneWidget);
    expect(find.text('호'), findsOneWidget);
    expect(find.text('시리얼 번호'), findsOneWidget);
  });
}
