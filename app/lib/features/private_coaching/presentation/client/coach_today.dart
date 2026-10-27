/// Which day of a coach's plan is today's. Pure, so Home and Eat agree.
library;

import '../../../events/domain/cairo_time.dart';
import '../../../onboarding/domain/intake.dart' show LifeStage;
import '../../../train/domain/my_plan.dart';
import '../../../train/domain/workout_library.dart' show suits;
import '../../domain/coach_plan.dart';

/// Whole Cairo days from [startsOn] (a calendar date, read as written) to the
/// Cairo day of [now]. Counted between two UTC dates, so the night Egypt moves
/// its clocks is still one day and week two starts on day seven.
int cairoDaysSince(DateTime startsOn, DateTime now) {
  final today = DateTime.parse(cairoDay(now));
  return DateTime.utc(today.year, today.month, today.day)
      .difference(DateTime.utc(startsOn.year, startsOn.month, startsOn.day))
      .inDays;
}

/// The day of the workout [plan] that comes next for a woman who has done
/// [doneThisWeek] sessions, or null when no day suits [stage]. With several
/// weeks and a [startsOn] date, only the days of the current week count, and
/// the last week repeats once the weeks run out. Before [startsOn] there is
/// no day.
int? todaysWorkoutDay(
  MyPlan plan,
  int doneThisWeek,
  LifeStage? stage, {
  DateTime? startsOn,
  DateTime? now,
}) {
  if (plan.weekCount <= 1 || startsOn == null) {
    return planDayForSlot(plan, doneThisWeek, stage);
  }
  final gone = cairoDaysSince(startsOn, now ?? DateTime.now());
  if (gone < 0) return null;
  final week = (1 + gone ~/ 7).clamp(1, plan.weekCount);
  final offered = [
    for (final i in plan.daysOfWeek(week))
      if (suits(plan.days[i].session, stage)) i,
  ];
  if (offered.isEmpty) return null;
  return offered[doneThisWeek % offered.length];
}

/// Which week of [plan] is today (1 based), or null before the start.
int? currentWeekOf(MyPlan plan, DateTime? startsOn, DateTime now) {
  if (plan.weekCount <= 1 || startsOn == null) return null;
  final gone = cairoDaysSince(startsOn, now);
  return gone < 0 ? null : (1 + gone ~/ 7).clamp(1, plan.weekCount);
}

/// The day of the meal plan [plan] for [now]: day 1 is the day it starts on,
/// else the Cairo day it was published, and the days repeat after the last
/// one. Null for no days, and before a start date that is still ahead.
int? todaysMealDay(CoachPlan plan, DateTime now) {
  final days = plan.meal?.days.length ?? 0;
  if (days == 0) return null;
  final startsOn = plan.startsOn;
  final from = startsOn ?? plan.publishedAt;
  if (from == null) return (cairoWeekday(now) - 1) % days;
  // A published instant is a Cairo day; a start date already is one.
  final day = startsOn ?? DateTime.parse(cairoDay(from));
  final gone = cairoDaysSince(day, now);
  if (gone < 0) return startsOn == null ? 0 : null;
  return gone % days;
}
