/// Her goal, and the one rest the product pays for.
///
/// Two things reach for this file from two different features, and both were
/// comments pointing at a class that did not exist:
///
/// * `tier_slip_view.dart` — T05 lets her shrink this week's goal in one tap,
///   "because a goal she can meet beats a goal she abandons. That write belongs
///   to the rewards group (`WeeklyGoalService.setTarget`), not to this screen —
///   the spine forbids two groups writing one field."
/// * `cycle_hub_view.dart` — Y11's rest row, which `DECISIONS.md` D5a says must
///   cost her nothing, and which needs "a capped
///   `WeeklyGoalService.markPlannedRest(date)` to make it true".
///
/// So the two live here together: one class, one group, one place either field
/// is decided.
///
/// ## This class decides; it does not write
///
/// Every other type in `domain/rewards/` is pure — [WeekRollup], [DailyCap] and
/// [RestWeekRepair] all take the state they are given and return the state that
/// should be stored. `daily_cap.dart` names the pattern: *"the pure decision
/// half of that transaction"*. This is the same, and for a sharper reason.
///
/// `firestore.rules` does not let a client write **any** of this. The whole
/// `weeklyGoal` map is denied to clients by `rewardsUntouched()`, which is
/// AND-ed outside every per-group slice, and `users/{uid}`'s `allow update`
/// additionally restricts a client write to `profile`, `privacy`, `notify` and
/// `updatedAt`. `weeks/{weekId}` is `allow write: if false` outright.
///
/// That **contradicts** `weekly_goal.dart`'s statement that `sessionsTarget`,
/// `tz` and `goalKind` are client-writable (G6 §6 item 3): as the rules
/// actually stand, they are not. The contradiction is recorded here rather than
/// resolved here, because widening a rule is a security decision and this file
/// is not where one gets made. What follows from it is concrete: this class
/// returns values and performs no I/O, so nothing in it can attempt a write the
/// rules would reject. Whoever eventually persists a target — a Cloud Function,
/// or a client once the rule is widened deliberately — applies the [WeeklyGoal]
/// this class returns.
///
/// ## Planned rest deliberately returns no [WeeklyGoal]
///
/// D5a's promise is about **adherence**: an app-advised rest day "is not a skip"
/// and "only an *unexplained* absence counts toward the week's adherence".
/// Adherence lives on `users/{uid}/weeks/{yyyy-Www}`, and every field of it is
/// written by a Cloud Function — `week_rollup.dart` puts it plainly: *"What a
/// woman writes is evidence; what the server writes is the score."*
///
/// So [markPlannedRest] returns a [PlannedRestDecision] carrying the marker and
/// the cap's verdict, and it does **not** hand back a mutated [WeeklyGoal]. It
/// cannot: there is no client-writable field, on any document this app can
/// reach, in which a planned rest day could be recorded. Returning a goal with a
/// counter nudged would look finished and change nothing.
///
/// ## D16 — two per week
///
/// > **D16 — Planned rest is capped at two per week.** D5a's missing number.
///
/// D5a asked for a cap "so it cannot be used to excuse every day", left the
/// number to implementation, and the number was never recorded until the owner
/// settled it on 19 September 2026. [kPlannedRestPerWeek] is it, and it is one
/// constant so that changing it stays a one-line decision.
///
/// The cap is counted in **weeks**, like everything else this product counts
/// (§2 rule 3). A week rolls over when [WeekKey] says it is a different week —
/// an equality test on two week ids, exactly as [DailyCap] rolls its day over by
/// comparing two `yyyy-MM-dd` strings, and never by elapsed time.
///
/// ## Why a set of day ids is not a run counter
///
/// [PlannedRest] holds at most [kPlannedRestPerWeek] day ids for one week, and
/// the ids live in an **unordered set**. There is no first and no last, no
/// index, no adjacency test and no arithmetic between two of them, so "how many
/// in a row" is not a question this type can be asked — the same way
/// `week_key.dart` refuses `+`, `difference` and `isAdjacentTo`. The set exists
/// only so that marking the same day twice consumes one rest rather than two
/// (spine C1: a replay must collide with itself), and it is bounded by the cap
/// it enforces, so it cannot grow into a diary.
library;

import 'package:meta/meta.dart';

import '../format/day_key.dart';
import '../week/week_key.dart';
import 'weekly_goal.dart';

