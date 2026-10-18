/// The 159 Egyptian dishes bundled with the app, for search that works offline.
///
/// `assets/content/foods_eg.json` is built from `functions/nutrition` by
/// `tool/build_food_pack.py`. Its figures are estimates from standard recipes
/// of USDA FoodData Central foods (CC0), pending dietitian review. It carries
/// no allergen data, so every dish here has `allergens: null`, which the guard
/// reads as unknown.
library;

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../../../l10n/app_l10n.dart';
import '../domain/food_library.dart';

class EgyptianFoodPack {
  EgyptianFoodPack._();

  static const String assetPath = 'assets/content/foods_eg.json';

  /// Dishes the 8 hand-written foods already cover, left out so one plate is
  /// not offered twice under two names.
  static const Set<String> _covered = {
    'koshary',
    'eggs_boiled',
    'molokhia_chicken',
    'ful_medames',
  };

  static List<Map<String, Object?>> _dishes = const [];
  static final Map<bool, List<Food>> _built = {};
  static Future<void>? _loading;

  static bool get isLoaded => _dishes.isNotEmpty;

  /// Reads the asset once a run. A file that cannot be read leaves the pack
  /// empty and search keeps the sample foods.
  static Future<void> ensureLoaded() => _loading ??= _load();

  static Future<void> _load() async {
    try {
      adopt(await rootBundle.loadString(assetPath));
    } catch (_) {}
  }

  /// Takes the pack's JSON text. Public so a test can supply it.
  static void adopt(String json) {
    final decoded = jsonDecode(json) as Map;
    _built.clear();
    _dishes = [
      for (final dish in decoded['foods'] as List)
        (dish as Map).cast<String, Object?>(),
    ];
  }

  static void reset() {
    _dishes = const [];
    _built.clear();
    _loading = null;
  }

  /// The pack's dishes with names and portion labels in her language.
  static List<Food> foods(AppL10n l10n) {
    final arabic = l10n.localeName.startsWith('ar');
    return _built[arabic] ??= [
      for (final dish in _dishes)
        if (!_covered.contains(dish['id'])) _food(dish, l10n, arabic),
    ];
  }

  static Food _food(Map<String, Object?> dish, AppL10n l10n, bool arabic) {
    final en = dish['nameEn'] as String;
    final ar = dish['nameAr'] as String;
    final sizes = (dish['sizes'] as Map).cast<String, Object?>();
    FoodSize size(String id, String label) {
      final s = (sizes[id] as Map).cast<String, Object?>();
      return FoodSize(
        id: id,
        label: label,
        kcal: (s['kcal'] as num).toInt(),
        proteinG: (s['proteinG'] as num).toInt(),
        carbsG: (s['carbsG'] as num).toInt(),
        fatG: (s['fatG'] as num).toInt(),
        fiberG: (s['fiberG'] as num).toInt(),
        grams: (s['grams'] as num).toInt(),
      );
    }

    return Food(
      foodId: dish['id'] as String,
      names: [
        arabic ? ar : en,
        arabic ? en : ar,
        for (final alias in (dish['aliases'] as List)) alias as String,
      ],
      sizes: [
        size('S', l10n.small),
        size('M', l10n.medium),
        size('L', l10n.large),
      ],
      popularity: 40,
    );
  }
}
