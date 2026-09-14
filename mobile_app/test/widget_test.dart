import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/main.dart';

void main() {
  testWidgets('App renders QuickSave title', (WidgetTester tester) async {
    await tester.pumpWidget(const QuickSaveApp());
    expect(find.byType(QuickSaveApp), findsOneWidget);
  });
}
