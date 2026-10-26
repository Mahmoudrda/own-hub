// The screens the motivation design (guide §15, D37–D41) changed, each held to
// what it now promises: R08 records a hold in seconds, R09 pauses for real,
// Home says when today's session is done and keeps its extra lines inside the
// week block, R11 leads with one session, O05 shows the steps that ran.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/domain/rewards/training_streak.dart';
import 'package:own_hub/domain/training/prescribed_set.dart';
import 'package:own_hub/features/onboarding/domain/intake.dart';
import 'package:own_hub/features/onboarding/domain/intake_repository.dart';
import 'package:own_hub/features/onboarding/presentation/starting_program_view.dart';
import 'package:own_hub/features/today/domain/today_day.dart';
import 'package:own_hub/features/today/domain/today_repository.dart';
import 'package:own_hub/features/today/presentation/today_view.dart';
import 'package:own_hub/features/train/domain/library_recommendation.dart';
import 'package:own_hub/features/train/domain/train_repository.dart';
import 'package:own_hub/features/train/presentation/change_set_view.dart';
import 'package:own_hub/features/train/presentation/resting_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/theme/app_tokens.dart';
import 'package:own_hub/ui/app_chip_row.dart';
import 'package:own_hub/ui/app_ring_stat.dart';

Widget _host(Widget child) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppL10n.localizationsDelegates,
  supportedLocales: AppL10n.supportedLocales,
  theme: buildTheme(const Locale('en')),
  home: child,
);

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