/// The fewest sessions a weekly goal may ask for.
///
/// `weekly_goal.dart`: "1–7. **Hers**, and the only counter on this object she
/// may write."
const int kMinSessionsTarget = 1;

/// The most sessions a weekly goal may ask for: every day of the week.
///
/// `Intake.days` runs over the same 1 to 7, so every answer she can give on O03
/// is a goal [WeeklyGoalService.setTarget] accepts and it reaches the goal
/// whole. A number outside the bounds is still refused and never clamped, see
/// [WeeklyGoalService.setTarget]. The owner raised the ceiling from four on
/// 18 October 2026: she decides how often she
/// trains, and the week still counts when she reaches her own goal, whatever
/// it is.
const int kMaxSessionsTarget = 7;

/// `DECISIONS.md` D16 — planned rest days allowed in any one ISO week.
///
/// Settled by the owner on 19 September 2026 ("yes one or 2 weeks max", read as
/// *up to two*). D5a required a cap and recorded none; this is the number.
const int kPlannedRestPerWeek = 2;

/// What [WeeklyGoalService.setTarget] did.
enum TargetOutcome {
  /// The goal now asks for the number she chose.
  set,

  /// She chose the target she already had. Nothing moved, and that is not an
  /// error — re-tapping the goal she is on is a normal thing to do.
  unchanged,

  /// Below [kMinSessionsTarget]. Refused, never clamped.
  belowMinimum,

  /// Above [kMaxSessionsTarget]. Refused, never clamped.
  aboveMaximum,
}

/// The goal after she chose a target, and whether the choice took.
@immutable
class TargetDecision {
  const TargetDecision({required this.goal, required this.outcome});

  /// Her goal afterwards. On a refusal this is the goal she already had,
  /// unchanged in every field.
  final WeeklyGoal goal;

  final TargetOutcome outcome;

  /// True when the number she asked for is the number she now has.
  bool get accepted =>
      outcome == TargetOutcome.set || outcome == TargetOutcome.unchanged;
}

/// What [WeeklyGoalService.markPlannedRest] did.
enum PlannedRestOutcome {
  /// The day is now planned rest. D5a: it is not a skip and costs her nothing.
  planned,

  /// That exact day was already planned rest. Nothing was consumed.
  ///
  /// Checked **before** the cap, so a second tap on a day she already marked
  /// never reports a refusal she did not earn.
  alreadyPlanned,

  /// [kPlannedRestPerWeek] days of this week are already planned rest.
  capReached,
}

/// The planned-rest days of one week.
///
/// Scoped to a single [WeekKey] by construction: there is no field here for a
/// second week, so nothing can accumulate across one. See the library comment
/// for why an unordered set cannot express a run.
@immutable
class PlannedRest {
  const PlannedRest({required this.week, this.dayKeys = const <String>{}});

  /// A week with no rest planned yet.
  const PlannedRest.fresh(WeekKey week) : this(week: week);

  /// The week these days belong to.
  final WeekKey week;

  /// `yyyy-MM-dd` ids, unordered, at most [kPlannedRestPerWeek] of them.
  final Set<String> dayKeys;

  /// How many of this week's allowance is spent.
  int get used => dayKeys.length;

  /// How many planned rest days are left this week. Never negative.
  int get remaining =>
      used >= kPlannedRestPerWeek ? 0 : kPlannedRestPerWeek - used;

  /// True when this week's allowance is spent.
  bool get isFull => remaining == 0;

  /// True when [date] is already planned rest.
  bool covers(DateTime date) => dayKeys.contains(dayKey(date));

  @override
  bool operator ==(Object other) =>
      other is PlannedRest &&
      other.week == week &&
      other.dayKeys.length == dayKeys.length &&
      other.dayKeys.containsAll(dayKeys);

  @override
  int get hashCode => Object.hash(week, Object.hashAllUnordered(dayKeys));

  @override
  String toString() {
    final days = dayKeys.toList()..sort();
    return 'PlannedRest(${week.id} ${days.join(' ')})';
  }
}

/// A planned rest day, and what the cap said about it.
@immutable
class PlannedRestDecision {
  const PlannedRestDecision({required this.planned, required this.outcome});

  /// The week's planned rest afterwards. On a refusal, and on a repeat, this is
  /// exactly what came in.
  final PlannedRest planned;

