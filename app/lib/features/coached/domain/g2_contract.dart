/// **The cross-group contract this feature is built against, stated in full.**
///
/// G11 §7.3 lists seven fields it *requests* of G2 and does not add. Its own
/// words: without them "these screens are fiction". None of them exist in the
/// codebase today — `lib/features/train/domain/train_repository.dart` has
/// `PlannedMove` with no coach note, no rest seconds and no approved
/// alternatives, and `lib/features/eat/domain/meal_repository.dart` says
/// plainly that `assignment.meal == null` for the whole current cut.
///
/// So this file is the contract, written down where it can be reconciled later
/// rather than assumed. **It reaches into no other feature's folder.** The
/// types here are this feature's own view of a published coached plan; the day
/// G2 publishes the real ones, this file is what the reconciliation is against.
///
/// ## The seven fields, and the screen that is fiction without each
///
/// | Contract member | G2 field requested | Screen |
/// |---|---|---|
/// | [AssignedWorkout.coachNote] | `assignments.workout.coachNote` | G06 — "her note" |
/// | [AssignedMove.coachNote] | `moves[].coachNote` | G06 — the note on the move |
/// | [AssignedMove.restSec] | `moves[].restSec` | G07 — *her* rest seconds, not a default |
/// | [AssignedMove.alternatives] | `moves[].alternatives[]` | G08 — approved before she asks |
/// | [MealAssignment] | `assignments.meal{slots, items[]}` | G10, G11 |
/// | [NutritionAssignment.proteinTargetG] | `assignments.nutrition.proteinTargetG` | G11's protein bar |
/// | [PlanVersion.calendar] | `versions/{v}.calendar[30]` | G05 — **one read instead of thirty** |
///
/// ## Two properties the types enforce rather than document
///
///  1. **A prescription is never a result.** [AssignedMove.sets] is a list of
///     G4's `PrescribedSet`, which has no field capable of holding what she
///     did. This file adds nothing that could carry an outcome, so nothing in
///     a published coached plan can be mistaken for a record of work done.
///  2. **The calendar is exactly thirty.** [PlanVersion] throws when it is not.
///     The whole reason the field exists is that G05 must cost one read rather
///     than thirty; a short or absent calendar that silently fell back to a
///     day-by-day read would restore the thirty reads without anyone noticing,
///     which is the defect this field was requested to prevent.
library;

import 'package:meta/meta.dart';

import '../../../domain/training/prescribed_set.dart';
import '../../eat/domain/meal_repository.dart' show MealSlot;

/// What a day of a published coached plan is.
///
/// `free` is a day the coach deliberately left to her — distinct from `rest`,
/// which she planned, and distinct from an absent day, which is an error rather
/// than a meaning. G05 renders all three differently.
enum PlanDayKind { train, rest, free }

/// One coach-approved substitution, travelling **with the assignment**.
///
/// It travels with the assignment rather than being fetched, which is what
/// makes G08 work with no signal (`P2-OFF-G08`) and what makes "approved first,
/// ask second" true: she is never waiting for a reply mid-session.
@immutable
class ApprovedAlternative {
  const ApprovedAlternative({
    required this.exerciseId,
    required this.name,
    required this.reason,
  });

  final String exerciseId;

  /// "Box squat to a chair".
  final String name;

  /// Why the coach approved it — "same muscles, less depth".
  final String reason;

  @override
  String toString() => 'ApprovedAlternative($exerciseId)';
}

/// A move inside an assigned workout.
///
/// [restSec] is nullable and **null means the coach did not set one**, never
/// "zero seconds" and never "use the app's default". G07 says "Sara set 45
/// seconds between these sets"; it may only say that when she did.
@immutable
class AssignedMove {
  const AssignedMove({
    required this.exerciseId,
    required this.name,
    required this.sets,
    this.coachNote,
    this.restSec,
    this.alternatives = const <ApprovedAlternative>[],
  });

  final String exerciseId;
  final String name;

  /// What was asked for. No member of [PrescribedSet] can hold a result.
  final List<PrescribedSet> sets;

  /// `moves[].coachNote` — her words about this move, shown on G06.
  final String? coachNote;

  /// `moves[].restSec` — hers, not a default. Null when she set none.
  final int? restSec;

  /// `moves[].alternatives[]` — approved in advance.
  final List<ApprovedAlternative> alternatives;

  @override
  String toString() => 'AssignedMove($exerciseId, ${sets.length} sets)';
}

/// `assignments.workout` for a coached client.
@immutable
class AssignedWorkout {
  const AssignedWorkout({
    required this.title,
    required this.moves,
    this.summary = '',
    this.coachNote,
  });

  /// "Full-body strength".
  final String title;

  /// "35 min".
  final String summary;

  /// `assignments.workout.coachNote` — the note at the top of G06.
  final String? coachNote;

  final List<AssignedMove> moves;

  @override
  String toString() => 'AssignedWorkout($title, ${moves.length} moves)';
}

