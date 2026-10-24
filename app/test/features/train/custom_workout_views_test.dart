// R03's edit controls, the builder, "My workouts" on R01 and the tags on R02.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/custom_workout_state.dart';
import 'package:own_hub/domain/training/prescribed_set.dart';
import 'package:own_hub/features/train/domain/custom_workout.dart';
import 'package:own_hub/features/train/domain/train_repository.dart';
import 'package:own_hub/features/train/presentation/custom_workout_builder_view.dart';
import 'package:own_hub/features/train/presentation/program_view.dart';
import 'package:own_hub/features/train/presentation/train_view.dart';
import 'package:own_hub/features/train/presentation/workout_day_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/theme/app_tokens.dart';
import 'package:own_hub/ui/app_button.dart';

Widget _host(
  Widget child, {
  Locale locale = const Locale('en'),
  GlobalKey<NavigatorState>? navigator,
}) => MaterialApp(
  navigatorKey: navigator,
  locale: locale,
  localizationsDelegates: AppL10n.localizationsDelegates,
  supportedLocales: AppL10n.supportedLocales,
  theme: buildTheme(locale),
  onGenerateRoute: (settings) => MaterialPageRoute<void>(
    settings: settings,
    builder: (_) => settings.name == '/' || settings.name == null
        ? child
        : Text('opened ${settings.name}'),
  ),
);

PlannedMove _move(String id, String name, {int sets = 3, int reps = 10}) =>
    PlannedMove(
      exerciseId: id,
      name: name,
      prescriptionLabel: '$sets × $reps',
      needsEquipment: id == 'goblet_squat',
      sets: [
        for (var i = 1; i <= sets; i++)
          PrescribedSet(exerciseId: id, order: i, reps: reps),
      ],
    );

final _day = WorkoutDay(
  id: '2026-10-20',
  title: 'Legs',
  summary: '15 minutes, 3 moves',
  constraints: '',
  moves: [
    _move('donkey_kick', 'Donkey kick'),
    _move('goblet_squat', 'Goblet squat'),
    _move('glute_bridge', 'Glute bridge'),
  ],
);

Widget _r03({
  required List<List<PlannedMove>> edits,
  Future<List<PlannedMove>?> Function()? pick,
  ValueChanged<List<PlannedMove>>? saveAsMine,
  Future<List<MoveAlternative>> Function(String)? alternatives,
}) => WorkoutDayView(
  day: _day,
  onMovesChanged: edits.add,
  onPickMoves: pick,
  onSaveAsMine: saveAsMine,
  alternativesFor: alternatives,
);

/// Taps move [i], and Sets and reps when the move offers more than one thing.
Future<void> _openEditor(WidgetTester tester, int i) async {
  await tester.tap(find.byKey(ValueKey('r03-move-$i')));
  await tester.pumpAndSettle();
  final sets = find.byKey(const ValueKey('r03-move-Sets and reps'));
  if (sets.evaluate().isNotEmpty) {
    await tester.tap(sets);
    await tester.pumpAndSettle();
  }
}

