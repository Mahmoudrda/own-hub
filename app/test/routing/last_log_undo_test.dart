// "I did them all" goes to the next move with Undo, the last log of a workout
// keeps five seconds of Undo on R10 that put her back on it, and a coached
// woman with no workout from her coach today still gets her own Today card.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/custom_workout_state.dart';
import 'package:own_hub/app_state/private_coaching_state.dart';
import 'package:own_hub/app_state/workout_session_state.dart';
import 'package:own_hub/domain/clock/app_clock.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/domain/format/day_key.dart';
import 'package:own_hub/domain/training/prescribed_set.dart';
import 'package:own_hub/features/private_coaching/domain/coaching_contract.dart';
import 'package:own_hub/features/train/domain/train_repository.dart';
import 'package:own_hub/main.dart';
import 'package:own_hub/routing/app_router.dart';

import '../features/private_coaching/support/fake_coaching_repository.dart';
import '../features/private_coaching/support/fixtures.dart';
import '../helpers/pause_menu.dart';
import '../qa/round1/round1_harness.dart' show topScreen, wipe;

PlannedMove _move(String id, String name) => PlannedMove(
  exerciseId: id,
  name: name,
  prescriptionLabel: '3 × 10',
  sets: [
    for (var i = 1; i <= 3; i++)
      PrescribedSet(exerciseId: id, order: i, reps: 10),
  ],
);

Future<void> _open(WidgetTester tester, List<PlannedMove> moves) async {
  await tester.pumpWidget(OwnHubApp(key: UniqueKey()));
  await tester.pumpAndSettle();
  CustomWorkoutState.instance.draft = TodayDraft(
    day: WorkoutDay(
      id: 'last-log',
      title: 'Legs',
      summary: '',
      constraints: '',
      moves: moves,
    ),
    dayKey: dayKey(AppClock.now()),
  );
  AppRouter.goTo(tester.element(find.byType(Scaffold).first), 'R07');
  await tester.pumpAndSettle();
}

int _sessionCount() =>
    AppRouter.trainRepository.completedSessions(limit: 100).length;

int _loggedSets() => AppRouter.trainRepository
    .completedSessions(limit: 100)
    .fold<int>(0, (sum, s) => sum + s.sets.length);

