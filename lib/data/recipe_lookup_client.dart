import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../domain/recipe_entry.dart';

class RecipeLookupClient {
  static const _endpoint = 'https://www.themealdb.com/api/json/v1/1/search.php?s=';

  Future<RecipeEntry?> findByDishName(String keyword) async {
    final primary = await _query(keyword);
    if (primary != null) return primary;
    return _query('chicken');
  }

  Future<RecipeEntry?> _query(String keyword) async {
    try {
      final uri = Uri.parse('$_endpoint${Uri.encodeComponent(keyword)}');
      final response = await http.get(uri);
      if (response.statusCode != 200) return null;

      final meals = json.decode(response.body)['meals'];
      if (meals is! List || meals.isEmpty) return null;

      return RecipeEntry.fromMealDbJson(meals.first as Map<String, dynamic>);
    } catch (error) {
      debugPrint('RecipeLookupClient error: $error');
      return null;
    }
  }
}
