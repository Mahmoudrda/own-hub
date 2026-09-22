/// Logging the meal her coach planned — G10 and G11.
///
/// This is G5's logging path with the coach's item in it. **Nothing here is a
/// second food diary**: the write is a `MealWrite` built by `MealLogService`,
/// the id is `plannedItemId(...)` so re-logging corrects rather than doubles,
/// and the guard is `AllergyGuard` — the same instance G5 uses, not a copy.
///
/// > A safety rule with two implementations has one that is weaker.
///
/// So this file contains **no allergen logic of its own**. It resolves the
/// coach's item against the food pack, hands it to G5, and turns G5's refusal
/// into something G10 can render. If the guard says no, this returns the
/// refusal unchanged rather than interpreting it.
///
/// ## The interlock G11 §2 asks for
///
/// `P0-INTAKE-03`: a conflicting meal should be refused at publish time; if one
/// ever arrives anyway, "the planned row is disabled with its reason at G10 and
/// the log is blocked behind an explicit acknowledgement". [screenAssignment]
/// is the first half — it marks each planned row blocked or clear *before* she
/// taps — and [logPlanned] is the second: it refuses the write and names what
/// is outstanding.
///
/// `P0-INTAKE-04`: with no profile yet, `DietaryConstraints.unknown` makes the
/// guard fail closed, and a blocked row stays blocked until she acknowledges.
/// Unknown is not absent, and this file adds no default that would make it so.
library;

import 'package:meta/meta.dart';

import '../../eat/domain/allergy_guard.dart';
import '../../eat/domain/food_library.dart';
import '../../eat/domain/meal_log_service.dart';
import '../../eat/domain/meal_repository.dart';
import '../../eat/domain/meal_sentence_parser.dart';
import '../../eat/domain/meal_slot_state_machine.dart';
import 'g2_contract.dart';

/// One planned row as G10 renders it.
@immutable
class PlannedRow {
  const PlannedRow({
    required this.slot,
    required this.index,
    required this.item,
    required this.food,
    required this.assessment,
    this.coachNote,
  });

  final MealSlot slot;

  /// Position in the slot, so the deterministic item id can be rebuilt.
  final int index;

  final AssignedMealItem item;

  /// Null when the coach's item is not in the signed pack. §2 rule 10: the
  /// product does not log a food it cannot name, and it does not invent one.
  final Food? food;

  /// G5's verdict for this row, computed before she taps anything.
  final AllergyAssessment assessment;

  /// "Add the salad if you are still hungry after."
  final String? coachNote;

  /// Whether the row must be disabled with a reason.
  bool get isBlocked => food == null || assessment.isBlocked;

  /// The allergens to name on the sheet, empty when there is nothing to name.
  Set<String> get allergens => assessment.allergens;

  @override
  String toString() =>
      'PlannedRow(${slot.name}#$index ${food?.foodId ?? 'unknown'}'
      '${isBlocked ? ' blocked' : ''})';
}

/// Turns a coach's meal assignment into rows, and rows into G5 writes.
class PlannedMealService {
  const PlannedMealService({
    required this.library,
    required this.guard,
    required this.logs,
  });

  final FoodLibrary library;

  /// G5's guard. **Required, never defaulted** — whether her allergies are
  /// known is a fact the caller has to state out loud, and both possible
  /// defaults are wrong in a different way.
  final AllergyGuard guard;

  /// G5's write builder. Every log this feature makes goes through it.
  final MealLogService logs;

  /// The rows for one slot, screened before anything is offered.
  ///
  /// Screening happens here rather than after ranking because a conflicting
  /// dish shown and then removed is how the filter gets "fixed" by being moved
  /// later. There is no ranking on this screen at all — the coach chose the
  /// order — so screening is simply first.
  List<PlannedRow> screenAssignment(
    MealAssignment assignment,
    MealSlot slot, {
    Set<String> acknowledged = const <String>{},
  }) {
    final items = assignment.itemsIn(slot);
    final rows = <PlannedRow>[];
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final food = item.foodId == null ? null : library.byId(item.foodId!);
      rows.add(
        PlannedRow(
          slot: slot,
          index: i,
          item: item,
          food: food,
          assessment: food == null
              ? AllergyAssessment.clear
              : guard.assess(food, acknowledged: acknowledged),
          coachNote: item.coachNote,
        ),
      );
    }
    return rows;
  }

  /// Builds the write for "Ate this".
  ///
  /// Returns G5's own [MealLogOutcome]: a `MealLogPrepared` to hand to the undo
  /// bus, or a `MealLogRefused` carrying the guard's verdict. This method does
  /// not inspect the refusal and does not soften it.
  ///
  /// Logging the same planned row twice **corrects** it — the item id is
  /// derived from the assignment, the slot and the index, so the slot holds one
  /// item before and one after. Tapping twice cannot create a second log.
  MealLogOutcome logPlanned({
    required MealDay day,
    required PlannedRow row,
    required String assignmentId,
    required DateTime at,
    int? servings,
    String? sizeId,
    Set<String> acknowledged = const <String>{},
  }) {
    final food = row.food;
    if (food == null) {
      return const MealLogRefused(LogRefusal(LogRefusalReason.foodNotInPack));
    }

    final size = food.sizeById(sizeId ?? row.item.sizeId) ?? food.sizes.first;

    return logs.correctPlannedLog(
      day: day,
      planRef: PlanRef(
        assignmentId: assignmentId,
        slot: row.slot,
        idx: row.index,
      ),
      entry: ParsedItem(
        food: food,
        size: size,
        servings: servings ?? row.item.servings.round(),
        sourceText: food.names.isEmpty ? food.foodId : food.names.first,
      ),
      at: at,
      acknowledged: acknowledged,
    );
  }

  /// A deliberate second helping.
  ///
  /// A **separate method**, as it is in G5. There is no
  /// `logPlanned(..., {bool asHelping})`, because a boolean there is exactly
  /// how a correction and a helping collapse into one path and a serving
  /// silently doubles.
  MealLogOutcome addHelping({
    required MealDay day,
    required MealSlot slot,
    required MealItem of,
    required DateTime at,
    Set<String> acknowledged = const <String>{},
  }) => logs.addHelping(
    day: day,
    slot: slot,
    of: of,
    at: at,
    acknowledged: acknowledged,
  );

  /// The protein target for the day: the coach's when she set one, otherwise
  /// whatever G5's totals already use.
  ///
  /// Returns null when the coach set none, so the caller keeps G5's provisional
  /// figure rather than this feature inventing a target.
  int? proteinTargetFor(CoachAssignment? assignment) =>
      assignment?.nutrition.proteinTargetG;
}
