import 'package:flutter_test/flutter_test.dart';
import 'package:khk_mobile/main.dart';

void main() {
  testWidgets('App loads', (WidgetTester tester) async {
    await tester.pumpWidget(const KHKApp(showOnboarding: false));
    expect(find.text('KHK CRICKET'), findsOneWidget);
  });
}
