import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_ml_model_downloader/firebase_ml_model_downloader.dart';
import 'package:flutter_litert/flutter_litert.dart';
import 'package:http/http.dart' as http;
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import '../utils/camera_image_converter.dart';

enum ModelSource { none, firebaseMl, firebaseStorage, localAsset }

class RecognitionResult {
  final String label;
  final double confidence;

  RecognitionResult({required this.label, required this.confidence});

  String get confidencePercentage => '${(confidence * 100).toStringAsFixed(1)}%';

  @override
  String toString() => '$label ($confidencePercentage)';
}

class MLService {
  static const _assetModelPath = 'assets/models/food_classifier.tflite';
  static const _storageModelUrl =
      'https://firebasestorage.googleapis.com/v0/b/food-recognizer-56804.firebasestorage.app/o/models%2Ffood_classifier.tflite?alt=media';
  static const _minModelBytes = 1024;
  static const _minConfidence = 0.25;

  Interpreter? _interpreter;
  List<String> _labels = [];
  bool _isModelLoaded = false;
  ModelSource modelSource = ModelSource.none;
  int _inputSize = 224;
  int _outputClassCount = 0;
  TensorType _inputType = TensorType.float32;
  TensorType _outputType = TensorType.float32;
  QuantizationParams _outputQuant = QuantizationParams(1.0, 0);

  bool get isModelLoaded => _isModelLoaded;
  bool get labelsMatchModel =>
      _labels.isNotEmpty && _outputClassCount > 0 && _labels.length == _outputClassCount;
  ModelSource get loadedFrom => modelSource;
  List<String> get labels => List.unmodifiable(_labels);

  Future<void> initialize() async {
    try {
      await _loadLabels();
      await _loadModel();
    } catch (e) {
      debugPrint('MLService initialization error: $e');
    }
  }

  Future<void> _loadLabels() async {
    try {
      final labelData = await rootBundle.loadString('assets/models/labels.txt');
      _labels = labelData
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('Error loading labels.txt: $e');
      rethrow;
    }
  }

  Future<void> _loadModel() async {
    File? modelFile;

    modelFile = await _tryFirebaseMlDownload();
    modelFile ??= await _tryFirebaseStorageDownload();
    modelFile ??= await _copyAssetModelToCache();
    if (modelFile != null && modelSource == ModelSource.none) {
      modelSource = ModelSource.localAsset;
    }

    if (modelFile == null || !await _isValidModelFile(modelFile)) {
      final loadedFromAsset = await _loadModelFromBundledAsset();
      if (loadedFromAsset) return;

      _isModelLoaded = false;
      debugPrint(
        'Model ML tidak valid. Pastikan assets/models/food_classifier.tflite '
        'dan assets/models/labels.txt tersedia dan ukuran model > 1 KB.',
      );
      return;
    }

    try {
      _interpreter = Interpreter.fromFile(modelFile);
      _configureInterpreterShapes();
      _isModelLoaded = true;
      debugPrint('LiteRT model loaded from ${modelSource.name}: ${modelFile.path}');
    } catch (e) {
      _interpreter = null;
      _isModelLoaded = false;
      debugPrint('Error creating LiteRT Interpreter: $e');
    }
  }

  Future<bool> _loadModelFromBundledAsset() async {
    try {
      final bytes = await rootBundle.load(_assetModelPath);
      if (bytes.lengthInBytes < _minModelBytes) return false;

      _interpreter = await Interpreter.fromAsset(_assetModelPath);
      modelSource = ModelSource.localAsset;
      _configureInterpreterShapes();
      _isModelLoaded = true;
      debugPrint('LiteRT model loaded from bundled asset');
      return true;
    } catch (e) {
      debugPrint('Bundled asset model unavailable: $e');
      return false;
    }
  }

  Future<File?> _tryFirebaseMlDownload() async {
    try {
      if (Firebase.apps.isEmpty) return null;

      final customModel = await FirebaseModelDownloader.instance.getModel(
        'food_classifier',
        FirebaseModelDownloadType.localModelUpdateInBackground,
        FirebaseModelDownloadConditions(
          iosAllowsCellularAccess: true,
          androidChargingRequired: false,
          androidWifiRequired: false,
          androidDeviceIdleRequired: false,
        ),
      );

      final file = customModel.file;
      if (await _isValidModelFile(file)) {
        modelSource = ModelSource.firebaseMl;
        debugPrint('Firebase ML model at: ${file.path}');
        return file;
      }
    } catch (e) {
      debugPrint('Firebase ML download failed: $e');
    }
    return null;
  }

