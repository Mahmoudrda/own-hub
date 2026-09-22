/// K26 and K27's boundary — G14 §7.7. **The assistant cannot publish.**
///
/// The screens are G15's; this is the gate they hand a draft through, and
/// `P0-PUB-02` checks all four of its properties:
///
///  1. Anything whose status is not `draft` is rejected — **there is no publish
///     tool and none is exposed here**.
///  2. Every `exerciseId` is re-validated against G4's pack and every `foodId`
///     against G5's. An id outside the packs is dropped, never rendered.
///  3. `ExerciseCandidateFilter` and `AllergyGuard` are re-run against her
///     constraints. Server-side filtering is not trusted as the last word,
///     because the draft may have been produced before the latest assessment
///     was recorded.
///  4. The result is written with `origin: 'assistant'` and `status: 'draft'`.
///     The coach opens W03 or W06 and publishes herself, or does not.
///
/// §2.10, at its sharpest: a planner selects, it never generates. Everything
/// arriving from a model is a *proposal about ids*, and an id that is not in
/// the pack is not a food or a move — it is a token that would render as one.
library;

import 'package:meta/meta.dart';

import '../../../domain/safety/client_constraints.dart';
import '../../../domain/safety/exercise_candidate_filter.dart';
import '../../eat/domain/food_library.dart';
import 'meal/meal_slot_planner.dart';
import 'plan/plan_draft.dart';
import 'prescription.dart';
import 'split/split_applicator.dart';

/// What the assistant hands over.
@immutable
class AssistantDraft {
  AssistantDraft({
    required this.clientUid,
    required this.month,
    required Map<String, PlanDay> days,
    this.status = 'draft',
  }) : days = Map<String, PlanDay>.unmodifiable(days);

  final String clientUid;
  final String month;
  final Map<String, PlanDay> days;

  /// A string on purpose: it is whatever arrived, and the gate's first job is
  /// to refuse anything that is not the one word it accepts.
  final String status;
}

/// Refused because something arrived claiming to be more than a draft.
class AssistantDraftNotADraft implements Exception {
  const AssistantDraftNotADraft(this.status);

  final String status;

  @override
  String toString() =>
      'AssistantDraftNotADraft("$status") — there is no publish tool, and '
      'nothing the assistant produces may arrive as anything but a draft';
}

/// What the gate dropped, so a screen can be honest about it.
@immutable
class AssistantIntakeReport {
  AssistantIntakeReport({
    required this.draft,
    Set<String> droppedExerciseIds = const <String>{},
    Set<String> droppedFoodIds = const <String>{},
  }) : droppedExerciseIds = Set<String>.unmodifiable(droppedExerciseIds),
       droppedFoodIds = Set<String>.unmodifiable(droppedFoodIds);

  /// Always `status: draft`, always `origin: assistant`.
  final PlanDraft draft;

  final Set<String> droppedExerciseIds;
  final Set<String> droppedFoodIds;

  bool get droppedSomething =>
      droppedExerciseIds.isNotEmpty || droppedFoodIds.isNotEmpty;
}

/// The gate.
class AssistantDraftIntake {
  const AssistantDraftIntake({
    required this.constraints,
    required this.catalogue,
    required this.safety,
  });

  final ClientConstraints constraints;

  /// G4's pack. Null for an id it does not contain.
  final MoveCatalogue catalogue;

  /// G5's pack and her allergies, for the meal half.
  final MealSafety safety;

  /// Accepts [incoming] into a draft, or throws.
  AssistantIntakeReport accept(
    AssistantDraft incoming, {
    required String coachUid,
  }) {
    if (incoming.status != PlanDraftStatus.draft.wireName) {
      throw AssistantDraftNotADraft(incoming.status);
    }

    final droppedMoves = <String>{};
    final droppedFoods = <String>{};
    final days = <String, PlanDay>{};

    for (final entry in incoming.days.entries) {
      var day = entry.value;

      final workout = day.workout;
      if (workout != null) {
        day = day.withWorkout(
          workout.withMoves(_screenMoves(workout.moves, droppedMoves)),
        );
      }

      final meal = day.meal;
      if (meal != null) {
        day = day.withMeal(_screenMeals(meal, droppedFoods));
      }

      days[entry.key] = day;
    }

    return AssistantIntakeReport(
      draft: PlanDraft(
        clientUid: incoming.clientUid,
        coachUid: coachUid,
        month: incoming.month,
        days: days,
        // Both stated, and neither is a parameter the assistant can set.
        origin: DraftOrigin.assistant,
        status: PlanDraftStatus.draft,
      ),
      droppedExerciseIds: droppedMoves,
      droppedFoodIds: droppedFoods,
    );
  }

  /// Ids checked against the pack, then the survivors screened again.
  List<PrescribedMove> _screenMoves(
    List<PrescribedMove> moves,
    Set<String> dropped,
  ) {
    final candidates = <ScreenableExercise>[];
    for (final move in moves) {
      final known = catalogue(move.exerciseId);
      if (known == null) {
        dropped.add(move.exerciseId);
        continue;
      }
      candidates.add(known);
    }

    final allowed = <String>{
      for (final survivor in ExerciseCandidateFilter(
        constraints,
      ).screen(candidates))
        survivor.exerciseId,
    };

    final kept = <PrescribedMove>[];
    var order = 1;
    for (final move in moves) {
      if (!allowed.contains(move.exerciseId)) {
        dropped.add(move.exerciseId);
        continue;
      }
      kept.add(
        PrescribedMove(
          exerciseId: move.exerciseId,
          order: order++,
          sets: move.sets,
          load: move.load,
          reps: move.reps,
          holdSeconds: move.holdSeconds,
          note: move.note,
        ),
      );
    }
    return kept;
  }

  /// The same treatment for food: an id the pack does not carry is not a food.
  ///
  /// A slot emptied by this is left **null** — a gap W06 counts — rather than
  /// quietly becoming a free choice. "She chooses" is an answer somebody gave;
  /// this is the absence of one.
  DraftMealDay _screenMeals(DraftMealDay meal, Set<String> dropped) {
    final planner = MealSlotPlanner(safety);
    var cleaned = meal;

    for (final slot in PlanMealSlot.values) {
      final assignment = meal.slots[slot];
      if (assignment == null || assignment.source != MealSlotSource.library) {
        continue;
      }

      final kept = <String>[];
      for (final foodId in assignment.foodIds) {
        final food = safety.foods(foodId);
        if (food == null) {
          dropped.add(foodId);
          continue;
        }
        if (planner.offerable(<Food>[food]).isEmpty) {
          dropped.add(foodId);
          continue;
        }
        kept.add(foodId);
      }

      cleaned = cleaned.withSlot(
        slot,
        kept.isEmpty
            ? null
            : MealSlotAssignment.fromLibrary(
                foodIds: kept,
                servings: assignment.servings,
                note: assignment.note,
              ),
      );
    }
    return cleaned;
  }
}
