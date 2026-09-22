/// The day, as Today renders it — and nothing more.
///
/// §2 rule 3 is *weeks, not days*, and the way that is guaranteed here is the
/// same way [WeekKey] guarantees it: **nothing in this file can produce a daily
/// tally.** [TodayDay] carries one date, never a list of them; [WeekProgress]
/// carries two integers for the current week; [FirstWeekArc] carries five
/// booleans. There is no field capable of holding "how many days in a row", so
/// no view model can compute one and no widget can render one.
///
/// [FirstWeekArc] additionally has no deadline, no expiry and no failed state —
/// HANDOFF rule 17. [ArcStepState] has exactly three values and none of them
/// means failure, so a failure state is not constructible rather than merely
/// unused.
library;

import 'package:meta/meta.dart';

/// The five first actions of the arc, in the order T07 lists them.
///
/// Steps four and five live in Community. `DECISIONS.md` D1 withdrew the MVP
/// cut, so they ship; until Community is built they route onward and land on the
/// router's "not built yet" screen. They are never silently dropped — an arc
/// that quietly became three steps would make T08 unreachable while appearing
/// complete.
enum FirstWeekStep { logSet, logMeal, finishSession, joinGroup, followUp }

/// How a step renders. Three values, deliberately.
///
/// There is no `expired` and no `failed`: the steps simply wait. The health-app
/// evidence behind this product is that visible failure erodes the motivation it
/// is built to create, so the absence here is the enforcement.
enum ArcStepState { done, now, waiting }

/// The first-week arc — five booleans, never a count of days.
@immutable
class FirstWeekArc {
  const FirstWeekArc({
    this.hasAnyLog = false,
    this.completed = const <FirstWeekStep>{},
  });

  /// Whether anything at all has been logged. This single boolean is what T01
  /// branches on to render T06, so day one costs one read rather than a scan.
  final bool hasAnyLog;

  final Set<FirstWeekStep> completed;

  int get doneCount => completed.length;

  int get stepCount => FirstWeekStep.values.length;

  /// True once all five are done. Derived rather than stored, so "complete" and
  /// "five done" cannot disagree.
  bool get isComplete => completed.length == FirstWeekStep.values.length;

  /// The state of one step. Exactly one incomplete step is [ArcStepState.now] —
  /// the first — and the rest wait.
  ArcStepState stateOf(FirstWeekStep step) {
    if (completed.contains(step)) return ArcStepState.done;
    final next = FirstWeekStep.values.firstWhere(
      (s) => !completed.contains(s),
      orElse: () => step,
    );
    return step == next ? ArcStepState.now : ArcStepState.waiting;
  }

  FirstWeekArc withStep(FirstWeekStep step) =>
      FirstWeekArc(hasAnyLog: true, completed: {...completed, step});

  /// Marks that something has been logged without completing a step — the
  /// transition that stops T06 rendering, permanently.
  FirstWeekArc get started =>
      hasAnyLog ? this : FirstWeekArc(hasAnyLog: true, completed: completed);
}

/// This week's sessions against this week's goal.
///
/// Two integers and a flag. Note what is missing: there is no "missed" count,
/// because T04 and T05 must never render one.
@immutable
class WeekProgress {
  const WeekProgress({
    required this.sessionsLogged,
    required this.sessionsTarget,
    this.repairedByRestWeek = false,
  });

  final int sessionsLogged;
  final int sessionsTarget;

  /// D5: a banked rest week repairs a missed week and costs her nothing. When
  /// this is true the week is whole — there is nothing to make up and nothing to
  /// display in red.
  final bool repairedByRestWeek;
}

/// One plate Today offers her, and what it actually costs.
///
/// The figure travels with the plate rather than being frozen into a dictionary
/// string. Home used to render the fixed `n410Kcal` and `n290Kcal` — the
/// prototype's two breakfasts — beside whatever it called them, so every woman
/// read 410 and 290 however she eats. A kcal is a value, not copy, and this is
/// where a value belongs.
@immutable
class PlateSuggestion {
  const PlateSuggestion({required this.foodId, required this.kcal});

  /// Resolved to her language by the view, the way the food pack and the
  /// workout library already are.
  final String foodId;

