class FoodPrediction {
  const FoodPrediction({
    required this.name,
    required this.score,
  });

  final String name;
  final double score;

  String get scoreLabel => '${(score * 100).toStringAsFixed(1)}%';

  @override
  String toString() => '$name ($scoreLabel)';
}
