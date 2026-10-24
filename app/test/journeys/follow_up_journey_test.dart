// The follow-ups, walked through the real app: a session on Monday, the
// question on Tuesday, the week review on Friday.
//
// Each screen of it has its own test. This one checks that Home, the stored
// answers and her plan agree with each other when she does it all in a row.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/follow_up_state.dart';
import 'package:own_hub/domain/clock/app_clock.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/domain/week/week_key.dart';
import 'package:own_hub/domain/training/prescribed_set.dart';
import 'package:own_hub/features/eat/domain/meal_repository.dart';
import 'package:own_hub/features/followup/domain/follow_up_plan.dart';
import 'package:own_hub/features/followup/presentation/follow_up_card.dart';
import 'package:own_hub/features/train/domain/train_repository.dart';
import 'package:own_hub/main.dart';
import 'package:own_hub/routing/app_router.dart';

const String _monday = '2026-10-12';

void _logProtein(String dayId, int proteinG) {
  final at = DateTime.parse('${dayId}T13:00:00');
  AppRouter.mealRepository.store.apply(
    MealWrite.transform(
      dayId: dayId,
      slot: MealSlot.lunch,
      tz: WeekKey.fallbackTimezone,
      libVersion: 1,
      added: [
        MealItem(
          itemId: 'p-$dayId',
          foodId: 'boiled_eggs',
          servings: 1,
          size: '2',
          loggedAt: at,
          source: MealSource.search,
          origin: MealOrigin.search,
          kcal: 400,
          proteinG: proteinG,
        ),
      ],
    ),
  );
}

TrainSession _session(String dateKey) => TrainSession(
  id: 'live-$dateKey',
  source: SessionSource.live,
  dateKey: dateKey,
  completed: true,
  endedReason: EndedReason.finished,
  sets: [
    for (var i = 0; i < 3; i++)
      LoggedSet(
        prescribed: PrescribedSet(
          exerciseId: 'goblet_squat',
          order: i,
          weightKg: 12.5,
          reps: 10,
        ),
        outcome: const SetOutcome(weightKg: 12.5, reps: 10),
      ),
  ],
);

Future<void> _openHome(WidgetTester tester) async {
  await tester.pumpWidget(OwnHubApp(key: UniqueKey()));
  await tester.pumpAndSettle();
  tester
      .state<NavigatorState>(find.byType(Navigator).first)
      .pushNamed(appDestinations['T01']!.name);
  await tester.pumpAndSettle();
}