  final PlannedRestOutcome outcome;

  /// True when the day is planned rest now — including when it already was.
  ///
  /// The screen asking "may she rest today without it counting against her?"
  /// wants this, not the distinction between the two ways of saying yes.
  bool get isPlannedRest => outcome != PlannedRestOutcome.capReached;

  /// Planned rest days left this week.
  int get remaining => planned.remaining;
}

/// Her weekly goal: the one target she chooses, and the rest the product pays
/// for.
///
/// Pure. It holds no state, performs no I/O, and has no repository — see the
/// library comment.
class WeeklyGoalService {
  const WeeklyGoalService({
    this.minTarget = kMinSessionsTarget,
    this.maxTarget = kMaxSessionsTarget,
    this.plannedRestPerWeek = kPlannedRestPerWeek,
  });

  final int minTarget;
  final int maxTarget;

  /// D16's two.
  final int plannedRestPerWeek;

  /// Sets the weekly goal to [target] sessions.
  ///
  /// **Refused, never clamped.** A 7 handed to this method is a caller's bug,
  /// and silently turning it into a 4 would give her a goal she did not choose
  /// and no way to find out. T05 and P01 offer 2, 3 and 4; anything else is
  /// returned as the goal she already had.
  ///
  /// Nothing but [WeeklyGoal.sessionsTarget] moves. Every other counter on that
  /// object belongs to a Cloud Function, and this method's only expression of a
  /// change is a `copyWith` naming one field.
  TargetDecision setTarget(WeeklyGoal goal, int target) {
    if (target < minTarget) {
      return TargetDecision(goal: goal, outcome: TargetOutcome.belowMinimum);
    }
    if (target > maxTarget) {
      return TargetDecision(goal: goal, outcome: TargetOutcome.aboveMaximum);
    }
    if (target == goal.sessionsTarget) {
      return TargetDecision(goal: goal, outcome: TargetOutcome.unchanged);
    }
    return TargetDecision(
      goal: goal.copyWith(sessionsTarget: target),
      outcome: TargetOutcome.set,
    );
  }

  /// Marks [date] as planned rest, up to [plannedRestPerWeek] days a week.
  ///
  /// D5a: when the app itself advises rest — a severe-symptom suppression under
  /// rule 5, or a rest day the plan prescribes — that day "is recorded as
  /// planned rest and is not a skip. It costs her nothing, exactly as the screen
  /// says."
  ///
  /// ### Why [planned] is required, when the call site sketched `markPlannedRest(date)`
  ///
  /// Because a cap whose state is optional is not a cap. Defaulting a missing
  /// [planned] to an empty week would grant every call, and the one line D5a
  /// wrote this method for — "so it cannot be used to excuse every day" — would
  /// be false while the signature still looked right. A caller that has not
  /// loaded the week's rest says so with [PlannedRest.fresh], which is a visible
  /// claim rather than a silent default.
  ///
  /// ### There is no confirmation
  ///
  /// Rule 9, and the same absence [RestWeekRepair] relies on: no `confirm`
  /// parameter, no callback, and nothing here that could raise a dialog. She
  /// taps rest and it is rest.
  PlannedRestDecision markPlannedRest(
    DateTime date, {
    required PlannedRest planned,
  }) {
    final week = WeekKey.of(date);

    // A different week starts clean. Week-id equality, never elapsed time, and
    // deliberately `!=` rather than a comparison: a state from a LATER week is
    // as wrong for this date as one from an earlier week, and `isBefore` would
    // quietly accept it and spend the wrong week's allowance.
    final state = planned.week == week ? planned : PlannedRest.fresh(week);

    final key = dayKey(date);

    // Dedupe before the cap. A replayed or double-tapped mark on a day she has
    // already rested is not a third rest day, and must not be reported as one
    // once the week is full (spine C1).
    if (state.dayKeys.contains(key)) {
      return PlannedRestDecision(
        planned: state,
        outcome: PlannedRestOutcome.alreadyPlanned,
      );
    }

    if (state.dayKeys.length >= plannedRestPerWeek) {
      return PlannedRestDecision(
        planned: state,
        outcome: PlannedRestOutcome.capReached,
      );
    }

    return PlannedRestDecision(
      planned: PlannedRest(week: week, dayKeys: {...state.dayKeys, key}),
      outcome: PlannedRestOutcome.planned,
    );
  }
}