/// One item the coach planned into a slot.
///
/// Either a `foodId` or a `recipeId`, never both and never neither — the
/// constructor refuses the other two combinations, because an item that is
/// neither is a row G10 would have to render as an apology.
@immutable
class AssignedMealItem {
  AssignedMealItem({
    required this.servings,
    required this.sizeId,
    this.foodId,
    this.recipeId,
    this.coachNote,
    this.alternatives = const <String>[],
  }) {
    if ((foodId == null) == (recipeId == null)) {
      throw ArgumentError(
        'An assigned meal item is exactly one of a food or a recipe.',
      );
    }
  }

  final String? foodId;
  final String? recipeId;

  final num servings;

  /// A size id from the food's own `sizes[]`. Never a gram figure she did not
  /// choose — G5 owns quantities and this contract does not widen that.
  final String sizeId;

  /// "Add the salad if you are still hungry after."
  final String? coachNote;

  /// Other food ids she may have instead.
  final List<String> alternatives;

  @override
  String toString() => 'AssignedMealItem(${foodId ?? recipeId} ×$servings)';
}

/// `assignments.meal{slots, items[]}`.
@immutable
class MealAssignment {
  const MealAssignment({
    this.slots = const <MealSlot, List<AssignedMealItem>>{},
  });

  /// Slot → the items the coach planned into it. An absent slot is a slot she
  /// left free; an empty list is a slot she explicitly emptied. Both render,
  /// and they do not render the same.
  final Map<MealSlot, List<AssignedMealItem>> slots;

  List<AssignedMealItem> itemsIn(MealSlot slot) =>
      slots[slot] ?? const <AssignedMealItem>[];

  bool get isEmpty => slots.values.every((items) => items.isEmpty);

  @override
  String toString() => 'MealAssignment(${slots.keys.map((s) => s.name)})';
}

/// `assignments.nutrition`.
///
/// G11 §7.2: for a **coached** client the coach authors the protein target at
/// her own planning screen, which resolves half of G5's open question. For a
/// self-serve woman it remains unowned, which is why this is nullable and why
/// `DayTotals` keeps its provisional target for everyone else.
@immutable
class NutritionAssignment {
  const NutritionAssignment({this.proteinTargetG});

  final int? proteinTargetG;

  @override
  String toString() => 'NutritionAssignment($proteinTargetG g)';
}

/// One day of a published coached plan: `plans/{uid}/assignments/{yyyy-MM-dd}`.
///
/// **Absence means rest, never an error and never a spinner** — G2's rule,
/// inherited verbatim. So a null assignment is a legitimate answer from the
/// repository and every screen here treats it as one.
@immutable
class CoachAssignment {
  const CoachAssignment({
    required this.dateKey,
    required this.planVersion,
    this.workout,
    this.meal,
    this.nutrition = const NutritionAssignment(),
  });

  /// `yyyy-MM-dd`, in her timezone.
  final String dateKey;

  /// The version this day was published under. Pinned at session start and
  /// never re-read, so a revision published mid-session changes nothing that is
  /// running.
  final String planVersion;

  final AssignedWorkout? workout;
  final MealAssignment? meal;
  final NutritionAssignment nutrition;

  @override
  String toString() => 'CoachAssignment($dateKey @$planVersion)';
}

/// `plans/{uid}/versions/{v}` — the document G05 reads, once.
///
/// [calendar] is the **whole reason this type is in the contract**: thirty
/// entries in one document, so the month view is one read rather than thirty.
@immutable
class PlanVersion {
  PlanVersion({
    required this.version,
    required this.calendar,
    required this.publishedAt,
    required this.effectiveFrom,
    required this.startsOn,
    this.authorUid,
    this.source = 'coach',
  }) {
    if (calendar.length != calendarLength) {
      throw ArgumentError.value(
        calendar.length,
        'calendar',
        'A coached plan version carries exactly $calendarLength days. A short '
            'calendar would silently send G05 back to one read per day, which '
            'is the cost this field exists to remove.',
      );
    }
  }

  /// Thirty days, because a coached engagement is thirty days.
  static const int calendarLength = 30;

  final String version;

  /// `versions/{v}.calendar[30]`.
  final List<PlanDayKind> calendar;

  /// When the coach published it. `PlanUpdateCard` compares against this and
  /// against nothing else.
  final DateTime publishedAt;

  /// The first date it applies to. A revision defaults to future dates.
  final DateTime effectiveFrom;

  /// Day 1 of the engagement, so a calendar index maps to a date.
  final DateTime startsOn;

  /// `authorUid` is the coach for a coached plan.
  final String? authorUid;

  /// `source:'coach'` — G2 reserved this shape; this feature exercises it.
  final String source;

  /// The kind of day at [dayNumber] (1-based, as she reads it).
  PlanDayKind dayAt(int dayNumber) {
    if (dayNumber < 1 || dayNumber > calendarLength) {
      throw RangeError.range(dayNumber, 1, calendarLength, 'dayNumber');
    }
    return calendar[dayNumber - 1];
  }

  @override
  String toString() => 'PlanVersion($version, from $effectiveFrom)';
}
