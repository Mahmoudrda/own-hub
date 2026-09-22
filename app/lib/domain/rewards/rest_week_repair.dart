/// A rest week repairs a missed week, and nobody is asked.
///
/// `DECISIONS.md` D5: *"A banked rest week protects her completely and must
/// never reduce a reward."* G6 §3.1 states how: **repair runs inside the close
/// transaction — no prompt, no confirmation, no permission sought.** T04 reports
/// what already happened; it does not offer a choice.
///
/// That is a deliberate product decision with a source. The documented way to
/// remove the sting of a missed goal is to repair it without making her ask
/// (Silverman & Barasch 2023, *JCR* 49(6)), and an "use your rest week?" prompt
/// would reintroduce exactly the moment of failure the repair exists to delete.
/// So there is **no method on this class that takes a confirmation**, and no
/// parameter anywhere that could carry one.
///
/// ## Two rules that keep the economy honest
///
/// 1. **A repaired week earns no points.** No goal-moving behaviour occurred.
///    The count and the run are preserved; the 40 points are not (G6 §9.3).
/// 2. **A repaired week earns no progress toward the next rest week.** Only
///    `counted && !repairedByRestWeek` advances [WeeklyGoal.restWeekProgress],
///    so repair cannot fund itself.
///
/// Neither is a condition somebody has to remember: [RepairOutcome] is the
/// switch, and every branch is written once, here.
library;

import 'package:meta/meta.dart';

import '../week/week_key.dart';
import 'week_rollup.dart';
import 'weekly_goal.dart';

/// What happened to a week at close.
///
/// Three outcomes and no fourth. None of them is a failure state: [missed] is
/// the absence of a reward, never the presence of a penalty.
enum RepairOutcome {
  /// She met the goal. The week counted on its own.
  counted,

  /// She did not, and a banked rest week covered it. Counted all the same.
  repaired,

  /// She did not, and there was no rest week. The run resets; nothing is taken.
  missed,
}

/// The result of closing one week.
@immutable
class RepairDecision {
  const RepairDecision({
    required this.week,
    required this.goal,
    required this.outcome,
    required this.pointsAwarded,
  });

  /// The closed week document.
  final WeekDoc week;

  /// Her counters afterwards.
  final WeeklyGoal goal;

  final RepairOutcome outcome;

  /// Always zero.
  ///
  /// The 40 points for a counted week fire at the **crossing**, not at the
  /// close — `WeekRollup.creditSession` reports that moment as
  /// [WeekCredit.countedNow], and it can only happen once per week because the
  /// award id is `week:{yyyy-Www}`. Paying again here would pay twice for one
  /// week, which is precisely what `P0-WEEK-01` ("Points award once") forbids.
  ///
  /// Kept as a field rather than dropped, so a future change that decides a
  /// close *should* pay has somewhere to say so out loud.
  final int pointsAwarded;

  bool get counts => outcome != RepairOutcome.missed;
}

/// Closes weeks, and repairs what it can.
class RestWeekRepair {
  const RestWeekRepair({this.rollup = const WeekRollup()});

  final WeekRollup rollup;

  /// Closes one week.
  ///
  /// Note the absent parameter: there is no `askFirst`, no `confirm` and no
  /// callback. Repair is automatic or it is not repair.
  ///
  /// A week that is already closed is returned untouched — `closedAt` is
  /// write-once, so re-running a close (which Cloud Functions' at-least-once
  /// delivery makes normal rather than exceptional) changes nothing.
  RepairDecision decide({
    required WeekDoc week,
    required WeeklyGoal goal,
    required DateTime closedAt,
  }) {
    if (week.isClosed) {
      return RepairDecision(
        week: week,
        goal: goal,
        outcome: _outcomeOfClosed(week),
        pointsAwarded: 0,
      );
    }

    final state = rollup.evaluate(week);

    if (state == WeekState.met) {
      final closed = week.copyWith(counted: true, closedAt: closedAt);
      return RepairDecision(
        week: closed,
        goal: _afterEarnedWeek(goal, closed),
        outcome: RepairOutcome.counted,
        pointsAwarded: 0,
      );
    }

    if (_canRepair(goal)) {
      final closed = week.copyWith(
        counted: true,
        repairedByRestWeek: true,
        closedAt: closedAt,
      );
      return RepairDecision(
        week: closed,
        goal: _afterRepairedWeek(goal, closed),
        outcome: RepairOutcome.repaired,
        pointsAwarded: 0,
      );
    }

    final closed = week.copyWith(closedAt: closedAt);
    return RepairDecision(
      week: closed,
      goal: _afterMissedWeek(goal, closed),
      outcome: RepairOutcome.missed,
      pointsAwarded: 0,
    );
  }

