// Typing "ful" and "boiled eggs" must carry the pack's carbs and fat all the way
// to the day's totals, not just kcal and protein.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/eat/domain/day_totals.dart';
import 'package:own_hub/features/eat/domain/meal_repository.dart';
import 'package:own_hub/features/eat/domain/meal_sentence_parser.dart';
import 'package:own_hub/features/eat/presentation/eat_sample_library.dart';
import 'package:own_hub/l10n/app_l10n_en.dart';

void main() {
  test('typed ful and eggs total the pack carbs, fat and fibre', () {
    final pack = jsonDecode(
      File('assets/content/foods_eg.json').readAsStringSync(),
    ) as Map<String, Object?>;
    final foods = {
      for (final f in (pack['foods'] as List).cast<Map<String, Object?>>())
        f['id'] as String: f,
    };
    Map<String, Object?> size(String id, String s) =>
        ((foods[id]!['sizes'] as Map)[s] as Map).cast<String, Object?>();

    final parsed = MealSentenceParser(eatSampleLibrary(AppL10nEn()))
        .parse('ful, boiled eggs');
    expect(parsed.unresolved, isEmpty);
    expect(parsed.items, hasLength(2));

    final items = [
      for (final (i, e) in parsed.items.indexed)
        MealItem(
          itemId: 'i$i',
          foodId: e.food.foodId,
          servings: e.servings,
          size: e.size.id,
          loggedAt: DateTime(2026, 9, 15, 8),
          source: MealSource.search,
          origin: MealOrigin.search,
          kcal: e.kcal,
          proteinG: e.proteinG,
          carbsG: e.carbsG,
          fatG: e.fatG,
          fiberG: e.fiberG,
        ),
    ];
    final totals = DayTotals.recompute(items);

    final ful = size('ful_medames', 'M');
    final eggs = size('eggs_boiled', 'M');
    expect(totals.carbsSoFar, (ful['carbsG'] as num) + (eggs['carbsG'] as num));
    expect(totals.fatSoFar, (ful['fatG'] as num) + (eggs['fatG'] as num));
    expect(totals.fiberSoFar, (ful['fiberG'] as num) + (eggs['fiberG'] as num));
  });
}
