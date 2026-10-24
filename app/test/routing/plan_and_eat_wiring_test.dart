// The Eat hub and "My plan" through the real router: E01, E02 and E04 are the
// one hub page, Home's Change plan link reaches the plan editor, and an edited
// day becomes her plan.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/app_state/chosen_programme.dart';
import 'package:own_hub/app_state/custom_workout_state.dart';
import 'package:own_hub/app_state/eat_state.dart';
import 'package:own_hub/app_state/my_plan_state.dart';
import 'package:own_hub/app_state/workout_library_state.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/features/eat/data/egyptian_food_pack.dart';
import 'package:own_hub/features/eat/presentation/eat_hub_view.dart';
import 'package:own_hub/features/onboarding/domain/intake.dart';
import 'package:own_hub/features/onboarding/domain/starting_program.dart';
import 'package:own_hub/features/signup/domain/verification.dart';
import 'package:own_hub/features/train/domain/my_plan.dart';
import 'package:own_hub/features/train/domain/viewed_tier.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/routing/app_routes.dart';
import 'package:own_hub/theme/app_tokens.dart';
import 'package:own_hub/ui/app_undo_bar.dart';

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 3200);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

Widget _app(String screenId) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppL10n.localizationsDelegates,
  supportedLocales: AppL10n.supportedLocales,
  theme: buildTheme(const Locale('en')),
  onGenerateRoute: AppRouter.onGenerateRoute,
  onUnknownRoute: AppRouter.onUnknownRoute,
  initialRoute: appRoutes[screenId]!.name,
);

/// A row of the programme page's "…".
Future<void> _fromMenu(WidgetTester tester, String label) async {
  await tester.tap(find.byKey(const ValueKey('overflow-menu')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey('overflow-row-$label')));
  await tester.pumpAndSettle();
}

