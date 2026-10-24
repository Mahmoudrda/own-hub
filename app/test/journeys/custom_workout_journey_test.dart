// Her own workouts, walked through the real app: edit today on R03, save it as
// hers, start it, finish it, and see it count toward the week.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/custom_workout_state.dart';
import 'package:own_hub/app_state/workout_session_state.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/features/train/domain/custom_workout.dart';
import 'package:own_hub/main.dart';
import 'package:own_hub/routing/app_router.dart';

import '../helpers/pause_menu.dart';

Future<void> _open(WidgetTester tester, String id) async {
  tester.view.physicalSize = const Size(1170, 4200);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(OwnHubApp(key: UniqueKey()));
  await tester.pumpAndSettle();
  tester
      .state<NavigatorState>(find.byType(Navigator).first)
      .pushNamed(appDestinations[id]!.name);
  await tester.pumpAndSettle();
}

int get _weekOnHome => AppRouter.todayRepository.day.week.sessionsLogged;

void main() {
  final saved = AppRouter.featureFlags;
  final state = CustomWorkoutState.instance;

  setUp(() {
    AppRouter.featureFlags = FeatureFlags.allOff.with_({
      for (final f in Feature.values) f: f != Feature.accountRequired,
    });
    WorkoutSessionState.instance.reset();
    state.reset();
  });

  tearDown(() {
    AppRouter.featureFlags = saved;
    WorkoutSessionState.instance.reset();
    state.reset();
  });

  testWidgets('edits on R03 are what the session starts with, once', (
    tester,
  ) async {
    await _open(tester, 'R03');
    // Move 0 offers Sets and reps (and more), in the sheet its row opens.
    await tester.tap(find.byKey(const ValueKey('r03-move-0')));
    await tester.pumpAndSettle();
    final sets = find.byKey(const ValueKey('r03-move-Sets and reps'));
    if (sets.evaluate().isNotEmpty) {
      await tester.tap(sets);
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byKey(const ValueKey('edit-sets-up')));
    await tester.pumpAndSettle();

    final draft = state.draft!;
    expect(draft.day.moves.first.sets, hasLength(4));
    expect(draft.dayKey, isNotEmpty);

    await tester.tap(find.textContaining('Start'));
    await tester.pumpAndSettle();
    expect(WorkoutSessionState.instance.moves.first.sets, hasLength(4));
    expect(state.draft, isNull, reason: 'cleared when the session starts');
    expect(
      state.workouts,
      isEmpty,
      reason: 'nothing is saved unless she taps Save as my workout',
    );
  });

  testWidgets('Save as my workout keeps a copy under her name', (tester) async {
    await _open(tester, 'R03');
    await tester.tap(find.byKey(const ValueKey('overflow-menu')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('overflow-row-Save as my workout')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('name-sheet-field')),
      'Home legs',
    );
    await tester.tap(find.byKey(const ValueKey('name-sheet-save')));
    await tester.pumpAndSettle();

    expect(state.workouts, hasLength(1));
    expect(state.workouts.single.name, 'Home legs');
    expect(state.workouts.single.moves.first.exerciseId, 'donkey_kick');
    expect(state.draft?.customId, state.workouts.single.id);
    expect(find.text('Saved to your workouts'), findsOneWidget);
  });

  testWidgets('a saved workout started from My workouts counts for the week', (
    tester,
  ) async {
    final before = _weekOnHome;
    state.save(
      const CustomWorkout(
        id: 'mine1',
        name: 'Two minute core',
        moves: [
          CustomMove(exerciseId: 'dead_bug', sets: 1, reps: 6),
          CustomMove(exerciseId: 'donkey_kick', sets: 1, reps: 6),
        ],
      ),
    );
    await _open(tester, 'R01');
    // Her list opens from the "My workouts" row.
    await tester.tap(find.byKey(const ValueKey('r01-open-my-workouts')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('r01-mine-mine1')));
    await tester.tap(find.byKey(const ValueKey('r01-mine-mine1')));
    await tester.pumpAndSettle();
    expect(find.text('Two minute core'), findsWidgets);

    await tester.tap(find.textContaining('Start'));
    await tester.pumpAndSettle();
    expect(WorkoutSessionState.instance.day?.title, 'Two minute core');

    var guard = 0;
    while (!WorkoutSessionState.instance.isComplete && guard++ < 12) {
      if (!await logWholeMove(tester)) break;
    }
    if (WorkoutSessionState.instance.day != null) await finishEarly(tester);

    expect(_weekOnHome, before + 1, reason: 'a custom session is a session');
    expect(state.draft, isNull);
  });

  testWidgets('"Build my own workout" from setup opens the builder on Train', (
    tester,
  ) async {
    state.builderRequested = true;
    await _open(tester, 'R01');
    expect(find.byKey(const ValueKey('build-add')), findsOneWidget);
    expect(state.builderRequested, isFalse, reason: 'one use');
  });
}
