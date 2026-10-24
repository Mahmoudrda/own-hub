// How far each way of changing a plan is from Home, counted in taps, with the
// screens wired by hand (the router's wiring is a separate pass): Edit is one
// tap, Change plan is one tap to the programme page, and from there every way
// in is the "…" and a row. A change she keeps forks the split; one she does
// not forks nothing.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/my_plan_state.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/domain/training/prescribed_set.dart';
import 'package:own_hub/features/onboarding/domain/intake.dart';
import 'package:own_hub/features/train/domain/my_plan.dart';
import 'package:own_hub/features/train/domain/train_repository.dart';
import 'package:own_hub/features/train/domain/workout_library.dart';
import 'package:own_hub/features/train/presentation/my_plan_day.dart';
import 'package:own_hub/features/train/presentation/plan_editor_view.dart';
import 'package:own_hub/features/train/presentation/plan_entry_cards.dart';
import 'package:own_hub/features/train/presentation/program_view.dart';
import 'package:own_hub/features/train/presentation/workout_day_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/theme/app_tokens.dart';

AuthoredProgramme _template() => AuthoredProgramme(
  programId: 'split_fixture',
  titleEn: 'Split',
  titleAr: 'خطة',
  status: ProgrammeStatus.published,
  sessions: [
    for (final id in ['a', 'b'])
      AuthoredSession(
        sessionId: id,
        titleEn: 'Day $id',
        titleAr: 'يوم $id',
        minutes: 45,
        lifeStages: const {LifeStage.none},
        moves: [
          for (final m in ['m1', 'm2', 'm3'])
            AuthoredMove(
              exerciseId: '$id$m',
              nameEn: '$id$m',
              nameAr: '$id$m',
              sets: 3,
              reps: 10,
            ),
        ],
      ),
  ],
);

PlannedMove _planned(String id, {double? kg}) => PlannedMove(
  exerciseId: id,
  name: id,
  prescriptionLabel: '3 × 10',
  sets: [
    for (var i = 1; i <= 3; i++)
      PrescribedSet(exerciseId: id, order: i, reps: 10, weightKg: kg),
  ],
);

WorkoutDay _dayOf(MyPlan? plan) {
  final session =
      (plan == null
              ? _template().sessions
              : [for (final d in plan.days) d.session])
          .first;
  return WorkoutDay(
    id: '2026-10-21',
    title: session.titleEn,
    summary: '45 minutes, ${session.moves.length} moves',
    constraints: 'Gym',
    moves: [for (final m in session.moves) _planned(m.exerciseId)],
  );
}

/// Home, Train and R03 on one navigator, each reached by its own button.
class _App extends StatefulWidget {
  const _App();

  @override
  State<_App> createState() => _AppState();
}

class _AppState extends State<_App> {
  final state = MyPlanState.instance;
  int taps = 0;

  void _push(BuildContext context, WidgetBuilder builder) {
    Navigator.of(context).push<void>(MaterialPageRoute<void>(builder: builder));
  }

  void _editor(BuildContext context) => _push(
    context,
    (_) => PlanEditorView(
      stage: LifeStage.none,
      original: () => _template(),
      onEditDay: (i) => _push(context, (_) => _r03(startInEditMode: true)),
      onPickMoves: () async => [_planned('picked')],
    ),
  );

  Widget _r03({bool startInEditMode = false}) => _R03(
    startInEditMode: startInEditMode,
    kind: SavedKind.plan,
    onUpdate: (moves) => state.saveDayMoves(
      template: _template(),
      stage: LifeStage.none,
      slot: 0,
      moves: moves,
    ),
  );

  @override
  Widget build(BuildContext context) => Builder(
    builder: (home) => Scaffold(
      body: Column(
        children: [
          PlanLinksRow(
            onEdit: () => _push(home, (_) => _r03(startInEditMode: true)),
            onChangePlan: () => state.hasPlan
                ? _editor(home)
                : _push(
                    home,
                    (train) => ProgramView(
                      days: const [ProgramDay(title: 'Day a')],
                      hasMyPlan: state.hasPlan,
                      onCustomizePlan: () {
                        state.preview(_template(), LifeStage.none);
                        _editor(train);
                      },
                      onStartPlanFromScratch: () {
                        state.previewBlank();
                        _editor(train);
                      },
                      onEditSplit: () {
                        state.preview(_template(), LifeStage.none);
                        _editor(train);
                      },
                      onBuildOwn: () {},
                    ),
                  ),
          ),
        ],
      ),
    ),
  );
}

class _R03 extends StatefulWidget {
  const _R03({
    required this.startInEditMode,
    required this.kind,
    required this.onUpdate,
  });

  final bool startInEditMode;
  final SavedKind kind;
  final bool Function(List<PlannedMove>) onUpdate;

  @override
  State<_R03> createState() => _R03State();
}

class _R03State extends State<_R03> {
  late WorkoutDay day = _dayOf(MyPlanState.instance.plan);

  @override
  Widget build(BuildContext context) => WorkoutDayView(
    day: day,
    startInEditMode: widget.startInEditMode,
    savedKind: widget.kind,
    onUpdateSaved: widget.onUpdate,
    onMovesChanged: (moves) => setState(
      () => day = WorkoutDay(
        id: day.id,
        title: day.title,
        summary: day.summary,
        constraints: day.constraints,
        moves: moves,
      ),
    ),
  );
}

