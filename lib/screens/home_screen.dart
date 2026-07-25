import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/ml_service.dart';
import '../services/gemini_nutrition_service.dart';
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
            toolbarColor: Colors.teal,
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
      appBar: AppBar(
        title: const Text('Food Recognizer App'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.vpn_key),
            tooltip: 'Gemini API Key',
            onPressed: _showApiKeyDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Top Camera Stream Section
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      children: [
                        if (_cameraController != null && _cameraController!.value.isInitialized)
                          CameraPreview(_cameraController!)
                        else
                          const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.camera_alt, size: 64, color: Colors.white54),
                                SizedBox(height: 12),
                                Text(
                                  'Kamera Siap Disambungkan',
                                  style: TextStyle(color: Colors.white70),
                                ),
                              ],
                            ),
                          ),

                        // Real-time Inference Result Overlay Badge (Advanced Kriteria 1)
                        if (_isCameraStreaming && _liveResult != null)
                          Positioned(
                            top: 16,
                            left: 16,
                            right: 16,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.black87,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.tealAccent, width: 2),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.videocam, color: Colors.tealAccent),
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
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                          ),
                                        ),
                                        Text(
                                          'Confidence: ${_liveResult!.confidencePercentage}',
                                          style: const TextStyle(color: Colors.tealAccent),
                                        ),
                                      ],
                                    ),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.teal,
                                      foregroundColor: Colors.white,
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

                // Bottom Action Buttons Panel
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isCameraStreaming ? Colors.redAccent : Colors.teal,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: Icon(_isCameraStreaming ? Icons.videocam_off : Icons.videocam),
                        label: Text(_isCameraStreaming ? 'Hentikan Live Camera Stream' : 'Mulai Live Camera Stream (Real-Time)'),
                        onPressed: _toggleCameraStream,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                side: const BorderSide(color: Colors.teal),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.camera_alt, color: Colors.teal),
                              label: const Text('Kamera (Crop)', style: TextStyle(color: Colors.teal)),
                              onPressed: () => _pickAndCropImage(ImageSource.camera),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                side: const BorderSide(color: Colors.teal),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.photo_library, color: Colors.teal),
                              label: const Text('Galeri (Crop)', style: TextStyle(color: Colors.teal)),
                              onPressed: () => _pickAndCropImage(ImageSource.gallery),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