  /// Closes every week she was away for, most-recent-first where it matters.
  ///
  /// Two passes, and the split is the point. **Selection** runs newest-first,
  /// because a limited bank should protect the weeks nearest to now — both
  /// [WeeklyGoal.currentRun] and the tier's recency floor weight recency
  /// (G6 §3.1). **Application** then runs oldest-first, because the run and the
  /// eight-bar chart are chronological and closing them backwards would record
  /// her history in the wrong order.
  ///
  /// At most [kRecentWeekWindow] weeks are reconciled. An older gap is skipped
  /// entirely — no document, not counted, not repaired — so a two-year absence
  /// cannot fan out a hundred writes (G6 §9.13). The return is rewarded by a
  /// milestone instead, which is the kinder answer as well as the cheaper one.
  WeekCloseRun closeStaleWeeks({
    required List<WeekDoc> unclosed,
    required WeeklyGoal goal,
    required DateTime closedAt,
  }) {
    final open = unclosed.where((w) => !w.isClosed).toList()
      ..sort((a, b) => a.week.compareTo(b.week));

    final skipped = open.length > kRecentWeekWindow
        ? open.sublist(0, open.length - kRecentWeekWindow)
        : const <WeekDoc>[];
    final reconciled = open.length > kRecentWeekWindow
        ? open.sublist(open.length - kRecentWeekWindow)
        : open;

    // Pass one — selection, newest first, against a simulated bank.
    var bank = goal.restWeeksBanked;
    var countedSoFar = goal.countedWeeks;
    final repairing = <WeekKey>{};
    for (final week in reconciled.reversed) {
      if (rollup.evaluate(week) == WeekState.met) {
        countedSoFar += 1;
        continue;
      }
      if (bank > 0 && countedSoFar > 0) {
        repairing.add(week.week);
        bank -= 1;
        countedSoFar += 1;
      }
    }

    // Pass two — application, oldest first.
    //
    // Note that a week pass one did NOT select goes through
    // [_closeWithoutRepair] rather than through [decide]. This is the whole
    // point of splitting the passes, and getting it wrong defeats the rule
    // silently: [decide] repairs whenever the bank allows, so calling it here
    // let the OLDEST unmet week spend the bank first and the most-recent-first
    // selection above was overridden a moment after it was made.
    var running = goal;
    final decisions = <RepairDecision>[];
    for (final week in reconciled) {
      final decision = repairing.contains(week.week)
          ? _repairOutright(week, running, closedAt)
          : _closeWithoutRepair(week, running, closedAt);
      decisions.add(decision);
      running = decision.goal;
    }

    return WeekCloseRun(
      decisions: decisions,
      goal: running,
      skippedWeeks: skipped.map((w) => w.week).toList(),
    );
  }

  /// A rest week is never spent on a week she could not yet have earned one for.
  ///
  /// `P0-FR-02` requires that no rest week is spent on an unmet *first* week.
  /// Structurally this is already true — a bank is only earned by counted weeks,
  /// so `restWeeksBanked > 0` implies she has counted some — but the guard is
  /// explicit because [decide] takes the bank as a parameter and a caller could
  /// hand it one that her history does not justify.
  bool _canRepair(WeeklyGoal goal) =>
      goal.restWeeksBanked > 0 && goal.countedWeeks > 0;

