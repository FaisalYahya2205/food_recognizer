import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:camera/camera.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_ml_model_downloader/firebase_ml_model_downloader.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_litert/flutter_litert.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import '../core/camera/yuv_frame_decoder.dart';
import '../domain/food_prediction.dart';

enum ClassifierOrigin { unavailable, firebaseMl, remoteStorage, bundledAsset }

class TensorFoodClassifier {
  static const _bundleModel = 'assets/ml/dish_classifier.tflite';
  static const _bundleLabels = 'assets/ml/class_labels.txt';
  static const _remoteModelUrl =
      'https://firebasestorage.googleapis.com/v0/b/food-recognizer-56804.firebasestorage.app/o/models%2Fdish_classifier.tflite?alt=media';
  static const _firebaseModelId = 'dish_classifier';
  static const _minBytes = 1024;
  static const _scoreFloor = 0.25;

  Interpreter? _engine;
  List<String> _classNames = [];
  bool _ready = false;
  ClassifierOrigin origin = ClassifierOrigin.unavailable;
  int _tensorSize = 224;
  int _classCount = 0;
  TensorType _inputKind = TensorType.float32;
  TensorType _outputKind = TensorType.float32;
  QuantizationParams _outputScale = QuantizationParams(1.0, 0);

  bool get isReady => _ready;
  bool get hasAlignedLabels =>
      _classNames.isNotEmpty && _classCount > 0 && _classNames.length == _classCount;
  ClassifierOrigin get source => origin;

  Future<void> boot() async {
    try {
      await _readLabelFile();
      await _resolveEngine();
    } catch (error) {
      debugPrint('TensorFoodClassifier boot error: $error');
    }
  }

