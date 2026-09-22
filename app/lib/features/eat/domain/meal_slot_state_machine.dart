/// The meal slot's states and the transitions between them — G5 §3.1.
///
/// Two methods, doing two different jobs:
///
///   * [resolve] answers "what does this slot look like right now?", from the
///     stored document. That is what E01 renders.
///   * [next] answers "is this transition legal, and where does it land?", from
///     the table in §3.1. That is what the log service checks before it builds a
///     write.
///
/// They are separate because `corrected` is not a stored state. Nothing in the
/// schema records that an item was edited — and nothing should, because a
/// "was corrected" flag is a field a screen could render as a judgement about
/// her. It is a transition *outcome*, so it lives in [next] and never in
/// [resolve].
///
/// ## Rule 1 lives here
///
/// `planned` renders the prescription and **writes nothing**. `slots.<slot>` is
/// absent until she acts, so a prescribed meal cannot become a result by being
/// displayed. That is the same guarantee `PrescribedSet` gives on the training
/// side, enforced the same way: the planned item is a different object from a
/// logged item, and it has no `loggedAt` to fill in.
///
/// `planned` is **unreachable in the MVP** — G2 publishes `assignment.meal ==
/// null` for the whole cut, so E01 renders the free-log path. It is implemented
/// and tested now so that coaching does not have to retrofit rule 1 onto a
/// shipped logging path later.
library;

import 'package:meta/meta.dart';

import 'allergy_guard.dart';
import 'food_library.dart';
import 'meal_repository.dart';

/// Where a slot is. `queued` is deliberately absent: syncing is an orthogonal
/// flag rendered as a badge on the row (§4.3), not a state of the meal.
enum MealSlotState {
  /// The day document does not exist. E09's branch.
  absent,

  /// The day exists; this slot has nothing in it and nothing planned.
  empty,

  /// An assignment exists. The prescription is shown and nothing is written.
  planned,

  /// She logged something.
  logged,

  /// A logged item was replaced by an edit.
  corrected,

  /// She said she skipped it. Carries no penalty, and is never final.
  skipped,
}

/// What can happen to a slot.
enum MealSlotEvent {
  /// A plan assignment arrived for this slot.
  assignmentArrived,

  /// She logged one or more items into an empty or skipped slot.
  logItems,

  /// She re-logged the planned meal, or edited a logged one.
  correctPlannedLog,

  /// "Another helping" — a second item, not a replacement.
  addHelping,

  /// She skipped the slot.
  skipSlot,

  /// Undo, inside the five seconds. The pending buffer is discarded and **no
  /// write is ever issued**.
  undoPending,

  /// The last item was removed, so the slot is empty again.
  removeLastItem,
}

/// Why a log was refused before any write was built.
enum LogRefusalReason {
  /// There is no day to log into. Guards `absent → logged`.
  noDayContext,

  /// The food is not in the signed pack. §2 rule 10: the product cannot log a
  /// food it cannot name, and it will not invent one.
  foodNotInPack,

  /// An allergen verdict is outstanding and unacknowledged (§5.1).
  allergenOutstanding,
}

/// The refusal, with enough detail for the caller to say why.
@immutable
class LogRefusal {
  const LogRefusal(this.reason, {this.assessment});

  final LogRefusalReason reason;

  /// Present only for [LogRefusalReason.allergenOutstanding].
  final AllergyAssessment? assessment;

  @override
  String toString() => 'LogRefusal(${reason.name})';
}

/// §3.1, as code.
class MealSlotStateMachine {
  const MealSlotStateMachine();

  /// What the slot looks like now.
  ///
  /// [hasAssignment] comes from `plans/{uid}/assignments/{date}.meal`, which is
  /// null for the whole MVP — so this parameter is false everywhere today and
  /// the `planned` branch is exercised only by its tests.
  MealSlotState resolve({
    required MealDay? day,
    required MealSlot slot,
    bool hasAssignment = false,
  }) {
    if (day == null) return MealSlotState.absent;

    final items = day.itemsIn(slot);
    if (items.isNotEmpty) return MealSlotState.logged;

    // Checked after items, because "a skip is never final": logging into a
    // skipped slot makes it logged again.
    if (day.skipped.contains(slot)) return MealSlotState.skipped;

    if (hasAssignment) return MealSlotState.planned;

    // A day document that exists but holds nothing in this slot is `empty`, not
    // `absent`. E09 branches on the whole day being untouched, not on one slot.
    return day.hasNothingLogged && day.skipped.isEmpty
        ? MealSlotState.absent
        : MealSlotState.empty;
  }

  /// The transition table. Throws [StateError] on an illegal transition.
  ///
  /// The one illegal transition worth naming: **`absent → logged`**. A log needs
  /// a day document, and a write that created items without one would produce a
  /// day whose totals nothing ever computed.
  MealSlotState next(MealSlotState from, MealSlotEvent event) {
    switch (event) {
      case MealSlotEvent.assignmentArrived:
        if (from == MealSlotState.absent || from == MealSlotState.empty) {
          return MealSlotState.planned;
        }
        // An assignment arriving for a slot she has already logged changes
        // nothing. It must never un-log her.
        return from;

      case MealSlotEvent.logItems:
        if (from == MealSlotState.absent) {
          throw StateError(
            'absent → logged is illegal: a log needs a day document. Create the '
            'day first (G5 §3.1).',
          );
        }
        return MealSlotState.logged;

      case MealSlotEvent.correctPlannedLog:
        if (from != MealSlotState.logged && from != MealSlotState.corrected) {
          throw StateError(
            '${from.name} → corrected is illegal: there is nothing logged to '
            'correct.',
          );
        }
        // Idempotent on the same itemId — correcting a correction is still one
        // item, which is the whole of HANDOFF rule 3's first half.
        return MealSlotState.corrected;

      case MealSlotEvent.addHelping:
        if (from != MealSlotState.logged && from != MealSlotState.corrected) {
          throw StateError(
            '${from.name} → helping is illegal: a helping is a SECOND serving, '
            'so there must be a first one.',
          );
        }
        // Stays where it was. A helping adds an item; it does not correct one.
        return from;

      case MealSlotEvent.skipSlot:
        return MealSlotState.skipped;

      case MealSlotEvent.undoPending:
        throw StateError(
          'undo is not a transition. The five seconds run BEFORE the write '
          '(§4.2), so an undone log never changed the slot and there is nothing '
          'to transition back from.',
        );

      case MealSlotEvent.removeLastItem:
        if (from != MealSlotState.logged && from != MealSlotState.corrected) {
          throw StateError('${from.name} has no last item to remove.');
        }
        return MealSlotState.empty;
    }
  }

  /// The three conditions under which a log is refused before a write is built.
  ///
  /// Returns null when the log may proceed. Called in the domain layer, so every
  /// entry point hits it — including the lock-screen nudge, which therefore
  /// cannot one-tap-log a conflicting meal.
  LogRefusal? refuseLog({
    required MealDay? day,
    required Food? food,
    required AllergyAssessment assessment,
  }) {
    if (day == null) return const LogRefusal(LogRefusalReason.noDayContext);
    if (food == null) return const LogRefusal(LogRefusalReason.foodNotInPack);
    if (assessment.isBlocked) {
      return LogRefusal(
        LogRefusalReason.allergenOutstanding,
        assessment: assessment,
      );
    }
    return null;
  }
}
