/// Measuring a portion in the unit she thinks in, without inventing a weight.
///
/// Every unit is turned into grams and the figures are scaled from the food's
/// own weighed size (`Food.sizeForGrams`). A food whose pack gives no weight
/// offers no units at all, so nothing here ever guesses a gram figure.
///
/// The conversions, from per-100 g figures:
///   * 1 oz is 28.35 g.
///   * Millilitres equal grams for drinks and soups (density 1).
///   * A cup is 240 ml for drinks and soups, and a typical weight for the
///     dish's category otherwise. That one is approximate, and says so.
///   * A piece and a serving are the medium size. A piece is approximate.
library;

import 'food_library.dart';

enum FoodUnit { g, oz, ml, cup, piece, serving }

/// The most she may enter for one portion, in grams.
const int kMaxPortionGrams = 9999;

class FoodUnits {
  const FoodUnits._();

  static const double gramsPerOunce = 28.35;
  static const double millilitresPerCup = 240;

  /// What a cup of a solid dish weighs, by the pack's category. A category not
  /// listed (bread, sandwiches) has no cup.
  static const Map<String, int> cupGramsByCategory = {
    'main': 200,
    'breakfast': 180,
    'side': 150,
    'salad': 100,
    'sweet': 150,
    'cheese': 110,
  };

  static bool isLiquid(Food food) =>
      food.category == 'drink' || food.category == 'soup';

  /// The units this food can be measured in, in the order the picker shows
  /// them. Empty when its weight is unknown.
  static List<FoodUnit> availableFor(Food food) {
    if (food.weighedSize == null) return const <FoodUnit>[];
    return [
      FoodUnit.g,
      FoodUnit.oz,
      if (isLiquid(food)) FoodUnit.ml,
      if (isLiquid(food) || cupGramsByCategory.containsKey(food.category))
        FoodUnit.cup,
      FoodUnit.piece,
      FoodUnit.serving,
    ];
  }

  /// Grams in one [unit] of [food], or null when the food cannot be measured
  /// that way.
  static double? gramsPerUnit(Food food, FoodUnit unit) {
    final base = food.weighedSize?.grams;
    if (base == null) return null;
    switch (unit) {
      case FoodUnit.g:
        return 1;
      case FoodUnit.oz:
        return gramsPerOunce;
      case FoodUnit.ml:
        return isLiquid(food) ? 1 : null;
      case FoodUnit.cup:
        if (isLiquid(food)) return millilitresPerCup;
        return cupGramsByCategory[food.category]?.toDouble();
      case FoodUnit.piece:
      case FoodUnit.serving:
        return base.toDouble();
    }
  }

  /// True where the weight behind the unit is an estimate, so the sheet says
  /// "about".
  static bool isApproximate(Food food, FoodUnit unit) => switch (unit) {
    FoodUnit.piece => true,
    FoodUnit.cup => !isLiquid(food),
    _ => false,
  };

  /// The whole grams in [amount] of [unit], or null when the unit does not
  /// apply or the amount is not a positive number within the limit.
  static int? gramsFor(Food food, FoodUnit unit, double amount) {
    final per = gramsPerUnit(food, unit);
    if (per == null || !amount.isFinite || amount <= 0) return null;
    final grams = (per * amount).round();
    if (grams < 1 || grams > kMaxPortionGrams) return null;
    return grams;
  }

  /// The portion for [amount] of [unit], or null as for [gramsFor].
  static FoodSize? sizeFor(Food food, FoodUnit unit, double amount) {
    final grams = gramsFor(food, unit, amount);
    return grams == null ? null : food.sizeForGrams(grams);
  }

  /// What to put in the amount box when a unit is picked: the medium size for
  /// the weight units, one for the counting units.
  static double startingAmount(Food food, FoodUnit unit) {
    final base = food.weighedSize?.grams ?? 100;
    return switch (unit) {
      FoodUnit.g || FoodUnit.ml => base.toDouble(),
      _ => 1,
    };
  }

  /// [grams] expressed in [unit], to one decimal below ten. Used to show the
  /// amount of a portion she chose earlier.
  static double amountFromGrams(Food food, FoodUnit unit, int grams) {
    final per = gramsPerUnit(food, unit) ?? 1;
    final value = grams / per;
    return value >= 10 ? value.roundToDouble() : (value * 10).round() / 10;
  }
}
