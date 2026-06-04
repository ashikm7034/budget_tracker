import 'package:flutter_test/flutter_test.dart';
import 'package:moeny_control/main.dart';

void main() {
  testWidgets('App starts up smoke test', (WidgetTester tester) async {
    await tester.runAsync(() async {
      // Build our app and trigger a frame.
      await tester.pumpWidget(const MyApp());

      // Verify that the MaterialApp container is built.
      expect(find.byType(MyApp), findsOneWidget);
    });
  });
}
