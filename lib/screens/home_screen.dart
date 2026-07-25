import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/ml_service.dart';
import '../services/gemini_nutrition_service.dart';
import '../theme/app_theme.dart';
import 'prediction_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MLService _mlService = MLService();
  final ImagePicker _picker = ImagePicker();

  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraStreaming = false;
  bool _isProcessingFrame = false;
  RecognitionResult? _liveResult;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    setState(() => _isLoading = true);
    await _requestPermissions();
    await _mlService.initialize();
    await _initCamera();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _requestPermissions() async {
    if (Platform.isIOS) {
      await [
        Permission.camera,
        Permission.photos,
      ].request();
    } else {
      await [
        Permission.camera,
        Permission.storage,
        Permission.photos,
      ].request();
    }
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        _cameraController = CameraController(
          _cameras!.first,
          ResolutionPreset.medium,
          enableAudio: false,
        );
        await _cameraController!.initialize();
        if (mounted) {
          setState(() {});
        }
      }
    } catch (e) {
      debugPrint('Camera init error: $e');
    }
  }

  void _toggleCameraStream() {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kamera tidak tersedia pada perangkat ini.')),
      );
      return;
    }

    if (_isCameraStreaming) {
      _cameraController!.stopImageStream();
      setState(() {
        _isCameraStreaming = false;
        _liveResult = null;
      });
    } else {
      setState(() => _isCameraStreaming = true);
      _cameraController!.startImageStream((CameraImage image) async {
        if (_isProcessingFrame) return;
        _isProcessingFrame = true;

        try {
          // Convert plane 0 buffer or bytes to image for isolate processing
          final planes = image.planes;
          final bytes = planes.first.bytes;
          final result = await _mlService.classifyImageBytes(bytes);
          if (mounted && _isCameraStreaming) {
            setState(() {
              _liveResult = result;
            });
          }
        } catch (e) {
          debugPrint('Frame processing error: $e');
        } finally {
          _isProcessingFrame = false;
        }
      });
    }
  }

  Future<void> _pickAndCropImage(ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(source: source);
      if (picked == null) return;

      // Crop feature using image_cropper (Skilled Kriteria 1)
      CroppedFile? cropped = await ImageCropper().cropImage(
        sourcePath: picked.path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Potong Gambar Makanan',
            toolbarColor: AppColors.coralDark,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: false,
          ),
          IOSUiSettings(
            title: 'Potong Gambar Makanan',
          ),
        ],
      );

      final File fileToProcess = File(cropped != null ? cropped.path : picked.path);
      setState(() {
        _isLoading = true;
      });

      // Background Isolate ML Inference (Skilled Kriteria 2)
      final result = await _mlService.classifyImage(fileToProcess);

      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PredictionDetailScreen(
              imageFile: fileToProcess,
              result: result,
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('Error pick/crop image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal memproses gambar. Silakan coba lagi.')),
        );
      }
    }
  }

  void _showApiKeyDialog() {
    final controller = TextEditingController(text: GeminiNutritionService.userProvidedApiKey ?? '');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pengaturan Gemini API Key'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Masukkan Gemini API Key Anda untuk mengaktifkan fitur pencarian nutrisi dinamis.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'AIzaSy...',
                labelText: 'Gemini API Key',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              GeminiNutritionService.userProvidedApiKey = controller.text.trim();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Gemini API Key berhasil disimpan!')),
              );
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _mlService.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: AppTheme.pageGradient,
        child: SafeArea(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.coral),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(),
                    Expanded(child: _buildCameraSection()),
                    _buildActionPanel(),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 12, 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.coral.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.restaurant_rounded, color: AppColors.coral, size: 26),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Food Recognizer',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.charcoal,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  'Kenali makanan dari kamera',
                  style: TextStyle(fontSize: 13, color: AppColors.muted),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _showApiKeyDialog,
            tooltip: 'Gemini API Key',
            style: IconButton.styleFrom(
              backgroundColor: AppColors.surface,
              foregroundColor: AppColors.charcoal,
            ),
            icon: const Icon(Icons.tune_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: AppColors.coral.withValues(alpha: 0.18),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(
              color: AppColors.charcoal,
              child: _cameraController != null && _cameraController!.value.isInitialized
                  ? CameraPreview(_cameraController!)
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.camera_outdoor_rounded, size: 72, color: Colors.white.withValues(alpha: 0.35)),
                          const SizedBox(height: 14),
                          Text(
                            'Kamera siap digunakan',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 15),
                          ),
                        ],
                      ),
                    ),
            ),
            if (_isCameraStreaming)
              Positioned(
                top: 16,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.liveRed,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, size: 8, color: Colors.white),
                      SizedBox(width: 6),
                      Text('LIVE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            if (_isCameraStreaming && _liveResult != null)
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.amber.withValues(alpha: 0.6)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.amber.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.fastfood_rounded, color: AppColors.amber, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _liveResult!.label,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 17,
                              ),
                            ),
                            Text(
                              'Akurasi ${_liveResult!.confidencePercentage}',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.amber,
                          foregroundColor: AppColors.charcoal,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        ),
                        onPressed: () {
                          _cameraController?.stopImageStream();
                          setState(() => _isCameraStreaming = false);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PredictionDetailScreen(
                                imageFile: null,
                                result: _liveResult!,
                              ),
                            ),
                          );
                        },
                        child: const Text('Detail'),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionPanel() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      padding: const EdgeInsets.all(18),
      decoration: AppTheme.softCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _isCameraStreaming ? 'Streaming aktif' : 'Pilih sumber gambar',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.muted,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: _isCameraStreaming ? AppColors.liveRed : AppColors.coral,
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            icon: Icon(_isCameraStreaming ? Icons.stop_circle_outlined : Icons.play_circle_outline),
            label: Text(
              _isCameraStreaming ? 'Hentikan Live Stream' : 'Mulai Live Stream',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            onPressed: _toggleCameraStream,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _SourceButton(
                  icon: Icons.photo_camera_rounded,
                  label: 'Kamera',
                  onTap: () => _pickAndCropImage(ImageSource.camera),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SourceButton(
                  icon: Icons.collections_rounded,
                  label: 'Galeri',
                  onTap: () => _pickAndCropImage(ImageSource.gallery),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SourceButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SourceButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.creamDark,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Column(
            children: [
              Icon(icon, color: AppColors.coral, size: 28),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.charcoal,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
