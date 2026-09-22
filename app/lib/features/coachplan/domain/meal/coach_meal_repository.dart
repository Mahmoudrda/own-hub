/// `coaches/{coachUid}/meals/*` — W07's own collection.
///
/// Never `foods`. W07 says so on screen ("not added to the app's public
/// library") and G5's rules deny the write anyway. A coach's dish is hers; the
/// verified pack is content, and the difference is the whole reason W07 shows
/// no totals for an unverified ingredient.
///
/// The fake refuses exactly what the ruleset refuses: figures on a meal whose
/// ingredients did not all resolve. `P2-ERR-W07` is that case — "the write is
/// refused and the screen states nutrition is unavailable rather than storing a
/// partial total. No estimate is ever written."
library;

import 'coach_meal.dart';

/// Refused because a meal carried numbers it has not earned.
class UnverifiedNutritionStored implements Exception {
  const UnverifiedNutritionStored();

  @override
  String toString() =>
      'UnverifiedNutritionStored — totals may exist only when every '
      'ingredient resolved to the verified pack';
}

/// Refused because the ingredient list is longer than one dish.
class TooManyIngredients implements Exception {
  const TooManyIngredients(this.count);

  final int count;

  @override
  String toString() => 'TooManyIngredients($count > $kMaxMealIngredients)';
}

abstract class CoachMealRepository {
  /// W06's picker. Newest first, capped — no ranking of any kind.
  Future<List<CoachMeal>> meals({int limit = 50});

  Future<CoachMeal?> byId(String mealId);

  Future<void> save(CoachMeal meal);

  Future<void> delete(String mealId);
}

class InMemoryCoachMealRepository implements CoachMealRepository {
  InMemoryCoachMealRepository({List<CoachMeal> meals = const <CoachMeal>[]}) {
    for (final meal in meals) {
      _store[meal.mealId] = meal;
    }
  }

  final Map<String, CoachMeal> _store = <String, CoachMeal>{};

  int reads = 0;
  int writes = 0;

  @override
  Future<List<CoachMeal>> meals({int limit = 50}) async {
    final all = _store.values.toList()
      ..sort((a, b) {
        final left = a.updatedAt;
        final right = b.updatedAt;
        if (left == null && right == null) return 0;
        if (left == null) return 1;
        if (right == null) return -1;
        return right.compareTo(left);
      });
    final page = all.take(limit).toList(growable: false);
    reads += page.length;
    return page;
  }

  @override
  Future<CoachMeal?> byId(String mealId) async {
    final found = _store[mealId];
    if (found != null) reads += 1;
    return found;
  }

  @override
  Future<void> save(CoachMeal meal) async {
    if (meal.ingredients.length > kMaxMealIngredients) {
      throw TooManyIngredients(meal.ingredients.length);
    }

    final wire = meal.toWire();
    final nutrition = wire['nutrition']! as Map<String, Object?>;
    final resolved = nutrition['resolved'] == true;
    final carriesFigures =
        nutrition.containsKey('kcal') || nutrition.containsKey('proteinG');
    if (!resolved && carriesFigures) throw const UnverifiedNutritionStored();
    // And the claim itself has to be true: a `resolved:true` on a meal with an
    // unresolved line is the same lie with the flag flipped instead.
    if (resolved && meal.unresolvedIngredients.isNotEmpty) {
      throw const UnverifiedNutritionStored();
    }

    _store[meal.mealId] = meal;
    writes += 1;
  }

  @override
  Future<void> delete(String mealId) async {
    _store.remove(mealId);
    writes += 1;
  }

  Map<String, CoachMeal> get contents =>
      Map<String, CoachMeal>.unmodifiable(_store);
}
