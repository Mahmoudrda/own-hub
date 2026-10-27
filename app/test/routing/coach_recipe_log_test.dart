// "Log this" on a recipe in her coach's meal plan puts it in her day in one
// tap, like a food: the figures are the book's for the servings the plan names,
// the allergy guard has the same say, and a recipe with no figures is not
// logged on a guess.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/eat_state.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/features/account/domain/dietary_profile.dart';
import 'package:own_hub/features/eat/data/seeded_recipe_library.dart';
import 'package:own_hub/features/eat/domain/meal_repository.dart' as eat;
import 'package:own_hub/features/private_coaching/domain/coach_plan.dart';
import 'package:own_hub/features/private_coaching/domain/coaching_contract.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/routing/coaching_wiring.dart';
import 'package:own_hub/theme/app_tokens.dart';

MealItem _item(String id, double servings) => MealItem.recipe(id, servings);

CoachPlan _plan(MealItem item) => CoachPlan(
  id: 'p1',
  kind: PlanKind.meal,
  meal: MealPlanBody(
    days: [
      MealDay(
        label: 'Day 1',
        slots: {
          'breakfast': [item],
        },
      ),
    ],
  ),
  startsOn: DateTime(2026, 1, 1, 12),
);

/// Lets the five-second undo offer lapse, which writes the meal.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 6));
  await tester.pump();
}

void main() {
  final saved = AppRouter.featureFlags;

  setUp(() async {
    AppRouter.featureFlags = FeatureFlags.allOff.with_({
      for (final f in Feature.values) f: f != Feature.accountRequired,
    });
    SeededRecipeLibrary.resetCache();
    EatAppState.instance.reset();
    EatAppState.instance.recipeBook = await SeededRecipeLibrary(
      readAsset: (key) async => File(key).readAsStringSync(),
    ).load();
  });

  tearDown(() async {
    AppRouter.featureFlags = saved;
    EatAppState.instance.reset();
    SeededRecipeLibrary.resetCache();
    await AppRouter.dietaryRepository.save(
      allergies: const <AllergenTag>{},
      dietary: const <DietaryTag>{},
    );
  });

  /// Pumps a screen, then calls [logCoachMeal] from inside it.
  Future<List<String>> tap(WidgetTester tester, MealItem item) async {
    final opened = <String>[];
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        theme: buildTheme(const Locale('en')),
        home: Scaffold(
          body: Builder(
            builder: (c) {
              context = c;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    logCoachMeal(
      context,
      plan: _plan(item),
      item: item,
      slot: 'breakfast',
      openRecipe: opened.add,
    );
    await tester.pump();
    return opened;
  }

  /// What the day holds once the undo windows have closed.
  List<dynamic> stored() =>
      AppRouter.mealRepository.store.days[EatAppState.dayIdOf(DateTime.now())]
          ?.itemsIn(eat.MealSlot.breakfast) ??
      const [];

  List<dynamic> breakfast() => EatAppState.instance.session
      .project(eat.MealDay(dayId: EatAppState.dayIdOf(DateTime.now())))
      .itemsIn(eat.MealSlot.breakfast);

  testWidgets('one tap logs the recipe at the servings the plan names', (
    tester,
  ) async {
    // Lazy Cake: 123 kcal, 10 g protein, 10 g carbs, 6 g fat, a serving.
    final opened = await tap(tester, _item('rahma_lazy_cake', 2));
    expect(opened, isEmpty, reason: 'it was logged, not just opened');
    final logged = breakfast();
    expect(logged, hasLength(1));
    expect(logged.single.name, 'Lazy Cake');
    expect(logged.single.kcal, 246);
    expect(logged.single.proteinG, 20);
    expect(logged.single.carbsG, 20);
    expect(logged.single.fatG, 12);
    expect(find.byType(SnackBar), findsOneWidget, reason: 'with its Undo');
    await _settle(tester);
    final rows = stored();
    expect(rows, hasLength(1));
    expect(rows.single.name, 'Lazy Cake');
  });

  testWidgets('tapping it again corrects the row, it does not add another', (
    tester,
  ) async {
    await tap(tester, _item('rahma_lazy_cake', 1));
    await _settle(tester);
    await tap(tester, _item('rahma_lazy_cake', 2));
    await _settle(tester);
    final rows = stored();
    expect(rows, hasLength(1));
    expect(rows.single.kcal, 246, reason: 'the second tap is the correction');
  });

  testWidgets('a dish she is allergic to is held by the same guard', (
    tester,
  ) async {
    await AppRouter.dietaryRepository.save(
      allergies: const {AllergenTag.eggs},
      dietary: const <DietaryTag>{},
    );
    final opened = await tap(tester, _item('rahma_lazy_cake', 1));
    expect(breakfast(), isEmpty);
    expect(opened, isEmpty);
  });

  testWidgets(
    'a recipe with withheld macros is opened, not logged on a guess',
    (tester) async {
      final raw = jsonDecode(
        File('assets/content/rahma_recipes.json').readAsStringSync(),
      ) as Map<String, Object?>;
      final withheld = [
        for (final r in (raw['recipes']! as List).cast<Map<String, Object?>>())
          if (r['recipeId'] == 'rahma_lazy_cake')
            {...r, 'macroBasis': 'withheld', 'kcal': null}
          else
            r,
      ];
      EatAppState.instance.recipeBook = RecipeBook.fromJson({
        ...raw,
        'recipes': withheld,
      });
      SeededRecipeLibrary.resetCache();
      final opened = await tap(tester, _item('rahma_lazy_cake', 1));
      expect(opened, ['rahma_lazy_cake']);
      expect(breakfast(), isEmpty);
    },
  );
}
