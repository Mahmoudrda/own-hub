// The first minute, driven through the REAL app.
//
// The setup questions were built, tested screen by screen, and wired to
// nothing: their only inbound route was `C16`, inside the switched-off sign-up
// flow, so on a fresh install no woman was ever asked how many days a week she
// could train — and every one of them was given a goal of three sessions,
// because `WeeklyGoalService.setTarget` had no call site in the product.
//
// Every test here boots `OwnHubApp` and taps, so what is proved is the app a
// woman downloads: the questions open on first launch, her answer becomes her
// weekly goal, a second launch does not ask again, deleting everything asks
// again, skipping is safe, and the questions can be reopened from her profile
// afterwards.
//
// The world is built from `FeatureFlags.allOff` with the first release's six
// features named one by one rather than inherited from the defaults, which is
// what `flag_independence_test` asks of every file whose subject is a screen
// rather than the switch positions themselves. It is the shipping shape, said
// out loud: no account, no community, no coach side.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/features/onboarding/domain/intake.dart';
import 'package:own_hub/features/onboarding/presentation/equipment_view.dart';
import 'package:own_hub/features/onboarding/presentation/goal_view.dart';
import 'package:own_hub/features/onboarding/presentation/minutes_view.dart';
import 'package:own_hub/features/onboarding/presentation/starting_program_view.dart';
import 'package:own_hub/features/account/presentation/profile_view.dart';
import 'package:own_hub/features/today/presentation/today_view.dart';
import 'package:own_hub/main.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/ui/app_button.dart';

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

/// Opens the app the way a woman does: no route supplied, nothing pushed.
Future<void> _launch(WidgetTester tester) async {
  _phone(tester);
  await tester.pumpWidget(OwnHubApp(key: UniqueKey()));
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target.first);
  await tester.pumpAndSettle();
  await tester.tap(target.first);
  await tester.pumpAndSettle();
}

/// What Home and Progress count her week against.
int get _homeTarget => AppRouter.todayRepository.day.week.sessionsTarget;
int get _progressTarget => AppRouter.progressStore.goal.sessionsTarget;

/// The first release, named rather than borrowed.
final FeatureFlags _firstRelease = FeatureFlags.allOff.with_(<Feature, bool>{
  Feature.today: true,
  Feature.firstWeek: true,
  Feature.quietWeek: true,
  Feature.train: true,
  Feature.recordFromMemory: true,
  Feature.program: true,
  Feature.exerciseVideo: true,
  Feature.exerciseSwap: true,
  Feature.workoutLibrary: true,
  Feature.trainingReminders: true,
  Feature.reassuringWaits: true,
  Feature.haptics: true,
  Feature.finishReveal: true,
  Feature.weeklyChallenge: true,
  Feature.trainingStreak: true,
  Feature.exerciseLibrary: true,
  Feature.eat: true,
  Feature.recipes: true,
  Feature.weekPlan: true,
  Feature.progress: true,
  Feature.milestones: true,
  Feature.personalBests: true,
  Feature.bodyPrivately: true,
  Feature.shareCard: true,
  Feature.cycle: true,
  Feature.cycleCalendar: true,
  Feature.cyclePatterns: true,
  Feature.privacyCentre: true,
});

