// A workout of her own is screened for her life stage every time it is
// started, edited or folded into today, and Undo cannot outlive Start.

import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/custom_workout_state.dart';
import 'package:own_hub/app_state/exercise_library_state.dart';
import 'package:own_hub/domain/clock/app_clock.dart';
import 'package:own_hub/domain/training/prescribed_set.dart';
import 'package:own_hub/features/onboarding/domain/intake.dart';
import 'package:own_hub/features/train/domain/custom_workout.dart';
import 'package:own_hub/features/train/domain/exercise_library.dart';
import 'package:own_hub/features/train/domain/train_repository.dart';
import 'package:own_hub/features/train/presentation/authored_workout.dart';
import 'package:own_hub/features/train/presentation/custom_workout_builder_view.dart';
import 'package:own_hub/features/train/presentation/move_editor.dart';
import 'package:own_hub/features/train/presentation/move_picker_view.dart';
import 'package:own_hub/features/train/presentation/workout_day_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/l10n/app_l10n_en.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/theme/app_tokens.dart';
import 'package:own_hub/ui/app_button.dart';

import '../../helpers/exercise_library_fixture.dart';

Widget _host(Widget child) => MaterialApp(
  localizationsDelegates: AppL10n.localizationsDelegates,
  supportedLocales: AppL10n.supportedLocales,
  theme: buildTheme(const Locale('en')),
  onGenerateRoute: (settings) => MaterialPageRoute<void>(
    settings: settings,
    builder: (_) =>
        settings.name == '/' ? child : Text('opened ${settings.name}'),
  ),
);

void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 4200);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

PlannedMove _move(String id) => PlannedMove(
  exerciseId: id,
  name: id,
  prescriptionLabel: '3 × 10',
  sets: [
    for (var i = 1; i <= 3; i++)
      PrescribedSet(exerciseId: id, order: i, reps: 10),
  ],
);

