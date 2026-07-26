import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../services/ml_service.dart';
import '../services/meal_db_service.dart';
import '../services/gemini_nutrition_service.dart';
import '../theme/app_colors.dart';

class PredictionDetailScreen extends StatefulWidget {
  final File? imageFile;
  final RecognitionResult result;

  const PredictionDetailScreen({
    super.key,
    required this.imageFile,
    required this.result,
  });

  @override
  State<PredictionDetailScreen> createState() => _PredictionDetailScreenState();
}

class _PredictionDetailScreenState extends State<PredictionDetailScreen> {
  final MealDBService _mealDBService = MealDBService();
  final GeminiNutritionService _geminiService = GeminiNutritionService();

  MealDetail? _mealDetail;
  FoodNutritionInfo? _nutritionInfo;
  bool _isLoadingMealDB = true;
  bool _isLoadingNutrition = true;
  Size? _imageSize;

  @override
  void initState() {
    super.initState();
    _loadDetails();
    _loadImageSize();
  }

  Future<void> _loadImageSize() async {
    if (widget.imageFile == null) return;
    try {
      final bytes = await widget.imageFile!.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      if (mounted) {
        setState(() {
          _imageSize = Size(
            frame.image.width.toDouble(),
            frame.image.height.toDouble(),
          );
        });
      }
      frame.image.dispose();
    } catch (e) {
      debugPrint('Failed to read image size: $e');
    }
  }

  Future<void> _loadDetails() async {
    _fetchMealDB();
    _fetchNutrition();
  }

  Future<void> _fetchMealDB() async {
    try {
      final detail = await _mealDBService.fetchMealByFoodName(widget.result.label);
      if (mounted) {
        setState(() {
          _mealDetail = detail;
          _isLoadingMealDB = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMealDB = false;
        });
      }
    }
  }

  Future<void> _fetchNutrition() async {
    try {
      final info = await _geminiService.fetchNutritionInfo(widget.result.label);
      if (mounted) {
        setState(() {
          _nutritionInfo = info;
          _isLoadingNutrition = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingNutrition = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final confidenceColor = widget.result.confidence >= 0.8
        ? AppColors.olive
        : (widget.result.confidence >= 0.5 ? AppColors.amber : AppColors.liveRed);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Prediksi Makanan'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Section 1: Selected Photo & Prediction Results
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  if (widget.imageFile != null)
                    _buildCroppedImagePreview()
                  else
                    Container(
                      height: 180,
                      color: AppColors.creamDark,
                      child: Center(
                        child: Icon(Icons.fastfood, size: 80, color: AppColors.coral),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Text(
                          widget.result.label,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.charcoal,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'Confidence Score: ',
                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: confidenceColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: confidenceColor, width: 1.5),
                              ),
                              child: Text(
                                widget.result.confidencePercentage,
                                style: TextStyle(
                                  color: confidenceColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Section 2: Gemini AI Nutrition Info Card (Advanced Kriteria 3)
            _buildNutritionSection(theme),
            const SizedBox(height: 20),

            // Section 3: TheMealDB Recipe Information Card (Skilled Kriteria 3)
            _buildMealDBSection(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildCroppedImagePreview() {
    if (_imageSize == null) {
      return Container(
        height: 220,
        color: AppColors.creamDark,
        alignment: Alignment.center,
        child: CircularProgressIndicator(color: AppColors.coral),
      );
    }

    return Container(
      width: double.infinity,
      color: AppColors.creamDark,
      padding: const EdgeInsets.all(12),
      child: AspectRatio(
        aspectRatio: _imageSize!.width / _imageSize!.height,
        child: Image.file(
          widget.imageFile!,
          fit: BoxFit.contain,
          alignment: Alignment.center,
        ),
      ),
    );
  }

  Widget _buildNutritionSection(ThemeData theme) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, color: Colors.amber, size: 28),
                const SizedBox(width: 8),
                Text(
                  'Informasi Nutrisi (Gemini AI)',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.charcoal,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            if (_isLoadingNutrition)
              const Padding(
                padding: EdgeInsets.all(24.0),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_nutritionInfo != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _nutritionInfo!.summary,
                    style: TextStyle(color: Colors.grey.shade700, fontStyle: FontStyle.italic),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _buildNutritionChip('Kalori', '${_nutritionInfo!.calories} kcal', Icons.local_fire_department, Colors.orange),
                      _buildNutritionChip('Karbohidrat', '${_nutritionInfo!.carbs} g', Icons.grain, Colors.blue),
                      _buildNutritionChip('Lemak', '${_nutritionInfo!.fat} g', Icons.opacity, Colors.redAccent),
                      _buildNutritionChip('Serat', '${_nutritionInfo!.fiber} g', Icons.grass, Colors.green),
                      _buildNutritionChip('Protein', '${_nutritionInfo!.protein} g', Icons.fitness_center, Colors.purple),
                    ],
                  ),
                ],
              )
            else
              const Text('Gagal memuat informasi nutrisi.'),
          ],
        ),
      ),
    );
  }

  Widget _buildNutritionChip(String label, String value, IconData icon, Color color) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildMealDBSection(ThemeData theme) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.restaurant_menu, color: AppColors.olive, size: 28),
                const SizedBox(width: 8),
                Text(
                  'Referensi Resep (TheMealDB)',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.charcoal,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            if (_isLoadingMealDB)
              const Padding(
                padding: EdgeInsets.all(24.0),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_mealDetail != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_mealDetail!.thumbnail.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        _mealDetail!.thumbnail,
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const SizedBox(),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Text(
                    _mealDetail!.name,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Bahan-bahan:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 8),
                  ..._mealDetail!.ingredients.map(
                    (ing) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2.0),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_outline, size: 16, color: AppColors.olive),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${ing.name} ${ing.measure.isNotEmpty ? "(${ing.measure})" : ""}',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Langkah-langkah Pembuatan:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _mealDetail!.instructions,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade800, height: 1.4),
                  ),
                ],
              )
            else
              const Text('Tidak menemukan resep referensi untuk makanan ini.'),
          ],
        ),
      ),
    );
  }
}
