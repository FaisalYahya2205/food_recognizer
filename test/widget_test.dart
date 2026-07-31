import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrisnap_app/app/nutrisnap_app.dart';

void main() {
  testWidgets('NutriSnap app material shell loads', (tester) async {
    await tester.pumpWidget(const NutriSnapApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
