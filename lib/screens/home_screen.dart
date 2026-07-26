import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/ml_service.dart';
import '../services/gemini_nutrition_service.dart';
import '../theme/app_colors.dart';
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
  DateTime? _lastLiveInferenceAt;
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

        final now = DateTime.now();
        if (_lastLiveInferenceAt != null &&
            now.difference(_lastLiveInferenceAt!) < const Duration(milliseconds: 700)) {
          return;
        }

        _isProcessingFrame = true;

        try {
          final result = await _mlService.classifyCameraImage(image);
          _lastLiveInferenceAt = DateTime.now();
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

      CroppedFile? cropped = await ImageCropper().cropImage(
        sourcePath: picked.path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Potong Gambar Makanan',
            toolbarColor: AppColors.coralDark,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
          ),
          IOSUiSettings(
            title: 'Potong Gambar Makanan',
          ),
        ],
      );

      if (cropped == null) return;

      final File fileToProcess = File(cropped.path);
      setState(() {
        _isLoading = true;
      });

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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.vpn_key, color: AppColors.amber, size: 20),
            ),
            const SizedBox(width: 10),
            const Text('Gemini API Key'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Masukkan Gemini API Key Anda untuk mengaktifkan fitur pencarian nutrisi dinamis.',
              style: TextStyle(fontSize: 13, color: AppColors.muted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                hintText: 'AIzaSy...',
                labelText: 'Gemini API Key',
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.coral, width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal', style: TextStyle(color: AppColors.muted)),
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildHeader(),
                Expanded(child: _buildCameraSection()),
                _buildActionPanel(),
              ],
            ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.coral, AppColors.coralDark],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 12, 24),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.restaurant, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Food Recognizer',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      'Kenali makanan dengan AI',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.vpn_key, color: Colors.white, size: 20),
                ),
                tooltip: 'Gemini API Key',
                onPressed: _showApiKeyDialog,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCameraSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: AppColors.coral,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Pratinjau Kamera',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.charcoal,
                ),
              ),
              const Spacer(),
              if (_isCameraStreaming)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.liveRed.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.liveRed.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: AppColors.liveRed,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'LIVE',
                        style: TextStyle(
                          color: AppColors.liveRed,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.charcoal,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.coral.withValues(alpha: 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  if (_cameraController != null && _cameraController!.value.isInitialized)
                    CameraPreview(_cameraController!)
                  else
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.camera_alt_outlined,
                              size: 48,
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Kamera Siap Disambungkan',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),

                  if (_isCameraStreaming && _liveResult != null)
                    Positioned(
                      top: 16,
                      left: 16,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.coral.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.fastfood, color: AppColors.coral, size: 22),
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
                                      color: AppColors.charcoal,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    'Confidence: ${_liveResult!.confidencePercentage}',
                                    style: const TextStyle(
                                      color: AppColors.coral,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.coral,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
          ),
        ],
      ),
    );
  }

  Widget _buildActionPanel() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.charcoal.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.creamDark,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _isCameraStreaming ? AppColors.liveRed : AppColors.coral,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              icon: Icon(_isCameraStreaming ? Icons.videocam_off : Icons.videocam),
              label: Text(
                _isCameraStreaming
                    ? 'Hentikan Live Camera Stream'
                    : 'Mulai Live Camera Stream',
              ),
              onPressed: _toggleCameraStream,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildSourceButton(
                  icon: Icons.camera_alt_outlined,
                  label: 'Kamera',
                  onPressed: () => _pickAndCropImage(ImageSource.camera),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSourceButton(
                  icon: Icons.photo_library_outlined,
                  label: 'Galeri',
                  onPressed: () => _pickAndCropImage(ImageSource.gallery),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSourceButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        side: BorderSide(color: AppColors.coral.withValues(alpha: 0.4)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: AppColors.cream,
      ),
      onPressed: onPressed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.coral, size: 24),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.coral,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
