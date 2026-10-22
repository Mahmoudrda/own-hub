/// Which day of a coach's plan is today's. Pure, so Home and Eat agree.
library;

import '../../../events/domain/cairo_time.dart';
import '../../../onboarding/domain/intake.dart' show LifeStage;
import '../../../train/domain/my_plan.dart';
import '../../domain/coach_plan.dart';

/// The day of the workout [plan] that comes next for a woman who has done
/// [doneThisWeek] sessions, or null when no day suits [stage]. The days rotate
/// the way her own plan's do.
int? todaysWorkoutDay(MyPlan plan, int doneThisWeek, LifeStage? stage) =>
    planDayForSlot(plan, doneThisWeek, stage);

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
