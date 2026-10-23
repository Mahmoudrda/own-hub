import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/features/private_coaching/domain/coach_plan.dart';
import 'package:own_hub/features/private_coaching/domain/coaching_contract.dart';
import 'package:own_hub/features/private_coaching/domain/coaching_failure.dart';
import 'package:own_hub/features/private_coaching/domain/subscription.dart';
import 'package:own_hub/features/private_coaching/presentation/plans/schedule_session_sheet.dart';
import 'package:own_hub/features/private_coaching/presentation/plans/share_meal_plan_view.dart';
import 'package:own_hub/features/private_coaching/presentation/plans/share_workout_view.dart';

import 'package:own_hub/ui/app_button.dart';

import 'plans_support.dart';

void _phone(WidgetTester t) {
  t.view.physicalSize = const Size(1170, 3200);
  t.view.devicePixelRatio = 3;
  addTearDown(t.view.reset);
}

void main() {
  testWidgets('workout: start from a split, name it, publish', (t) async {
    _phone(t);
    final repo = RecordingRepo(uid: 'coach1');
    String? sent;
    await t.pumpWidget(
      host(
        ShareWorkoutView(
          repository: repo,
          subscription: sub(),
          clientName: 'Mai',
          splits: [split()],
          onPublished: (id, rev) => sent = id,
        ),
      ),
    );
    await t.tap(find.byKey(const ValueKey('workout-split-0')));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('workout-day-1')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('workout-publish')));
    await t.pumpAndSettle();
    expect(repo.calls.where((c) => c.$1 == 'publish'), isNotEmpty);
    // The split's name was filled in, so it went out.
    final req = repo.calls.single.$2;
    expect(req['kind'], 'workout');
    expect(req['subId'], 'sub1');
    expect(req['name'], 'Three days');
    expect(sent, 'plan1');
    expect(find.byKey(const ValueKey('workout-published')), findsOneWidget);
  });

  testWidgets('workout: no name blocks the call; update keeps the plan id', (
    t,
  ) async {
    _phone(t);
    final repo = RecordingRepo(uid: 'coach1');
    await t.pumpWidget(
      host(
        ShareWorkoutView(
          repository: repo,
          subscription: sub(),
          clientName: 'Mai',
          existing: CoachPlan(
            id: 'planX',
            kind: PlanKind.workout,
            revision: 2,
            workout: workoutPlan(),
          ),
        ),
      ),
    );
    await t.tap(find.byKey(const ValueKey('workout-publish')));
    await t.pumpAndSettle();
    expect(repo.calls, isEmpty);
    expect(find.byKey(const ValueKey('workout-error')), findsOneWidget);
    await t.enterText(find.byKey(const ValueKey('workout-name')), 'Plan B');
    await t.tap(find.byKey(const ValueKey('workout-publish')));
    await t.pumpAndSettle();
    expect(repo.calls.single.$2['planId'], 'planX');
  });

  testWidgets('a refused publish says so where she can see it', (t) async {
    _phone(t);
    final repo = RecordingRepo(uid: 'coach1')
      ..failPublish = const CoachingFailure(CoachingRefusal.badRequest);
    await t.pumpWidget(
      host(
        ShareWorkoutView(
          repository: repo,
          subscription: sub(),
          clientName: 'Mai',
          existing: CoachPlan(
            id: 'planX',
            kind: PlanKind.workout,
            revision: 2,
            workout: workoutPlan(),
          ),
        ),
      ),
    );
    await t.enterText(find.byKey(const ValueKey('workout-name')), 'Plan B');
    await t.tap(find.byKey(const ValueKey('workout-publish')));
    await t.pumpAndSettle();
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.byKey(const ValueKey('workout-error')), findsOneWidget);
  });

  testWidgets('workout: save as a template writes a draft', (t) async {
    _phone(t);
    final repo = RecordingRepo(uid: 'coach1');
    await t.pumpWidget(
      host(
        ShareWorkoutView(
          repository: repo,
          subscription: sub(),
          splits: [split()],
        ),
      ),
    );
    await t.tap(find.byKey(const ValueKey('workout-split-0')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('workout-save-template')));
    await t.pumpAndSettle();
    expect(repo.calls.single.$1, 'saveDraft');
    expect(repo.calls.single.$2['kind'], 'workout');
  });

  testWidgets('meal: allergen clash is marked and the plan publishes', (
    t,
  ) async {
    _phone(t);
    final repo = RecordingRepo(uid: 'coach1');
    await t.pumpWidget(
      host(
        ShareMealPlanView(
          repository: repo,
          subscription: sub(allergies: ['Sesame']),
          catalog: catalog(),
          clientName: 'Mai',
          existing: CoachPlan(
            id: 'm1',
            kind: PlanKind.meal,
            name: 'Week',
            meal: mealBody(),
          ),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('meal-flag-banner')), findsOneWidget);
    expect(find.byKey(const ValueKey('meal-flag-0-dinner-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('meal-flag-0-breakfast-0')), findsNothing);
    expect(find.byKey(const ValueKey('meal-figures')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('meal-publish')));
    await t.pumpAndSettle();
    final body = repo.calls.single.$2['body'] as Map;
    expect(repo.calls.single.$2['kind'], 'meal');
    expect(repo.calls.single.$2['planId'], 'm1');
    expect(body.containsKey('days'), isTrue);
  });

  testWidgets('meal: add a free line to a slot', (t) async {
    _phone(t);
    final repo = RecordingRepo(uid: 'coach1');
    await t.pumpWidget(
      host(
        ShareMealPlanView(
          repository: repo,
          subscription: sub(),
          catalog: catalog(),
          clientName: 'Mai',
        ),
      ),
    );
    await t.tap(find.byKey(const ValueKey('meal-add-snack')));
    await t.pumpAndSettle();
    await t.tap(find.text('Her choice'));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const ValueKey('add-free')), 'Fruit');
    await t.pump();
    await t.tap(find.byKey(const ValueKey('add-confirm')));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('meal-item-0-snack-0')), findsOneWidget);
    await t.enterText(find.byKey(const ValueKey('meal-name')), 'Week');
    await t.tap(find.byKey(const ValueKey('meal-publish')));
    await t.pumpAndSettle();
    expect(repo.calls.single.$1, 'publish');
  });

  for (final kind in ['recipe', 'food']) {
    testWidgets('meal: tapping a $kind adds it and closes the sheet', (
      t,
    ) async {
      _phone(t);
      final repo = RecordingRepo(uid: 'coach1');
      await t.pumpWidget(
        host(
          ShareMealPlanView(
            repository: repo,
            subscription: sub(),
            catalog: catalog(),
            clientName: 'Mai',
          ),
        ),
      );
      await t.tap(find.byKey(const ValueKey('meal-add-breakfast')));
      await t.pumpAndSettle();
      if (kind == 'food') {
        await t.tap(find.text('Foods'));
        await t.pumpAndSettle();
      }
      await t.tap(
        find.byKey(
          ValueKey(kind == 'recipe' ? 'add-recipe-r1' : 'add-food-f1'),
        ),
      );
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('add-tabs')), findsNothing);
      expect(
        find.byKey(const ValueKey('meal-item-0-breakfast-0')),
        findsOneWidget,
      );
      await t.enterText(find.byKey(const ValueKey('meal-name')), 'Week');
      await t.tap(find.byKey(const ValueKey('meal-publish')));
      await t.pumpAndSettle();
      final day = ((repo.calls.single.$2['body'] as Map)['days'] as List).first;
      final item = (((day as Map)['slots'] as Map)['breakfast'] as List).single;
      expect(
        (item as Map)[kind == 'recipe' ? 'recipeId' : 'foodId'],
        kind == 'recipe' ? 'r1' : 'f1',
      );
    });
  }

  testWidgets('session sheet: a bad link is refused before the call', (
    t,
  ) async {
    _phone(t);
    final repo = RecordingRepo(uid: 'coach1');
    final now = DateTime.utc(2026, 10, 24, 12);
    await t.pumpWidget(
      host(
        Scaffold(
          body: ScheduleSessionSheet(
            repository: repo,
            subscription: sub(),
            sessions: const [],
            clientName: 'Mai',
            now: () => now,
          ),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('session-used')), findsOneWidget);
    final send = find.byKey(const ValueKey('session-send'));
    bool enabled() => t.widget<AppButton>(send).onPressed != null;
    // Nothing chosen yet: it cannot be sent.
    expect(enabled(), isFalse);
    await t.tap(find.byKey(const ValueKey('session-time')));
    await t.pumpAndSettle();
    await t.tap(find.text('OK'));
    await t.pumpAndSettle();
    await t.tap(find.text('OK'));
    await t.pumpAndSettle();
    expect(find.text('Sat 24 Oct, 18:00'), findsOneWidget);
    expect(enabled(), isFalse);
    await t.enterText(
      find.byKey(const ValueKey('session-link')),
      'https://example.com/room',
    );
    await t.pump();
    expect(enabled(), isFalse);
    expect(find.byKey(const ValueKey('session-error')), findsOneWidget);
    expect(repo.calls, isEmpty);
    await t.enterText(
      find.byKey(const ValueKey('session-link')),
      'https://meet.google.com/abc-defg-hij',
    );
    await t.pump();
    expect(enabled(), isTrue);
    await t.tap(send);
    await t.pumpAndSettle();
    final call = repo.calls.single.$2;

    expect((call['startsAt'] as DateTime).isUtc, isTrue);
    expect(call['minutes'], 30);
    expect(find.byKey(const ValueKey('session-sent')), findsOneWidget);
    // Sent, the form is gone and one button closes the sheet.
    expect(find.byKey(const ValueKey('session-send')), findsNothing);
    expect(find.byKey(const ValueKey('session-done')), findsOneWidget);
  });

  testWidgets('session sheet: no sessions left', (t) async {
    _phone(t);
    await t.pumpWidget(
      host(
        Scaffold(
          body: ScheduleSessionSheet(
            repository: RecordingRepo(),
            subscription: sub(included: 1),
            sessions: [LiveSession(id: 'a', status: SessionStatus.confirmed)],
          ),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('session-none-left')), findsOneWidget);
    expect(find.byKey(const ValueKey('session-send')), findsNothing);
  });
}
