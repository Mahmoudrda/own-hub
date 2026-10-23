// The tour's sample: every write refused, the refusal reported, and the
// sample exactly as it was afterwards.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/domain/logging/log_command_bus.dart';
import 'package:own_hub/domain/training/prescribed_set.dart';
import 'package:own_hub/domain/week/week_key.dart';
import 'package:own_hub/features/eat/data/seeded_recipe_library.dart';
import 'package:own_hub/features/eat/domain/meal_repository.dart';
import 'package:own_hub/features/signup/demo/demo_sample.dart';
import 'package:own_hub/features/signup/presentation/look_around_view.dart';
import 'package:own_hub/features/today/domain/today_day.dart';
import 'package:own_hub/features/today/domain/today_repository.dart';
import 'package:own_hub/features/train/domain/train_repository.dart';
import 'package:own_hub/features/train/presentation/workout_day_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/theme/app_tokens.dart';

/// Lets the microtasks a refused write schedules run, without waiting on a
/// future that is designed never to complete.
Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  final now = DateTime(2026, 10, 6, 10);
  late DemoSample sample;
  late int heard;

  setUp(() {
    sample = DemoSample.build(now: now);
    heard = 0;
    sample.refusals.listener = () => heard++;
  });
  tearDown(() => sample.dispose());

  group('Today', () {
    test('the sample day: a week under way, no programme week', () {
      final day = sample.today.day;
      expect(day.isDayOne, isFalse);
      expect(day.week.sessionsLogged, 1);
      expect(day.walkToCount, isTrue);
      expect(day.showCycleCard, isFalse);
      expect(day.programWeek, isNull);
      expect(day.programTotalWeeks, isNull);
      expect(day.date, now);
    });

    test('every write is refused and changes nothing', () async {
      final before = sample.today.day;
      final writes = <Future<void> Function()>[
        sample.today.countWalk,
        () => sample.today.logRecalledSession(
          const RecalledSession(id: 'recalled-x', title: 'x'),
        ),
        () => sample.today.completeStep(FirstWeekStep.finishSession),
        () async => sample.today.recordMeal(at: now),
        () async => sample.today.recordSession('live-1'),
      ];
      for (final write in writes) {
        await write();
      }
      expect(heard, writes.length);
      expect(sample.refusals.count, writes.length);
      expect(identical(sample.today.day, before), isTrue);
      expect(sample.today.creditedSessions, isEmpty);
    });

    test('a notice is not her data: dismissing one asks nothing', () async {
      await sample.today.markNoticeSeen(NoticeKind.quietWeek, WeekKey.of(now));
      expect(heard, 0);
      expect(sample.today.seenNotices, isEmpty);
    });
  });

  group('Train', () {
    test('every write is refused and nothing is kept', () async {
      final day = sampleWorkoutDay(lookupAppL10n(const Locale('en')));

      // These hand back a session, so they never complete. Not awaited.
      final pending = <Future<TrainSession>>[
        sample.train.startSession(day),
        sample.train.finishSession(sessionId: 's', durationSec: 60),
        sample.train.logRecalled(
          dateKey: '2026-10-06',
          method: RecallMethod.plan,
        ),
        sample.train.logUnplanned(
          dateKey: '2026-10-06',
          activity: 'walk',
          durationSec: 600,
        ),
      ];
      var completed = 0;
      var failed = 0;
      for (final future in pending) {
        future.then((_) => completed++, onError: (_) => failed++);
      }
      await sample.train.flushMove(
        sessionId: 's',
        exerciseId: 'glute_bridge',
        sets: [LoggedSet(prescribed: day.moves.first.sets.first)],
      );
      await sample.train.swapMove(
        sessionId: 's',
        fromExerciseId: 'glute_bridge',
        toExerciseId: 'dead_bug',
      );
      await _settle();

      expect(heard, 6);
      expect(completed, 0, reason: 'nothing to hand back');
      expect(failed, 0, reason: 'a failure nobody awaits is a crash report');
      expect(sample.train.sessions, isEmpty);
      expect(sample.train.flushes, isEmpty);
      expect(sample.train.swaps, isEmpty);
      expect(sample.train.liveSessionId, isNull);
    });
  });

  group('Eat', () {
    test("the sample week's dinners are there to read", () async {
      final plan = await sample.meal.mealPlan(WeekKey.of(now).id);
      expect(plan, isNotNull);
      expect(plan!.dinners, hasLength(5));
    });

    test('every write is refused and changes nothing', () async {
      final weekId = WeekKey.of(now).id;
      final before = await sample.meal.mealPlan(weekId);
      await sample.meal.swapDinner(
        weekId: weekId,
        day: PlanDay.mon,
        recipeId: 'koshari_portioned',
      );
      await sample.meal.tickGrocery(
        weekId: weekId,
        itemKey: before!.groceries.keys.first,
        ticked: true,
      );
      await sample.meal.applyLog(
        MealWrite.skipSlot(
          dayId: '2026-10-06',
          slot: MealSlot.breakfast,
          tz: 'Africa/Cairo',
          libVersion: 1,
        ),
      );
      expect(heard, 3);
      expect(identical(await sample.meal.mealPlan(weekId), before), isTrue);
      expect(sample.meal.writes, isEmpty);
      expect(sample.meal.store.days, isEmpty);
    });
  });

  group('the undo bus', () {
    test('a log is taken back the moment it is made, and never written', () {
      var committed = 0;
      final handle = sample.bus.submit(
        UndoableLog(describe: 'set', commit: () async => committed++),
      );
      expect(sample.bus.isPending(handle), isFalse);
      expect(handle.undo(), isFalse, reason: 'already withdrawn');
      expect(heard, 1);
      expect(committed, 0);
    });
  });

  group('the workout player in the tour', () {
    testWidgets('logging a set leaves nothing logged', (tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      final saved = AppRouter.featureFlags;
      AppRouter.featureFlags = FeatureFlags.allOff.with_(const {
        Feature.accountRequired: true,
        Feature.signUp: true,
        Feature.appTour: true,
        Feature.today: true,
        Feature.firstWeek: true,
        Feature.quietWeek: true,
        Feature.tiers: true,
        Feature.lockScreenNudge: true,
        Feature.train: true,
        Feature.recordFromMemory: true,
        Feature.program: true,
        Feature.exerciseVideo: true,
        Feature.exerciseSwap: true,
        Feature.followAlong: true,
        Feature.workoutLibrary: true,
        Feature.trainingReminders: true,
        Feature.eat: true,
        Feature.recipes: true,
        Feature.weekPlan: true,
        Feature.groceryList: true,
        Feature.progress: true,
        Feature.milestones: true,
        Feature.personalBests: true,
        Feature.bodyPrivately: true,
        Feature.shareCard: true,
        Feature.cycle: true,
        Feature.cycleMeals: true,
        Feature.cycleCalendar: true,
        Feature.cyclePatterns: true,
      });
      addTearDown(() => AppRouter.featureFlags = saved);
      final book = await tester.runAsync(
        () => SeededRecipeLibrary(
          readAsset: (path) async => File(path).readAsString(),
        ).load(),
      );
      sample.book = book;
      sample.refusals.listener = null;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          theme: buildTheme(const Locale('en')),
          home: LookAroundView(sample: sample, initialStop: 2),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Done · 12 reps'));
      await tester.pumpAndSettle();
      // Past the five seconds a real log would wait before its write.
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();

      expect(find.text('Join to make this yours'), findsOneWidget);
      expect(sample.train.flushes, isEmpty);
      expect(sample.train.sessions, isEmpty);
      expect(sample.refusals.count, greaterThan(0));
    });
  });
}
