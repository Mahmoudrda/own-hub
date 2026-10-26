/// Which day of a coach's plan is today's. Pure, so Home and Eat agree.
library;

import '../../../events/domain/cairo_time.dart';
import '../../../onboarding/domain/intake.dart' show LifeStage;
import '../../../train/domain/my_plan.dart';
import '../../../train/domain/workout_library.dart' show suits;
import '../../domain/coach_plan.dart';

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
  final a = DateTime.parse(cairoDay(startsOn));
  final b = DateTime.parse(cairoDay(now ?? DateTime.now()));
  final gone = b.difference(a).inDays;
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
  final gone = DateTime.parse(cairoDay(now))
      .difference(DateTime.parse(cairoDay(startsOn)))
      .inDays;
  return gone < 0 ? null : (1 + gone ~/ 7).clamp(1, plan.weekCount);
}

/// The day of the meal plan [plan] for [now]: day 1 is the Cairo day it was
/// published, and the days repeat after the last one. Null for no days.
int? todaysMealDay(CoachPlan plan, DateTime now) {
  final days = plan.meal?.days.length ?? 0;
  if (days == 0) return null;
  final from = plan.publishedAt;
  if (from == null) return (cairoWeekday(now) - 1) % days;
  final a = DateTime.parse(cairoDay(from));
  final b = DateTime.parse(cairoDay(now));
  final gone = b.difference(a).inDays;
  return (gone < 0 ? 0 : gone) % days;
}
