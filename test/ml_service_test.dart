import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_recognizer_app/services/ml_service.dart';
import 'package:image/image.dart' as img;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('AIY food model loads and classifies sample image', () async {
    final service = MLService();
    await service.initialize();

    expect(service.isModelLoaded, isTrue);
    expect(service.labels.length, 2024);
    expect(service.labelsMatchModel, isTrue);
    expect(service.labels.contains('Sushi'), isTrue);

    final image = img.Image(width: 192, height: 192);
    img.fill(image, color: img.ColorRgb8(240, 220, 180));
    final bytes = Uint8List.fromList(img.encodeJpg(image));

    final result = await service.classifyImageBytes(bytes);

    expect(result.label, isNotEmpty);
    expect(result.label, isNot('Model belum tersedia'));
    expect(result.label, isNot('Model dan label tidak cocok'));
    expect(result.label, isNot('Prediksi gagal'));

    service.close();
  });
}
