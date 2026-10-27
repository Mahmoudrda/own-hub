// Where a target may and may not appear: E01, the portion sheet, the week on
// Progress, the follow-up card, the life-stage step, and the one place every
// screen gets its targets from.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/app_state/eat_state.dart';
import 'package:own_hub/app_state/private_coaching_state.dart';
import 'package:own_hub/domain/nutrition/target_safety.dart';
import 'package:own_hub/features/eat/domain/daily_targets.dart';
import 'package:own_hub/features/eat/domain/day_totals.dart';
import 'package:own_hub/features/eat/presentation/eat_sample_library.dart';
import 'package:own_hub/features/eat/presentation/eat_widgets.dart';
import 'package:own_hub/features/eat/presentation/food_portion_sheet.dart';
import 'package:own_hub/features/followup/domain/follow_up_plan.dart';
import 'package:own_hub/features/onboarding/domain/body_data.dart';
import 'package:own_hub/features/onboarding/domain/intake.dart';
import 'package:own_hub/features/onboarding/domain/intake_repository.dart';
import 'package:own_hub/features/onboarding/presentation/life_stage_view.dart';
import 'package:own_hub/features/private_coaching/domain/coaching_contract.dart'
    show SubscriptionStatus;
import 'package:own_hub/features/private_coaching/domain/subscription.dart'
    as coaching;
import 'package:own_hub/features/progress/domain/nutrition_insights.dart';
import 'package:own_hub/features/progress/presentation/progress_insights_sections.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/theme/app_tokens.dart';

import '../private_coaching/support/fake_coaching_repository.dart';

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

