class NutritionFacts {
  const NutritionFacts({
    required this.dishName,
    required this.caloriesKcal,
    required this.carbsGram,
    required this.fatGram,
    required this.fiberGram,
    required this.proteinGram,
    required this.description,
  });

  final String dishName;
  final int caloriesKcal;
  final double carbsGram;
  final double fatGram;
  final double fiberGram;
  final double proteinGram;
  final String description;

  factory NutritionFacts.fromMap(Map<String, dynamic> map, String fallbackName) {
    return NutritionFacts(
      dishName: map['foodName']?.toString() ?? fallbackName,
      caloriesKcal: _asInt(map['calories'], 350),
      carbsGram: _asDouble(map['carbs'], 45),
      fatGram: _asDouble(map['fat'], 15),
      fiberGram: _asDouble(map['fiber'], 3.5),
      proteinGram: _asDouble(map['protein'], 12),
      description: map['summary']?.toString() ??
          'Perkiraan nutrisi berdasarkan porsi standar (100–250 g).',
    );
  }

  static int _asInt(dynamic value, int fallback) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static double _asDouble(dynamic value, double fallback) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }
}
