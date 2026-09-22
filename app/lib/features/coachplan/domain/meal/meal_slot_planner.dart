/// W06 — allergies before selection, on the coach's screen. G14 §5.2.
///
/// > W06's picker is built from `AllergyGuard.screen(clientConstraints)` — **the
/// > client's constraints, not the coach's**. A conflicting food is therefore
/// > never offered.
///
/// `AllergyGuard` is reused unchanged. A safety rule with two implementations
/// has one that is weaker, and the weaker one is always the copy.
///
/// ## The coach may not override an allergy
///
/// G5 gives *her* an override, because she is the authority on her own body.
/// A coach is not. So [assess] here calls `AllergyGuard.assess` with **no**
/// acknowledgement argument and there is no parameter to pass one through:
/// prescribing around somebody else's allergy is not hers to override, and the
/// refusal names the allergen so the screen can say which one.
///
/// `P0-MEAL-02` is the case this exists for — a slot filled before the allergy
/// was recorded. The picker cannot help there, because the slot arrived before
/// the constraint did. The write path can, and does.
library;

import 'package:meta/meta.dart';

import '../../../../domain/safety/client_constraints.dart';
import '../../../eat/domain/allergy_guard.dart';
import '../../../eat/domain/food_library.dart';
import '../plan/plan_draft.dart';
import 'coach_meal.dart';

// `CoachMealResolver` moved next to `CoachMeal` when the publisher needed it
// too. Re-exported so every existing caller of this file still sees one name
// for one signature.
export 'coach_meal.dart' show CoachMealResolver;

/// Looks a food up in G5's verified pack.
typedef FoodResolver = Food? Function(String foodId);

/// Everything the write path needs to judge a meal slot.
///
/// Held as one object so a repository cannot be constructed with half of it —
/// constraints without a pack resolves every food to "unknown", which blocks
/// correctly but for the wrong reason and would be diagnosed as a content bug.
@immutable
class MealSafety {
  const MealSafety({
    required this.constraints,
    required this.foods,
    this.coachMeals,
  });

  final ClientConstraints constraints;
  final FoodResolver foods;
  final CoachMealResolver? coachMeals;

  DietaryConstraints get dietary => DietaryConstraints(
    allergies: constraints.allergies,
    dietary: constraints.dietary,
  );
}

/// A slot that may not be written, and why.
@immutable
class BlockedMealSlot {
  const BlockedMealSlot({
    required this.dayKey,
    required this.slot,
    required this.reason,
    this.allergens = const <String>{},
    this.foodId,
  });

  final String dayKey;
  final PlanMealSlot slot;
  final AllergyBlockReason reason;

  /// Named when there is something to name. Empty for the two unknown cases,
  /// because naming a specific allergen there would state something nobody
  /// knows.
  final Set<String> allergens;

  final String? foodId;

  @override
  String toString() =>
      'BlockedMealSlot($dayKey/${slot.wireName}, ${reason.name}, $allergens)';
}

/// Thrown by the write path. Carries the first block, and all of them.
class AllergenInPlan implements Exception {
  AllergenInPlan(List<BlockedMealSlot> blocked)
    : blocked = List<BlockedMealSlot>.unmodifiable(blocked);

  final List<BlockedMealSlot> blocked;

  BlockedMealSlot get first => blocked.first;

  @override
  String toString() =>
      'AllergenInPlan(${blocked.length} slot(s); first: $first) — a coach may '
      'not prescribe around a woman\'s allergy';
}

/// Builds W06's candidate lists, and judges a draft before it is written.
class MealSlotPlanner {
  const MealSlotPlanner(this.safety);

  final MealSafety safety;

  /// What may be offered for a slot. Filtered at the source.
  ///
  /// Order is preserved: screening is not a ranking.
  List<Food> offerable(Iterable<Food> candidates) =>
      AllergyGuard(safety.dietary).screen(candidates);

  /// The coach's own meals that may be offered — every ingredient screened.
  ///
  /// A meal is offered only when *all* of its resolvable foods pass. One
  /// conflicting ingredient makes the dish conflicting; there is no partial
  /// offer, because a coach cannot un-cook the nuts out of it.
  List<CoachMeal> offerableMeals(Iterable<CoachMeal> meals) => <CoachMeal>[
    for (final meal in meals)
      if (_mealIsClear(meal)) meal,
  ];

  bool _mealIsClear(CoachMeal meal) {
    final guard = AllergyGuard(safety.dietary);
    for (final foodId in meal.foodIds) {
      final food = safety.foods(foodId);
      // Unknown is unsafe: a dish built from something the pack does not know
      // cannot be declared clear.
      if (food == null) return false;
      if (guard.assess(food).isBlocked) return false;
    }
    // An unresolved ingredient means nobody has said what is in it.
    return meal.unresolvedIngredients.isEmpty;
  }

  /// Every slot in [draft] that may not be written.
  ///
  /// Returns a list rather than the first hit, so W06 can mark all the blocked
  /// slots at once rather than sending a coach round a loop fixing them one at
  /// a time.
  List<BlockedMealSlot> blockedSlots(PlanDraft draft) {
    final guard = AllergyGuard(safety.dietary);
    final blocked = <BlockedMealSlot>[];

    for (final entry in draft.days.entries) {
      final meal = entry.value.meal;
      if (meal == null) continue;
      for (final slotEntry in meal.slots.entries) {
        final assignment = slotEntry.value;
        if (assignment == null || assignment.isFreeChoice) continue;

        for (final foodId in _foodIdsOf(assignment)) {
          final food = safety.foods(foodId);
          if (food == null) {
            blocked.add(
              BlockedMealSlot(
                dayKey: entry.key,
                slot: slotEntry.key,
                reason: AllergyBlockReason.unknownAllergenData,
                foodId: foodId,
              ),
            );
            continue;
          }
          // No `acknowledged` argument exists to pass. See the library note.
          final assessment = guard.assess(food);
          if (assessment.isBlocked) {
            blocked.add(
              BlockedMealSlot(
                dayKey: entry.key,
                slot: slotEntry.key,
                reason: assessment.reason!,
                allergens: assessment.allergens,
                foodId: foodId,
              ),
            );
          }
        }
      }
    }
    return blocked;
  }

  /// Throws [AllergenInPlan] when anything in [draft] conflicts.
  void assertWritable(PlanDraft draft) {
    final blocked = blockedSlots(draft);
    if (blocked.isNotEmpty) throw AllergenInPlan(blocked);
  }

  Set<String> _foodIdsOf(MealSlotAssignment assignment) {
    switch (assignment.source) {
      case MealSlotSource.library:
        return assignment.foodIds.toSet();
      case MealSlotSource.coach:
        final resolver = safety.coachMeals;
        final mealId = assignment.coachMealId;
        if (resolver == null || mealId == null) return <String>{};
        return resolver(mealId)?.foodIds ?? <String>{};
      case MealSlotSource.freeChoice:
        return <String>{};
    }
  }
}
