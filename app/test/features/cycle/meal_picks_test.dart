// Y07 — meals for today come only from today's check-in and the recipes' tags.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/cycle/domain/meal_picks.dart';
import 'package:own_hub/features/cycle/domain/today_check_in.dart';
import 'package:own_hub/features/cycle/presentation/cycle_meals_view.dart';
import 'package:own_hub/features/eat/data/seeded_recipe_library.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';

late RecipeBook _book;

void main() {
  setUpAll(() {
    _book = RecipeBook.fromJson(
      (jsonDecode(
        File('assets/content/rahma_recipes.json').readAsStringSync(),
      ) as Map).cast<String, Object?>(),
    );
  });

  test('no check-in, or an easy day, picks nothing', () {
    expect(mealsForToday(TodayCheckIn.absent, _book.recipes), isEmpty);
    expect(
      mealsForToday(
        const TodayCheckIn(energy: Energy.high, cramps: Cramps.none),
        _book.recipes,
      ),
      isEmpty,
    );
  });

  test('low energy picks her comfy dinners first, three at most', () {
    final picks = mealsForToday(
      const TodayCheckIn(energy: Energy.low),
      _book.recipes,
    );
    expect(picks, hasLength(3));
    expect(picks.first.tags, MealTags.comfyAndProtein);
    expect(picks.first.recipe.recipeId, 'rahma_bagel');
    expect(picks[1].tags, MealTags.comfy);
    for (final pick in picks) {
      expect(pick.signal, MealSignal.lowEnergy);
      expect(
        pick.recipe.sectionId == kComfyDinnerSection ||
            pick.recipe.dietTags.contains(kHighProteinTag),
        isTrue,
      );
    }
  });

  test('cramps pick too, and both say both', () {
    expect(
      mealSignalOf(const TodayCheckIn(cramps: Cramps.mild)),
      MealSignal.cramps,
    );
    expect(
      mealSignalOf(
        const TodayCheckIn(energy: Energy.low, cramps: Cramps.severe),
      ),
      MealSignal.both,
    );
  });

  test('only what the allergy guard let through is picked from', () {
    final picks = mealsForToday(
      const TodayCheckIn(energy: Energy.low),
      const [],
    );
    expect(picks, isEmpty);
  });

  testWidgets('the reason names what she logged and the tags, nothing else', (
    tester,
  ) async {
    final picks = mealsForToday(
      const TodayCheckIn(energy: Energy.low, cramps: Cramps.mild),
      _book.recipes,
    );
    late CycleMealOption option;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        theme: buildTheme(const Locale('en')),
        home: Builder(
          builder: (context) {
            option = cycleMealOption(AppL10n.of(context), picks.first);
            return CycleMealsView(options: [option], onAddToPlan: (_) {});
          },
        ),
      ),
    );
    expect(
      option.reason,
      'Your energy is low and you have cramps today. '
      'A comfy dinner, high in protein.',
    );
    expect(option.reason.toLowerCase(), isNot(contains('phase')));
    expect(find.text(option.reason), findsOneWidget);
    expect(find.text('Add to today\'s plan'), findsOneWidget);
    expect(find.text('Swap'), findsNothing);
  });
}