void main() {
  final saved = AppRouter.featureFlags;

  setUp(() {
    AppRouter.featureFlags = FeatureFlags.allOff.with_({
      for (final f in Feature.values) f: f != Feature.accountRequired,
    });
    wipe();
  });
  tearDown(() {
    AppRouter.featureFlags = saved;
    CustomWorkoutState.instance.draft = null;
    wipe();
  });

  testWidgets('"I did them all" goes to the next move, and Undo goes back', (
    tester,
  ) async {
    await _open(tester, [
      _move('glute_bridge', 'Glute bridge'),
      _move('dead_bug', 'Dead bug'),
    ]);
    expect(await logWholeMove(tester), isTrue);
    expect(topScreen(tester), 'R07');
    expect(WorkoutSessionState.instance.moveIndex, 1);
    expect(find.text('Dead bug'), findsWidgets);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(WorkoutSessionState.instance.moveIndex, 0);
    expect(topScreen(tester), 'R07');
    await tester.pump(const Duration(seconds: 70));
  });

  testWidgets('"I did them all" on the last move opens R10 with Undo', (
    tester,
  ) async {
    await _open(tester, [_move('glute_bridge', 'Glute bridge')]);
    expect(await logWholeMove(tester), isTrue);
    expect(topScreen(tester), 'R10');
    expect(find.byKey(const ValueKey('r10-undo-last-set')), findsOneWidget);
    // Not finished yet: the window is still open.
    expect(WorkoutSessionState.instance.lastFinished, isNull);

    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(WorkoutSessionState.instance.lastFinished, isNotNull);
    expect(find.byKey(const ValueKey('r10-undo-last-set')), findsNothing);
    expect(find.text('Undo'), findsNothing);
    await tester.pump(const Duration(seconds: 70));
  });

  testWidgets('Undo on R10 puts her back on the last set', (tester) async {
    await _open(tester, [_move('glute_bridge', 'Glute bridge')]);
    for (var set = 1; set <= 3; set++) {
      await tester.tap(find.textContaining('Done'));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      if (set < 3) {
        await tester.pump(const Duration(seconds: 6));
        await tester.tap(find.text("I'm ready, next set"));
        await tester.pumpAndSettle(const Duration(milliseconds: 100));
      }
    }
    expect(topScreen(tester), 'R10');
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    expect(topScreen(tester), 'R07');
    expect(WorkoutSessionState.instance.isComplete, isFalse);
    expect(WorkoutSessionState.instance.setIndex, 2);
    // Nothing finishes behind her back.
    await tester.pump(const Duration(seconds: 6));
    expect(WorkoutSessionState.instance.lastFinished, isNull);
    await tester.pump(const Duration(seconds: 70));
  });

  testWidgets('the app going to the background inside the window saves the '
      'last set', (tester) async {
    await _open(tester, [_move('glute_bridge', 'Glute bridge')]);
    expect(await logWholeMove(tester), isTrue);
    expect(WorkoutSessionState.instance.lastFinished, isNull);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(WorkoutSessionState.instance.lastFinished, isNotNull);
    expect(_loggedSets(), 3);
    await tester.pump(const Duration(seconds: 70));
  });

  testWidgets('the last set reaches the repository once, after the window', (
    tester,
  ) async {
    await _open(tester, [_move('glute_bridge', 'Glute bridge')]);
    expect(await logWholeMove(tester), isTrue);
    expect(_loggedSets(), 0, reason: 'nothing is saved while Undo is open');

    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(_sessionCount(), 1);
    expect(_loggedSets(), 3);
    await tester.pump(const Duration(seconds: 70));
  });

  testWidgets('Undo then log again still saves the last set once', (
    tester,
  ) async {
    await _open(tester, [_move('glute_bridge', 'Glute bridge')]);
    for (var set = 1; set <= 3; set++) {
      await tester.tap(find.textContaining('Done'));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      if (set < 3) {
        await tester.pump(const Duration(seconds: 6));
        await tester.tap(find.text("I'm ready, next set"));
        await tester.pumpAndSettle(const Duration(milliseconds: 100));
      }
    }
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(topScreen(tester), 'R07');

    await tester.tap(find.textContaining('Done'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(_sessionCount(), 1);
    expect(_loggedSets(), 3);
    await tester.pump(const Duration(seconds: 70));
  });

  testWidgets('Done on R10 inside the window finishes at once', (tester) async {
    await _open(tester, [_move('glute_bridge', 'Glute bridge')]);
    expect(await logWholeMove(tester), isTrue);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(WorkoutSessionState.instance.lastFinished, isNotNull);
    expect(topScreen(tester), 'T01');
    await tester.pump(const Duration(seconds: 70));
  });

  testWidgets('a coached woman with no coach workout today has her own card', (
    tester,
  ) async {
    final coaching = FakeCoachingRepository(uid: 'me');
    addTearDown(PrivateCoachingState.instance.stop);
    coaching.clientSubs.value = [
      sub('s1', SubscriptionStatus.active, coachUid: 'c1'),
    ];
    PrivateCoachingState.instance.start(coaching);
    AppRouter.intakeRepository.markSetupDone();
    await tester.runAsync(AppRouter.todayRepository.countWalk);
    await tester.pumpWidget(OwnHubApp(key: UniqueKey()));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('coach-home-start')), findsNothing);
    expect(find.byKey(const ValueKey('coach-home-card')), findsNothing);
    expect(
      find.text("Start, everything's ready", skipOffstage: false),
      findsOneWidget,
    );
  });
}
