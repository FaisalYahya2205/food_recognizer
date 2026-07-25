import 'package:flutter_test/flutter_test.dart';
import 'package:food_recognizer_app/main.dart';

void main() {
  testWidgets('App initialization smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const FoodRecognizerApp());
    expect(find.text('Food Recognizer App'), findsOneWidget);
  });
}