void main() {
  setUp(CustomWorkoutState.instance.reset);

  void tall(WidgetTester tester) {
    tester.view.physicalSize = const Size(1170, 4200);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
  }

  group('R03 before she starts', () {
    testWidgets('+ Add a move adds the picked moves to today', (tester) async {
      tall(tester);
      final edits = <List<PlannedMove>>[];
      await tester.pumpWidget(
        _host(
          _r03(edits: edits, pick: () async => [_move('dead_bug', 'Dead bug')]),
        ),
      );
      await tester.pumpAndSettle();

      // Add is part of Edit moves, in the "…".
      expect(find.byKey(const ValueKey('r03-add')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('overflow-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('overflow-row-Edit moves')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('r03-add')));
      await tester.tap(find.byKey(const ValueKey('r03-add')));
      await tester.pumpAndSettle();

      expect(find.text('Dead bug'), findsOneWidget);
      expect(edits.last.map((m) => m.exerciseId), [
        'donkey_kick',
        'goblet_squat',
        'glute_bridge',
        'dead_bug',
      ]);
      expect(find.text('Changes here are for today only'), findsOneWidget);
    });

    testWidgets('Remove takes a move out, and Undo puts it back', (
      tester,
    ) async {
      tall(tester);
      final edits = <List<PlannedMove>>[];
      await tester.pumpWidget(_host(_r03(edits: edits)));
      await tester.pumpAndSettle();

      await _openEditor(tester, 1);
      await tester.tap(find.byKey(const ValueKey('edit-remove')));
      await tester.pumpAndSettle();
      expect(find.text('Goblet squat'), findsNothing);
      expect(edits.last.map((m) => m.exerciseId), [
        'donkey_kick',
        'glute_bridge',
      ]);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(find.text('Goblet squat'), findsOneWidget);
      expect(edits.last.map((m) => m.exerciseId), [
        'donkey_kick',
        'goblet_squat',
        'glute_bridge',
      ]);
      // The bus keeps its five seconds; let them run out.
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('the last move cannot be removed', (tester) async {
      tall(tester);
      final edits = <List<PlannedMove>>[];
      await tester.pumpWidget(
        _host(
          WorkoutDayView(
            day: WorkoutDay(
              id: _day.id,
              title: 'One',
              summary: '',
              constraints: '',
              moves: [_move('donkey_kick', 'Donkey kick')],
            ),
            onMovesChanged: edits.add,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _openEditor(tester, 0);
      expect(find.byKey(const ValueKey('edit-remove')), findsNothing);
    });

    testWidgets('sets, reps and weight edit inline and stay in bounds', (
      tester,
    ) async {
      tall(tester);
      final edits = <List<PlannedMove>>[];
      await tester.pumpWidget(_host(_r03(edits: edits)));
      await tester.pumpAndSettle();

      await _openEditor(tester, 1);
      await tester.tap(find.byKey(const ValueKey('edit-sets-up')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('edit-reps-down')));
      await tester.pumpAndSettle();
      final squat = edits.last[1];
      expect(squat.sets, hasLength(4));
      expect(squat.sets.first.reps, 9);
      expect(find.text('4 × 9'), findsOneWidget);

      // A weight starts at the minimum and the minus button takes it back to
      // bodyweight.
      await tester.tap(find.byKey(const ValueKey('edit-weight-up')));
      await tester.pumpAndSettle();
      expect(edits.last[1].sets.first.weightKg, kMinWeightKg);
      await tester.tap(find.byKey(const ValueKey('edit-weight-down')));
      await tester.pumpAndSettle();
      expect(edits.last[1].sets.first.weightKg, isNull);

      // Nine more taps cannot pass the ceiling of ten sets.
      for (var i = 0; i < 9; i++) {
        await tester.tap(find.byKey(const ValueKey('edit-sets-up')));
        await tester.pump();
      }
      expect(edits.last[1].sets, hasLength(kMaxSets));
      final up = tester.widget<IconButton>(
        find.byKey(const ValueKey('edit-sets-up')),
      );
      expect(up.onPressed, isNull);
    });

    testWidgets('a hold switches to seconds', (tester) async {
      tall(tester);
      final edits = <List<PlannedMove>>[];
      await tester.pumpWidget(_host(_r03(edits: edits)));
      await tester.pumpAndSettle();
      await _openEditor(tester, 0);
      await tester.tap(find.text('Seconds'));
      await tester.pumpAndSettle();
      expect(edits.last.first.sets.first.holdSeconds, 30);
      expect(edits.last.first.sets.first.reps, isNull);
    });

    testWidgets('Swap uses the swap sheet and Undo restores the move', (
      tester,
    ) async {
      tall(tester);
      final edits = <List<PlannedMove>>[];
      await tester.pumpWidget(
        _host(
          _r03(
            edits: edits,
            alternatives: (id) async => const [
              MoveAlternative(
                exerciseId: 'step_up',
                name: 'Step up',
                reason: 'Easier on the knees',
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      await _openEditor(tester, 1);
      await tester.tap(find.byKey(const ValueKey('edit-swap')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Swap it'));
      await tester.pumpAndSettle();

      expect(edits.last[1].exerciseId, 'step_up');
      expect(edits.last[1].sets, hasLength(3));
      expect(find.text('Step up'), findsWidgets);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(edits.last[1].exerciseId, 'goblet_squat');
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('Save as my workout hands over today\'s moves', (tester) async {
      tall(tester);
      final edits = <List<PlannedMove>>[];
      final saved = <List<PlannedMove>>[];
      await tester.pumpWidget(_host(_r03(edits: edits, saveAsMine: saved.add)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('overflow-menu')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('overflow-row-Save as my workout')),
      );
      await tester.pumpAndSettle();
      expect(saved.single.map((m) => m.exerciseId), [
        'donkey_kick',
        'goblet_squat',
        'glute_bridge',
      ]);
    });

    testWidgets('without the callbacks R03 stays read-only', (tester) async {
      tall(tester);
      await tester.pumpWidget(_host(WorkoutDayView(day: _day)));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('r03-add')), findsNothing);
      expect(find.byKey(const ValueKey('overflow-menu')), findsNothing);
      expect(find.byKey(const ValueKey('r03-edit-0')), findsNothing);
    });
  });

  group('the builder', () {
    Widget builder({
      required List<(String, List<PlannedMove>)> started,
      required List<(String, List<PlannedMove>)> saved,
      List<PlannedMove> initial = const [],
    }) => CustomWorkoutBuilderView(
      initialMoves: initial,
      onPickMoves: () async => [_move('dead_bug', 'Dead bug')],
      onSave: (name, moves) {
        saved.add((name, moves));
        return true;
      },
      onStartNow: (name, moves) => started.add((name, moves)),
    );

    testWidgets('Start and Save wait for a move', (tester) async {
      tall(tester);
      await tester.pumpWidget(_host(builder(started: [], saved: [])));
      await tester.pumpAndSettle();
      for (final key in ['build-start', 'build-save']) {
        expect(
          tester.widget<AppButton>(find.byKey(ValueKey(key))).onPressed,
          isNull,
        );
      }
    });

    testWidgets('add, name, start now', (tester) async {
      tall(tester);
      final started = <(String, List<PlannedMove>)>[];
      await tester.pumpWidget(_host(builder(started: started, saved: [])));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('build-add')));
      await tester.pumpAndSettle();
      expect(find.text('Dead bug'), findsOneWidget);

      await tester.enterText(find.byKey(const ValueKey('build-name')), 'Mine');
      await tester.tap(find.byKey(const ValueKey('build-start')));
      await tester.pumpAndSettle();
      expect(started.single.$1, 'Mine');
      expect(started.single.$2.single.exerciseId, 'dead_bug');
    });

    testWidgets('save keeps an empty name empty for the caller to fill', (
      tester,
    ) async {
      tall(tester);
      final saved = <(String, List<PlannedMove>)>[];
      await tester.pumpWidget(
        _host(
          builder(
            started: [],
            saved: saved,
            initial: [_move('dead_bug', 'Dead bug'), _move('plank', 'Plank')],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Reorder, then save.
      await tester.tap(find.text('Dead bug'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('edit-later')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('build-save')));
      await tester.pumpAndSettle();
      expect(saved.single.$1, isEmpty);
      expect(saved.single.$2.map((m) => m.exerciseId), ['plank', 'dead_bug']);
    });

    testWidgets('a save the cap refuses is not announced as saved', (
      tester,
    ) async {
      tall(tester);
      var asked = 0;
      await tester.pumpWidget(
        _host(
          CustomWorkoutBuilderView(
            initialMoves: [_move('dead_bug', 'Dead bug')],
            onPickMoves: () async => null,
            onSave: (name, moves) {
              asked++;
              return false;
            },
            onStartNow: (name, moves) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('build-save')));
      await tester.pumpAndSettle();
      expect(asked, 1);
      expect(find.text('Saved to your workouts'), findsNothing);
      expect(find.byKey(const ValueKey('build-save')), findsOneWidget);
    });

    testWidgets('a save that happens says so', (tester) async {
      tall(tester);
      await tester.pumpWidget(
        _host(
          builder(
            started: [],
            saved: [],
            initial: [_move('dead_bug', 'Dead bug')],
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('build-save')));
      await tester.pump();
      expect(find.text('Saved to your workouts'), findsOneWidget);
    });

    testWidgets('remove offers Undo', (tester) async {
      tall(tester);
      await tester.pumpWidget(
        _host(
          builder(
            started: [],
            saved: [],
            initial: [_move('dead_bug', 'Dead bug'), _move('plank', 'Plank')],
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Plank'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('edit-remove')));
      await tester.pumpAndSettle();
      expect(find.text('Plank'), findsNothing);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(find.text('Plank'), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
    });
  });

  group('My workouts on R01', () {
    final mine = CustomWorkout(
      id: 'wa',
      name: 'Thursday legs',
      moves: const [CustomMove(exerciseId: 'goblet_squat', sets: 3, reps: 8)],
    );

    testWidgets('lists them, and start, edit and delete reach the caller', (
      tester,
    ) async {
      tall(tester);
      final log = <String>[];
      await tester.pumpWidget(
        _host(
          TrainView(
            myWorkouts: [mine],
            onBuildOwn: () => log.add('build'),
            onStartMine: (w) => log.add('start ${w.id}'),
            onEditMine: (w) => log.add('edit ${w.id}'),
            onDeleteMine: (w) => log.add('delete ${w.id}'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      Future<void> tapKey(String key) async {
        await tester.ensureVisible(find.byKey(ValueKey(key)));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(ValueKey(key)));
        await tester.pump();
      }

      // Her list opens from the "My workouts" row.
      expect(find.text('Thursday legs'), findsNothing);
      await tapKey('r01-open-my-workouts');
      await tester.pumpAndSettle();
      expect(find.text('Thursday legs'), findsOneWidget);
      await tapKey('r01-build-own');
      await tapKey('r01-mine-wa');
      await tapKey('r01-mine-edit-wa');
      await tapKey('r01-mine-delete-wa');
      expect(log, ['build', 'start wa', 'edit wa', 'delete wa']);
    });

    testWidgets('with none saved, no heading is drawn', (tester) async {
      tall(tester);
      await tester.pumpWidget(_host(TrainView(onBuildOwn: () {})));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('r01-my-workouts')), findsNothing);
    });

    testWidgets('start opens R03 on the saved moves; delete has Undo', (
      tester,
    ) async {
      tall(tester);
      final nav = GlobalKey<NavigatorState>();
      late BuildContext inner;
      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) {
              inner = context;
              return Scaffold(
                body: Column(
                  children: [
                    TextButton(
                      onPressed: () => AppRouter.startMyWorkout(context, mine),
                      child: const Text('go'),
                    ),
                    TextButton(
                      onPressed: () => AppRouter.deleteMyWorkout(context, mine),
                      child: const Text('del'),
                    ),
                  ],
                ),
              );
            },
          ),
          navigator: nav,
        ),
      );
      await tester.pumpAndSettle();
      final state = CustomWorkoutState.instance;
      state.save(mine);

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(find.textContaining('opened /'), findsOneWidget);
      final pinned = state.draft!;
      expect(pinned.baseKey, isNull, reason: 'pinned over the plan');
      expect(pinned.customId, 'wa');
      expect(pinned.day.title, 'Thursday legs');
      expect(pinned.day.moves.single.sets, hasLength(3));
      expect(pinned.day.moves.single.sets.first.reps, 8);
      nav.currentState!.pop();
      await tester.pumpAndSettle();

      await tester.tap(find.text('del'));
      await tester.pumpAndSettle();
      expect(state.workouts, isEmpty);
      expect(state.draft, isNull, reason: 'a deleted workout is unpinned');
      expect(inner.mounted, isTrue);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(state.workouts.map((w) => w.id), ['wa']);
      expect(state.deletedIds, isEmpty);
      await tester.pump(const Duration(seconds: 6));
    });
  });

  group('R02', () {
    testWidgets('finished sessions say Completed, the next says Up next', (
      tester,
    ) async {
      tall(tester);
      await tester.pumpWidget(
        _host(
          const ProgramView(
            days: [
              ProgramDay(title: 'Day 1 · Legs', done: true),
              ProgramDay(title: 'Day 2 · Upper', today: true),
              ProgramDay(title: 'Day 3 · Core'),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('Up next'), findsOneWidget);
    });
  });
}