  Future<File?> _tryFirebaseStorageDownload() async {
    try {
      final response = await http.get(Uri.parse(_storageModelUrl)).timeout(
            const Duration(seconds: 20),
          );
      if (response.statusCode != 200 || response.bodyBytes.length < _minModelBytes) {
        return null;
      }

      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/food_classifier_remote.tflite');
      await file.writeAsBytes(response.bodyBytes, flush: true);

      modelSource = ModelSource.firebaseStorage;
      debugPrint('Firebase Storage model saved to: ${file.path}');
      return file;
    } catch (e) {
      debugPrint('Firebase Storage download failed: $e');
      return null;
    }
  }

  Future<File?> _copyAssetModelToCache() async {
    try {
      final bytes = await rootBundle.load(_assetModelPath);
      if (bytes.lengthInBytes < _minModelBytes) {
        return null;
      }

      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/food_classifier_asset.tflite');
      await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
      return file;
    } catch (e) {
      debugPrint('Local asset model unavailable: $e');
      return null;
    }
  }

  Future<bool> _isValidModelFile(File file) async {
    if (!await file.exists()) return false;
    final size = await file.length();
    return size >= _minModelBytes;
  }

  void _configureInterpreterShapes() {
    if (_interpreter == null) return;

    final inputTensor = _interpreter!.getInputTensor(0);
    final outputTensor = _interpreter!.getOutputTensor(0);
    final inputShape = inputTensor.shape;
    final outputShape = outputTensor.shape;

    if (inputShape.length >= 3) {
      _inputSize = inputShape[inputShape.length - 2];
    }
    _outputClassCount = outputShape.last;
    _inputType = inputTensor.type;
    _outputType = outputTensor.type;
    _outputQuant = outputTensor.params;

    if (_labels.isNotEmpty && !labelsMatchModel) {
      debugPrint(
        'ERROR: labels (${_labels.length}) tidak cocok dengan output model '
        '($_outputClassCount). Prediksi dinonaktifkan sampai file diselaraskan.',
      );
    }

    debugPrint(
      'Model input shape: $inputShape ($_inputType), '
      'output shape: $outputShape ($_outputType, $_outputQuant)',
    );
  }

  Future<RecognitionResult> classifyImage(File imageFile) async {
    final imageBytes = await imageFile.readAsBytes();
    return classifyImageBytes(imageBytes);
  }

  Future<RecognitionResult> classifyCameraImage(CameraImage cameraImage) async {
    if (!_isModelLoaded || _interpreter == null) {
      return RecognitionResult(label: 'Model belum tersedia', confidence: 0.0);
    }

    if (_labels.isEmpty) {
      await _loadLabels();
    }

    if (!labelsMatchModel) {
      return RecognitionResult(
        label: 'Model dan label tidak cocok',
        confidence: 0.0,
      );
    }

    final frame = LiveCameraFrame.fromCameraImage(cameraImage);
    final inputSize = _inputSize;
    final outputSize = _outputClassCount;
    final useUint8Input = _inputType == TensorType.uint8;

    final inputTensor = await Isolate.run(
      () => _prepareInputFromCameraFrame(
        frame,
        inputSize,
        useUint8Input: useUint8Input,
      ),
    );
    if (inputTensor == null) {
      return RecognitionResult(label: 'Gambar tidak valid', confidence: 0.0);
    }

    return _predictFromInput(inputTensor, outputSize);
  }

  Future<RecognitionResult> classifyImageBytes(Uint8List imageBytes) async {
    if (!_isModelLoaded || _interpreter == null) {
      return RecognitionResult(label: 'Model belum tersedia', confidence: 0.0);
    }

    if (_labels.isEmpty) {
      await _loadLabels();
    }

    if (!labelsMatchModel) {
      return RecognitionResult(
        label: 'Model dan label tidak cocok',
        confidence: 0.0,
      );
    }

    final inputSize = _inputSize;
    final outputSize = _outputClassCount;
    final useUint8Input = _inputType == TensorType.uint8;

    final inputTensor = await Isolate.run(
      () => _prepareInputTensor(
        imageBytes,
        inputSize,
        useUint8Input: useUint8Input,
      ),
    );
    if (inputTensor == null) {
      return RecognitionResult(label: 'Gambar tidak valid', confidence: 0.0);
    }

    return _predictFromInput(inputTensor, outputSize);
  }

