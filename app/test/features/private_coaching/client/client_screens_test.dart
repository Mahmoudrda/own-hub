import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/private_coaching_state.dart';
import 'package:own_hub/features/eat/domain/allergy_guard.dart';
import 'package:own_hub/features/onboarding/domain/intake.dart' show LifeStage;
import 'package:own_hub/features/private_coaching/domain/coach_plan.dart';
import 'package:own_hub/features/private_coaching/domain/coaching_contract.dart';
import 'package:own_hub/features/private_coaching/domain/subscription.dart';
import 'package:own_hub/features/private_coaching/presentation/client/coach_home_card.dart';
import 'package:own_hub/features/private_coaching/presentation/client/coach_plan_view.dart';
import 'package:own_hub/features/private_coaching/presentation/client/coach_today.dart';
import 'package:own_hub/features/private_coaching/presentation/client/from_your_coach_section.dart';
import 'package:own_hub/features/private_coaching/presentation/client/my_coach_view.dart';
import 'package:own_hub/app_state/coach_meal_swaps.dart';
import 'package:own_hub/features/private_coaching/presentation/client/grocery_list.dart';
import 'package:own_hub/features/private_coaching/presentation/client/grocery_list_view.dart';
import 'package:own_hub/features/train/domain/my_plan.dart';
import 'package:own_hub/ui/app_button.dart';
import 'package:own_hub/ui/app_list_item.dart';

import '../../../helpers/exercise_library_fixture.dart';
import '../support/fake_coaching_repository.dart';
import '../plans/plans_support.dart';

void _phone(WidgetTester t) {
  t.view.physicalSize = const Size(1170, 3600);
  t.view.devicePixelRatio = 3;
  addTearDown(t.view.reset);
}

final _now = DateTime.utc(2026, 10, 24, 12);
final _start = DateTime.utc(2026, 10, 24, 10);

CoachPlan _workout() => CoachPlan(
  id: 'w1',
  kind: PlanKind.workout,
  coachUid: 'coach1',
  coachName: 'Sara',
  name: 'Strength',
  workout: workoutPlan(),
);

CoachPlan _meal() => CoachPlan(
  id: 'm1',
  kind: PlanKind.meal,
  coachUid: 'coach1',
  name: 'Week',
  meal: mealBody(),
  publishedAt: DateTime.utc(2026, 10, 24, 6),
);

