import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class MealIngredient {
  final String name;
  final String measure;

  MealIngredient({required this.name, required this.measure});
}

class MealDetail {
  final String id;
  final String name;
  final String thumbnail;
  final String instructions;
  final List<MealIngredient> ingredients;

  MealDetail({
    required this.id,
    required this.name,
    required this.thumbnail,
    required this.instructions,
    required this.ingredients,
  });

  factory MealDetail.fromJson(Map<String, dynamic> json) {
    List<MealIngredient> ingredientsList = [];
    for (int i = 1; i <= 20; i++) {
      final ingredient = json['strIngredient$i'];
      final measure = json['strMeasure$i'];
      if (ingredient != null &&
          ingredient.toString().trim().isNotEmpty &&
          ingredient.toString().trim() != 'null') {
        ingredientsList.add(
          MealIngredient(
            name: ingredient.toString().trim(),
            measure: (measure != null && measure.toString().trim().isNotEmpty)
                ? measure.toString().trim()
                : '',
          ),
        );
      }
    }

    return MealDetail(
      id: json['idMeal'] ?? '',
      name: json['strMeal'] ?? '',
      thumbnail: json['strMealThumb'] ?? '',
      instructions: json['strInstructions'] ?? 'No instructions available.',
      ingredients: ingredientsList,
    );
  }
}

class MealDBService {
  static const String _baseUrl = 'https://www.themealdb.com/api/json/v1/1/search.php?s=';

  Future<MealDetail?> fetchMealByFoodName(String query) async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl${Uri.encodeComponent(query)}'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final meals = data['meals'];
        if (meals != null && meals is List && meals.isNotEmpty) {
          return MealDetail.fromJson(meals.first);
        }
      }
    } catch (e) {
      debugPrint('Error searching MealDB: $e');
    }

    // Fallback query with general food term if specific query returns empty
    try {
      final fallbackResponse = await http.get(Uri.parse('${_baseUrl}chicken'));
      if (fallbackResponse.statusCode == 200) {
        final data = json.decode(fallbackResponse.body);
        final meals = data['meals'];
        if (meals != null && meals is List && meals.isNotEmpty) {
          return MealDetail.fromJson(meals.first);
        }
      }
    } catch (e) {
      debugPrint('Error searching MealDB fallback: $e');
    }

    return null;
  }
}