  RecognitionResult _predictFromInput(List<dynamic> inputTensor, int outputSize) {
    try {
      final scores = _runInference(inputTensor, outputSize);
      final ranked = _rankScores(scores);
      _logTopPredictions(ranked);

      if (ranked.isEmpty) {
        return RecognitionResult(label: 'Makanan tidak dikenali', confidence: 0.0);
      }

      final best = ranked.first;
      if (best.value < _minConfidence) {
        return RecognitionResult(label: 'Makanan tidak dikenali', confidence: best.value);
      }

      final rawLabel = best.key < _labels.length ? _labels[best.key] : 'Unknown';
      return RecognitionResult(
        label: rawLabel,
        confidence: best.value.clamp(0.0, 1.0),
      );
    } catch (e) {
      debugPrint('Interpreter execution failed: $e');
      return RecognitionResult(label: 'Prediksi gagal', confidence: 0.0);
    }
  }

  List<double> _runInference(List<dynamic> inputTensor, int outputSize) {
    if (_outputType == TensorType.uint8) {
      final output = List.filled(outputSize, 0).reshape([1, outputSize]);
      _interpreter!.run(inputTensor, output);
      return _dequantizeOutput(List<int>.from(output[0]));
    }

    final output = List.filled(outputSize, 0.0).reshape([1, outputSize]);
    _interpreter!.run(inputTensor, output);
    return List<double>.from(output[0]);
  }

  List<double> _dequantizeOutput(List<int> rawValues) {
    final scale = _outputQuant.scale;
    final zeroPoint = _outputQuant.zeroPoint;
    return rawValues
        .map((value) => (value - zeroPoint) * scale)
        .toList(growable: false);
  }

  List<MapEntry<int, double>> _rankScores(List<double> scores) {
    final ranked = <MapEntry<int, double>>[];
    for (var i = 0; i < scores.length; i++) {
      if (_shouldSkipLabel(i)) continue;
      ranked.add(MapEntry(i, scores[i]));
    }
    ranked.sort((a, b) => b.value.compareTo(a.value));
    return ranked;
  }

  bool _shouldSkipLabel(int index) {
    if (index >= _labels.length) return true;
    final label = _labels[index].toLowerCase();
    return label == 'background' || label == '__background__';
  }

  void _logTopPredictions(List<MapEntry<int, double>> ranked) {
    if (!kDebugMode || ranked.isEmpty) return;

    final top = ranked.take(5).map((entry) {
      final name = entry.key < _labels.length ? _labels[entry.key] : '?';
      return '$name=${(entry.value * 100).toStringAsFixed(1)}%';
    }).join(', ');
    debugPrint('Top predictions: $top');
  }

  static List<dynamic>? _prepareInputFromCameraFrame(
    LiveCameraFrame frame,
    int inputSize, {
    required bool useUint8Input,
  }) {
    final decodedImage = CameraImageConverter.toImage(frame);
    if (decodedImage == null) return null;

    return _buildInputTensor(decodedImage, inputSize, useUint8Input: useUint8Input);
  }

  static List<dynamic>? _prepareInputTensor(
    Uint8List imageBytes,
    int inputSize, {
    required bool useUint8Input,
  }) {
    final decodedImage = img.decodeImage(imageBytes);
    if (decodedImage == null) return null;

    return _buildInputTensor(decodedImage, inputSize, useUint8Input: useUint8Input);
  }

  static List<dynamic> _buildInputTensor(
    img.Image decodedImage,
    int inputSize, {
    required bool useUint8Input,
  }) {
    final resizedImage = img.copyResize(decodedImage, width: inputSize, height: inputSize);

    return List.generate(
      1,
      (_) => List.generate(
        inputSize,
        (y) => List.generate(
          inputSize,
          (x) {
            final pixel = resizedImage.getPixel(x, y);
            if (useUint8Input) {
              return [pixel.r.toInt(), pixel.g.toInt(), pixel.b.toInt()];
            }
            return [pixel.r / 255.0, pixel.g / 255.0, pixel.b / 255.0];
          },
        ),
      ),
    );
  }

  void close() {
    _interpreter?.close();
  }
}