  Future<void> _readLabelFile() async {
    final raw = await rootBundle.loadString(_bundleLabels);
    _classNames = raw.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  Future<void> _resolveEngine() async {
    File? resolved = await _pullFromFirebaseMl();
    resolved ??= await _pullFromRemoteStorage();
    resolved ??= await _cacheBundledCopy();
    if (resolved != null && origin == ClassifierOrigin.unavailable) {
      origin = ClassifierOrigin.bundledAsset;
    }

    if (resolved == null || !await _validateFile(resolved)) {
      if (await _loadBundledDirect()) return;
      _ready = false;
      debugPrint('Model dish_classifier.tflite tidak ditemukan atau rusak.');
      return;
    }

    try {
      _engine = Interpreter.fromFile(resolved);
      _syncTensorMetadata();
      _ready = true;
      debugPrint('Classifier aktif dari ${origin.name}: ${resolved.path}');
    } catch (error) {
      _engine = null;
      _ready = false;
      debugPrint('Gagal memuat interpreter: $error');
    }
  }

  Future<bool> _loadBundledDirect() async {
    try {
      final blob = await rootBundle.load(_bundleModel);
      if (blob.lengthInBytes < _minBytes) return false;
      _engine = await Interpreter.fromAsset(_bundleModel);
      origin = ClassifierOrigin.bundledAsset;
      _syncTensorMetadata();
      _ready = true;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<File?> _pullFromFirebaseMl() async {
    try {
      if (Firebase.apps.isEmpty) return null;
      final model = await FirebaseModelDownloader.instance.getModel(
        _firebaseModelId,
        FirebaseModelDownloadType.localModelUpdateInBackground,
        FirebaseModelDownloadConditions(
          iosAllowsCellularAccess: true,
          androidChargingRequired: false,
          androidWifiRequired: false,
          androidDeviceIdleRequired: false,
        ),
      );
      final file = model.file;
      if (await _validateFile(file)) {
        origin = ClassifierOrigin.firebaseMl;
        return file;
      }
    } catch (error) {
      debugPrint('Firebase ML skip: $error');
    }
    return null;
  }

  Future<File?> _pullFromRemoteStorage() async {
    try {
      final res = await http.get(Uri.parse(_remoteModelUrl)).timeout(const Duration(seconds: 20));
      if (res.statusCode != 200 || res.bodyBytes.length < _minBytes) return null;

      final dir = await getApplicationDocumentsDirectory();
      final out = File('${dir.path}/dish_classifier_remote.tflite');
      await out.writeAsBytes(res.bodyBytes, flush: true);
      origin = ClassifierOrigin.remoteStorage;
      return out;
    } catch (error) {
      debugPrint('Remote storage skip: $error');
      return null;
    }
  }

  Future<File?> _cacheBundledCopy() async {
    try {
      final blob = await rootBundle.load(_bundleModel);
      if (blob.lengthInBytes < _minBytes) return null;
      final dir = await getApplicationDocumentsDirectory();
      final out = File('${dir.path}/dish_classifier_cached.tflite');
      await out.writeAsBytes(blob.buffer.asUint8List(), flush: true);
      return out;
    } catch (_) {
      return null;
    }
  }

  Future<bool> _validateFile(File file) async {
    if (!await file.exists()) return false;
    return (await file.length()) >= _minBytes;
  }

  void _syncTensorMetadata() {
    if (_engine == null) return;
    final inTensor = _engine!.getInputTensor(0);
    final outTensor = _engine!.getOutputTensor(0);
    final inShape = inTensor.shape;

    if (inShape.length >= 3) _tensorSize = inShape[inShape.length - 2];
    _classCount = outTensor.shape.last;
    _inputKind = inTensor.type;
    _outputKind = outTensor.type;
    _outputScale = outTensor.params;

    if (_classNames.isNotEmpty && !hasAlignedLabels) {
      debugPrint('Label ($_classNames.length) != kelas model ($_classCount)');
    }
  }

  Future<FoodPrediction> predictFile(File image) async =>
      predictBytes(await image.readAsBytes());

  Future<FoodPrediction> predictStreamFrame(CameraImage frame) async {
    if (!_ready || _engine == null) {
      return const FoodPrediction(name: 'Model belum siap', score: 0);
    }
    if (!hasAlignedLabels) {
      return const FoodPrediction(name: 'Label tidak selaras', score: 0);
    }

    final buffer = CameraFrameBuffer.capture(frame);
    final tensor = await Isolate.run(
      () => _tensorFromCamera(buffer, _tensorSize, _inputKind == TensorType.uint8),
    );
    if (tensor == null) {
      return const FoodPrediction(name: 'Frame kamera invalid', score: 0);
    }
    return _infer(tensor);
  }

  Future<FoodPrediction> predictBytes(Uint8List bytes) async {
    if (!_ready || _engine == null) {
      return const FoodPrediction(name: 'Model belum siap', score: 0);
    }
    if (!hasAlignedLabels) {
      return const FoodPrediction(name: 'Label tidak selaras', score: 0);
    }

    final tensor = await Isolate.run(
      () => _tensorFromBytes(bytes, _tensorSize, _inputKind == TensorType.uint8),
    );
    if (tensor == null) {
      return const FoodPrediction(name: 'Gambar tidak terbaca', score: 0);
    }
    return _infer(tensor);
  }

  FoodPrediction _infer(List<dynamic> tensor) {
    try {
      final scores = _forwardPass(tensor);
      final ranking = _sortedScores(scores);
      _debugRanking(ranking);

      if (ranking.isEmpty) {
        return const FoodPrediction(name: 'Tidak teridentifikasi', score: 0);
      }

      final top = ranking.first;
      if (top.value < _scoreFloor) {
        return FoodPrediction(name: 'Bukan makanan', score: top.value);
      }

      final label = top.key < _classNames.length ? _classNames[top.key] : 'Unknown';
      return FoodPrediction(name: label, score: top.value.clamp(0, 1));
    } catch (error) {
      debugPrint('Inferensi gagal: $error');
      return const FoodPrediction(name: 'Inferensi error', score: 0);
    }
  }

  List<double> _forwardPass(List<dynamic> tensor) {
    if (_outputKind == TensorType.uint8) {
      final buf = List.filled(_classCount, 0).reshape([1, _classCount]);
      _engine!.run(tensor, buf);
      return _dequantize(List<int>.from(buf[0]));
    }
    final buf = List.filled(_classCount, 0.0).reshape([1, _classCount]);
    _engine!.run(tensor, buf);
    return List<double>.from(buf[0]);
  }

  List<double> _dequantize(List<int> raw) {
    final s = _outputScale.scale;
    final z = _outputScale.zeroPoint;
    return raw.map((v) => (v - z) * s).toList(growable: false);
  }

  List<MapEntry<int, double>> _sortedScores(List<double> scores) {
    final list = <MapEntry<int, double>>[];
    for (var i = 0; i < scores.length; i++) {
      if (_isIgnoredClass(i)) continue;
      list.add(MapEntry(i, scores[i]));
    }
    list.sort((a, b) => b.value.compareTo(a.value));
    return list;
  }

  bool _isIgnoredClass(int index) {
    if (index >= _classNames.length) return true;
    final name = _classNames[index].toLowerCase();
    return name == 'background' || name == '__background__';
  }

  void _debugRanking(List<MapEntry<int, double>> ranking) {
    if (!kDebugMode || ranking.isEmpty) return;
    final line = ranking.take(5).map((e) {
      final tag = e.key < _classNames.length ? _classNames[e.key] : '?';
      return '$tag ${(e.value * 100).toStringAsFixed(1)}%';
    }).join(' | ');
    debugPrint('Top-5: $line');
  }

  static List<dynamic>? _tensorFromCamera(
    CameraFrameBuffer buffer,
    int size,
    bool uint8,
  ) {
    final decoded = YuvFrameDecoder.decode(buffer);
    if (decoded == null) return null;
    return _packTensor(decoded, size, uint8);
  }

  static List<dynamic>? _tensorFromBytes(Uint8List bytes, int size, bool uint8) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;
    return _packTensor(decoded, size, uint8);
  }

  static List<dynamic> _packTensor(img.Image source, int size, bool uint8) {
    final scaled = img.copyResize(source, width: size, height: size);
    return List.generate(
      1,
      (_) => List.generate(
        size,
        (y) => List.generate(size, (x) {
          final px = scaled.getPixel(x, y);
          if (uint8) return [px.r.toInt(), px.g.toInt(), px.b.toInt()];
          return [px.r / 255, px.g / 255, px.b / 255];
        }),
      ),
    );
  }

  void shutdown() => _engine?.close();
}
