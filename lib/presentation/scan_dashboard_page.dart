import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/theme/brand_palette.dart';
import '../data/ai_nutrition_provider.dart';
import '../data/tensor_food_classifier.dart';
import '../domain/food_prediction.dart';
import 'analysis_result_page.dart';

class ScanDashboardPage extends StatefulWidget {
  const ScanDashboardPage({super.key});

  @override
  State<ScanDashboardPage> createState() => _ScanDashboardPageState();
}

class _ScanDashboardPageState extends State<ScanDashboardPage> {
  final _classifier = TensorFoodClassifier();
  final _mediaPicker = ImagePicker();

  CameraController? _cam;
  bool _streamActive = false;
  bool _busyFrame = false;
  DateTime? _lastScan;
  FoodPrediction? _streamPrediction;
  bool _booting = true;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() => _booting = true);
    await _ensurePermissions();
    await _classifier.boot();
    await _setupCamera();
    if (mounted) setState(() => _booting = false);
  }

  Future<void> _ensurePermissions() async {
    final needed = Platform.isIOS
        ? [Permission.camera, Permission.photos]
        : [Permission.camera, Permission.storage, Permission.photos];
    await needed.request();
  }

  Future<void> _setupCamera() async {
    try {
      final devices = await availableCameras();
      if (devices.isEmpty) return;
      _cam = CameraController(devices.first, ResolutionPreset.medium, enableAudio: false);
      await _cam!.initialize();
      if (mounted) setState(() {});
    } catch (error) {
      debugPrint('Kamera error: $error');
    }
  }

  void _handleStreamToggle() {
    if (_cam == null || !_cam!.value.isInitialized) {
      _toast('Kamera belum siap di perangkat ini.');
      return;
    }

    if (_streamActive) {
      _cam!.stopImageStream();
      setState(() {
        _streamActive = false;
        _streamPrediction = null;
      });
      return;
    }

    setState(() => _streamActive = true);
    _cam!.startImageStream((frame) async {
      if (_busyFrame) return;
      final tick = DateTime.now();
      if (_lastScan != null && tick.difference(_lastScan!) < const Duration(milliseconds: 700)) {
        return;
      }

      _busyFrame = true;
      try {
        final prediction = await _classifier.predictStreamFrame(frame);
        _lastScan = DateTime.now();
        if (mounted && _streamActive) {
          setState(() => _streamPrediction = prediction);
        }
      } catch (error) {
        debugPrint('Stream inferensi: $error');
      } finally {
        _busyFrame = false;
      }
    });
  }

  Future<void> _captureFrom(ImageSource source) async {
    try {
      final picked = await _mediaPicker.pickImage(source: source);
      if (picked == null) return;

      final cropped = await ImageCropper().cropImage(
        sourcePath: picked.path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Sesuaikan Area Makanan',
            toolbarColor: BrandPalette.terracottaDeep,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
          ),
          IOSUiSettings(title: 'Sesuaikan Area Makanan'),
        ],
      );
      if (cropped == null) return;

      setState(() => _booting = true);
      final prediction = await _classifier.predictFile(File(cropped.path));
      setState(() => _booting = false);

      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AnalysisResultPage(
            photo: File(cropped.path),
            prediction: prediction,
          ),
        ),
      );
    } catch (error) {
      setState(() => _booting = false);
      _toast('Gagal memproses foto.');
      debugPrint('Capture error: $error');
    }
  }

  void _openKeyDialog() {
    final input = TextEditingController(text: AiNutritionProvider.runtimeApiKey ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Kunci API Gemini'),
        content: TextField(
          controller: input,
          decoration: const InputDecoration(
            labelText: 'API Key',
            hintText: 'AIzaSy...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup')),
          FilledButton(
            onPressed: () {
              AiNutritionProvider.runtimeApiKey = input.text.trim();
              Navigator.pop(ctx);
              _toast('API Key tersimpan.');
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  void dispose() {
    _cam?.dispose();
    _classifier.shutdown();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_booting) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: Column(
        children: [
          _TopBanner(onKeyTap: _openKeyDialog),
          Expanded(child: _PreviewPanel(
            controller: _cam,
            streaming: _streamActive,
            livePrediction: _streamPrediction,
            onOpenDetail: () {
              if (_streamPrediction == null) return;
              _cam?.stopImageStream();
              setState(() => _streamActive = false);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AnalysisResultPage(
                    photo: null,
                    prediction: _streamPrediction!,
                  ),
                ),
              );
            },
          )),
          _ControlDeck(
            streaming: _streamActive,
            onToggleStream: _handleStreamToggle,
            onCameraTap: () => _captureFrom(ImageSource.camera),
            onGalleryTap: () => _captureFrom(ImageSource.gallery),
          ),
        ],
      ),
    );
  }
}

class _TopBanner extends StatelessWidget {
  const _TopBanner({required this.onKeyTap});

  final VoidCallback onKeyTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [BrandPalette.forest, BrandPalette.terracottaDeep],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(26)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 12, 22),
          child: Row(
            children: [
              const Icon(Icons.ramen_dining, color: Colors.white, size: 32),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'NutriSnap',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Deteksi makanan on-device',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onKeyTap,
                icon: const Icon(Icons.key, color: Colors.white),
                tooltip: 'Gemini API Key',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewPanel extends StatelessWidget {
  const _PreviewPanel({
    required this.controller,
    required this.streaming,
    required this.livePrediction,
    required this.onOpenDetail,
  });

  final CameraController? controller;
  final bool streaming;
  final FoodPrediction? livePrediction;
  final VoidCallback onOpenDetail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Live Preview', style: TextStyle(fontWeight: FontWeight.w700)),
              const Spacer(),
              if (streaming)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: BrandPalette.streamRed.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('REC', style: TextStyle(color: BrandPalette.streamRed, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(
                    color: BrandPalette.ink,
                    child: controller != null && controller!.value.isInitialized
                        ? CameraPreview(controller!)
                        : const Center(child: Icon(Icons.videocam_off, color: Colors.white54, size: 48)),
                  ),
                  if (streaming && livePrediction != null)
                    Positioned(
                      top: 12,
                      left: 12,
                      right: 12,
                      child: Material(
                        elevation: 4,
                        borderRadius: BorderRadius.circular(14),
                        child: ListTile(
                          leading: const Icon(Icons.local_dining, color: BrandPalette.terracotta),
                          title: Text(livePrediction!.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('Akurasi ${livePrediction!.scoreLabel}'),
                          trailing: TextButton(onPressed: onOpenDetail, child: const Text('Lihat')),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ControlDeck extends StatelessWidget {
  const _ControlDeck({
    required this.streaming,
    required this.onToggleStream,
    required this.onCameraTap,
    required this.onGalleryTap,
  });

  final bool streaming;
  final VoidCallback onToggleStream;
  final VoidCallback onCameraTap;
  final VoidCallback onGalleryTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, -4))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FilledButton.icon(
            onPressed: onToggleStream,
            icon: Icon(streaming ? Icons.stop : Icons.play_arrow),
            label: Text(streaming ? 'Stop Live Scan' : 'Start Live Scan'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              backgroundColor: streaming ? BrandPalette.streamRed : BrandPalette.terracotta,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onCameraTap,
                  icon: const Icon(Icons.photo_camera),
                  label: const Text('Ambil Foto'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onGalleryTap,
                  icon: const Icon(Icons.collections),
                  label: const Text('Galeri'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
