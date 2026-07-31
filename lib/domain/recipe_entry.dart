class RecipeIngredient {
  const RecipeIngredient({required this.item, required this.amount});

  final String item;
  final String amount;
}

class RecipeEntry {
  const RecipeEntry({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.steps,
    required this.ingredients,
  });

  final String id;
  final String title;
  final String imageUrl;
  final String steps;
  final List<RecipeIngredient> ingredients;

  factory RecipeEntry.fromMealDbJson(Map<String, dynamic> json) {
    final items = <RecipeIngredient>[];
    for (var i = 1; i <= 20; i++) {
      final rawItem = json['strIngredient$i'];
      final rawAmount = json['strMeasure$i'];
      if (rawItem == null || rawItem.toString().trim().isEmpty) continue;
      if (rawItem.toString().trim() == 'null') continue;

      items.add(
        RecipeIngredient(
          item: rawItem.toString().trim(),
          amount: rawAmount?.toString().trim() ?? '',
        ),
      );
    }

    return RecipeEntry(
      id: json['idMeal']?.toString() ?? '',
      title: json['strMeal']?.toString() ?? '',
      imageUrl: json['strMealThumb']?.toString() ?? '',
      steps: json['strInstructions']?.toString() ?? 'Instruksi belum tersedia.',
      ingredients: items,
    );
  }
}
