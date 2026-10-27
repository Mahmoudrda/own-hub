import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/features/private_coaching/domain/coach_plan.dart';
import 'package:own_hub/features/private_coaching/domain/coaching_contract.dart';
import 'package:own_hub/features/private_coaching/domain/coaching_failure.dart';
import 'package:own_hub/features/private_coaching/domain/subscription.dart';
import 'package:own_hub/features/private_coaching/presentation/plans/assign_clients_sheet.dart';
import 'package:own_hub/features/private_coaching/presentation/plans/coach_day_editor_view.dart';
import 'package:own_hub/features/private_coaching/presentation/plans/coach_plan_logic.dart';
import 'package:own_hub/features/private_coaching/presentation/plans/schedule_session_sheet.dart';
import 'package:own_hub/features/private_coaching/presentation/plans/share_meal_plan_view.dart';
import 'package:own_hub/features/private_coaching/presentation/plans/share_workout_view.dart';
import 'package:own_hub/features/onboarding/domain/starting_program.dart';
import 'package:own_hub/features/onboarding/domain/intake.dart' show LifeStage;
import 'package:own_hub/features/train/domain/my_plan.dart';
import 'package:own_hub/features/train/domain/workout_library.dart';
import 'package:own_hub/features/train/presentation/plan_editor_view.dart';
import 'package:own_hub/routing/coaching_wiring.dart';

import 'package:own_hub/domain/format/day_key.dart';
import 'package:own_hub/ui/app_button.dart';

import '../../../helpers/primary_actions.dart';

import 'plans_support.dart';

void _phone(WidgetTester t) {
  t.view.physicalSize = const Size(1170, 3200);
  t.view.devicePixelRatio = 3;
  addTearDown(t.view.reset);
}

