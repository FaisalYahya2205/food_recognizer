import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../domain/nutrition_facts.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class AiNutritionProvider {
  static String? runtimeApiKey;

  static String get _resolvedKey {
    final manual = runtimeApiKey?.trim();
    if (manual != null && manual.isNotEmpty) return manual;
    return const String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');
  }

  Future<NutritionFacts> lookup(String dishName) async {
    final key = _resolvedKey;
    if (key.isNotEmpty) {
      try {
        return await _viaSdk(dishName, key);
      } catch (sdkError) {
        debugPrint('Gemini SDK gagal: $sdkError');
        try {
          return await _viaHttp(dishName, key);
        } catch (httpError) {
          debugPrint('Gemini REST gagal: $httpError');
        }
      }
    }
    return _estimateOffline(dishName);
  }

  Future<NutritionFacts> _viaSdk(String dishName, String key) async {
    final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: key);
    final prompt = _buildPrompt(dishName);
    final response = await model.generateContent([Content.text(prompt)]);
    final cleaned = _stripMarkdown(response.text ?? '');
    return NutritionFacts.fromMap(json.decode(cleaned), dishName);
  }

  Future<NutritionFacts> _viaHttp(String dishName, String key) async {
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$key',
    );
    final payload = json.encode({
      'contents': [
        {
          'parts': [
            {'text': _buildPrompt(dishName)},
          ],
        },
      ],
    });

    final res = await http.post(uri, headers: {'Content-Type': 'application/json'}, body: payload);
    if (res.statusCode != 200) throw HttpException('Gemini HTTP ${res.statusCode}');

    final body = json.decode(res.body);
    final text = body['candidates'][0]['content']['parts'][0]['text'] as String;
    return NutritionFacts.fromMap(json.decode(_stripMarkdown(text)), dishName);
  }

  String _buildPrompt(String dishName) => '''
Berikan nilai nutrisi per porsi standar untuk "$dishName" dalam format JSON saja:
{
  "foodName": "$dishName",
  "calories": integer,
  "carbs": float,
  "fat": float,
  "fiber": float,
  "protein": float,
  "summary": "Ringkasan singkat dalam Bahasa Indonesia"
}
''';

  String _stripMarkdown(String raw) =>
      raw.replaceAll('```json', '').replaceAll('```', '').trim();

  NutritionFacts _estimateOffline(String dishName) {
    final key = dishName.toLowerCase();
    if (key.contains('burger')) {
      return NutritionFacts(
        dishName: dishName,
        caloriesKcal: 540,
        carbsGram: 42,
        fatGram: 29,
        fiberGram: 2.1,
        proteinGram: 25,
        description: 'Burger tinggi protein dan lemak — cocok untuk asupan energi.',
      );
    }
    if (key.contains('pizza')) {
      return NutritionFacts(
        dishName: dishName,
        caloriesKcal: 285,
        carbsGram: 36,
        fatGram: 10.4,
        fiberGram: 2.5,
        proteinGram: 12.2,
        description: 'Pizza mengandung karbohidrat dari adonan dan kalsium dari keju.',
      );
    }
    if (key.contains('salad')) {
      return NutritionFacts(
        dishName: dishName,
        caloriesKcal: 120,
        carbsGram: 11,
        fatGram: 7,
        fiberGram: 4.5,
        proteinGram: 3.2,
        description: 'Salad kaya serat dan vitamin dengan kalori relatif rendah.',
      );
    }
    return NutritionFacts(
      dishName: dishName,
      caloriesKcal: 310,
      carbsGram: 38,
      fatGram: 11,
      fiberGram: 3,
      proteinGram: 14,
      description: 'Perkiraan nutrisi seimbang untuk kebutuhan harian.',
    );
  }
}
