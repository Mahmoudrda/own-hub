import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/features/eat/domain/allergy_guard.dart';
import 'package:own_hub/features/onboarding/domain/intake.dart' show LifeStage;
import 'package:own_hub/features/private_coaching/domain/coach_plan.dart';
import 'package:own_hub/features/private_coaching/domain/coaching_contract.dart';
import 'package:own_hub/features/private_coaching/domain/subscription.dart';
import 'package:own_hub/features/private_coaching/presentation/client/coach_home_card.dart';
import 'package:own_hub/features/private_coaching/presentation/client/coach_plan_view.dart';
import 'package:own_hub/features/private_coaching/presentation/client/from_your_coach_section.dart';
import 'package:own_hub/features/private_coaching/presentation/client/my_coach_view.dart';
import 'package:own_hub/features/train/domain/my_plan.dart';

import '../../../helpers/exercise_library_fixture.dart';
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
        await t.ensureVisible(find.byKey(const ValueKey('session-confirm-p')));
        await t.tap(find.byKey(const ValueKey('session-confirm-p')));
        await t.pumpAndSettle();
        expect(repo.calls.last.$1, 'respond');
        expect(repo.calls.last.$2['confirm'], isTrue);
        await t.ensureVisible(find.byKey(const ValueKey('session-join-c')));
        await t.tap(find.byKey(const ValueKey('session-join-c')));
        expect(joined, 'https://meet.google.com/abc-defg-hij');
        await t.ensureVisible(find.byKey(const ValueKey('session-done-c')));
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
        expect(find.byKey(const ValueKey('session-waiting-c')), findsOneWidget);
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
                  onOpen: () {},
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
            onStartWorkout: (d) => started = d,
          ),
        ),
      );
      expect(find.byKey(const ValueKey('plan-doctor-line')), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('plan-start-1')));
      expect(started, 1);
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
      expect(opened, 'r1');
    });
  });
}
