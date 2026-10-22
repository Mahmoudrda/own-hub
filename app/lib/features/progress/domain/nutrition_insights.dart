/// Her last seven days of eating against her targets, for the Insights page.
///
/// Read from the same totals Home draws, so the two cannot disagree: the
/// caller supplies [NutritionWeek.from]'s `totalsFor`, and for every day,
/// today included, that is `EatAppState.totalsWithPending`. Nothing here is
/// stored. Averages are over the days she logged, not over seven, because a
/// day with nothing logged is a day she did not write down, not a day she
/// ate nothing. There is no remaining, over or deficit figure anywhere.
library;

import 'package:meta/meta.dart';

import '../../../domain/format/day_key.dart';
import '../../eat/domain/daily_targets.dart';
import '../../eat/domain/day_totals.dart';

/// One day on the chart.
@immutable
class NutritionDay {
  const NutritionDay({
    required this.date,
    required this.kcal,
    required this.proteinG,
    required this.logged,
  });

  final DateTime date;
  final int kcal;
  final int proteinG;

  /// True when at least one meal is written down for the day.
  final bool logged;
}

@immutable
class NutritionWeek {
  const NutritionWeek({
    required this.days,
    required this.proteinTargetG,
    required this.kcalTarget,
  });

  /// Seven days, oldest first, the last one today.
  factory NutritionWeek.from({
    required DateTime today,
    required DailyTargets targets,
    required DayTotals Function(String dayId) totalsFor,
  }) {
    return NutritionWeek(
      proteinTargetG: targets.proteinG,
      kcalTarget: targets.kcal,
      days: [
        for (var back = 6; back >= 0; back--)
          _day(DateTime(today.year, today.month, today.day - back), totalsFor),
      ],
    );
  }

  static NutritionDay _day(
    DateTime date,
    DayTotals Function(String dayId) totalsFor,
  ) {
    final totals = totalsFor(dayKey(date));
    return NutritionDay(
      date: date,
      kcal: totals.kcalSoFar,
      proteinG: totals.proteinSoFar,
      logged: totals.hasAnything,
    );
  }

  /// A week with nothing logged.
  factory NutritionWeek.empty(DateTime today, DailyTargets targets) =>
      NutritionWeek.from(
        today: today,
        targets: targets,
        totalsFor: (_) => DayTotals.empty,
      );

  final List<NutritionDay> days;
  final int proteinTargetG;
  final int kcalTarget;

  Iterable<NutritionDay> get _logged => days.where((d) => d.logged);

  /// How many of the seven days have a meal written down.
  int get loggedDays => _logged.length;

  bool get hasAny => loggedDays > 0;

  /// Mean protein over the logged days, or null when none is logged.
  int? get averageProteinG => hasAny
      ? (_logged.fold<int>(0, (a, d) => a + d.proteinG) / loggedDays).round()
      : null;

  /// Mean energy over the logged days, or null when none is logged.
  int? get averageKcal => hasAny
      ? (_logged.fold<int>(0, (a, d) => a + d.kcal) / loggedDays).round()
      : null;
}
