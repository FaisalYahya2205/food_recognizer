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
    final confidenceColor = widget.result.confidence >= 0.8
        ? AppColors.olive
        : (widget.result.confidence >= 0.5 ? AppColors.amber : AppColors.liveRed);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(confidenceColor),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildNutritionSection(),
                  const SizedBox(height: 16),
                  _buildMealDBSection(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(Color confidenceColor) {
    return SliverAppBar(
      expandedHeight: widget.imageFile != null ? 320 : 220,
      pinned: true,
      stretch: true,
      backgroundColor: AppColors.coral,
      foregroundColor: Colors.white,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.arrow_back, size: 20),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (widget.imageFile != null)
              _buildHeroImage()
            else
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.coral, AppColors.coralDark],
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.fastfood,
                    size: 80,
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                ),
              ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    AppColors.charcoal.withValues(alpha: 0.75),
                  ],
                  stops: const [0.4, 1.0],
                ),
              ),
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.result.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: confidenceColor.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.analytics_outlined, color: Colors.white, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'Confidence ${widget.result.confidencePercentage}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroImage() {
    if (_imageSize == null) {
      return Container(
        color: AppColors.creamDark,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(color: AppColors.coral),
      );
    }

    return Image.file(
      widget.imageFile!,
      fit: BoxFit.cover,
      alignment: Alignment.center,
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required Color accentColor,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: accentColor, size: 22),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.charcoal,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNutritionSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.creamDark, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.amber.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              icon: Icons.auto_awesome,
              title: 'Informasi Nutrisi (Gemini AI)',
              accentColor: AppColors.amber,
            ),
            const SizedBox(height: 16),
            if (_isLoadingNutrition)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_nutritionInfo != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.cream,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.creamDark),
                    ),
                    child: Text(
                      _nutritionInfo!.summary,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontStyle: FontStyle.italic,
                        height: 1.5,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _buildNutritionChip('Kalori', '${_nutritionInfo!.calories} kcal', Icons.local_fire_department, AppColors.coral),
                      _buildNutritionChip('Karbohidrat', '${_nutritionInfo!.carbs} g', Icons.grain, AppColors.amber),
                      _buildNutritionChip('Lemak', '${_nutritionInfo!.fat} g', Icons.opacity, AppColors.liveRed),
                      _buildNutritionChip('Serat', '${_nutritionInfo!.fiber} g', Icons.grass, AppColors.olive),
                      _buildNutritionChip('Protein', '${_nutritionInfo!.protein} g', Icons.fitness_center, const Color(0xFF7B5EA7)),
                    ],
                  ),
                ],
              )
            else
              const Text(
                'Gagal memuat informasi nutrisi.',
                style: TextStyle(color: AppColors.muted),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNutritionChip(String label, String value, IconData icon, Color color) {
    return Container(
      width: (MediaQuery.of(context).size.width - 72) / 2,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
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
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildMealDBSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.creamDark, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.olive.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              icon: Icons.restaurant_menu,
              title: 'Referensi Resep (TheMealDB)',
              accentColor: AppColors.olive,
            ),
            const SizedBox(height: 16),
            if (_isLoadingMealDB)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_mealDetail != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_mealDetail!.thumbnail.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.network(
                        _mealDetail!.thumbnail,
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const SizedBox(),
                      ),
                    ),
                  const SizedBox(height: 14),
                  Text(
                    _mealDetail!.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.charcoal,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildSubSectionTitle('Bahan-bahan', Icons.shopping_basket_outlined),
                  const SizedBox(height: 8),
                  ..._mealDetail!.ingredients.map(
                    (ing) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 2),
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: AppColors.olive.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check, size: 14, color: AppColors.olive),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '${ing.name}${ing.measure.isNotEmpty ? " (${ing.measure})" : ""}',
                              style: const TextStyle(fontSize: 14, color: AppColors.charcoal, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildSubSectionTitle('Langkah Pembuatan', Icons.menu_book_outlined),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.cream,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.creamDark),
                    ),
                    child: Text(
                      _mealDetail!.instructions,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.charcoal,
                        height: 1.6,
                      ),
                    ),
                  ),
                ],
              )
            else
              const Text(
                'Tidak menemukan resep referensi untuk makanan ini.',
                style: TextStyle(color: AppColors.muted),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.olive),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: AppColors.olive,
          ),
        ),
      ],
    );
  }
}
