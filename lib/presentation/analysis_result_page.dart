import 'dart:io';

import 'package:flutter/material.dart';

import '../core/theme/brand_palette.dart';
import '../data/ai_nutrition_provider.dart';
import '../data/recipe_lookup_client.dart';
import '../domain/food_prediction.dart';
import '../domain/nutrition_facts.dart';
import '../domain/recipe_entry.dart';

class AnalysisResultPage extends StatefulWidget {
  const AnalysisResultPage({
    super.key,
    required this.photo,
    required this.prediction,
  });

  final File? photo;
  final FoodPrediction prediction;

  @override
  State<AnalysisResultPage> createState() => _AnalysisResultPageState();
}

class _AnalysisResultPageState extends State<AnalysisResultPage> {
  final _nutritionApi = AiNutritionProvider();
  final _recipeApi = RecipeLookupClient();

  RecipeEntry? _recipe;
  NutritionFacts? _nutrition;
  bool _loadingRecipe = true;
  bool _loadingNutrition = true;

  @override
  void initState() {
    super.initState();
    _fetchAll();
  }

  Future<void> _fetchAll() async {
    _loadNutrition();
    _loadRecipe();
  }

  Future<void> _loadNutrition() async {
    try {
      final facts = await _nutritionApi.lookup(widget.prediction.name);
      if (mounted) setState(() { _nutrition = facts; _loadingNutrition = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingNutrition = false);
    }
  }

  Future<void> _loadRecipe() async {
    try {
      final entry = await _recipeApi.findByDishName(widget.prediction.name);
      if (mounted) setState(() { _recipe = entry; _loadingRecipe = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingRecipe = false);
    }
  }

  Color get _badgeColor {
    if (widget.prediction.score >= 0.8) return BrandPalette.forest;
    if (widget.prediction.score >= 0.5) return BrandPalette.honey;
    return BrandPalette.streamRed;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: widget.photo != null ? 300 : 200,
            pinned: true,
            backgroundColor: BrandPalette.terracotta,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (widget.photo != null)
                    Image.file(widget.photo!, fit: BoxFit.cover)
                  else
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [BrandPalette.terracotta, BrandPalette.terracottaDeep],
                        ),
                      ),
                    ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.prediction.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Chip(
                          label: Text('Skor ${widget.prediction.scoreLabel}'),
                          backgroundColor: _badgeColor,
                          labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _NutritionPanel(loading: _loadingNutrition, facts: _nutrition),
                const SizedBox(height: 14),
                _RecipePanel(loading: _loadingRecipe, recipe: _recipe),
                const SizedBox(height: 24),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _NutritionPanel extends StatelessWidget {
  const _NutritionPanel({required this.loading, required this.facts});

  final bool loading;
  final NutritionFacts? facts;

  @override
  Widget build(BuildContext context) {
    return _PanelShell(
      title: 'Nutrisi (Gemini)',
      icon: Icons.auto_awesome,
      accent: BrandPalette.honey,
      child: loading
          ? const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
          : facts == null
              ? const Text('Data nutrisi tidak tersedia.')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(facts!.description, style: const TextStyle(color: BrandPalette.stone, height: 1.5)),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _MetricTile('Kalori', '${facts!.caloriesKcal} kcal'),
                        _MetricTile('Karbo', '${facts!.carbsGram} g'),
                        _MetricTile('Lemak', '${facts!.fatGram} g'),
                        _MetricTile('Serat', '${facts!.fiberGram} g'),
                        _MetricTile('Protein', '${facts!.proteinGram} g'),
                      ],
                    ),
                  ],
                ),
    );
  }
}

class _RecipePanel extends StatelessWidget {
  const _RecipePanel({required this.loading, required this.recipe});

  final bool loading;
  final RecipeEntry? recipe;

  @override
  Widget build(BuildContext context) {
    return _PanelShell(
      title: 'Resep Referensi',
      icon: Icons.menu_book,
      accent: BrandPalette.forest,
      child: loading
          ? const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
          : recipe == null
              ? const Text('Resep tidak ditemukan untuk hidangan ini.')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (recipe!.imageUrl.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(recipe!.imageUrl, height: 160, width: double.infinity, fit: BoxFit.cover),
                      ),
                    const SizedBox(height: 10),
                    Text(recipe!.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    const Text('Bahan:', style: TextStyle(fontWeight: FontWeight.w600, color: BrandPalette.forest)),
                    ...recipe!.ingredients.map(
                      (i) => Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('• ${i.item}${i.amount.isNotEmpty ? ' — ${i.amount}' : ''}'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('Langkah:', style: TextStyle(fontWeight: FontWeight.w600, color: BrandPalette.forest)),
                    const SizedBox(height: 6),
                    Text(recipe!.steps, style: const TextStyle(height: 1.5)),
                  ],
                ),
    );
  }
}

class _PanelShell extends StatelessWidget {
  const _PanelShell({
    required this.title,
    required this.icon,
    required this.accent,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Color accent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: BrandPalette.sandDeep),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accent),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: (MediaQuery.sizeOf(context).width - 64) / 2,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: BrandPalette.sand,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: BrandPalette.stone)),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