void main() {
  final savedFlags = AppRouter.featureFlags;

  setUp(() {
    AppRouter.featureFlags = _firstRelease;
    AppRouter.intakeRepository.reset();
    AppRouter.progressStore.reset();
    AppRouter.todayRepository.reset();
  });

  tearDown(() {
    AppRouter.featureFlags = savedFlags;
    AppRouter.intakeRepository.reset();
    AppRouter.progressStore.reset();
    AppRouter.todayRepository.reset();
  });

  group('the first launch', () {
    testWidgets('a fresh install opens on the questions, and answering them '
        'reaches Home with her own weekly goal', (tester) async {
      await _launch(tester);

      // Question one, and it says what is about to happen before it asks.
      expect(find.byType(GoalView), findsOneWidget);
      expect(find.text('1 of 6'), findsOneWidget);
      expect(
        find.text(
          'A few short questions, one at a time. Your week is ready at the '
          'end.',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('account'),
        findsNothing,
        reason: 'there is no sign-up in this build, so nothing may mention one',
      );

      await _tap(tester, find.text('Get back into it'));
      await _tap(tester, find.text('Continue'));

      // Two: where.
      expect(find.text('2 of 6'), findsOneWidget);
      await _tap(tester, find.text('Both'));
      await _tap(tester, find.text('Continue'));

      // Three: with what, asked because home is part of her answer.
      expect(find.byType(EquipmentView), findsOneWidget);
      expect(find.text('3 of 6'), findsOneWidget);
      await _tap(tester, find.text('Dumbbells'));
      await _tap(tester, find.text('Continue'));

      // Four: the one that becomes her goal.
      expect(find.text('4 of 6'), findsOneWidget);
      await _tap(tester, find.text('4'));
      await _tap(tester, find.text('Continue'));

      // Five: how long a session can be.
      expect(find.byType(MinutesView), findsOneWidget);
      expect(find.text('5 of 6'), findsOneWidget);
      await _tap(tester, find.text('30 min'));
      await _tap(tester, find.text('Continue'));

      // Six: what the programme has to train around.
      expect(find.text('6 of 6'), findsOneWidget);
      await _tap(tester, find.text('A knee, back or shoulder'));
      await _tap(tester, find.text('Continue'));

      // Her answers, read back as hers rather than as a fixed sentence about
      // somebody who trains three days a week at home.
      expect(find.byType(StartingProgramView), findsOneWidget);
      expect(
        find.text('4 days a week · 30 min a session · At home and the gym'),
        findsOneWidget,
      );

      await _tap(
        tester,
        find.widgetWithText(AppButton, 'I will start tomorrow'),
      );

      // Home, with the setup gone from the history behind her.
      expect(find.byType(TodayView), findsOneWidget);
      expect(find.byType(GoalView, skipOffstage: false), findsNothing);
      expect(
        find.byType(StartingProgramView, skipOffstage: false),
        findsNothing,
      );

      // Her answers reached the app.
      final intake = AppRouter.intakeRepository.read();
      expect(intake.goal, TrainingGoal.backIntoIt);
      expect(intake.place, TrainingPlace.both);
      expect(intake.equipment, {Equipment.dumbbells});
      expect(intake.days, 4);
      expect(intake.minutes, 30);
      expect(intake.lifeStage, LifeStage.painInjury);

      // And the one that changes what she sees every day: four, not the three
      // the product imposed on everybody.
      expect(_progressTarget, 4);
      expect(_homeTarget, 4);
    });

    testWidgets('a ladies-only gym is five questions, and never asks what '
        'she has at home', (tester) async {
      await _launch(tester);
      await _tap(tester, find.text('Continue')); // O01

      expect(find.text('2 of 6'), findsOneWidget);
      await _tap(tester, find.text('A ladies-only gym'));
      expect(find.text('2 of 5'), findsOneWidget);
      await _tap(tester, find.text('Continue'));

      // Straight to her days: no O06.
      expect(find.byType(EquipmentView), findsNothing);
      expect(find.text('3 of 5'), findsOneWidget);
      await _tap(tester, find.text('4'));
      await _tap(tester, find.text('Continue'));
      expect(find.text('4 of 5'), findsOneWidget);
      await _tap(tester, find.text('Continue')); // O07
      expect(find.text('5 of 5'), findsOneWidget);
      await _tap(tester, find.text('Continue')); // O04

      expect(find.byType(StartingProgramView), findsOneWidget);
      expect(
        find.text('4 days a week · 15 min a session · At a ladies-only gym'),
        findsOneWidget,
      );
      expect(find.byType(EquipmentView, skipOffstage: false), findsNothing);
      expect(AppRouter.intakeRepository.read().place, TrainingPlace.ladiesGym);
      expect(
        AppRouter.intakeRepository.read().equipment,
        Intake.defaults.equipment,
        reason: 'nothing was asked, so nothing was written',
      );
    });

    testWidgets('the second launch goes straight to Home', (tester) async {
      await _launch(tester);
      await _tap(tester, find.text('Continue')); // O01
      await _tap(tester, find.text('Continue')); // O02
      await _tap(tester, find.text('Continue')); // O06
      await _tap(tester, find.text('Continue')); // O03
      await _tap(tester, find.text('Continue')); // O07
      await _tap(tester, find.text('Continue')); // O04
      await _tap(
        tester,
        find.widgetWithText(AppButton, 'I will start tomorrow'),
      );
      expect(find.byType(TodayView), findsOneWidget);

      // Closed and opened again.
      await _launch(tester);
      expect(find.byType(TodayView), findsOneWidget);
      expect(
        find.byType(GoalView, skipOffstage: false),
        findsNothing,
        reason: 'she has been asked; asking again is the app forgetting her',
      );
    });

    testWidgets('deleting everything from Profile asks again', (tester) async {
      await _launch(tester);
      await _tap(tester, find.text('Continue')); // O01
      await _tap(tester, find.text('Continue')); // O02
      await _tap(tester, find.text('Continue')); // O06
      await _tap(tester, find.text('4')); // O03, four days a week
      await _tap(tester, find.text('Continue'));
      await _tap(tester, find.text('Continue')); // O07
      await _tap(tester, find.text('Continue')); // O04
      await _tap(
        tester,
        find.widgetWithText(AppButton, 'I will start tomorrow'),
      );
      expect(_progressTarget, 4);
      expect(AppRouter.intakeRepository.setupDone, isTrue);

      // Her profile, and the row that deletes everything.
      await _tap(tester, find.bySemanticsLabel('Your profile'));
      expect(find.byType(ProfileView), findsOneWidget);
      await _tap(tester, find.text('Privacy and data'));
      await _tap(tester, find.text('Your data'));
      await _tap(tester, find.widgetWithText(AppButton, 'Delete everything'));

      // A fresh start includes being asked, because that is what a fresh start
      // is: her answers are gone, so the app knows nothing about her again.
      expect(AppRouter.intakeRepository.setupDone, isFalse);
      expect(AppRouter.intakeRepository.read(), Intake.defaults);

      await _launch(tester);
      expect(find.byType(GoalView), findsOneWidget);
    });
  });

  group('skipping', () {
    // R1-P10: Skip is gone. Every answer is preselected, so Skip did what
    // Continue does; going through on the defaults is the same walk.
    testWidgets('she can go through every question on its defaults and land '
        'on an honest Home', (tester) async {
      await _launch(tester);

      for (var step = 1; step <= 6; step++) {
        expect(find.text('$step of 6'), findsOneWidget);
        expect(find.widgetWithText(AppButton, 'Skip'), findsNothing);
        await _tap(tester, find.widgetWithText(AppButton, 'Continue'));
      }
      await _tap(
        tester,
        find.widgetWithText(AppButton, 'I will start tomorrow'),
      );

      expect(find.byType(TodayView), findsOneWidget);

      // What she gets is the default the design preselects, which is a real
      // answer rather than an empty one.
      expect(AppRouter.intakeRepository.read(), Intake.defaults);
      expect(_progressTarget, Intake.defaults.days);
      expect(_homeTarget, Intake.defaults.days);

      // And she is not asked a second time.
      expect(AppRouter.intakeRepository.setupDone, isTrue);
      await _launch(tester);
      expect(find.byType(TodayView), findsOneWidget);
    });

    testWidgets('closing at question one leaves setup immediately', (
      tester,
    ) async {
      await _launch(tester);
      expect(find.byType(GoalView), findsOneWidget);

      // The X in the corner. It rendered on every question and was passed
      // no callback by anybody, so the one control promising she is not
      // trapped in setup was the one control that could not let her out.
      await _tap(tester, find.byTooltip('Skip setup'));

      expect(find.byType(TodayView), findsOneWidget);
      expect(find.byType(GoalView, skipOffstage: false), findsNothing);
      expect(AppRouter.intakeRepository.setupDone, isTrue);
      expect(AppRouter.intakeRepository.writes, isEmpty);
    });
  });

  group('editable afterwards', () {
    testWidgets('Profile reopens the same questions and comes back to '
        'Profile', (tester) async {
      AppRouter.intakeRepository.markSetupDone();
      await _launch(tester);
      expect(find.byType(TodayView), findsOneWidget);

      await _tap(tester, find.bySemanticsLabel('Your profile'));
      expect(find.text('Your profile'), findsWidgets);

      await _tap(tester, find.text('Your training'));
      expect(find.byType(GoalView), findsOneWidget);

      // Three days a week was the default she never chose. Two is.
      await _tap(tester, find.text('Continue')); // O01
      await _tap(tester, find.text('Continue')); // O02
      await _tap(tester, find.text('Continue')); // O06
      await _tap(tester, find.text('2'));
      await _tap(tester, find.text('Continue')); // O03
      await _tap(tester, find.text('Continue')); // O07
      await _tap(tester, find.text('Continue')); // O04
      await _tap(
        tester,
        find.widgetWithText(AppButton, 'I will start tomorrow'),
      );

      // Back where she opened them from, not on Home.
      expect(find.byType(ProfileView), findsOneWidget);
      expect(find.byType(TodayView), findsNothing);
      expect(AppRouter.intakeRepository.read().days, 2);
      expect(_progressTarget, 2);
      expect(_homeTarget, 2);
    });

    testWidgets('the Home tab works from Profile', (tester) async {
      // A02 drew the bar claiming Home was the active tab, and the bar gives
      // the active tab no onTap on purpose — so the Home tab was rendered and
      // dead on the screen a woman most often wants to leave.
      AppRouter.intakeRepository.markSetupDone();
      await _launch(tester);
      await _tap(tester, find.bySemanticsLabel('Your profile'));
      expect(find.byType(ProfileView), findsOneWidget);

      await _tap(tester, find.text('Home'));
      expect(find.byType(TodayView), findsOneWidget);
    });
  });
}