/// Wide enough for the test font to fit the target bars' two-ended rows.
void _wide(WidgetTester t) {
  t.view.physicalSize = const Size(1800, 3200);
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

  testWidgets('a publish refused as not reviewed says so', (t) async {
    _phone(t);
    final repo = RecordingRepo(uid: 'coach1')
      ..failPublish = const CoachingFailure(CoachingRefusal.healthNotReviewed);
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
    expect(
      find.text(
        'Read her health answers first. Open her page and tick that you have.',
      ),
      findsWidgets,
    );
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
    await t.ensureVisible(find.byKey(const ValueKey('meal-add-snack')));
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

  testWidgets('day editor: details sheet saves weight, rest, note, superset', (
    t,
  ) async {
    _phone(t);
    final state = CoachPlanEditState(workoutPlan());
    await t.pumpWidget(
      host(
        CoachDayEditorView(
          state: state,
          dayIndex: 0,
          pickExercises: () async => null,
        ),
      ),
    );
    await t.tap(find.byKey(const ValueKey('move-details-0')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const ValueKey('details-kg')), '12.5');
    await t.tap(find.byKey(const ValueKey('details-rest-plus')));
    await t.pump();
    await t.tap(find.byKey(const ValueKey('details-rest-plus')));
    await t.pump();
    await t.enterText(find.byKey(const ValueKey('details-note')), 'Slow');
    await t.tap(find.byKey(const ValueKey('details-superset')));
    await t.pump();
    await t.tap(find.byKey(const ValueKey('details-save')));
    await t.pumpAndSettle();

    final day = state.current!.days[0];
    final move0 = day.session.moves[0];
    expect(day.kgAt(0), 12.5);
    expect(move0.restSeconds, 90);
    expect(move0.notesEn, 'Slow');
    expect(move0.supersetWithNext, isTrue);
    final summary = t.widget<Text>(
      find.byKey(const ValueKey('move-summary-0')),
    );
    expect(summary.data, contains('12.5'));
  });

  testWidgets('day editor: empty weight clears the target', (t) async {
    _phone(t);
    final state = CoachPlanEditState(
      changeMoveDetails(workoutPlan(), 0, 0, kg: 15),
    );
    await t.pumpWidget(
      host(
        CoachDayEditorView(
          state: state,
          dayIndex: 0,
          pickExercises: () async => null,
        ),
        locale: const Locale('ar'),
      ),
    );
    await t.tap(find.byKey(const ValueKey('move-details-0')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const ValueKey('details-kg')), '');
    await t.tap(find.byKey(const ValueKey('details-save')));
    await t.pumpAndSettle();
    expect(state.current!.days[0].kgAt(0), isNull);
  });

  testWidgets('day editor: last move cannot be a superset', (t) async {
    _phone(t);
    final state = CoachPlanEditState(workoutPlan());
    await t.pumpWidget(
      host(
        CoachDayEditorView(
          state: state,
          dayIndex: 0,
          pickExercises: () async => null,
        ),
      ),
    );
    await t.tap(find.byKey(const ValueKey('move-details-1')));
    await t.pumpAndSettle();
    final tile = t.widget<SwitchListTile>(
      find.byKey(const ValueKey('details-superset')),
    );
    expect(tile.onChanged, isNull);
  });

  testWidgets('plan editor: Duplicate adds a named copy in one tap', (t) async {
    _phone(t);
    var p = workoutPlan();
    p = p.withCopyOf(0);
    expect(p.days.length, 3);
    final state = CoachPlanEditState(p);
    await t.pumpWidget(
      host(
        PlanEditorView(
          state: state,
          onEditDay: (_) {},
          onPickMoves: () async => null,
        ),
      ),
    );
    final day0Title = p.days[0].session.titleEn;
    await t.tap(find.byKey(const ValueKey('plan-duplicate-0')));
    await t.pumpAndSettle();
    final updated = state.current!;
    expect(updated.days.length, 4);
    expect(updated.days[3].session.titleEn, '$day0Title (copy)');
    expect(updated.days[3].session.moves, p.days[0].session.moves);
    expect(
      updated.days[3].session.sessionId,
      isNot(p.days[0].session.sessionId),
    );
  });

  testWidgets('plan editor: Duplicate is off when the week is full', (t) async {
    _phone(t);
    var p = workoutPlan();
    while (p.days.length < kMaxPlanDays) {
      p = p.withCopyOf(0);
    }
    expect(p.days.length, 7);
    final state = CoachPlanEditState(p);
    await t.pumpWidget(
      host(
        PlanEditorView(
          state: state,
          onEditDay: (_) {},
          onPickMoves: () async => null,
        ),
      ),
    );
    final btn = t.widget<ButtonStyleButton>(
      find.descendant(
        of: find.byKey(const ValueKey('plan-duplicate-0')),
        matching: find.bySubtype<ButtonStyleButton>(),
      ),
    );
    expect(btn.onPressed, isNull);
  });

  test('the seeded splits are offered: 3 families, 3 levels', () {
    addTearDown(StartingProgrammes.reset);
    StartingProgrammes.adopt(
      File('assets/content/starting_programmes.json').readAsStringSync(),
    );
    final splits = coachSplits();
    expect(splits.length, 9);
    expect({for (final s in splits) programmeFamily(s.programId)}.length, 3);
  });

  testWidgets('assign: pick one more client and publish', (t) async {
    _phone(t);
    final repo = RecordingRepo(uid: 'coach1');
    await t.pumpWidget(
      host(
        ShareWorkoutView(
          repository: repo,
          subscription: sub(),
          clientName: 'Mariam',
          others: const [AssignClient(subId: 'nour', name: 'Nour')],
          splits: [split()],
        ),
      ),
    );
    await t.tap(find.byKey(const ValueKey('workout-split-0')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('assign-more')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('assign-client-nour')));
    await t.pump();
    await t.tap(find.byKey(const ValueKey('assign-done')));
    await t.pumpAndSettle();
    expect(find.text('Publish to 2 clients'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('workout-publish')));
    await t.pumpAndSettle();
    final publishes = [
      for (final c in repo.calls)
        if (c.$1 == 'publish') c.$2,
    ];
    expect(publishes.map((p) => p['subId']).toList(), ['sub1', 'nour']);
    expect(publishes[0]['startsOn'], isNotNull);
    expect(publishes[1]['startsOn'], publishes[0]['startsOn']);
    final publishedText = t.widget<Text>(
      find.byKey(const ValueKey('workout-published')),
    );
    expect(publishedText.data, 'Sent to 2 clients');
  });

  testWidgets(
    'assign: a failure shows the partial card and retry sends only the failed one',
    (t) async {
      _phone(t);
      var nourCalls = 0;
      final repo = RecordingRepo(uid: 'coach1')
        ..failPublishFor = (subId) {
          if (subId == 'nour') {
            nourCalls++;
            if (nourCalls == 1) {
              return const CoachingFailure(CoachingRefusal.unreachable);
            }
          }
          return null;
        };
      await t.pumpWidget(
        host(
          ShareWorkoutView(
            repository: repo,
            subscription: sub(),
            clientName: 'Mariam',
            others: const [AssignClient(subId: 'nour', name: 'Nour')],
            splits: [split()],
          ),
        ),
      );
      await t.tap(find.byKey(const ValueKey('workout-split-0')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('assign-more')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('assign-client-nour')));
      await t.pump();
      await t.tap(find.byKey(const ValueKey('assign-done')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('workout-publish')));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('assign-partial')), findsOneWidget);
      expect(find.text('Sent to 1 clients'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('assign-retry')));
      await t.pumpAndSettle();
      final subIds = [
        for (final c in repo.calls)
          if (c.$1 == 'publish') c.$2['subId'],
      ];
      expect(subIds, ['sub1', 'nour', 'nour']);
      expect(find.byKey(const ValueKey('workout-published')), findsOneWidget);
    },
  );

  testWidgets(
    'assign button is hidden with no other clients and for a new version',
    (t) async {
      _phone(t);
      final repo = RecordingRepo(uid: 'coach1');
      await t.pumpWidget(
        host(
          ShareWorkoutView(
            repository: repo,
            subscription: sub(),
            clientName: 'Mariam',
            others: const [],
            splits: [split()],
          ),
        ),
      );
      await t.tap(find.byKey(const ValueKey('workout-split-0')));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('assign-more')), findsNothing);

      await t.pumpWidget(
        host(
          ShareWorkoutView(
            repository: repo,
            subscription: sub(),
            clientName: 'Mariam',
            others: const [AssignClient(subId: 'nour', name: 'Nour')],
            existing: CoachPlan(
              id: 'planX',
              kind: PlanKind.workout,
              revision: 2,
              workout: workoutPlan(),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('assign-more')), findsNothing);
    },
  );

  testWidgets('meal plan: same flow', (t) async {
    _phone(t);
    final repo = RecordingRepo(uid: 'coach1');
    await t.pumpWidget(
      host(
        ShareMealPlanView(
          repository: repo,
          subscription: sub(),
          catalog: catalog(),
          clientName: 'Mariam',
          others: const [AssignClient(subId: 'nour', name: 'Nour')],
        ),
      ),
    );
    await t.tap(find.byKey(const ValueKey('meal-add-breakfast')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('add-recipe-r1')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const ValueKey('meal-name')), 'Week');
    await t.tap(find.byKey(const ValueKey('assign-more')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('assign-client-nour')));
    await t.pump();
    await t.tap(find.byKey(const ValueKey('assign-done')));
    await t.pumpAndSettle();
    expect(find.text('Publish to 2 clients'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('meal-publish')));
    await t.pumpAndSettle();
    final publishes = [
      for (final c in repo.calls)
        if (c.$1 == 'publish') c.$2,
    ];
    expect(publishes.map((p) => p['subId']).toList(), ['sub1', 'nour']);
    expect(publishes[0]['startsOn'], isNotNull);
    expect(publishes[1]['startsOn'], publishes[0]['startsOn']);
    final publishedText = t.widget<Text>(
      find.byKey(const ValueKey('meal-published')),
    );
    expect(publishedText.data, 'Sent to 2 clients');
  });

  testWidgets(
    'assign sheet renders in Arabic with 6 clients without overflow',
    (t) async {
      _phone(t);
      await t.pumpWidget(
        host(
          Scaffold(
            body: AssignClientsSheet(
              mine: const AssignClient(subId: 'c1', name: 'مريم'),
              others: const [
                AssignClient(subId: 'c2', name: 'نور'),
                AssignClient(subId: 'c3', name: 'سلمى'),
                AssignClient(subId: 'c4', name: 'سارة'),
                AssignClient(subId: 'c5', name: 'هبة'),
                AssignClient(subId: 'c6', name: 'ياسمين'),
              ],
              initial: const {'c2'},
              startsOn: DateTime(2026, 11, 1),
            ),
          ),
          locale: const Locale('ar'),
        ),
      );
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('assign-done')), findsOneWidget);
    },
  );

  /// Four days, then the same four again as week two: eight days in all.
  MyPlan eightDays() => MyPlan.fork(
    AuthoredProgramme(
      programId: 'split4',
      titleEn: 'Four days',
      titleAr: 'أربع أيام',
      status: ProgrammeStatus.published,
      sessions: [
        for (final d in ['a', 'b', 'c', 'd'])
          AuthoredSession(
            sessionId: d,
            titleEn: 'Day $d',
            titleAr: 'يوم $d',
            minutes: 40,
            lifeStages: const {LifeStage.none},
            moves: [move('${d}1'), move('${d}2')],
          ),
      ],
    ),
  ).withRepeatedLastWeek();

  testWidgets('a 4-day split with Repeat last week can be sent: 8 days', (
    t,
  ) async {
    _phone(t);
    final plan = eightDays();
    expect(plan.days.length, 8);
    expect(plan.weekCount, 2);
    final repo = RecordingRepo(uid: 'coach1');
    await t.pumpWidget(
      host(
        ShareWorkoutView(
          repository: repo,
          subscription: sub(),
          clientName: 'Mai',
          templates: [
            CoachDraft(
              id: 't1',
              kind: PlanKind.workout,
              name: 'Four days, two weeks',
              body: plan.toJson(),
            ),
          ],
        ),
      ),
    );
    await t.tap(find.byKey(const ValueKey('workout-template-0')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('workout-publish')));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('workout-error')), findsNothing);
    final sent = repo.calls.single.$2;
    expect((sent['body'] as Map)['days'], hasLength(8));
    expect(find.byKey(const ValueKey('workout-published')), findsOneWidget);
  });

  test('what the server refuses is found before the call', () {
    final eight = eightDays();
    expect(coachWorkoutProblems(eight, 'Plan'), isEmpty);
    // Eight days all in week one is a week too many.
    final crowded = MyPlan(
      days: [for (final d in eight.days) MyPlanDay(session: d.session)],
    );
    expect(coachWorkoutProblems(crowded, 'Plan'), [PlanProblem.tooManyDays]);
    // Week 3 with no week 2 is a gap the server refuses.
    final gapped = MyPlan(
      days: [
        MyPlanDay(session: eight.days.first.session),
        MyPlanDay(session: eight.days.last.session, week: 3),
      ],
    );
    expect(coachWorkoutProblems(gapped, 'Plan'), [PlanProblem.noDays]);
  });

  testWidgets('a coach with one client sets the start date', (t) async {
    _phone(t);
    final repo = RecordingRepo(uid: 'coach1');
    await t.pumpWidget(
      host(
        ShareWorkoutView(
          repository: repo,
          subscription: sub(),
          clientName: 'Mai',
          splits: [split()],
        ),
      ),
    );
    await t.tap(find.byKey(const ValueKey('workout-split-0')));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('assign-more')), findsNothing);
    await t.tap(find.byKey(const ValueKey('start-date')));
    await t.pumpAndSettle();
    await t.tap(find.text('OK'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('workout-publish')));
    await t.pumpAndSettle();
    expect(repo.calls.single.$2['startsOn'], dayKey(cairoToday()));
  });

  testWidgets('the same plan to the same client carries the same request key', (
    t,
  ) async {
    _phone(t);
    final repo = RecordingRepo(uid: 'coach1');
    Future<void> openAndSend() async {
      await t.pumpWidget(
        host(
          ShareWorkoutView(
            key: UniqueKey(),
            repository: repo,
            subscription: sub(),
            clientName: 'Mai',
            others: const [AssignClient(subId: 'nour', name: 'Nour')],
            splits: [split()],
          ),
        ),
      );
      await t.tap(find.byKey(const ValueKey('workout-split-0')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('assign-more')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('assign-client-nour')));
      await t.pump();
      await t.tap(find.byKey(const ValueKey('assign-done')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('workout-publish')));
      await t.pumpAndSettle();
    }

    await openAndSend();
    // Back, open it again, build the same plan, send once more.
    await openAndSend();
    final keys = [
      for (final c in repo.calls)
        if (c.$1 == 'publish') '${c.$2['subId']}:${c.$2['requestKey']}',
    ];
    expect(keys, hasLength(4));
    expect(keys[0], keys[2], reason: 'Mai: the server finds the plan she has');
    expect(keys[1], keys[3], reason: 'Nour: likewise');
    expect(keys[0].split(':').last, isNot(keys[1].split(':').last));
    expect(repo.calls.first.$2['reviewsHealth'], isTrue);
  });

  testWidgets(
    'a partial send has one filled button, and a held client gets no Retry',
    (t) async {
      _phone(t);
      var salmaCalls = 0;
      final repo = RecordingRepo(uid: 'coach1')
        ..failPublishFor = (subId) {
          if (subId == 'nour') {
            return const CoachingFailure(CoachingRefusal.healthNotReviewed);
          }
          if (subId == 'salma' && ++salmaCalls == 1) {
            return const CoachingFailure(CoachingRefusal.unreachable);
          }
          return null;
        };
      await t.pumpWidget(
        host(
          ShareWorkoutView(
            repository: repo,
            subscription: sub(),
            clientName: 'Mai',
            others: const [
              AssignClient(subId: 'nour', name: 'Nour'),
              AssignClient(subId: 'salma', name: 'Salma'),
            ],
            splits: [split()],
          ),
        ),
      );
      await t.tap(find.byKey(const ValueKey('workout-split-0')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('assign-more')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('assign-client-nour')));
      await t.tap(find.byKey(const ValueKey('assign-client-salma')));
      await t.pump();
      await t.tap(find.byKey(const ValueKey('assign-done')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('workout-publish')));
      await t.pumpAndSettle();

      expect(find.byKey(const ValueKey('assign-partial')), findsOneWidget);
      expect(find.byKey(const ValueKey('workout-publish')), findsNothing);
      expect(
        find.byKey(const ValueKey('workout-edit')),
        findsNothing,
        reason: 'the plan some clients have is not edited under a Retry',
      );
      expect(filledPrimaryActions(t), 1, reason: 'Retry is the only button');
      expect(find.text('Try again for 1'), findsOneWidget);

      await t.tap(find.byKey(const ValueKey('assign-retry')));
      await t.pumpAndSettle();
      final subIds = [
        for (final c in repo.calls)
          if (c.$1 == 'publish') c.$2['subId'],
      ];
      expect(subIds, ['sub1', 'nour', 'salma', 'salma']);
      // Nour waits for her coach to read her answers: nothing to retry.
      expect(find.byKey(const ValueKey('assign-partial')), findsOneWidget);
      expect(find.byKey(const ValueKey('assign-retry')), findsNothing);
      expect(filledPrimaryActions(t), 0);
    },
  );

  Future<void> buildMealForTwo(
    WidgetTester t,
    RecordingRepo repo, {
    required AssignClient other,
  }) async {
    await t.pumpWidget(
      host(
        ShareMealPlanView(
          repository: repo,
          subscription: sub(),
          catalog: catalog(),
          clientName: 'Mai',
          others: [other],
        ),
      ),
    );
    await t.tap(find.byKey(const ValueKey('meal-add-breakfast')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('add-recipe-r1')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const ValueKey('meal-name')), 'Week');
    await t.tap(find.byKey(const ValueKey('assign-more')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(Key('assign-client-${other.subId}')));
    await t.pump();
    await t.tap(find.byKey(const ValueKey('assign-done')));
    await t.pumpAndSettle();
    // Typed last, as in the goal tests above: the target bars are drawn at
    // the next frame, and the publish tap settles on the sent card instead.
    await t.enterText(find.byKey(const ValueKey('meal-goal-kcal')), '1600');
    await t.enterText(find.byKey(const ValueKey('meal-goal-protein')), '110');
    await t.tap(find.byKey(const ValueKey('meal-publish')));
    await t.pumpAndSettle();
  }

  Map<String, Object?> bodyOf(RecordingRepo repo, String subId) =>
      repo.calls.firstWhere((c) => c.$2['subId'] == subId).$2['body']!
          as Map<String, Object?>;

  testWidgets('meal: a client with an eating history is sent no goal', (
    t,
  ) async {
    _wide(t);
    final repo = RecordingRepo(uid: 'coach1');
    await buildMealForTwo(
      t,
      repo,
      other: const AssignClient(
        subId: 'nour',
        name: 'Nour',
        eatingHistory: true,
      ),
    );
    expect(bodyOf(repo, 'sub1')['goal'], isNotNull);
    expect(bodyOf(repo, 'nour').containsKey('goal'), isFalse);
    expect(find.byKey(const ValueKey('assign-partial')), findsNothing);
    expect(find.byKey(const ValueKey('meal-published')), findsOneWidget);
  });

  testWidgets('meal: a goal the server holds back is resent without it', (
    t,
  ) async {
    _wide(t);
    // The call being answered is already in repo.calls.
    late final RecordingRepo repo;
    repo = RecordingRepo(uid: 'coach1')
      ..failPublishFor = (subId) =>
          subId == 'nour' &&
              (repo.calls.last.$2['body'] as Map).containsKey('goal')
          ? const CoachingFailure(CoachingRefusal.eatingHistoryHold)
          : null;
    await buildMealForTwo(
      t,
      repo,
      other: const AssignClient(subId: 'nour', name: 'Nour'),
    );
    expect(find.byKey(const ValueKey('assign-retry')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('assign-retry')));
    await t.pumpAndSettle();
    final nour = [
      for (final c in repo.calls)
        if (c.$2['subId'] == 'nour') c.$2['body'] as Map,
    ];
    expect(nour, hasLength(2));
    expect(nour.first.containsKey('goal'), isTrue);
    expect(nour.last.containsKey('goal'), isFalse);
    expect(find.byKey(const ValueKey('meal-published')), findsOneWidget);
  });

  testWidgets('meal: target needs both numbers', (t) async {
    _phone(t);
    final repo = RecordingRepo(uid: 'coach1');
    await t.pumpWidget(
      host(
        ShareMealPlanView(
          repository: repo,
          subscription: sub(),
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
    await t.enterText(find.byKey(const ValueKey('meal-goal-kcal')), '1600');
    await t.tap(find.byKey(const ValueKey('meal-publish')));
    await t.pumpAndSettle();
    expect(repo.calls, isEmpty);
    expect(find.byKey(const ValueKey('meal-error')), findsOneWidget);
    expect(
      find.text('Fill in both numbers, or leave both empty.'),
      findsOneWidget,
    );

    await t.enterText(find.byKey(const ValueKey('meal-goal-protein')), '110');
    await t.tap(find.byKey(const ValueKey('meal-publish')));
    await t.pumpAndSettle();
    expect(repo.calls.length, 1);
    final body = repo.calls.single.$2['body'] as Map;
    final goal = body['goal'] as Map;
    expect(goal['kcalPerDay'], 1600);
    expect(goal['proteinGPerDay'], 110);
  });

  testWidgets('meal: the target bars fit a 326 px phone at 1x and 2x text', (
    t,
  ) async {
    t.view.physicalSize = const Size(326 * 3, 3200);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    for (final locale in [const Locale('en'), const Locale('ar')]) {
      for (final scale in [1.0, 2.0]) {
        await t.pumpWidget(
          host(
            ShareMealPlanView(
              repository: RecordingRepo(uid: 'coach1'),
              subscription: sub(),
              catalog: catalog(),
              clientName: 'Mai',
              existing: CoachPlan(
                id: 'm1',
                kind: PlanKind.meal,
                name: 'Week',
                meal: mealBody(),
              ),
            ),
            locale: locale,
            scale: scale,
          ),
        );
        await t.enterText(find.byKey(const ValueKey('meal-goal-kcal')), '1600');
        await t.enterText(
          find.byKey(const ValueKey('meal-goal-protein')),
          '110',
        );
        await t.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('meal-target-kcal-bar')),
          findsOneWidget,
        );
        expect(
          t.takeException(),
          isNull,
          reason: '${locale.languageCode} at $scale',
        );
      }
    }
  });

  testWidgets(
    'meal: flagged client sees the gate, no target fields, no figures',
    (t) async {
      _phone(t);
      final repo = RecordingRepo(uid: 'coach1');
      await t.pumpWidget(
        host(
          ShareMealPlanView(
            repository: repo,
            subscription: sub(
              intake: const Intake(
                health: {'eatingHistory': true},
                eatingHistory: true,
              ),
            ),
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
      expect(find.byKey(const ValueKey('meal-gate-banner')), findsOneWidget);
      expect(find.byKey(const ValueKey('meal-goal-kcal')), findsNothing);
      expect(find.byKey(const ValueKey('meal-goal-protein')), findsNothing);
      expect(find.byKey(const ValueKey('meal-figures')), findsNothing);

      await t.tap(find.byKey(const ValueKey('meal-publish')));
      await t.pumpAndSettle();
      expect(repo.calls.length, 1);
      final body = repo.calls.single.$2['body'] as Map;
      expect(body['goal'], isNull);
    },
  );

  testWidgets('meal: swaps in 3 taps', (t) async {
    _phone(t);
    final repo = RecordingRepo(uid: 'coach1');
    final c = catalog(
      recipes: [
        recipe('r1'),
        recipe('r2'),
        recipe('r3'),
        recipe('r4'),
        recipe('r5'),
      ],
    );
    final bodyWithRecipe = MealPlanBody(
      days: [
        MealDay(
          label: 'Day 1',
          slots: {
            'lunch': [MealItem.recipe('r1', 1)],
          },
        ),
      ],
    );
    await t.pumpWidget(
      host(
        ShareMealPlanView(
          repository: repo,
          subscription: sub(),
          catalog: c,
          clientName: 'Mai',
          existing: CoachPlan(
            id: 'm1',
            kind: PlanKind.meal,
            name: 'Week',
            meal: bodyWithRecipe,
          ),
        ),
      ),
    );

    await t.tap(find.byKey(const ValueKey('meal-swaps-0-lunch-0')));
    await t.pumpAndSettle();

    await t.tap(find.byKey(const ValueKey('swap-r2')));
    await t.pump();
    await t.tap(find.byKey(const ValueKey('swap-r3')));
    await t.pump();

    await t.tap(find.byKey(const ValueKey('swap-r4')));
    await t.pump();
    await t.tap(find.byKey(const ValueKey('swap-r5')));
    await t.pump();
    expect(find.text('Three at most.'), findsOneWidget);

    await t.tap(find.byKey(const ValueKey('swap-r4')));
    await t.pump();

    await t.tap(find.byKey(const ValueKey('swaps-save')));
    await t.pumpAndSettle();

    expect(find.text('Swaps (2)'), findsOneWidget);

    await t.tap(find.byKey(const ValueKey('meal-publish')));
    await t.pumpAndSettle();
    final body = repo.calls.single.$2['body'] as Map;
    final item = (body['days'] as List)[0]['slots']['lunch'][0] as Map;
    expect(item['swaps'], ['r2', 'r3']);
  });

  testWidgets('meal: out of range target is held back', (t) async {
    _phone(t);
    final repo = RecordingRepo(uid: 'coach1');
    await t.pumpWidget(
      host(
        ShareMealPlanView(
          repository: repo,
          subscription: sub(),
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
    await t.enterText(find.byKey(const ValueKey('meal-goal-kcal')), '900');
    await t.enterText(find.byKey(const ValueKey('meal-goal-protein')), '100');
    await t.tap(find.byKey(const ValueKey('meal-publish')));
    await t.pumpAndSettle();
    expect(repo.calls, isEmpty);
    expect(find.byKey(const ValueKey('meal-error')), findsOneWidget);
    expect(
      find.text('Fill in both numbers, or leave both empty.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'meal: Arabic pump on 320px width shows target card and sheet without overflow',
    (t) async {
      t.view.physicalSize = const Size(320 * 2, 640 * 2);
      t.view.devicePixelRatio = 2;
      addTearDown(t.view.reset);

      final repo = RecordingRepo(uid: 'coach1');
      final c = catalog(recipes: [recipe('r1'), recipe('r2')]);
      final bodyWithRecipe = MealPlanBody(
        days: [
          MealDay(
            label: 'Day 1',
            slots: {
              'lunch': [MealItem.recipe('r1', 1)],
            },
          ),
        ],
      );
      await t.pumpWidget(
        host(
          ShareMealPlanView(
            repository: repo,
            subscription: sub(),
            catalog: c,
            clientName: 'مي',
            existing: CoachPlan(
              id: 'm1',
              kind: PlanKind.meal,
              name: 'خطة',
              meal: bodyWithRecipe,
            ),
          ),
          locale: const Locale('ar'),
        ),
      );
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('meal-goal-kcal')), findsOneWidget);
      expect(find.byKey(const ValueKey('meal-goal-protein')), findsOneWidget);

      await t.ensureVisible(find.byKey(const ValueKey('meal-swaps-0-lunch-0')));
      await t.tap(find.byKey(const ValueKey('meal-swaps-0-lunch-0')));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('swaps-save')), findsOneWidget);
    },
  );
}