Widget _host(Widget child) {
  const locale = Locale('en');
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppL10n.localizationsDelegates,
    supportedLocales: AppL10n.supportedLocales,
    theme: buildTheme(locale),
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

const _body = BodyData(weightKg: 60, heightCm: 165, ageYears: 30);

DayTotals _eaten() =>
    const DayTotals(kcalSoFar: 900, proteinSoFar: 50, proteinTargetG: 100);

Finder _anyNumberOfTarget() => find.textContaining(RegExp(r'\bof \d'));

void main() {
  group('E01 hero', () {
    testWidgets('an eating-history answer: no number, her coach instead', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          EatHero(totals: _eaten(), targets: const DailyTargets.withheld()),
        ),
      );
      expect(find.byKey(const ValueKey('eat-hero-withheld')), findsOneWidget);
      expect(
        find.text(
          'Your coach sets your food plan with you. Log what you eat and '
          'talk to her about it.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('eat-kcal-hero')), findsNothing);
      expect(_anyNumberOfTarget(), findsNothing);
      expect(find.textContaining('900'), findsNothing);
    });

    testWidgets('a target that is normal says nothing extra', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          EatHero(
            totals: _eaten(),
            targets: DailyTargets.compute(body: _body),
          ),
        ),
      );
      expect(find.byKey(const ValueKey('eat-kcal-hero')), findsOneWidget);
      expect(find.byKey(const ValueKey('eat-target-note')), findsNothing);
    });

    testWidgets('the floor is named when it was used', (tester) async {
      _phone(tester);
      final small = DailyTargets.compute(
        body: const BodyData(weightKg: 40, heightCm: 145, ageYears: 50),
        goal: TrainingGoal.loseSteadily,
      );
      await tester.pumpWidget(_host(EatHero(totals: _eaten(), targets: small)));
      expect(
        find.text('We never set a target below 1,200 kcal.'),
        findsOneWidget,
      );
    });

    testWidgets(
      'under 18, a weight-loss goal is explained and the doctor named',
      (tester) async {
        _phone(tester);
        final teen = DailyTargets.compute(
          body: const BodyData(weightKg: 55, heightCm: 160, ageYears: 16),
          goal: TrainingGoal.loseSteadily,
        );
        await tester.pumpWidget(
          _host(EatHero(totals: _eaten(), targets: teen)),
        );
        expect(find.byKey(const ValueKey('eat-target-note')), findsOneWidget);
        expect(find.textContaining('under 18'), findsOneWidget);
        expect(find.textContaining('talk to your doctor'), findsOneWidget);
      },
    );

    testWidgets('pregnant or after a birth, the same, in its own words', (
      tester,
    ) async {
      _phone(tester);
      final pregnant = DailyTargets.compute(
        body: _body,
        goal: TrainingGoal.loseSteadily,
        stage: TargetStage.pregnant,
      );
      await tester.pumpWidget(
        _host(EatHero(totals: _eaten(), targets: pregnant)),
      );
      expect(find.textContaining('pregnant or after a birth'), findsOneWidget);
      expect(find.textContaining('talk to your doctor'), findsOneWidget);
    });
  });

  group('the portion sheet', () {
    Future<void> pump(WidgetTester tester, DailyTargets targets) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) => FoodPortionPanel(
              food: eatSampleLibrary(AppL10n.of(context)).byId('koshari_bowl')!,
              targets: targets,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('a withheld target draws no "Impact on today"', (tester) async {
      await pump(tester, const DailyTargets.withheld());
      expect(find.byKey(const ValueKey('portion-impact')), findsNothing);
    });

    testWidgets('her own target still does', (tester) async {
      await pump(tester, DailyTargets.compute(body: _body));
      expect(find.byKey(const ValueKey('portion-impact')), findsOneWidget);
    });
  });

  group('Progress, food', () {
    NutritionWeek week(DailyTargets targets) => NutritionWeek.from(
      today: DateTime(2026, 10, 23),
      targets: targets,
      totalsFor: (_) => const DayTotals(
        kcalSoFar: 1500,
        proteinSoFar: 80,
        proteinTargetG: 100,
      ),
    );

    testWidgets('a target shows the protein target and the calories', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(InsightsFood(week: week(DailyTargets.compute(body: _body)))),
      );
      expect(find.text('Protein target'), findsOneWidget);
      expect(find.textContaining('Calories'), findsOneWidget);
    });

    testWidgets('withheld: what she ate, no target and no calories', (
      tester,
    ) async {
      _phone(tester);
      final w = week(const DailyTargets.withheld());
      expect(w.targetsWithheld, isTrue);
      await tester.pumpWidget(_host(InsightsFood(week: w)));
      expect(find.text('Protein target'), findsNothing);
      expect(find.textContaining('Calories'), findsNothing);
      expect(
        find.byKey(const ValueKey('insights-food-logged')),
        findsOneWidget,
      );
      expect(find.textContaining('Protein'), findsWidgets);
    });
  });

  group('the follow-up card', () {
    test('a withheld protein target never makes a day "low"', () {
      final low = [for (var i = 0; i < 5; i++) (protein: 20, target: 0)];
      final facts = FollowUpFacts(
        now: DateTime(2026, 10, 21, 9),
        enabled: true,
        muted: const {},
        notBefore: const {},
        feels: const {},
        weekStartKey: '2026-10-17',
        sessionsThisWeek: 0,
        weekTarget: 3,
        setsThisWeek: 0,
        bestsThisWeek: 0,
        weekReviews: const {},
        lastLoggedDays: low,
        proteinPick: (name: 'Lentils', proteinG: 18),
        protectedStage: false,
        severeToday: false,
        gentleToday: false,
      );
      expect(FollowUpPlan.next(facts), isNull);
    });
  });

  group('where every screen gets its targets', () {
    late FakeCoachingRepository repo;

    setUp(() {
      BodyDataStore.instance.write(_body);
      repo = FakeCoachingRepository(uid: 'me');
      PrivateCoachingState.instance.start(repo);
    });

    tearDown(() {
      PrivateCoachingState.instance.stop();
      AppRouter.intakeRepository.reset();
      BodyDataStore.instance.reset();
    });

    coaching.Subscription sub(coaching.Intake intake) => coaching.Subscription(
      id: 's1',
      coachUid: 'c1',
      clientUid: 'me',
      status: SubscriptionStatus.active,
      intake: intake,
    );

    test('ordinary: a target with no note', () async {
      await AppRouter.intakeRepository.merge(goal: TrainingGoal.loseSteadily);
      final t = EatAppState.instance.targets();
      expect(t.withheld, isFalse);
      expect(t.note, TargetNote.none);
      expect(t.kcal, greaterThanOrEqualTo(1200));
    });

    test('an eating-history answer to her coach withholds all of it', () async {
      repo.clientSubs.value = [sub(const coaching.Intake(eatingHistory: true))];
      await Future<void>.delayed(Duration.zero);
      expect(EatAppState.instance.targets(), const DailyTargets.withheld());
    });

    test(
      'pregnant, from her own answer: a losing goal is maintenance',
      () async {
        await AppRouter.intakeRepository.merge(
          goal: TrainingGoal.loseSteadily,
          lifeStage: LifeStage.pregnant,
        );
        final t = EatAppState.instance.targets();
        expect(t.note, TargetNote.noDeficitStage);
        final maintaining = DailyTargets.compute(
          body: _body,
          goal: TrainingGoal.feelBetter,
          daysPerWeek: Intake.defaults.days,
          minutesPerSession: Intake.defaults.minutes,
          stage: TargetStage.pregnant,
        );
        expect(t.kcal, maintaining.kcal);
      },
    );

    test('pregnant, from what she told her coach', () async {
      await AppRouter.intakeRepository.merge(goal: TrainingGoal.loseSteadily);
      repo.clientSubs.value = [
        sub(const coaching.Intake(lifeStage: 'postpartum')),
      ];
      await Future<void>.delayed(Duration.zero);
      expect(EatAppState.instance.targets().note, TargetNote.noDeficitStage);
    });

    test('under 18, from her body data', () async {
      BodyDataStore.instance.write(
        const BodyData(weightKg: 55, heightCm: 160, ageYears: 16),
      );
      await AppRouter.intakeRepository.merge(goal: TrainingGoal.loseSteadily);
      expect(EatAppState.instance.targets().note, TargetNote.noDeficitMinor);
    });
  });

  group('O04, the life-stage step', () {
    testWidgets('losing weight while pregnant: the target is said to be kept', (
      tester,
    ) async {
      _phone(tester);
      final repo = InMemoryIntakeRepository(
        const Intake(goal: TrainingGoal.loseSteadily),
      );
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          theme: buildTheme(const Locale('en')),
          home: LifeStageView(repository: repo),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('life-stage-no-deficit')), findsNothing);
      await tester.tap(find.text('Pregnant'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('life-stage-no-deficit')),
        findsOneWidget,
      );
      await tester.tap(find.text('Nothing right now'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('life-stage-no-deficit')), findsNothing);
    });

    testWidgets('a goal that is not losing weight says nothing', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          theme: buildTheme(const Locale('en')),
          home: LifeStageView(repository: InMemoryIntakeRepository()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pregnant'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('life-stage-no-deficit')), findsNothing);
    });
  });
}
