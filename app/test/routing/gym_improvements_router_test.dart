// The gym improvements, through the real router: the History button on R07,
// kit-sized weight chips on R08, the plate line, Recent sessions from Insights
// and R02 with an edit that re-works bests, "next time" on R10, and the
// one-time bests backfill at launch.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/bar_preference.dart';
import 'package:own_hub/app_state/custom_workout_state.dart';
import 'package:own_hub/app_state/exercise_library_state.dart';
import 'package:own_hub/app_state/follow_up_state.dart';
import 'package:own_hub/app_state/workout_session_state.dart';
import 'package:own_hub/domain/clock/app_clock.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/domain/format/day_key.dart';
import 'package:own_hub/domain/rewards/personal_best_detector.dart';
import 'package:own_hub/domain/training/prescribed_set.dart';
import 'package:own_hub/features/followup/domain/follow_up_plan.dart' show Feel;
import 'package:own_hub/features/train/domain/exercise_traits.dart';
import 'package:own_hub/features/train/domain/live_best.dart';
import 'package:own_hub/features/train/domain/train_repository.dart';
import 'package:own_hub/features/train/presentation/move_history_sheet.dart';
import 'package:own_hub/main.dart';
import 'package:own_hub/routing/app_router.dart';

NavigatorState _nav(WidgetTester tester) =>
    tester.state<NavigatorState>(find.byType(Navigator).first);

WorkoutDay _day(String id, String name, {required bool loaded}) => WorkoutDay(
  id: 'gym-$id',
  title: 'Legs and glutes',
  summary: '5 minutes, 1 move',
  constraints: '',
  moves: [
    PlannedMove(
      exerciseId: id,
      name: name,
      prescriptionLabel: '3 × 10 at 40 kg',
      needsEquipment: loaded,
      sets: [
        for (var i = 1; i <= 3; i++)
          PrescribedSet(
            exerciseId: id,
            order: i,
            weightKg: loaded ? 40 : null,
            reps: 10,
          ),
      ],
    ),
  ],
);

LoggedSet _logged(String id, int order, double kg, int reps) => LoggedSet(
  prescribed: PrescribedSet(exerciseId: id, order: order, reps: 10),
  outcome: SetOutcome(weightKg: kg, reps: reps),
);

TrainSession _finished(String id, String dateKey) => TrainSession(
  id: id,
  source: SessionSource.live,
  dateKey: dateKey,
  sets: const [],
  completed: true,
  endedReason: EndedReason.finished,
);

/// A first session at 40 kg and a later one with a 140 kg typo.
void _seedTypoHistory() {
  AppRouter.trainRepository.restore(
    sessions: [_finished('s1', '2026-10-01'), _finished('s2', '2026-10-08')],
    flushes: [
      (
        sessionId: 's1',
        exerciseId: 'barbell_hip_thrust',
        sets: [_logged('barbell_hip_thrust', 1, 40, 10)],
      ),
      (
        sessionId: 's2',
        exerciseId: 'barbell_hip_thrust',
        sets: [_logged('barbell_hip_thrust', 1, 140, 10)],
      ),
    ],
  );
}

Future<void> _openR07(
  WidgetTester tester,
  String id,
  String name, {
  bool loaded = true,
}) async {
  await tester.pumpWidget(OwnHubApp(key: UniqueKey()));
  await tester.pumpAndSettle();
  CustomWorkoutState.instance.draft = TodayDraft(
    day: _day(id, name, loaded: loaded),
    dayKey: dayKey(AppClock.now()),
  );
  AppRouter.goTo(tester.element(find.byType(Scaffold).first), 'R07');
  await tester.pumpAndSettle();
}

