import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_litert/flutter_litert.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('inspect dish_classifier.tflite tensors', () async {
    final interpreter = await Interpreter.fromAsset('assets/ml/dish_classifier.tflite');
    final input = interpreter.getInputTensor(0);
    final output = interpreter.getOutputTensor(0);

    // ignore: avoid_print
    print('INPUT shape=${input.shape} type=${input.type} params=${input.params}');
    // ignore: avoid_print
    print('OUTPUT shape=${output.shape} type=${output.type} params=${output.params}');

    interpreter.close();
  });
}
