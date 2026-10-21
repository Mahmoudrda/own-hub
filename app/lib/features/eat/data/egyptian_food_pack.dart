/// The Egyptian foods bundled with the app, for search that works offline.
///
/// `assets/content/foods_eg.json` is built from `functions/nutrition` and
/// `tool/food_pack_singles.json` by `tool/build_food_pack.py`. Its figures are
/// estimates from standard recipes of USDA FoodData Central foods (CC0),
/// pending dietitian review. Every food carries an `allergens` list derived from
/// its standard ingredients, over-inclusive and not lab tested; the build
/// refuses a food without one.
library;

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../../../l10n/app_l10n.dart';
import '../domain/food_library.dart';

class EgyptianFoodPack {
  EgyptianFoodPack._();

  static const String assetPath = 'assets/content/foods_eg.json';

  /// Foods the hand-written samples already cover, left out so one plate is
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
    FoodSize size(String id, Map<String, Object?> s) {
      final named = s['label'] as Map?;
      final generic = switch (id) {
        'S' => l10n.small,
        'L' => l10n.large,
        _ => l10n.medium,
      };
      return FoodSize(
        id: id,
        label: named == null ? generic : named[arabic ? 'ar' : 'en'] as String,
        kcal: (s['kcal'] as num).toInt(),
        proteinG: (s['proteinG'] as num).toInt(),
        carbsG: (s['carbsG'] as num).toInt(),
        fatG: (s['fatG'] as num).toInt(),
        fiberG: (s['fiberG'] as num).toInt(),
        grams: (s['grams'] as num).toInt(),
      );
    }

    // The pack lists several spellings of one name (with and without hamza,
    // ta marbuta and ya). The matcher folds them together, so one is enough.
    final seen = <String>{};
    final names = <String>[
      for (final name in [
        arabic ? ar : en,
        arabic ? en : ar,
        for (final alias in (dish['aliases'] as List)) alias as String,
      ])
        if (seen.add(FoodLibrary.normalise(name))) name,
    ];

    return Food(
      foodId: dish['id'] as String,
      names: names,
      sizes: [
        for (final entry in sizes.entries)
          size(entry.key, (entry.value as Map).cast<String, Object?>()),
      ],
      allergens: {for (final tag in dish['allergens'] as List) tag as String},
      popularity: 40,
      category: FoodCategory.fromWire(dish['category'] as String?),
      kind: dish['kind'] as String?,
    );
  }
}