void main() {
  final saved = AppRouter.featureFlags;
  setUp(() => AppRouter.featureFlags = FeatureFlags.everything);
  tearDown(() => AppRouter.featureFlags = saved);

  group('R08', () {
    test('weights around the plan, none for bodyweight', () {
      expect(
        weightOptionsAround(
          const PrescribedSet(
            exerciseId: 'a',
            order: 1,
            weightKg: 17.5,
            reps: 8,
          ),
        ),
        [15.5, 17.5, 19.5],
      );
      expect(
        weightOptionsAround(
          const PrescribedSet(exerciseId: 'a', order: 1, reps: 8),
        ),
        isEmpty,
      );
      expect(
        holdOptionsAround(
          const PrescribedSet(exerciseId: 'p', order: 1, holdSeconds: 30),
        ),
        [20, 25, 30, 35, 40],
      );
    });

    testWidgets('the planned weight is the one selected', (tester) async {
      _phone(tester);
      const planned = PrescribedSet(
        exerciseId: 'goblet_squat',
        order: 1,
        weightKg: 17.5,
        reps: 8,
      );
      await tester.pumpWidget(
        _host(
          ChangeSetView(
            prescribed: planned,
            moveName: 'Goblet squat',
            weightOptionsKg: weightOptionsAround(planned),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final weights = [
        for (final chip in tester.widgetList<AppChip>(find.byType(AppChip)))
          if (chip.label.endsWith(' kg')) chip,
      ];
      expect(
        [for (final c in weights) c.label],
        ['15.5 kg', '17.5 kg', '19.5 kg'],
      );
      expect([for (final c in weights) c.selected], [false, true, false]);
    });

    testWidgets('a hold is changed and written in seconds', (tester) async {
      _phone(tester);
      final repository = InMemoryTrainRepository();
      await tester.pumpWidget(
        _host(
          ChangeSetView(
            repository: repository,
            prescribed: const PrescribedSet(
              exerciseId: 'plank',
              order: 1,
              holdSeconds: 30,
            ),
            moveName: 'Plank',
            onSaved: (handle) => handle,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Seconds'), findsOneWidget);
      await tester.tap(find.text('35'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done · 35 seconds'));
      await tester.pump(const Duration(seconds: 6));
      final outcome = repository.flushes.single.sets.single.outcome!;
      expect(outcome.holdSeconds, 35);
      expect(outcome.reps, isNull);
    });
  });

  testWidgets('R09 opens on the whole rest, not part of it', (tester) async {
    _phone(tester);
    await tester.pumpWidget(
      _host(
        const RestingView(
          remaining: Duration(seconds: 60),
          total: Duration(seconds: 60),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('1:00'), findsOneWidget);
    // The ring draws the rest she has left: the whole of it, at the start.
    expect(tester.widget<AppRingStat>(find.byType(AppRingStat)).fraction, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('R09 pause stops the clock where it is', (tester) async {
    _phone(tester);
    await tester.pumpWidget(
      _host(
        const RestingView(
          remaining: Duration(seconds: 60),
          total: Duration(seconds: 60),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('0:58'), findsOneWidget);
    await tester.tap(find.byTooltip('Pause'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('0:58'), findsOneWidget);
    expect(find.byKey(const ValueKey('pause-resume')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('pause-resume')));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('0:57'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  group('T01', () {
    TodayDay day(DayState state) => TodayDay(
      date: DateTime(2026, 10, 13, 10),
      state: state,
      arc: const FirstWeekArc(
        hasAnyLog: true,
        completed: {FirstWeekStep.logSet},
      ),
      week: const WeekProgress(sessionsLogged: 1, sessionsTarget: 3),
    );

    testWidgets('says when today is done, and offers another quietly', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          TodayView(
            repository: InMemoryTodayRepository(day: day(DayState.done)),
            now: DateTime(2026, 10, 13, 10),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text("Today's session is done"), findsOneWidget);
      expect(find.text('Another session'), findsOneWidget);
      expect(find.text("Start, everything's ready"), findsNothing);
    });

    testWidgets('the challenge and the first week sit in the week block, '
        'with the streak held back until the first week is done', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          TodayView(
            repository: InMemoryTodayRepository(day: day(DayState.nothingDone)),
            now: DateTime(2026, 10, 13, 10),
            challengeLine: 'Glute bridge: more than last week\'s 24 reps',
            trainingStreak: const StreakStatus(enabled: true, days: 6, best: 9),
            onOpenStreak: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text("This week's challenge"), findsOneWidget);
      // One line, and it counts steps, so it is never read against the
      // week's own sessions. Five steps with every switch on, three without.
      expect(find.textContaining('Your first week: 1 of'), findsOneWidget);
      expect(find.text('Training streak: 6 days'), findsNothing);
    });

    testWidgets('with the first week off, her streak is the one line', (
      tester,
    ) async {
      _phone(tester);
      AppRouter.featureFlags = FeatureFlags.everything.with_(<Feature, bool>{
        Feature.firstWeek: false,
      });
      await tester.pumpWidget(
        _host(
          TodayView(
            repository: InMemoryTodayRepository(day: day(DayState.nothingDone)),
            now: DateTime(2026, 10, 13, 10),
            trainingStreak: const StreakStatus(enabled: true, days: 6, best: 9),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Your first week'), findsNothing);
      // A line, not a control: Home keeps to five, and the streak opens
      // from You.
      expect(find.text('Training streak: 6 days'), findsOneWidget);
    });

    testWidgets('a day-zero streak says what starts it, never a failure', (
      tester,
    ) async {
      _phone(tester);
      AppRouter.featureFlags = FeatureFlags.everything.with_(<Feature, bool>{
        Feature.firstWeek: false,
      });
      await tester.pumpWidget(
        _host(
          TodayView(
            repository: InMemoryTodayRepository(day: day(DayState.nothingDone)),
            now: DateTime(2026, 10, 13, 10),
            trainingStreak: const StreakStatus(enabled: true, days: 0, best: 4),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Day one starts with your next session.'),
        findsOneWidget,
      );
    });
  });

  group('the recommended session', () {
    const rows = [
      LibraryWorkout(
        id: 'gym',
        title: 'Gym legs',
        detail: '',
        needsEquipment: true,
        minutes: 40,
      ),
      LibraryWorkout(
        id: 'quiet',
        title: 'Quiet floor',
        detail: '',
        quiet: true,
        minutes: 15,
      ),
    ];

    test('the recommendation fits what she said', () {
      final home = Intake.defaults.copyWith(
        place: TrainingPlace.home,
        minutes: 20,
      );
      expect(recommendedWorkout(rows, home)!.id, 'quiet');
      expect(recommendedWorkout(rows, home, chosenRowId: 'gym')!.id, 'gym');
      expect(recommendedWorkout(const [], home), isNull);
    });
  });

  testWidgets('O05 shows the steps that ran, then the programme', (
    tester,
  ) async {
    _phone(tester);
    resetStartingProgramSteps();
    await tester.pumpWidget(
      _host(
        StartingProgramView(
          repository: InMemoryIntakeRepository(
            Intake.defaults.copyWith(place: TrainingPlace.home),
          ),
          showSteps: true,
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Built from your answers'), findsOneWidget);
    expect(
      find.text('Built from your answers'),
      findsOneWidget,
      reason: 'the kicker, not the tick',
    );
    expect(find.text('Beginner foundations'), findsNothing);
    await tester.pumpAndSettle();
    expect(find.text('Beginner foundations'), findsOneWidget);
  });

  group('O05 steps', () {
    Widget o05({bool motionOff = false}) => _host(
      Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: motionOff),
          child: StartingProgramView(
            repository: InMemoryIntakeRepository(
              Intake.defaults.copyWith(place: TrainingPlace.home),
            ),
            showSteps: true,
          ),
        ),
      ),
    );

    testWidgets('a tap skips to the programme', (tester) async {
      _phone(tester);
      resetStartingProgramSteps();
      await tester.pumpWidget(o05());
      await tester.pump();
      expect(find.text('Beginner foundations'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('o05-steps')));
      await tester.pump();
      await tester.pump();
      expect(find.text('Beginner foundations'), findsOneWidget);
    });

    testWidgets('with motion off the steps stand still and the card is there', (
      tester,
    ) async {
      _phone(tester);
      resetStartingProgramSteps();
      await tester.pumpWidget(o05(motionOff: true));
      await tester.pump();
      await tester.pump();
      expect(find.text('Built from your answers'), findsOneWidget);
      expect(find.text('Beginner foundations'), findsOneWidget);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('once per run for the same answers', (tester) async {
      _phone(tester);
      resetStartingProgramSteps();
      await tester.pumpWidget(o05());
      await tester.pumpAndSettle();
      expect(find.text('Beginner foundations'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(o05());
      await tester.pump();
      expect(
        find.text('Built from your answers'),
        findsOneWidget,
        reason: 'the kicker, not the tick',
      );
      expect(find.text('Beginner foundations'), findsOneWidget);
    });
  });
}