  final int kcal;
}

/// What the body of Today is showing.
enum DayState { dayOne, nothingDone, inProgress, done, recalled, restDay }

/// Decides the day's state, and is incapable of deciding anything else.
///
/// Note the parameters: today's facts and this week's rollup. There is no
/// argument carrying a list of dates, so a consecutive-day count is not
/// computable at the one place T01's body is decided (plan G3 §5).
class DayStateResolver {
  const DayStateResolver();

  DayState resolve({
    required FirstWeekArc arc,
    required WeekProgress week,
    bool sessionStarted = false,
    bool sessionCompleted = false,
    bool recalled = false,
    bool restDay = false,
  }) {
    if (!arc.hasAnyLog) return DayState.dayOne;
    if (sessionCompleted) return DayState.done;
    if (recalled) return DayState.recalled;
    if (sessionStarted) return DayState.inProgress;
    // D5a: a rest day the plan prescribed is planned rest, never a skip.
    // Logging stays enabled on it — T04's shortest session "counts toward your
    // week like any session".
    if (restDay) return DayState.restDay;
    return DayState.nothingDone;
  }
}

/// One day's state, as the screens read it.
@immutable
class TodayDay {
  const TodayDay({
    required this.date,
    required this.state,
    required this.arc,
    required this.week,
    this.walkToCount = false,
    this.walkMinutes,
    this.mealLoggedAt,
    this.showCycleCard = false,
    this.plates = const <PlateSuggestion>[],
    this.programWeek,
    this.programTotalWeeks,
  });

  /// A single date. Not a range, and not a list — see the library comment.
  final DateTime date;

  final DayState state;
  final FirstWeekArc arc;
  final WeekProgress week;

  /// A walk her phone counted that she has not yet claimed.
  final bool walkToCount;

  /// How long that walk was, or null when the count carries no duration.
  ///
  /// Null renders the card **without** a duration rather than with the
  /// prototype's: `walkThisMorning32Min` told every woman her walk was 32
  /// minutes, and the undo bar then confirmed the same 32 back to her.
  final int? walkMinutes;

  /// When the day's first meal was logged, or null if none has been.
  final DateTime? mealLoggedAt;

  /// Whether Home shows the cycle row at all.
  ///
  /// **Defaults to false, and that default is the point.** Home rendered this
  /// row unconditionally, so a woman who skipped cycle tracking entirely — or
  /// never reached the setup screen — still got a cycle card on her first
  /// screen. P0-CYC-03 says skipping costs nothing; a card advertising the
  /// feature she declined is a cost.
  ///
  /// It is a plain bool rather than cycle state because Today must not depend
  /// on the cycle domain. The router projects `cycle/current.adaptation
  /// .homeCard` — which is false until she sets up, and which Y12 can switch
  /// off afterwards — down to this one flag.
  final bool showCycleCard;

  /// The plates Today offers for the meal at this hour. Empty renders none.
  final List<PlateSuggestion> plates;

  /// Where she is in her programme, and how long it runs.
  ///
  /// Both null renders **no week badge at all**. Home's badge was the fixed
  /// `week3Of8`, so it announced "Week 3 of 8" on her first day and in her
  /// ninth week alike — and `train_view.dart` had already withdrawn the same
  /// string for the same reason, leaving the two screens disagreeing.
  final int? programWeek;
  final int? programTotalWeeks;

  bool get isDayOne => state == DayState.dayOne;

  TodayDay copyWith({
    DayState? state,
    FirstWeekArc? arc,
    WeekProgress? week,
    bool? walkToCount,
    DateTime? mealLoggedAt,
    bool? showCycleCard,
    List<PlateSuggestion>? plates,
  }) {
    return TodayDay(
      date: date,
      state: state ?? this.state,
      arc: arc ?? this.arc,
      week: week ?? this.week,
      walkToCount: walkToCount ?? this.walkToCount,
      walkMinutes: walkMinutes,
      mealLoggedAt: mealLoggedAt ?? this.mealLoggedAt,
      showCycleCard: showCycleCard ?? this.showCycleCard,
      plates: plates ?? this.plates,
      programWeek: programWeek,
      programTotalWeeks: programTotalWeeks,
    );
  }
}
