// P01 as the Insights tab root: the body map as the hero, the week, bests and
// seven days of food in one scroll, friendly when there is nothing yet, and
// readable at the largest text size in English and Arabic.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/domain/rewards/personal_best_detector.dart';
import 'package:own_hub/domain/rewards/rewards.dart';
import 'package:own_hub/domain/rewards/tier_policy.dart';
import 'package:own_hub/domain/rewards/week_rollup.dart';
import 'package:own_hub/domain/rewards/weekly_goal.dart';
import 'package:own_hub/domain/week/week_key.dart';
import 'package:own_hub/features/eat/domain/daily_targets.dart';
import 'package:own_hub/features/eat/domain/day_totals.dart';
import 'package:own_hub/features/progress/domain/muscle_map.dart';
import 'package:own_hub/features/progress/domain/muscle_report.dart';
import 'package:own_hub/features/progress/domain/nutrition_insights.dart';
import 'package:own_hub/features/progress/presentation/muscle_figure.dart';
import 'package:own_hub/features/train/domain/exercise_library.dart';
import 'package:own_hub/features/progress/presentation/progress_view.dart';
import 'package:own_hub/features/progress/presentation/progress_view_model.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';

final DateTime _today = DateTime(2026, 10, 17, 21, 40);

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

Widget _host(
  Widget child, {
  Locale locale = const Locale('en'),
  double scale = 1,
}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppL10n.localizationsDelegates,
    supportedLocales: AppL10n.supportedLocales,
    theme: buildTheme(locale),
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child,
      ),
    ),
  );
}

ProgressSummary _summary() => ProgressSummary.from(
  goal: const WeeklyGoal(
    sessionsTarget: 3,
    countedWeeks: 6,
    restWeeksBanked: 0,
    currentRun: 2,
    bestRun: 4,
    recent8: <WeekBar>[],
  ),
  rewards: Rewards(points: 120, bestsCount: 1, milestones: const {}),
  currentWeek: WeekDoc(
    week: WeekKey.tryParse('2026-W42')!,
    sessionsTarget: 3,
    creditedSessionIds: const ['a', 'b'],
  ),
  ladder: TierLadder.unauthored,
  milestoneCount: 7,
);

MuscleReport _trained() => buildMuscleReport(
  log: const [
    (dateKey: '2026-10-17', exerciseId: 'glute_bridge', sets: 3),
    (dateKey: '2026-10-15', exerciseId: 'bent_over_row', sets: 4),
  ],
  musclesOf: (id) => musclesFor(id, ExerciseLibrary.empty),
  today: _today,
);

DayTotals _day(int kcal, int protein) =>
    DayTotals(kcalSoFar: kcal, proteinSoFar: protein, proteinTargetG: 95);

NutritionWeek _week(Map<int, DayTotals> byBack) => NutritionWeek.from(
  today: _today,
  targets: DailyTargets.compute(),
  totalsFor: (id) {
    for (final e in byBack.entries) {
      final d = DateTime(_today.year, _today.month, _today.day - e.key);
      final key =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      if (key == id) return e.value;
    }
    return DayTotals.empty;
  },
);

const _bests = <PersonalBest>[
  PersonalBest(
    exerciseId: 'goblet_squat',
    metric: BestMetric.load,
    dateKey: '2026-09-16',
    sessionId: 's1',
    loadKg: 12,
    reps: 10,
    previous: PreviousBest(loadKg: 10),
  ),
];

Widget _full() => ProgressView(
  summary: _summary(),
  muscleReport: _trained(),
  bests: _bests,
  nutrition: _week({0: _day(1400, 80), 1: _day(1800, 100), 3: _day(1600, 60)}),
);

Widget _empty() => ProgressView(summary: _summary());

void main() {
  group('the seven days of food', () {
    test('averages cover the days she logged, not seven', () {
      final w = _week({
        0: _day(1400, 80),
        1: _day(1800, 100),
        3: _day(1600, 60),
      });
      expect(w.days, hasLength(7));
      expect(w.loggedDays, 3);
      expect(w.averageProteinG, 80);
      expect(w.averageKcal, 1600);
    });

    test('today is the last day and carries the totals it was given', () {
      final w = _week({0: _day(1400, 80)});
      expect(w.days.last.date.day, _today.day);
      expect(w.days.last.proteinG, 80);
      expect(w.days.last.kcal, 1400);
      expect(w.days.first.logged, isFalse);
    });

    test('a week with nothing logged has no averages and no zeros', () {
      final w = _week({});
      expect(w.hasAny, isFalse);
      expect(w.averageProteinG, isNull);
      expect(w.averageKcal, isNull);
    });
  });

  group('Insights with her data', () {
    for (final (locale, scale) in [
      (const Locale('en'), 1.0),
      (const Locale('en'), 2.0),
      (const Locale('ar'), 2.0),
    ]) {
      testWidgets('renders every section at ${locale.languageCode} x$scale', (
        tester,
      ) async {
        _phone(tester);
        await tester.pumpWidget(_host(_full(), locale: locale, scale: scale));
        await tester.pumpAndSettle();

        expect(find.byType(MuscleFigure), findsOneWidget);
        expect(
          find.byKey(const ValueKey('insights-week-sets')),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('insights-bests')), findsOneWidget);
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('insights-food-logged')),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        expect(
          find.byKey(const ValueKey('insights-food-logged')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('the sets line and the food lines state her figures', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(_host(_full()));
      await tester.pumpAndSettle();

      // 3 glute sets + 4 row sets, weighted by group: the line says a number.
      expect(find.textContaining('Sets in 7 days'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('You logged food on 3 of 7 days'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('You logged food on 3 of 7 days'), findsOneWidget);
      expect(find.text('80 g protein'), findsOneWidget);
      expect(find.text('1,600 kcal'), findsOneWidget);
    });
  });

  group('Insights with nothing yet', () {
    testWidgets('says what will appear, in English and Arabic', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_host(_empty()));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Train once and your body map, records and weekly sets fill in here.',
        ),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.textContaining('Log a meal and your protein'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.textContaining('Log a meal and your protein'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        _host(_empty(), locale: const Locale('ar'), scale: 2.0),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('insights-body-empty')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