  /// Closes a week and does **not** consider repairing it.
  ///
  /// Used by [closeStaleWeeks] for every week its selection pass passed over.
  /// A week reaches here because a more recent one has a better claim on the
  /// bank, so re-asking "could this be repaired?" would undo that decision.
  RepairDecision _closeWithoutRepair(
    WeekDoc week,
    WeeklyGoal goal,
    DateTime closedAt,
  ) {
    if (week.isClosed) {
      return RepairDecision(
        week: week,
        goal: goal,
        outcome: _outcomeOfClosed(week),
        pointsAwarded: 0,
      );
    }

    if (rollup.evaluate(week) == WeekState.met) {
      final closed = week.copyWith(counted: true, closedAt: closedAt);
      return RepairDecision(
        week: closed,
        goal: _afterEarnedWeek(goal, closed),
        outcome: RepairOutcome.counted,
        pointsAwarded: 0,
      );
    }

    final closed = week.copyWith(closedAt: closedAt);
    return RepairDecision(
      week: closed,
      goal: _afterMissedWeek(goal, closed),
      outcome: RepairOutcome.missed,
      pointsAwarded: 0,
    );
  }

  RepairDecision _repairOutright(
    WeekDoc week,
    WeeklyGoal goal,
    DateTime closedAt,
  ) {
    if (!_canRepair(goal)) {
      return _closeWithoutRepair(week, goal, closedAt);
    }
    final closed = week.copyWith(
      counted: true,
      repairedByRestWeek: true,
      closedAt: closedAt,
    );
    return RepairDecision(
      week: closed,
      goal: _afterRepairedWeek(goal, closed),
      outcome: RepairOutcome.repaired,
      pointsAwarded: 0,
    );
  }

  RepairOutcome _outcomeOfClosed(WeekDoc week) {
    if (!week.counted) return RepairOutcome.missed;
    return week.repairedByRestWeek
        ? RepairOutcome.repaired
        : RepairOutcome.counted;
  }

  /// A week she earned: the count rises, the run rises, and the bank advances.
  WeeklyGoal _afterEarnedWeek(WeeklyGoal goal, WeekDoc week) {
    final run = goal.currentRun + 1;
    var progress = goal.restWeekProgress + 1;
    var banked = goal.restWeeksBanked;
    if (progress >= kCountedWeeksPerRestWeek) {
      progress = 0;
      if (banked < kRestWeekBankCap) banked += 1;
    }
    return goal
        .copyWith(
          countedWeeks: goal.countedWeeks + 1,
          currentRun: run,
          bestRun: run,
          restWeekProgress: progress,
          restWeeksBanked: banked,
        )
        .withClosedBar(week.toBar());
  }

  /// A week a rest week covered.
  ///
  /// The count rises and **the run survives, which is what the repair is**. The
  /// bank falls by one. [WeeklyGoal.restWeekProgress] is untouched, so this week
  /// buys nothing toward the next rest week.
  WeeklyGoal _afterRepairedWeek(WeeklyGoal goal, WeekDoc week) {
    return goal
        .copyWith(
          countedWeeks: goal.countedWeeks + 1,
          restWeeksBanked: goal.restWeeksBanked - 1,
          lastRepairedWeek: week.week,
        )
        .withClosedBar(week.toBar());
  }

  /// A week that did not count.
  ///
  /// The run resets. Nothing else moves: [WeeklyGoal.countedWeeks] does not
  /// fall, [WeeklyGoal.bestRun] does not fall, and no points are removed. There
  /// is no field here for "weeks missed" to be written into.
  WeeklyGoal _afterMissedWeek(WeeklyGoal goal, WeekDoc week) {
    return goal.copyWith(currentRun: 0).withClosedBar(week.toBar());
  }
}

/// Everything one lazy close settled.
@immutable
class WeekCloseRun {
  const WeekCloseRun({
    required this.decisions,
    required this.goal,
    required this.skippedWeeks,
  });

  /// Oldest first.
  final List<RepairDecision> decisions;

  /// Her counters after the whole run.
  final WeeklyGoal goal;

  /// Weeks older than the reconciliation window, skipped entirely.
  final List<WeekKey> skippedWeeks;

  int get repairedCount =>
      decisions.where((d) => d.outcome == RepairOutcome.repaired).length;

  /// Always zero — see [RepairDecision.pointsAwarded].
  int get pointsAwarded => decisions.fold(0, (sum, d) => sum + d.pointsAwarded);
}