void main() {
  final savedFlags = AppRouter.featureFlags;

  setUpAll(() {
    StartingProgrammes.adopt(
      File('assets/content/starting_programmes.json').readAsStringSync(),
    );
  });
  tearDownAll(StartingProgrammes.reset);

  setUp(() async {
    AppRouter.featureFlags = FeatureFlags.everything;
    AppRouter.consentRecorded = true;
    AppRouter.lastVerification = VerificationResult(
      method: VerificationMethod.automatic,
      decidedAt: DateTime(2026, 10, 2),
      imagesDeletedAt: DateTime(2026, 10, 2),
    );
    ChosenProgramme.reset();
    ViewedTier.clear();
    MyPlanState.instance.reset();
    CustomWorkoutState.instance.clearDraft();
    EatAppState.instance.reset();
    EgyptianFoodPack.reset();
    WorkoutLibraryState.instance
      ..openedSlot = null
      ..chosenRowId = null;
    await AppRouter.todayRepository.countWalk();
    await AppRouter.intakeRepository.merge(
      place: TrainingPlace.ladiesGym,
      goal: TrainingGoal.stronger,
      level: TrainingLevel.beginner,
      minutes: 45,
    );
  });

  tearDown(() {
    AppRouter.featureFlags = savedFlags;
    AppRouter.consentRecorded = false;
    AppRouter.lastVerification = null;
    ChosenProgramme.reset();
    ViewedTier.clear();
    MyPlanState.instance.reset();
    CustomWorkoutState.instance.clearDraft();
    EatAppState.instance.reset();
    EgyptianFoodPack.reset();
  });

  group('Eat', () {
    for (final id in ['E01', 'E02']) {
      testWidgets('$id is the Eat hub', (tester) async {
        _phone(tester);
        await tester.runAsync(EgyptianFoodPack.ensureLoaded);
        await tester.pumpWidget(_app(id));
        await tester.pumpAndSettle();
        expect(find.byType(EatHubView), findsOneWidget);
      });
    }

    testWidgets('E04 is the hub on the meal she has just logged', (
      tester,
    ) async {
      _phone(tester);
      await tester.runAsync(EgyptianFoodPack.ensureLoaded);
      await tester.pumpWidget(_app('E01'));
      await tester.pumpAndSettle();

      final handle = EatAppState.instance.logPlate(
        tester.element(find.byType(EatHubView)),
        'koshari_bowl',
      );
      expect(handle, isNotNull);
      unawaited(
        Navigator.of(tester.element(find.byType(EatHubView)))
            .pushNamed(appRoutes['E04']!.name, arguments: handle),
      );
      await tester.pumpAndSettle();

      expect(find.byType(EatHubView), findsWidgets);
      expect(find.byType(AppUndoBar), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
    });
  });

  group('The three splits', () {
    testWidgets('O05 offers Customize and Build my own, and Customize opens '
        'the plan editor', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app('O05'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('program-card-build-own')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('program-customize')), findsNWidgets(3));
      final first = find.byKey(const ValueKey('program-customize')).first;
      await tester.ensureVisible(first);
      await tester.tap(first);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('plan-day-0')), findsOneWidget);
      expect(MyPlanState.instance.hasPlan, isFalse);
    });

    testWidgets('R02 Change program sets her days to the split she picks', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(_app('R02'));
      await tester.pump(const Duration(milliseconds: 600));
      expect(AppRouter.intakeRepository.read().days, 3);

      await _fromMenu(tester, 'Change program');
      await tester.tap(find.byKey(const ValueKey('program-choose')).at(1));
      await tester.pumpAndSettle();

      final days = AppRouter.intakeRepository.read().days;
      expect(days, isNot(3));
      expect(ChosenProgramme.family, 'split_${days}day');
    });
  });

  group('Editing a split', () {
    Future<void> openChooser(WidgetTester tester) async {
      await tester.pumpWidget(_app('R02'));
      await tester.pump(const Duration(milliseconds: 600));
      await _fromMenu(tester, 'Edit one of the three splits');
    }

    testWidgets('backing out of the editor leaves her on the split she had', (
      tester,
    ) async {
      _phone(tester);
      await AppRouter.intakeRepository.merge(days: 3, weekdays: const {});
      await openChooser(tester);

      await tester.tap(find.byKey(const ValueKey('program-choose')).at(2));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('plan-day-4')), findsOneWidget);

      await tester.tap(find.byTooltip('Back').first);
      await tester.pumpAndSettle();

      expect(MyPlanState.instance.hasPlan, isFalse);
      expect(ChosenProgramme.family, isNull);
      expect(AppRouter.intakeRepository.read().days, 3);
    });

    testWidgets('the first change makes it her split and sets her days', (
      tester,
    ) async {
      _phone(tester);
      await AppRouter.intakeRepository.merge(days: 3, weekdays: const {});
      await openChooser(tester);
      await tester.tap(find.byKey(const ValueKey('program-choose')).at(2));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('plan-remove-0')));
      await tester.pumpAndSettle();

      expect(MyPlanState.instance.hasPlan, isTrue);
      expect(MyPlanState.instance.plan!.sourceProgrammeId, 'split_5day');
      expect(ChosenProgramme.family, 'split_5day');
      expect(AppRouter.intakeRepository.read().days, 5);
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
    });

    testWidgets('opening a day to change it makes it her split too', (
      tester,
    ) async {
      _phone(tester);
      await AppRouter.intakeRepository.merge(days: 3, weekdays: const {});
      await openChooser(tester);
      await tester.tap(find.byKey(const ValueKey('program-choose')).at(2));
      await tester.pumpAndSettle();

      final edit = find.byKey(const ValueKey('plan-edit-1'));
      await tester.ensureVisible(edit);
      await tester.tap(edit);
      await tester.pumpAndSettle();

      expect(ChosenProgramme.family, 'split_5day');
      expect(AppRouter.intakeRepository.read().days, 5);
      expect(find.byKey(const ValueKey('r03-edit-done')), findsOneWidget);
    });

    Future<void> withPlanOfFiveDays(WidgetTester tester) async {
      MyPlanState.instance.save(
        MyPlan.fork(
          StartingProgrammes.programme('split_5day')!,
          stage: LifeStage.none,
        ),
      );
      await tester.pumpWidget(_app('O05'));
      await tester.pumpAndSettle();
      final first = find.byKey(const ValueKey('program-customize')).first;
      await tester.ensureVisible(first);
      await tester.tap(first);
      await tester.pumpAndSettle();
      expect(find.text('Replace your plan with this split?'), findsOneWidget);
    }

    testWidgets('with a plan of her own Customize asks, and Replace shows the '
        'split she tapped', (tester) async {
      _phone(tester);
      await withPlanOfFiveDays(tester);
      await tester.tap(find.byKey(const ValueKey('plan-replace-yes')));
      await tester.pumpAndSettle();

      // The first card is the 3 day split.
      expect(find.byKey(const ValueKey('plan-day-2')), findsOneWidget);
      expect(find.byKey(const ValueKey('plan-day-3')), findsNothing);
      expect(MyPlanState.instance.hasPlan, isFalse);
    });

    testWidgets('with a plan of her own Customize asks, and Keep mine keeps '
        'it', (tester) async {
      _phone(tester);
      await withPlanOfFiveDays(tester);
      await tester.tap(find.byKey(const ValueKey('plan-replace-keep')));
      await tester.pumpAndSettle();

      expect(MyPlanState.instance.hasPlan, isTrue);
      expect(MyPlanState.instance.plan!.days, hasLength(5));
      expect(find.byKey(const ValueKey('plan-day-4')), findsOneWidget);
    });
  });

  group('My plan', () {
    testWidgets('Home, Change plan, Customize shows the split and keeps '
        'nothing', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app('T01'));
      await tester.pump(const Duration(milliseconds: 600));

      // Change plan is a row in the Today card's Change sheet.
      await tester.tap(find.byKey(const ValueKey('today-change')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('change-plan')));
      await tester.pumpAndSettle();
      // The plan page: its "…" holds the ways to change the plan.
      expect(find.byKey(const ValueKey('overflow-menu')), findsOneWidget);
      await _fromMenu(tester, 'Customize this plan');

      expect(find.byKey(const ValueKey('plan-day-0')), findsOneWidget);
      expect(MyPlanState.instance.hasPlan, isFalse);
    });

    testWidgets('an edited day becomes her plan, and Home follows it', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(_app('T01'));
      await tester.pump(const Duration(milliseconds: 600));
      final before = AppRouter.herProgramme!.content.programId;
      expect(before, isNot('my_plan'));

      // Change plan is a row in the Today card's Change sheet.
      await tester.tap(find.byKey(const ValueKey('today-change')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('change-plan')));
      await tester.pumpAndSettle();
      await _fromMenu(tester, 'Customize this plan');

      final edit = find.byKey(const ValueKey('plan-edit-0'));
      await tester.ensureVisible(edit);
      await tester.tap(edit);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('r03-edit-done')), findsOneWidget);
      expect(find.byKey(const ValueKey('r03-remove-0')), findsOneWidget);
      final moves = MyPlanState.instance.current!.days[0].session.moves.length;

      await tester.tap(find.byKey(const ValueKey('r03-remove-0')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('r03-edit-done')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('r03-update-yes')));
      await tester.pumpAndSettle();

      expect(MyPlanState.instance.hasPlan, isTrue);
      expect(
        MyPlanState.instance.plan!.days[0].session.moves.length,
        moves - 1,
      );
      expect(AppRouter.herProgramme!.content.programId, 'my_plan');
      expect(AppRouter.followingMyPlan, isTrue);
      // The removal's undo window.
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
    });
  });
}

void unawaited(Future<Object?> future) {}
