/// Y07's meals: up to three of Rahma's recipes, picked from today's check-in.
///
/// The only inputs are today's [TodayCheckIn] and the recipes the allergy guard
/// has already let through. A woman who logged low energy or cramps is offered
/// her comfy dinners first and the high-protein recipes after them; every other
/// check-in, and no check-in, picks nothing. The reason written on a card names
/// what she logged and the tags the recipe really carries, and nothing else.
///
/// There is no date, cycle day or estimate anywhere in here, by the rule
/// `today_check_in.dart` sets out: what she eats is never decided by where a
/// calendar says she is.
library;

import 'package:meta/meta.dart';

import '../../eat/domain/recipe.dart';
import 'today_check_in.dart';

/// What she logged today that picks the meals.
enum MealSignal { lowEnergy, cramps, both }

/// Why a recipe is on the card, in the tags it really has.
enum MealTags { comfyAndProtein, comfy, protein }

@immutable
class MealPick {
  const MealPick({
    required this.recipe,
    required this.signal,
    required this.tags,
  });

  final Recipe recipe;
  final MealSignal signal;
  final MealTags tags;
}

/// Her comfy dinners, in Rahma's book.
const String kComfyDinnerSection = 'comfy_dinner';

/// The recipe tag that says a dish is high in protein.
const String kHighProteinTag = 'high_protein';

/// The most cards Y07 shows.
const int kMealPickCap = 3;

/// What today's check-in says, or null when it picks nothing.
MealSignal? mealSignalOf(TodayCheckIn checkIn) {
  final low = checkIn.energy == Energy.low;
  final cramps = checkIn.cramps != null && checkIn.cramps != Cramps.none;
  if (low && cramps) return MealSignal.both;
  if (low) return MealSignal.lowEnergy;
  if (cramps) return MealSignal.cramps;
  return null;
}

/// Up to [kMealPickCap] of [recipes], best first. [recipes] must already have
/// been through the allergy guard.
List<MealPick> mealsForToday(TodayCheckIn checkIn, Iterable<Recipe> recipes) {
  final signal = mealSignalOf(checkIn);
  if (signal == null) return const <MealPick>[];

  final picks = <MealPick>[];
  for (final recipe in recipes) {
    // These are her picks from her book. Own Hub's recipes sit in the same
    // sections and are not hers, so they are not offered as hers here.
    if (recipe.isOwnHub) continue;
    final comfy = recipe.sectionId == kComfyDinnerSection;
    final protein = recipe.dietTags.contains(kHighProteinTag);
    if (!comfy && !protein) continue;
    picks.add(
      MealPick(
        recipe: recipe,
        signal: signal,
        tags: comfy
            ? (protein ? MealTags.comfyAndProtein : MealTags.comfy)
            : MealTags.protein,
      ),
    );
  }
  // Comfy and high-protein first, then comfy, then high-protein. A stable sort
  // keeps the book's own order inside each.
  int rank(MealPick p) => p.tags.index;
  final indexed = [for (var i = 0; i < picks.length; i++) (i, picks[i])]
    ..sort((a, b) {
      final byRank = rank(a.$2).compareTo(rank(b.$2));
      return byRank != 0 ? byRank : a.$1.compareTo(b.$1);
    });
  return [for (final e in indexed.take(kMealPickCap)) e.$2];
}