void main() {
  for (final lang in ['en', 'ar']) {
    group('MyCoachView $lang at text scale 2', () {
      testWidgets('active: days, sessions, plans, confirm, join, done', (
        t,
      ) async {
        _phone(t);
        final repo = RecordingRepo()
          ..sessions = [
            LiveSession(
              id: 'p',
              status: SessionStatus.proposed,
              startsAt: DateTime.utc(2026, 10, 28, 15),
              minutes: 45,
              link: 'https://meet.google.com/abc-defg-hij',
            ),
            LiveSession(
              id: 'c',
              status: SessionStatus.confirmed,
              startsAt: _start,
              minutes: 30,
              link: 'https://meet.google.com/abc-defg-hij',
            ),
          ];
        String? joined;
        await t.pumpWidget(
          host(
            MyCoachView(
              repository: repo,
              subscription: sub(),
              plans: [_workout(), _meal()],
              hasUnread: true,
              now: () => _now,
              onMessage: () {},
              onBlock: () {},
              onJoin: (l) => joined = l,
            ),
            locale: Locale(lang),
            scale: 2,
          ),
        );
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        expect(find.byKey(const ValueKey('coach-days-left')), findsOneWidget);
        expect(
          find.byKey(const ValueKey('coach-sessions-used')),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('coach-message')), findsOneWidget);
        expect(find.byKey(const ValueKey('coach-plan-w1')), findsOneWidget);
        // Each session is one row; its tap opens what she can do with it.
        Future<void> open(String id) async {
          await t.ensureVisible(find.byKey(ValueKey('session-$id')));
          await t.tap(find.byKey(ValueKey('session-$id')));
          await t.pumpAndSettle();
        }

        await open('p');
        await t.tap(find.byKey(const ValueKey('session-decline-p')));
        await t.pumpAndSettle();
        expect(repo.calls.last.$2['confirm'], isFalse);
        await open('p');
        await t.tap(find.byKey(const ValueKey('session-confirm-p')));
        await t.pumpAndSettle();
        expect(repo.calls.last.$1, 'respond');
        expect(repo.calls.last.$2['confirm'], isTrue);
        await open('c');
        await t.tap(find.byKey(const ValueKey('session-join-c')));
        await t.pumpAndSettle();
        expect(joined, 'https://meet.google.com/abc-defg-hij');
        await open('c');
        await t.tap(find.byKey(const ValueKey('session-done-c')));
        await t.pumpAndSettle();
        expect(repo.calls.last.$1, 'done');
      });

      testWidgets('i already marked it: it waits for the other side', (
        t,
      ) async {
        _phone(t);
        final repo = RecordingRepo()
          ..sessions = [
            LiveSession(
              id: 'c',
              status: SessionStatus.confirmed,
              startsAt: _start,
              minutes: 30,
              doneBy: const ['client1'],
            ),
          ];
        await t.pumpWidget(
          host(
            MyCoachView(repository: repo, subscription: sub(), now: () => _now),
            locale: Locale(lang),
            scale: 2,
          ),
        );
        await t.pumpAndSettle();
        expect(find.byKey(const ValueKey('session-done-c')), findsNothing);
        // Nothing left for her to do: the row is there and does not open.
        expect(
          t.widget<AppListItem>(find.byKey(const ValueKey('session-c'))).onTap,
          isNull,
        );
        expect(find.byKey(const ValueKey('coach-no-plans')), findsOneWidget);
      });

      testWidgets('ended: read only, plans still open', (t) async {
        _phone(t);
        final repo = RecordingRepo()
          ..sessions = [
            LiveSession(
              id: 'p',
              status: SessionStatus.proposed,
              startsAt: DateTime.utc(2026, 10, 28, 15),
            ),
          ];
        CoachPlan? opened;
        await t.pumpWidget(
          host(
            MyCoachView(
              repository: repo,
              subscription: sub(status: SubscriptionStatus.ended),
              plans: [_workout()],
              now: () => _now,
              onMessage: () {},
              onOpenPlan: (p) => opened = p,
            ),
            locale: Locale(lang),
            scale: 2,
          ),
        );
        await t.pumpAndSettle();
        expect(find.byKey(const ValueKey('coaching-ended')), findsOneWidget);
        expect(find.byKey(const ValueKey('coach-message')), findsNothing);
        expect(find.byKey(const ValueKey('session-confirm-p')), findsNothing);
        expect(find.byKey(const ValueKey('coach-days-left')), findsNothing);
        await t.ensureVisible(find.byKey(const ValueKey('coach-plan-w1')));
        await t.tap(find.byKey(const ValueKey('coach-plan-w1')));
        expect(opened?.id, 'w1');
      });
    });

    testWidgets('cards render $lang at text scale 2', (t) async {
      _phone(t);
      var started = -1;
      final logged = <String>[];
      await t.pumpWidget(
        host(
          SingleChildScrollView(
            child: Column(
              children: [
                CoachHomeCard(
                  workout: _workout(),
                  nextSession: LiveSession(
                    id: 'c',
                    status: SessionStatus.confirmed,
                    startsAt: DateTime.utc(2026, 10, 28, 15),
                  ),
                  hasUnread: true,
                  onStartWorkout: (p, d) => started = d,
                ),
                FromYourCoachSection(
                  plan: _meal(),
                  now: _now,
                  catalog: catalog(),
                  constraints: const DietaryConstraints(allergies: {'sesame'}),
                  onLog: (item, slot) => logged.add(slot),
                ),
              ],
            ),
          ),
          locale: Locale(lang),
          scale: 2,
        ),
      );
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.byKey(const ValueKey('coach-home-workout')), findsOneWidget);
      expect(find.byKey(const ValueKey('coach-home-session')), findsOneWidget);
      expect(find.byKey(const ValueKey('coach-home-unread')), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('coach-home-start')));
      expect(started, 0);
      expect(
        find.byKey(const ValueKey('coach-meal-dinner-0-flag')),
        findsOneWidget,
      );
      await t.ensureVisible(
        find.byKey(const ValueKey('coach-meal-breakfast-0-log')),
      );
      await t.tap(find.byKey(const ValueKey('coach-meal-breakfast-0-log')));
      expect(logged, ['breakfast']);
      expect(
        find.byKey(const ValueKey('coach-meal-lunch-1-log')),
        findsNothing,
        reason: 'a free line cannot be logged',
      );
    });
  }

  group('CoachPlanView', () {
    testWidgets('start goes out through the callback', (t) async {
      _phone(t);
      var started = -1;
      await t.pumpWidget(
        host(
          CoachPlanView(
            plan: _workout(),
            exercises: sampleExerciseLibrary().exercises,
            doneThisWeek: 1,
            onStartWorkout: (d) => started = d,
          ),
        ),
      );
      expect(find.byKey(const ValueKey('plan-doctor-line')), findsOneWidget);
      // Only today's day is open and carries the filled Start.
      expect(find.byKey(const ValueKey('plan-start-0')), findsNothing);
      expect(
        t.widget<AppButton>(find.byKey(const ValueKey('plan-start-1'))).variant,
        AppButtonVariant.filled,
      );
      await t.tap(find.byKey(const ValueKey('plan-start-1')));
      expect(started, 1);
      // Another day opens on a tap and starts with a text button.
      await t.tap(find.byKey(const ValueKey('plan-workout-day-0')));
      await t.pumpAndSettle();
      expect(
        t.widget<AppButton>(find.byKey(const ValueKey('plan-start-0'))).variant,
        AppButtonVariant.text,
      );
      await t.tap(find.byKey(const ValueKey('plan-start-0')));
      expect(started, 0);
    });

    testWidgets('a move her stage holds back blocks starting that day', (
      t,
    ) async {
      _phone(t);
      final plan = CoachPlan(
        id: 'w2',
        kind: PlanKind.workout,
        workout: MyPlan(
          days: [
            MyPlanDay(
              session: AuthoredSessionFor.make([
                move('standing_forward_fold'),
                move('glute_bridge', tags: const []),
              ]),
            ),
          ],
        ),
      );
      var started = false;
      await t.pumpWidget(
        host(
          CoachPlanView(
            plan: plan,
            lifeStage: LifeStage.pregnant,
            exercises: sampleExerciseLibrary().exercises,
            onStartWorkout: (_) => started = true,
          ),
        ),
      );
      expect(find.byKey(const ValueKey('plan-held-note-0')), findsOneWidget);
      await t.tap(
        find.byKey(const ValueKey('plan-start-0')),
        warnIfMissed: false,
      );
      expect(started, isFalse);
    });

    testWidgets('meal plan: allergen line, recipe opens, preview has no log', (
      t,
    ) async {
      _phone(t);
      String? opened;
      await t.pumpWidget(
        host(
          CoachPlanView(
            plan: _meal(),
            catalog: catalog(),
            constraints: const DietaryConstraints(allergies: {'sesame'}),
            onOpenRecipe: (id) => opened = id,
            onLog: (_, _) {},
            preview: true,
            now: () => _now,
          ),
        ),
      );
      expect(
        find.byKey(const ValueKey('plan-item-0-dinner-0-flag')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('plan-day-figures-0')), findsOneWidget);
      expect(find.textContaining('-log'), findsNothing);
      expect(
        find.byKey(const ValueKey('plan-item-0-breakfast-0-log')),
        findsNothing,
      );
      await t.tap(find.byKey(const ValueKey('plan-item-0-breakfast-0')));
      await t.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('plan-item-0-breakfast-0-log')),
        findsNothing,
      );
      await t.tap(find.byKey(const ValueKey('plan-item-0-breakfast-0-recipe')));
      expect(opened, 'r1');
    });

    testWidgets('meal plan: a row opens a sheet with Log this', (t) async {
      _phone(t);
      String? slot;
      await t.pumpWidget(
        host(
          CoachPlanView(
            plan: _meal(),
            catalog: catalog(),
            onLog: (_, s) => slot = s,
            now: () => _now,
          ),
        ),
      );
      await t.tap(find.byKey(const ValueKey('plan-item-0-breakfast-0')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('plan-item-0-breakfast-0-log')));
      expect(slot, 'breakfast');
    });

    test('two weeks follow the start date', () {
      final plan = MyPlan(
        days: [
          for (var i = 0; i < 6; i++)
            MyPlanDay(
              session: AuthoredSessionFor.make([move('m$i')]),
              week: i < 3 ? 1 : 2,
            ),
        ],
      );
      final monday = DateTime(2026, 10, 26, 12);
      expect(todaysWorkoutDay(plan, 0, null, startsOn: monday, now: monday), 0);
      expect(todaysWorkoutDay(plan, 1, null, startsOn: monday, now: monday), 1);
      expect(
        todaysWorkoutDay(
          plan,
          0,
          null,
          startsOn: monday,
          now: monday.add(const Duration(days: 8)),
        ),
        3,
      );
      expect(
        todaysWorkoutDay(
          plan,
          0,
          null,
          startsOn: monday,
          now: monday.add(const Duration(days: 30)),
        ),
        3,
      );
      expect(
        todaysWorkoutDay(
          plan,
          0,
          null,
          startsOn: monday,
          now: monday.subtract(const Duration(days: 1)),
        ),
        isNull,
      );
      final oneWeek = workoutPlan();
      expect(
        todaysWorkoutDay(
          oneWeek,
          0,
          null,
          startsOn: monday,
          now: monday.subtract(const Duration(days: 5)),
        ),
        0,
      );
    });

    testWidgets('client plan shows the current week only', (t) async {
      _phone(t);
      final monday = DateTime(2026, 10, 26, 12);
      final twoWeeks = workoutPlan().withRepeatedLastWeek();
      final plan = CoachPlan(
        id: 'w2',
        kind: PlanKind.workout,
        coachUid: 'coach1',
        name: 'Two weeks',
        workout: twoWeeks,
        startsOn: monday,
      );
      await t.pumpWidget(
        host(
          CoachPlanView(
            plan: plan,
            now: () => monday.add(const Duration(days: 8)),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(
        t.widget<Text>(find.byKey(const ValueKey('plan-week-line'))).data,
        'Week 2 of 2',
      );
      expect(find.byKey(const ValueKey('plan-workout-day-0')), findsNothing);
      expect(find.byKey(const ValueKey('plan-workout-day-2')), findsOneWidget);
      expect(find.byKey(const ValueKey('plan-workout-day-3')), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('plan-all-weeks')));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('plan-workout-day-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('plan-workout-day-3')), findsOneWidget);
    });

    testWidgets('client home card before the start', (t) async {
      _phone(t);
      final tomorrow = DateTime.now().add(const Duration(days: 2));
      final twoWeeks = workoutPlan().withRepeatedLastWeek();
      final plan = CoachPlan(
        id: 'w2',
        kind: PlanKind.workout,
        coachUid: 'coach1',
        name: 'Two weeks',
        workout: twoWeeks,
        startsOn: DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 12),
      );
      await t.pumpWidget(
        host(
          Scaffold(
            body: CoachHomeCard(workout: plan, onStartWorkout: (_, _) {}),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('coach-home-start')), findsNothing);
    });

    testWidgets('eat card: log is one tap', (t) async {
      _phone(t);
      MealItem? loggedItem;
      String? loggedSlot;
      final plan = CoachPlan(
        id: 'm1',
        kind: PlanKind.meal,
        coachUid: 'coach1',
        meal: MealPlanBody(
          days: [
            MealDay(
              label: 'Day 1',
              slots: {
                'lunch': [MealItem.food('f1', 150)],
              },
            ),
          ],
        ),
        publishedAt: _start,
      );
      await t.pumpWidget(
        host(
          Scaffold(
            body: FromYourCoachSection(
              plan: plan,
              now: _now,
              catalog: catalog(),
              onLog: (item, slot) {
                loggedItem = item;
                loggedSlot = slot;
              },
            ),
          ),
        ),
      );
      await t.tap(find.byKey(const ValueKey('coach-meal-lunch-0-log')));
      await t.pumpAndSettle();
      expect(loggedSlot, 'lunch');
      expect(loggedItem?.foodId, 'f1');
      expect(loggedItem?.grams, 150);
    });

    testWidgets(
      'eat card: a recipe can be logged only when the book has its figures',
      (t) async {
        _phone(t);
        final plan = CoachPlan(
          id: 'm1',
          kind: PlanKind.meal,
          coachUid: 'coach1',
          meal: MealPlanBody(
            days: [
              MealDay(
                label: 'Day 1',
                slots: {
                  'lunch': [MealItem.recipe('r1', 1), MealItem.recipe('nm', 1)],
                },
              ),
            ],
          ),
          publishedAt: _start,
        );
        await t.pumpWidget(
          host(
            Scaffold(
              body: FromYourCoachSection(
                plan: plan,
                now: _now,
                catalog: catalog(
                  recipes: [recipe('r1'), recipe('nm', kcal: null)],
                ),
                onLog: (_, _) {},
                onOpenRecipe: (_) {},
              ),
            ),
          ),
        );
        expect(
          find.byKey(const ValueKey('coach-meal-lunch-0-log')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('coach-meal-lunch-1-log')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('coach-meal-lunch-1')),
          findsOneWidget,
        );
      },
    );

    testWidgets('a client with an eating history is shown no coach target', (
      t,
    ) async {
      _phone(t);
      final repo = FakeCoachingRepository(uid: 'client1');
      PrivateCoachingState.instance.start(repo);
      addTearDown(PrivateCoachingState.instance.stop);
      repo.clientSubs.value = [
        Subscription(
          id: 'sub1',
          coachUid: 'coach1',
          clientUid: 'client1',
          status: SubscriptionStatus.active,
          intake: const Intake(eatingHistory: true),
        ),
      ];
      await t.pump();
      final withGoal = CoachPlan(
        id: 'm1',
        kind: PlanKind.meal,
        coachUid: 'coach1',
        meal: MealPlanBody(
          goal: const MealGoal(kcalPerDay: 1600, proteinGPerDay: 110),
          days: [
            MealDay(
              label: 'Day 1',
              slots: {
                'lunch': [MealItem.food('f1', 150)],
              },
            ),
          ],
        ),
        publishedAt: _start,
      );
      await t.pumpWidget(
        host(
          Scaffold(
            body: FromYourCoachSection(
              plan: withGoal,
              now: _now,
              catalog: catalog(),
            ),
          ),
        ),
      );
      expect(find.byKey(const ValueKey('coach-goal-line')), findsNothing);
      expect(find.textContaining('1600'), findsNothing);
    });

    testWidgets('eat card: goal line and planned total', (t) async {
      _phone(t);
      final withGoal = CoachPlan(
        id: 'm1',
        kind: PlanKind.meal,
        coachUid: 'coach1',
        meal: MealPlanBody(
          goal: const MealGoal(kcalPerDay: 1600, proteinGPerDay: 110),
          days: [
            MealDay(
              label: 'Day 1',
              slots: {
                'lunch': [MealItem.food('f1', 150)],
              },
            ),
          ],
        ),
        publishedAt: _start,
      );
      await t.pumpWidget(
        host(
          Scaffold(
            body: FromYourCoachSection(
              plan: withGoal,
              now: _now,
              catalog: catalog(),
            ),
          ),
        ),
      );
      expect(find.byKey(const ValueKey('coach-goal-line')), findsOneWidget);
      expect(
        find.text('Your coach\'s target: 1600 calories and 110 g protein'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('coach-planned-line')), findsOneWidget);

      final withoutGoal = CoachPlan(
        id: 'm2',
        kind: PlanKind.meal,
        coachUid: 'coach1',
        meal: MealPlanBody(
          days: [
            MealDay(
              label: 'Day 1',
              slots: {
                'lunch': [MealItem.food('f1', 150)],
              },
            ),
          ],
        ),
        publishedAt: _start,
      );
      await t.pumpWidget(
        host(
          Scaffold(
            body: FromYourCoachSection(
              plan: withoutGoal,
              now: _now,
              catalog: catalog(),
            ),
          ),
        ),
      );
      expect(find.byKey(const ValueKey('coach-goal-line')), findsNothing);
      expect(find.byKey(const ValueKey('coach-planned-line')), findsNothing);
    });

    testWidgets('swap in two taps and log the swapped dish', (t) async {
      _phone(t);
      addTearDown(
        () => CoachMealSwaps.instance.choose('m1', 0, 'lunch', 0, null),
      );
      MealItem? loggedItem;
      final cat = catalog(recipes: [recipe('r1'), recipe('r2')]);
      final plan = CoachPlan(
        id: 'm1',
        kind: PlanKind.meal,
        coachUid: 'coach1',
        meal: MealPlanBody(
          days: [
            MealDay(
              label: 'Day 1',
              slots: {
                'lunch': [
                  const MealItem.recipe('r1', 2, swaps: ['r2']),
                ],
              },
            ),
          ],
        ),
        publishedAt: _start,
      );

      await t.pumpWidget(
        host(
          Builder(
            builder: (context) => Scaffold(
              body: FromYourCoachSection(
                plan: plan,
                now: _now,
                catalog: cat,
                onSwap: (day, slot, index, item) {
                  showModalBottomSheet<void>(
                    context: context,
                    builder: (ctx) => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final id in item.swaps)
                          ListTile(
                            key: ValueKey('swap-choice-$id'),
                            title: Text(id),
                            onTap: () {
                              CoachMealSwaps.instance.choose(
                                'm1',
                                day,
                                slot,
                                index,
                                id,
                              );
                              Navigator.of(ctx).pop();
                            },
                          ),
                      ],
                    ),
                  );
                },
                onLog: (item, slot) => loggedItem = item,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Dish r1'), findsOneWidget);

      await t.tap(find.byKey(const ValueKey('coach-meal-lunch-0-swap')));
      await t.pumpAndSettle();

      await t.tap(find.byKey(const ValueKey('swap-choice-r2')));
      await t.pumpAndSettle();

      expect(find.text('Dish r2'), findsOneWidget);

      await t.tap(find.byKey(const ValueKey('coach-meal-lunch-0-log')));
      await t.pumpAndSettle();

      expect(loggedItem?.recipeId, 'r2');
      expect(loggedItem?.servings, 2);
    });

    testWidgets('swap is hidden for a dish without swaps and for a food item', (
      t,
    ) async {
      _phone(t);
      final plan = CoachPlan(
        id: 'm1',
        kind: PlanKind.meal,
        coachUid: 'coach1',
        meal: MealPlanBody(
          days: [
            MealDay(
              label: 'Day 1',
              slots: {
                'lunch': [
                  const MealItem.recipe('r1', 1),
                  MealItem.food('f1', 100),
                ],
              },
            ),
          ],
        ),
        publishedAt: _start,
      );
      await t.pumpWidget(
        host(
          Scaffold(
            body: FromYourCoachSection(
              plan: plan,
              now: _now,
              catalog: catalog(),
              onSwap: (d, s, i, item) {},
            ),
          ),
        ),
      );
      expect(
        find.byKey(const ValueKey('coach-meal-lunch-0-swap')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('coach-meal-lunch-1-swap')),
        findsNothing,
      );
    });

    testWidgets('grocery screen ticks rows and shows the empty text', (
      t,
    ) async {
      _phone(t);
      final lines = [
        const GroceryLine('Chicken', 200),
        const GroceryLine('Rice', 150),
      ];
      await t.pumpWidget(host(GroceryListView(lines: lines)));
      expect(find.byKey(const ValueKey('grocery-empty')), findsNothing);
      final tile0 = t.widget<CheckboxListTile>(
        find.byKey(const ValueKey('grocery-0')),
      );
      expect(tile0.value, isFalse);

      await t.tap(find.byKey(const ValueKey('grocery-0')));
      await t.pumpAndSettle();

      final tile0After = t.widget<CheckboxListTile>(
        find.byKey(const ValueKey('grocery-0')),
      );
      expect(tile0After.value, isTrue);

      await t.pumpWidget(host(const GroceryListView(lines: [])));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('grocery-empty')), findsOneWidget);
    });

    testWidgets('Arabic pump on 320px width of Eat card shows no overflow', (
      t,
    ) async {
      t.view.physicalSize = const Size(320 * 2, 640 * 2);
      t.view.devicePixelRatio = 2;
      addTearDown(t.view.reset);

      final plan = CoachPlan(
        id: 'm1',
        kind: PlanKind.meal,
        coachUid: 'coach1',
        meal: MealPlanBody(
          goal: const MealGoal(kcalPerDay: 1600, proteinGPerDay: 110),
          days: [
            MealDay(
              label: 'اليوم الأول',
              slots: {
                'lunch': [
                  const MealItem.recipe('r1', 1, swaps: ['r2']),
                ],
              },
            ),
          ],
        ),
        publishedAt: _start,
      );
      await t.pumpWidget(
        host(
          Scaffold(
            body: FromYourCoachSection(
              plan: plan,
              now: _now,
              catalog: catalog(),
              onSwap: (d, s, i, item) {},
              onGrocery: () {},
            ),
          ),
          locale: const Locale('ar'),
        ),
      );
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('coach-goal-line')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('coach-meal-lunch-0-swap')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('coach-grocery')), findsOneWidget);
    });
  });
}