void main() {
  final saved = AppRouter.featureFlags;
  LiveBest? liveBestAfterFirstSet;

  setUp(() {
    AppRouter.featureFlags = FeatureFlags.allOff.with_({
      for (final f in Feature.values) f: f != Feature.accountRequired,
    });
    WorkoutSessionState.instance.reset();
    ExerciseLibraryState.instance.reset();
    BarPreference.instance.reset();
    AppRouter.trainRepository.restore();
    AppRouter.progressStore.reset();
    AppRouter.personalBestLedger.reset();
    ExerciseTraits.adopt(
      File('assets/content/exercise_traits.json').readAsStringSync(),
    );
  });

  tearDown(() {
    AppRouter.featureFlags = saved;
    WorkoutSessionState.instance.reset();
    ExerciseLibraryState.instance.reset();
    BarPreference.instance.reset();
    CustomWorkoutState.instance.draft = null;
    AppRouter.trainRepository.restore();
    AppRouter.progressStore.reset();
  });

  testWidgets('R07 History opens the move history sheet', (tester) async {
    _seedTypoHistory();
    await _openR07(tester, 'barbell_hip_thrust', 'Barbell hip thrust');

    await tester.tap(find.byKey(const ValueKey('r07-history')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('move-history-close')), findsOneWidget);
    expect(find.byKey(const ValueKey('move-history-row-s2')), findsOneWidget);
    expect(find.byKey(const ValueKey('move-history-row-s1')), findsOneWidget);
    expect(find.text('Barbell hip thrust'), findsWidgets);
    await tester.pump(const Duration(seconds: 10));
  });

  testWidgets('R08 chips step by 2.5 kg for a barbell move', (tester) async {
    await _openR07(tester, 'barbell_hip_thrust', 'Barbell hip thrust');

    await tester.tap(find.byKey(const ValueKey('r07-change')));
    await tester.pumpAndSettle();

    expect(find.text('37.5 kg'), findsOneWidget);
    expect(find.text('40 kg'), findsWidgets);
    expect(find.text('42.5 kg'), findsOneWidget);
    expect(find.text('38 kg'), findsNothing);
    await tester.pump(const Duration(seconds: 10));
  });

  testWidgets('R07 shows the plate line for a barbell move only', (
    tester,
  ) async {
    await _openR07(tester, 'barbell_hip_thrust', 'Barbell hip thrust');
    expect(find.text('20 kg bar + 10 kg each side'), findsOneWidget);
    expect(find.byKey(const ValueKey('plate-diagram')), findsOneWidget);

    WorkoutSessionState.instance.reset();
    await _openR07(tester, 'dumbbell_reverse_lunge', 'Dumbbell reverse lunge');
    expect(find.byKey(const ValueKey('plate-helper')), findsNothing);
    expect(find.textContaining('each side'), findsNothing);
    await tester.pump(const Duration(seconds: 10));
  });

  group('Recent sessions', () {
    Future<void> fixTheTypo(WidgetTester tester) async {
      expect(AppRouter.progressStore.bests['barbell_hip_thrust']?.loadKg, 140);
      final paidBefore = AppRouter.progressStore.rewards;

      await tester.tap(find.byKey(const ValueKey('recent-s2')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('edit-set-1')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('edit-weight')), '45');
      await tester.tap(find.byKey(const ValueKey('edit-save')));
      await tester.pumpAndSettle();

      // The false 140 kg is gone, and nothing was paid or counted.
      final best = AppRouter.progressStore.bests['barbell_hip_thrust'];
      expect(best?.loadKg, 45);
      expect(AppRouter.progressStore.rewards.bestsCount, paidBefore.bestsCount);
      expect(AppRouter.progressStore.rewards.points, paidBefore.points);
      expect(
        AppRouter.trainRepository
            .loggedSetsFor(sessionId: 's2', exerciseId: 'barbell_hip_thrust')
            .single
            .outcome!
            .weightKg,
        45,
      );
    }

    testWidgets('reachable from Insights, and an edit re-works the best', (
      tester,
    ) async {
      _seedTypoHistory();
      AppRouter.sessionBests.backfill(repository: AppRouter.trainRepository);
      await tester.pumpWidget(OwnHubApp(key: UniqueKey()));
      await tester.pumpAndSettle();
      _nav(tester).pushNamed(appDestinations['P01']!.name);
      await tester.pumpAndSettle();

      final entry = find.byKey(const ValueKey('p01-recent-sessions'));
      await tester.scrollUntilVisible(
        entry,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(entry);
      await tester.pumpAndSettle();
      expect(find.text('Recent sessions'), findsWidgets);

      await fixTheTypo(tester);
    });

    testWidgets('reachable from the programme screen (R02)', (tester) async {
      _seedTypoHistory();
      AppRouter.sessionBests.backfill(repository: AppRouter.trainRepository);
      await tester.pumpWidget(OwnHubApp(key: UniqueKey()));
      await tester.pumpAndSettle();
      _nav(tester).pushNamed(appDestinations['R02']!.name);
      await tester.pumpAndSettle();

      final entry = find.byKey(const ValueKey('r02-recent-sessions'));
      await tester.scrollUntilVisible(
        entry,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(entry);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('recent-s2')), findsOneWidget);

      await fixTheTypo(tester);
    });
  });

  testWidgets('R10 shows a next-time line after a weighed session', (
    tester,
  ) async {
    await _openR07(tester, 'barbell_hip_thrust', 'Barbell hip thrust');

    for (var set = 1; set <= 3; set++) {
      await tester.tap(find.textContaining('Done'));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      if (set < 3) {
        await tester.pump(const Duration(seconds: 3));
        await tester.tap(find.text("I'm ready, next set"));
        await tester.pumpAndSettle(const Duration(milliseconds: 100));
      }
    }
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    expect(WorkoutSessionState.instance.isLive, isFalse);
    // She did every set at 40 kg on a barbell move, so the line names the
    // next bar step, the same 42.5 kg the set screen offers.
    expect(find.textContaining('Next time: 42.5 kg on'), findsOneWidget);
    await tester.pump(const Duration(seconds: 70));
  });

  testWidgets('the launch backfill finds the best once and pays nothing', (
    tester,
  ) async {
    await tester.runAsync(() async {
      _seedTypoHistory();
      expect(AppRouter.progressStore.bests, isEmpty);
      final countBefore = AppRouter.progressStore.rewards.bestsCount;
      final pointsBefore = AppRouter.progressStore.rewards.points;

      await prepareMoveBests();
      final found = AppRouter.progressStore.bests['barbell_hip_thrust'];
      expect(found, isNotNull);
      expect(found!.loadKg, 140);
      expect(AppRouter.progressStore.rewards.bestsCount, countBefore);
      expect(AppRouter.progressStore.rewards.points, pointsBefore);

      await prepareMoveBests();
      expect(AppRouter.progressStore.bests['barbell_hip_thrust'], same(found));
      expect(AppRouter.progressStore.rewards.bestsCount, countBefore);
      expect(AppRouter.progressStore.rewards.points, pointsBefore);
    });
  });

  testWidgets('a history sheet opened from a legacy best shows a name', (
    tester,
  ) async {
    AppRouter.progressStore.bests['dead_bug'] = const PersonalBest(
      exerciseId: 'dead_bug',
      metric: BestMetric.reps,
      dateKey: '2026-10-08',
      sessionId: 's2',
      reps: 14,
    );
    await tester.pumpWidget(OwnHubApp(key: UniqueKey()));
    await tester.pumpAndSettle();
    _nav(tester).pushNamed(appDestinations['P03']!.name);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dead bug'));
    await tester.pumpAndSettle();

    final sheet = find.byType(MoveHistoryBody);
    expect(sheet, findsOneWidget);
    expect(
      find.descendant(of: sheet, matching: find.text('Dead bug')),
      findsOneWidget,
    );
    expect(find.text('dead_bug'), findsNothing);
  });

  group('the gym switches', () {
    testWidgets('trainHistory off hides History and Recent sessions', (
      tester,
    ) async {
      AppRouter.featureFlags = AppRouter.featureFlags.with_({
        Feature.trainHistory: false,
      });
      _seedTypoHistory();
      await _openR07(tester, 'barbell_hip_thrust', 'Barbell hip thrust');
      expect(find.byKey(const ValueKey('r07-history')), findsNothing);
      expect(find.byKey(const ValueKey('plate-diagram')), findsOneWidget);

      await tester.pumpWidget(OwnHubApp(key: UniqueKey()));
      await tester.pumpAndSettle();
      _nav(tester).pushNamed(appDestinations['R02']!.name);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('r02-recent-sessions')), findsNothing);
    });

    testWidgets('gymHelpers off hides the plate line and the note', (
      tester,
    ) async {
      AppRouter.featureFlags = AppRouter.featureFlags.with_({
        Feature.gymHelpers: false,
      });
      await _openR07(tester, 'barbell_hip_thrust', 'Barbell hip thrust');
      expect(find.byKey(const ValueKey('plate-diagram')), findsNothing);
      expect(find.byKey(const ValueKey('plate-helper')), findsNothing);
      expect(find.byKey(const ValueKey('r07-note')), findsNothing);
      expect(find.byKey(const ValueKey('r07-history')), findsOneWidget);
    });
  });

  Future<void> doAllSets(WidgetTester tester) async {
    for (var set = 1; set <= 3; set++) {
      await tester.tap(find.textContaining('Done'));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      if (set < 3) {
        await tester.pump(const Duration(seconds: 3));
        if (set == 1) {
          // Past the undo window, so the set has been written.
          await tester.pump(const Duration(seconds: 3));
          liveBestAfterFirstSet = WorkoutSessionState.instance.liveBest;
        }
        await tester.tap(find.text("I'm ready, next set"));
        await tester.pumpAndSettle(const Duration(milliseconds: 100));
      }
    }
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
  }

  group('a split move through a whole session', () {
    testWidgets('a best reaches the live badge, the summary and R10', (
      tester,
    ) async {
      AppRouter.trainRepository.restore(
        sessions: [_finished('s0', '2026-10-01')],
        flushes: [
          (
            sessionId: 's0',
            exerciseId: 'barbell_hip_thrust',
            sets: [_logged('barbell_hip_thrust', 1, 30, 10)],
          ),
        ],
      );
      AppRouter.sessionBests.backfill(repository: AppRouter.trainRepository);
      expect(AppRouter.progressStore.bests['barbell_hip_thrust']!.loadKg, 30);

      await _openR07(tester, 'barbell_hip_thrust', 'Barbell hip thrust');
      await doAllSets(tester);

      expect(liveBestAfterFirstSet, isNotNull);
      final summary = WorkoutSessionState.instance.lastSummary!;
      expect(summary.newBests, isNotEmpty);
      expect(summary.newBests.single.exerciseId, 'barbell_hip_thrust');
      expect(find.textContaining('30 kg × 10'), findsWidgets);
      await tester.pump(const Duration(seconds: 70));
    });

    testWidgets('two very sore days hold the weight on R10', (tester) async {
      final today = AppClock.now();
      for (final back in [1, 2]) {
        FollowUpState.instance.feels[dayKey(
              DateTime(today.year, today.month, today.day - back),
            )] =
            Feel.verySore;
      }
      addTearDown(FollowUpState.instance.feels.clear);

      await _openR07(tester, 'barbell_hip_thrust', 'Barbell hip thrust');
      await doAllSets(tester);

      final next = WorkoutSessionState.instance.lastSummary!.nextTime;
      expect(next.single.rises, isFalse);
      expect(next.single.kg, 40);
      await tester.pump(const Duration(seconds: 70));
    });
  });
}