Widget _host(Widget child, {String locale = 'en', double scale = 1}) =>
    MaterialApp(
      locale: Locale(locale),
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      theme: buildTheme(Locale(locale)),
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: child,
      ),
    );

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  final savedFlags = AppRouter.featureFlags;
  setUp(() {
    MyPlanState.instance.reset();
    AppRouter.featureFlags = FeatureFlags.allOff.with_({
      Feature.train: true,
      Feature.workoutLibrary: true,
    });
  });
  tearDown(() {
    MyPlanState.instance.reset();
    AppRouter.featureFlags = savedFlags;
  });

  testWidgets('Edit: one tap from Home to the day with editing on', (
    tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(_host(const _App()));
    await tester.tap(find.byKey(const ValueKey('home-edit-workout')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('r03-remove-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('r03-add')), findsOneWidget);
  });

  Future<void> pickFromMenu(WidgetTester tester, String label) async {
    await tester.tap(find.byKey(const ValueKey('overflow-menu'))); // 2
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('overflow-row-$label'))); // 3
    await tester.pumpAndSettle();
  }

  testWidgets('Customize this plan: three taps from Home to the plan editor', (
    tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(_host(const _App()));
    await tester.tap(find.byKey(const ValueKey('home-change-plan'))); // 1
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('r01-build-plan-card')), findsNothing);
    await pickFromMenu(tester, 'Customize this plan');
    expect(find.byKey(const ValueKey('plan-day-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('plan-day-1')), findsOneWidget);
    // Looking at it keeps nothing.
    expect(MyPlanState.instance.hasPlan, isFalse);
  });

  testWidgets('Start from scratch: three taps to an empty editor', (
    tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(_host(const _App()));
    await tester.tap(find.byKey(const ValueKey('home-change-plan')));
    await tester.pumpAndSettle();
    await pickFromMenu(tester, 'Start from scratch');
    expect(find.text('No days yet. Add your first day.'), findsOneWidget);
  });

  testWidgets('with a plan, Change plan is one tap to the editor', (
    tester,
  ) async {
    _phone(tester);
    MyPlanState.instance.save(MyPlan.fork(_template(), stage: LifeStage.none));
    await tester.pumpWidget(_host(const _App()));
    await tester.tap(find.byKey(const ValueKey('home-change-plan')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('plan-day-0')), findsOneWidget);
  });

  testWidgets(
    'keeping a change forks the split; not keeping it forks nothing',
    (tester) async {
      _phone(tester);
      await tester.pumpWidget(_host(const _App()));
      await tester.tap(find.byKey(const ValueKey('home-edit-workout')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('r03-remove-0')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('r03-edit-done')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('r03-update-no')));
      await tester.pumpAndSettle();
      expect(
        MyPlanState.instance.hasPlan,
        isFalse,
        reason: 'cancel forks none',
      );

      // Again, and keep it.
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('home-edit-workout')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('r03-remove-0')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('r03-edit-done')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('r03-update-yes')));
      await tester.pumpAndSettle();
      final plan = MyPlanState.instance.plan!;
      expect(plan.sourceProgrammeId, 'split_fixture');
      expect(plan.days[0].session.moves.length, 2);
      expect(plan.days[1].session.moves.length, 3);
      await tester.pump(const Duration(seconds: 6));
    },
  );

  test('a day is shown without the moves her stage does not allow', () {
    final l10n = lookupAppL10n(const Locale('en'));
    final day = _dayOf(null);
    final kept = withoutBlockedMoves(l10n, day, {'am1'})!;
    expect(kept.moves.map((m) => m.exerciseId), ['am2', 'am3']);
    expect(kept.summary, contains('2 moves'));
    expect(withoutBlockedMoves(l10n, day, const {}), same(day));
    expect(withoutBlockedMoves(l10n, day, {'am1', 'am2', 'am3'}), isNull);
  });

  test('her target weights go back on the sets', () {
    final l10n = lookupAppL10n(const Locale('en'));
    final day = _dayOf(null);
    final withKg = withTargetWeights(l10n, 'en', day, [20, null, 7.5]);
    expect(withKg.moves[0].sets.first.weightKg, 20);
    expect(withKg.moves[0].prescriptionLabel, '3 × 10 · 20 kg');
    expect(withKg.moves[1].sets.first.weightKg, isNull);
    expect(withKg.moves[2].prescriptionLabel, '3 × 10 · 7.5 kg');
    expect(withTargetWeights(l10n, 'en', day, const [null]), same(day));
    final ar = withTargetWeights(lookupAppL10n(const Locale('ar')), 'ar', day, [
      20,
    ]);
    expect(ar.moves[0].prescriptionLabel, contains('\u2068'));
  });

  test('target weights keep the rest the plan gave each move', () {
    final l10n = lookupAppL10n(const Locale('en'));
    final base = _dayOf(null);
    final day = WorkoutDay(
      id: base.id,
      title: base.title,
      summary: base.summary,
      constraints: base.constraints,
      moves: [
        for (var i = 0; i < base.moves.length; i++)
          PlannedMove(
            exerciseId: base.moves[i].exerciseId,
            name: base.moves[i].name,
            prescriptionLabel: base.moves[i].prescriptionLabel,
            sets: base.moves[i].sets,
            restSeconds: 45 + i * 15,
          ),
      ],
    );
    final withKg = withTargetWeights(l10n, 'en', day, [20, null, 7.5]);
    expect(withKg.moves[0].restSeconds, 45);
    expect(withKg.moves[1].restSeconds, 60);
    expect(withKg.moves[2].restSeconds, 75);
  });
}