Future<void> _tapKey(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  final saved = AppRouter.featureFlags;

  setUp(() {
    AppRouter.featureFlags = FeatureFlags.allOff.with_({
      for (final f in Feature.values) f: f != Feature.accountRequired,
    });
    FollowUpState.instance.reset();
    FollowUpCard.lastThanks = null;
    AppRouter.trainRepository.restore(sessions: [_session(_monday)]);
    AppRouter.intakeRepository.markSetupDone();
  });

  tearDown(() {
    AppRouter.featureFlags = saved;
    AppClock.debugNow = null;
    FollowUpState.instance.reset();
    FollowUpCard.lastThanks = null;
    AppRouter.trainRepository.reset();
    AppRouter.intakeRepository.reset();
  });

  testWidgets('Tuesday asks how she feels; her answer is kept, and thanked', (
    tester,
  ) async {
    AppClock.debugNow = () => DateTime(2026, 10, 13, 9);
    await AppRouter.todayRepository.countWalk();
    AppRouter.todayRepository.rollTo(DateTime(2026, 10, 13, 9));
    FollowUpState.instance.answerFeel('2026-10-05', Feel.verySore);

    await _openHome(tester);
    expect(
      find.byKey(const ValueKey('follow-up-afterSession')),
      findsOneWidget,
    );
    expect(find.text('How do you feel today?'), findsOneWidget);

    // The card sits under the Eat line now, so scroll to its answers.
    await tester.ensureVisible(find.text('Very sore'));
    await tester.tap(find.text('Very sore'));
    await tester.pumpAndSettle();

    expect(FollowUpState.instance.feels[_monday], Feel.verySore);
    expect(FollowUpPlan.holdsLoad(FollowUpState.instance.feels), isTrue);
    expect(find.text('How do you feel today?'), findsNothing);
    expect(
      find.byKey(const ValueKey('follow-up-afterSession')),
      findsNothing,
      reason: 'answered, so the question is finished',
    );
    expect(find.byKey(const ValueKey('follow-up-thanks')), findsOneWidget);
    expect(
      find.text(
        'Next time, the same weights. Build up again when you feel fresh.',
      ),
      findsOneWidget,
    );

    // Back on Home later, the question does not return.
    FollowUpCard.lastThanks = null;
    await _openHome(tester);
    expect(find.byKey(const ValueKey('follow-up-afterSession')), findsNothing);
    expect(find.byKey(const ValueKey('follow-up-thanks')), findsNothing);
  });

  testWidgets('Not now sends it away for the day', (tester) async {
    AppClock.debugNow = () => DateTime(2026, 10, 13, 9);
    await AppRouter.todayRepository.countWalk();
    AppRouter.todayRepository.rollTo(DateTime(2026, 10, 13, 9));

    await _openHome(tester);
    await _tapKey(tester, 'follow-up-not-now-afterSession');
    expect(find.byKey(const ValueKey('follow-up-afterSession')), findsNothing);
    expect(FollowUpState.instance.feels, isEmpty);
    expect(
      FollowUpState.instance.notBefore[FollowUpKind.afterSession],
      isNotNull,
    );
  });

  testWidgets('the master switch on Notifications takes the card off Home', (
    tester,
  ) async {
    AppClock.debugNow = () => DateTime(2026, 10, 13, 9);
    await AppRouter.todayRepository.countWalk();
    AppRouter.todayRepository.rollTo(DateTime(2026, 10, 13, 9));

    await _openHome(tester);
    tester
        .state<NavigatorState>(find.byType(Navigator).first)
        .pushNamed(appDestinations['A01']!.name);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('a01-follow-ups')), findsOneWidget);
    await _tapKey(tester, 'a01-follow-ups');
    expect(FollowUpState.instance.enabled, isFalse);

    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('follow-up-afterSession')), findsNothing);
  });

  testWidgets('Friday: the week review, Save, then Use this changes her plan', (
    tester,
  ) async {
    AppClock.debugNow = () => DateTime(2026, 10, 16, 9);
    await AppRouter.todayRepository.countWalk();
    AppRouter.todayRepository.rollTo(DateTime(2026, 10, 16, 9));
    final before = AppRouter.intakeRepository.read().days;

    await _openHome(tester);
    expect(find.byKey(const ValueKey('follow-up-weekReview')), findsOneWidget);
    expect(find.textContaining('Sessions: 1'), findsOneWidget);

    await tester.ensureVisible(find.text('3 quick questions'));
    await tester.tap(find.text('3 quick questions'));
    await tester.pumpAndSettle();
    final chips = find.byKey(const ValueKey('week-review-sheet'));
    expect(chips, findsOneWidget);
    await tester.tap(find.text('Okay week'));
    await tester.tap(find.text('Too much'));
    await tester.tap(find.text('Strength'));
    await tester.pump();
    await _tapKey(tester, 'week-review-save');

    expect(FollowUpState.instance.weekReviews['2026-10-10'], isNotNull);
    expect(
      AppRouter.intakeRepository.read().days,
      before,
      reason: 'saving the answers changes nothing',
    );

    await _tapKey(tester, 'week-review-use-days');
    expect(AppRouter.intakeRepository.read().days, before - 1);

    await _tapKey(tester, 'week-review-keep');
    expect(find.byKey(const ValueKey('week-review-sheet')), findsNothing);
    expect(
      find.byKey(const ValueKey('follow-up-weekReview')),
      findsNothing,
      reason: 'reviewed, so the week is not asked about again',
    );
  });

  testWidgets('Friday: the average protein leaves today out', (tester) async {
    AppClock.debugNow = () => DateTime(2026, 10, 16, 9);
    await AppRouter.todayRepository.countWalk();
    AppRouter.todayRepository.rollTo(DateTime(2026, 10, 16, 9));
    _logProtein('2026-10-12', 80);
    _logProtein('2026-10-16', 200);
    addTearDown(AppRouter.mealRepository.store.reset);

    await _openHome(tester);
    expect(find.byKey(const ValueKey('follow-up-weekReview')), findsOneWidget);
    expect(find.textContaining('Average protein: 80 g'), findsOneWidget);
  });
}