void main() {
  final state = CustomWorkoutState.instance;
  late String blocked;
  late String allowed;

  setUp(() async {
    state.reset();
    ExerciseLibraryState.instance.reset();
    ExerciseLibraryState.instance.media = FakeExerciseMedia();
    ExerciseLibraryState.instance.library = sampleExerciseLibrary();
    final all = ExerciseLibraryState.instance.library.exercises;
    final shown = screenForLifeStage(all, LifeStage.pregnant).shown;
    blocked = all.firstWhere((e) => !shown.contains(e)).id;
    allowed = shown.first.id;
    await AppRouter.intakeRepository.merge(lifeStage: LifeStage.none);
  });

  tearDown(() async {
    state.reset();
    ExerciseLibraryState.instance.reset();
    await AppRouter.intakeRepository.merge(lifeStage: LifeStage.none);
  });

  test('blockedMoveIds names what her stage holds back, nothing otherwise', () {
    final all = ExerciseLibraryState.instance.library.exercises;
    final ids = [blocked, allowed, 'not_in_the_library'];
    expect(blockedMoveIds(ids, all, LifeStage.none), isEmpty);
    expect(blockedMoveIds(ids, all, LifeStage.pregnant), {
      blocked,
      'not_in_the_library',
    });
  });

  test('the picker offers only screened moves', () {
    final shown = ExerciseLibraryState.instance
        .screenedFor(LifeStage.pregnant)
        .shown;
    expect(shown.map((e) => e.id), isNot(contains(blocked)));
    expect(shown.map((e) => e.id), contains(allowed));
  });

  testWidgets('a saved move her stage now blocks is not started', (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (c) {
            context = c;
            return const Scaffold();
          },
        ),
      ),
    );
    await AppRouter.intakeRepository.merge(lifeStage: LifeStage.pregnant);
    final mine = CustomWorkout(
      id: 'wa',
      name: 'Mine',
      moves: [
        CustomMove(exerciseId: blocked, reps: 10),
        CustomMove(exerciseId: allowed, reps: 10),
      ],
    );
    AppRouter.startMyWorkout(context, mine);
    await tester.pump(const Duration(milliseconds: 300));
    expect(state.draft!.day.moves.map((m) => m.exerciseId), [allowed]);
    expect(find.text(AppL10nEn().weLeftOutMovesThatDoNot), findsOneWidget);
    state.reset();

    final onlyBlocked = CustomWorkout(
      id: 'wb',
      name: 'Blocked',
      moves: [CustomMove(exerciseId: blocked, reps: 10)],
    );
    AppRouter.startMyWorkout(context, onlyBlocked);
    await tester.pump(const Duration(milliseconds: 300));
    expect(state.draft, isNull, reason: 'nothing left, so nothing starts');
    expect(find.text(AppL10nEn().noneOfTheseMovesSuitYouRight), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('a pinned draft is screened before it is offered', (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (c) {
            context = c;
            return const Scaffold();
          },
        ),
      ),
    );
    await AppRouter.intakeRepository.merge(lifeStage: LifeStage.pregnant);
    state.pin(
      customWorkoutDay(
        AppL10n.of(context),
        name: 'Mine',
        moves: [_move(blocked), _move(allowed)],
        now: AppClock.now(),
      ),
      customId: 'wa',
    );
    final day = AppRouter.chosenWorkoutDay(context)!;
    expect(day.moves.map((m) => m.exerciseId), [allowed]);
  });

  testWidgets('Undo is gone once Start is tapped, and ignored off-screen', (
    tester,
  ) async {
    _tall(tester);
    var started = 0;
    final day = WorkoutDay(
      id: '2026-10-20',
      title: 'Legs',
      summary: '',
      constraints: '',
      moves: [_move('a'), _move('b')],
    );
    final edits = <List<PlannedMove>>[];
    await tester.pumpWidget(
      _host(
        WorkoutDayView(
          day: day,
          onMovesChanged: edits.add,
          onStart: () => started++,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('r03-edit-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('edit-remove')));
    await tester.pumpAndSettle();
    expect(find.text('Undo'), findsOneWidget);
    final before = edits.length;

    // The undo bar floats over the button, so call what the button does.
    tester
        .widget<AppButton>(
          find.ancestor(
            of: find.textContaining('Start'),
            matching: find.byType(AppButton),
          ),
        )
        .onPressed!();
    await tester.pumpAndSettle();
    expect(started, 1);
    expect(find.text('Undo'), findsNothing);
    expect(edits.length, before, reason: 'no edit after Start');
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('Swap is hidden when the move has nothing to swap to', (
    tester,
  ) async {
    _tall(tester);
    final day = WorkoutDay(
      id: '2026-10-20',
      title: 'Legs',
      summary: '',
      constraints: '',
      moves: [_move('a'), _move('b')],
    );
    await tester.pumpWidget(
      _host(
        WorkoutDayView(
          day: day,
          onMovesChanged: (_) {},
          canSwapMove: (id) => id == 'b',
          editedToday: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(AppL10nEn().changesHereAreForTodayOnly), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('r03-edit-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('edit-swap')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('r03-edit-0')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('edit-swap')), findsNothing);
  });

  testWidgets('a bodyweight move says so, and steppers name their row', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        Scaffold(
          body: MoveEditor(
            move: const CustomMove(exerciseId: 'a', reps: 10),
            showWeight: true,
            onChanged: (_) {},
          ),
        ),
      ),
    );
    expect(find.text(AppL10nEn().bodyweight), findsOneWidget);
    expect(find.byTooltip('Decrease Sets'), findsOneWidget);
    expect(find.byTooltip('Increase Weight'), findsOneWidget);
  });

  testWidgets('Back with unsaved moves asks first, in the app\'s own sheet', (
    tester,
  ) async {
    _tall(tester);
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: nav,
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        theme: buildTheme(const Locale('en')),
        home: const Scaffold(body: Text('home')),
      ),
    );
    unawaited(
      nav.currentState!.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => CustomWorkoutBuilderView(
            onPickMoves: () async => [_move('dead_bug')],
            onSave: (_, _) => true,
            onStartNow: (_, _) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Nothing changed: Back just goes.
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);

    unawaited(
      nav.currentState!.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => CustomWorkoutBuilderView(
            onPickMoves: () async => [_move('dead_bug')],
            onSave: (_, _) => true,
            onStartNow: (_, _) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('build-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text(AppL10nEn().leaveWithoutSaving), findsOneWidget);
    expect(find.text('home'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('build-keep-editing')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('build-add')), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('build-discard')));
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('a picker row says whether it is selected', (tester) async {
    _tall(tester);
    final handle = tester.ensureSemantics();
    late BuildContext context;
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (c) {
            context = c;
            return const Scaffold();
          },
        ),
      ),
    );
    final exercises = ExerciseLibraryState.instance.library.exercises;
    unawaited(
      pickMoves(
        context,
        exercises: exercises,
        media: ExerciseLibraryState.instance.media,
      ),
    );
    await tester.pumpAndSettle();
    final row = find.byKey(ValueKey('picker-${exercises.first.id}'));
    bool selected() =>
        tester
            .getSemantics(
              find.ancestor(of: row, matching: find.byType(Semantics)).first,
            )
            .flagsCollection
            .isSelected ==
        Tristate.isTrue;
    expect(selected(), isFalse);
    await tester.tap(
      find.byKey(ValueKey('picker-toggle-${exercises.first.id}')),
    );
    await tester.pumpAndSettle();
    expect(selected(), isTrue);
    handle.dispose();
  });
}
