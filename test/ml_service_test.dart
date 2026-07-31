import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nutrisnap_app/data/tensor_food_classifier.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('classifier boots with aligned labels', () async {
    final classifier = TensorFoodClassifier();
    await classifier.boot();

    expect(classifier.isReady, isTrue);
    expect(classifier.hasAlignedLabels, isTrue);

    final canvas = img.Image(width: 192, height: 192);
    img.fill(canvas, color: img.ColorRgb8(200, 160, 100));
    final result = await classifier.predictBytes(Uint8List.fromList(img.encodeJpg(canvas)));

    expect(result.name, isNotEmpty);
    expect(result.name, isNot('Model belum siap'));

    classifier.shutdown();
  });
}
