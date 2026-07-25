import 'dart:io';
import 'package:flutter/material.dart';
import '../services/ml_service.dart';
import '../services/meal_db_service.dart';
import '../services/gemini_nutrition_service.dart';
import '../theme/app_theme.dart';

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

  @override
  void initState() {
    super.initState();
    _loadDetails();
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
        setState(() => _isLoadingMealDB = false);
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
        setState(() => _isLoadingNutrition = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final confidenceColor = widget.result.confidence >= 0.8
        ? AppColors.olive
        : (widget.result.confidence >= 0.5 ? AppColors.amber : AppColors.liveRed);

    return Scaffold(
      body: Container(
        decoration: AppTheme.pageGradient,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: widget.imageFile != null ? 280 : 180,
              pinned: true,
              stretch: true,
              backgroundColor: AppColors.coral,
              foregroundColor: Colors.white,
              flexibleSpace: FlexibleSpaceBar(
                title: Text(
                  widget.result.label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    shadows: [Shadow(color: Colors.black45, blurRadius: 8)],
                  ),
                ),
                background: widget.imageFile != null
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.file(widget.imageFile!, fit: BoxFit.cover),
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  AppColors.charcoal.withValues(alpha: 0.65),
                                ],
                              ),
                            ),
                          ),
                        ],
                      )
                    : Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppColors.coral, AppColors.coralDark],
                          ),
                        ),
                        child: const Center(
                          child: Icon(Icons.fastfood_rounded, size: 80, color: Colors.white54),
                        ),
                      ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildConfidenceCard(confidenceColor),
                    const SizedBox(height: 16),
                    _buildNutritionSection(),
                    const SizedBox(height: 16),
                    _buildMealDBSection(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfidenceCard(Color confidenceColor) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AppTheme.softCard(),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: confidenceColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.verified_rounded, color: confidenceColor, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tingkat keyakinan',
                  style: TextStyle(color: AppColors.muted, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.result.confidencePercentage,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: confidenceColor,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNutritionSection() {
    return _SectionCard(
      icon: Icons.auto_awesome_rounded,
      iconColor: AppColors.amber,
      title: 'Informasi Nutrisi',
      subtitle: 'Powered by Gemini AI',
      child: _isLoadingNutrition
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator(color: AppColors.coral)),
            )
          : _nutritionInfo != null
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _nutritionInfo!.summary,
                      style: const TextStyle(color: AppColors.muted, height: 1.5, fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _NutritionChip('Kalori', '${_nutritionInfo!.calories} kcal', Icons.local_fire_department_rounded, AppColors.coral),
                        _NutritionChip('Karbohidrat', '${_nutritionInfo!.carbs} g', Icons.grain_rounded, AppColors.amber),
                        _NutritionChip('Lemak', '${_nutritionInfo!.fat} g', Icons.water_drop_rounded, AppColors.liveRed),
                        _NutritionChip('Serat', '${_nutritionInfo!.fiber} g', Icons.eco_rounded, AppColors.olive),
                        _NutritionChip('Protein', '${_nutritionInfo!.protein} g', Icons.fitness_center_rounded, AppColors.coralDark),
                      ],
                    ),
                  ],
                )
              : const Text('Gagal memuat informasi nutrisi.', style: TextStyle(color: AppColors.muted)),
    );
  }

  Widget _buildMealDBSection() {
    return _SectionCard(
      icon: Icons.menu_book_rounded,
      iconColor: AppColors.olive,
      title: 'Referensi Resep',
      subtitle: 'TheMealDB',
      child: _isLoadingMealDB
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator(color: AppColors.coral)),
            )
          : _mealDetail != null
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_mealDetail!.thumbnail.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(
                          _mealDetail!.thumbnail,
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const SizedBox(),
                        ),
                      ),
                    if (_mealDetail!.thumbnail.isNotEmpty) const SizedBox(height: 14),
                    Text(
                      _mealDetail!.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.charcoal,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const _Subheading('Bahan-bahan'),
                    const SizedBox(height: 8),
                    ..._mealDetail!.ingredients.map(
                      (ing) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.check_circle_rounded, size: 18, color: AppColors.olive),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '${ing.name}${ing.measure.isNotEmpty ? " (${ing.measure})" : ""}',
                                style: const TextStyle(fontSize: 14, height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const _Subheading('Cara membuat'),
                    const SizedBox(height: 8),
                    Text(
                      _mealDetail!.instructions,
                      style: const TextStyle(fontSize: 14, color: AppColors.muted, height: 1.55),
                    ),
                  ],
                )
              : const Text('Tidak menemukan resep referensi.', style: TextStyle(color: AppColors.muted)),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget child;

  const _SectionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AppTheme.softCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: AppColors.charcoal,
                      ),
                    ),
                    Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _Subheading extends StatelessWidget {
  final String text;

  const _Subheading(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 15,
        color: AppColors.charcoal,
      ),
    );
  }
}

class _NutritionChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _NutritionChip(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 148,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.muted), overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color),
          ),
        ],
      ),
    );
  }
}
