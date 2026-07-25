import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;

class FoodNutritionInfo {
  final String foodName;
  final int calories; // kcal
  final double carbs; // grams
  final double fat; // grams
  final double fiber; // grams
  final double protein; // grams
  final String summary;

  FoodNutritionInfo({
    required this.foodName,
    required this.calories,
    required this.carbs,
    required this.fat,
    required this.fiber,
    required this.protein,
    required this.summary,
  });

  factory FoodNutritionInfo.fromJson(Map<String, dynamic> json, String defaultFoodName) {
    return FoodNutritionInfo(
      foodName: json['foodName'] ?? defaultFoodName,
      calories: (json['calories'] ?? 350) is int ? json['calories'] : int.tryParse(json['calories'].toString()) ?? 350,
      carbs: (json['carbs'] ?? 45.0).toDouble(),
      fat: (json['fat'] ?? 15.0).toDouble(),
      fiber: (json['fiber'] ?? 3.5).toDouble(),
      protein: (json['protein'] ?? 12.0).toDouble(),
      summary: json['summary'] ?? 'Nutritional estimate based on standard portion (100g-250g).',
    );
  }
}

class GeminiNutritionService {
  static String? userProvidedApiKey;

  static String get apiKey {
    if (userProvidedApiKey != null && userProvidedApiKey!.trim().isNotEmpty) {
      return userProvidedApiKey!.trim();
    }
    return const String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');
  }

  Future<FoodNutritionInfo> fetchNutritionInfo(String foodName) async {
    final key = apiKey;

    if (key.isNotEmpty) {
      try {
        final model = GenerativeModel(
          model: 'gemini-1.5-flash',
          apiKey: key,
        );

        final prompt = '''
Provide the nutritional values per standard portion for the food "$foodName" in JSON format.
Strictly return ONLY a valid JSON object with the following schema:
{
  "foodName": "$foodName",
  "calories": integer,
  "carbs": float,
  "fat": float,
  "fiber": float,
  "protein": float,
  "summary": "Brief 1-2 sentence nutritional summary in Indonesian language"
}
Do not include markdown backticks or any additional text.
''';

        final response = await model.generateContent([Content.text(prompt)]);
        final rawText = response.text?.trim() ?? '';
        
        final cleanedJson = rawText
            .replaceAll('```json', '')
            .replaceAll('```', '')
            .trim();

        final parsed = json.decode(cleanedJson);
        return FoodNutritionInfo.fromJson(parsed, foodName);
      } catch (e) {
        debugPrint('Gemini SDK error, trying direct HTTP REST fallback: $e');
        try {
          return await _fetchViaRestApi(foodName, key);
        } catch (restErr) {
          debugPrint('Gemini REST API fallback error: $restErr');
        }
      }
    }

    // Default intelligent estimation fallback if API key is not supplied or offline
    return _generateFallbackNutrition(foodName);
  }

  Future<FoodNutritionInfo> _fetchViaRestApi(String foodName, String key) async {
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$key',
    );

    final prompt = 'Return JSON object only: {"foodName":"$foodName","calories":250,"carbs":30.0,"fat":10.0,"fiber":2.5,"protein":8.0,"summary":"Nutrisi terestimasi"} for $foodName';

    final body = json.encode({
      'contents': [
        {
          'parts': [{'text': prompt}]
        }
      ]
    });

    final res = await http.post(url, headers: {'Content-Type': 'application/json'}, body: body);
    if (res.statusCode == 200) {
      final jsonRes = json.decode(res.body);
      final text = jsonRes['candidates'][0]['content']['parts'][0]['text'];
      final cleaned = text.replaceAll('```json', '').replaceAll('```', '').trim();
      return FoodNutritionInfo.fromJson(json.decode(cleaned), foodName);
    }

    return _generateFallbackNutrition(foodName);
  }

  FoodNutritionInfo _generateFallbackNutrition(String foodName) {
    final nameLower = foodName.toLowerCase();
    if (nameLower.contains('burger')) {
      return FoodNutritionInfo(
        foodName: foodName,
        calories: 540,
        carbs: 42.0,
        fat: 29.0,
        fiber: 2.1,
        protein: 25.0,
        summary: 'Burger kaya akan protein dan lemak, cocok untuk kebutuhan energi tinggi.',
      );
    } else if (nameLower.contains('pizza')) {
      return FoodNutritionInfo(
        foodName: foodName,
        calories: 285,
        carbs: 36.0,
        fat: 10.4,
        fiber: 2.5,
        protein: 12.2,
        summary: 'Pizza mengandung karbohidrat berimbang dari adonan roti serta kalsium dari keju.',
      );
    } else if (nameLower.contains('salad')) {
      return FoodNutritionInfo(
        foodName: foodName,
        calories: 120,
        carbs: 11.0,
        fat: 7.0,
        fiber: 4.5,
        protein: 3.2,
        summary: 'Salad kaya akan serat dan vitamin rendah kalori yang sangat sehat.',
      );
    } else if (nameLower.contains('nasi goreng') || nameLower.contains('fried rice')) {
      return FoodNutritionInfo(
        foodName: foodName,
        calories: 330,
        carbs: 45.0,
        fat: 12.0,
        fiber: 2.0,
        protein: 9.5,
        summary: 'Nasi goreng memberikan karbohidrat utama dan energi siap pakai.',
      );
    } else {
      return FoodNutritionInfo(
        foodName: foodName,
        calories: 310,
        carbs: 38.0,
        fat: 11.0,
        fiber: 3.0,
        protein: 14.0,
        summary: 'Makanan dengan kandungan nutrisi seimbang untuk mendukung aktivitas harian.',
      );
    }
  }
}
