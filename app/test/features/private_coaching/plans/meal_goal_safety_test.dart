// The coach's daily goal on the meal composer, through the safety rules: a
// pregnant or postpartum client's goal has a floor, protein is held to 35% of
// the day, and the InBody suggestion never goes round either.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/features/private_coaching/domain/coach_plan.dart';
import 'package:own_hub/features/private_coaching/domain/coaching_contract.dart';
import 'package:own_hub/features/private_coaching/domain/inbody_scan.dart';
import 'package:own_hub/features/private_coaching/domain/subscription.dart';
import 'package:own_hub/features/private_coaching/presentation/plans/share_meal_plan_view.dart';

import 'plans_support.dart';

void _phone(WidgetTester t) {
  t.view.physicalSize = const Size(1170, 3200);
  t.view.devicePixelRatio = 3;
  addTearDown(t.view.reset);
}

Future<RecordingRepo> _open(WidgetTester t, {required Intake intake}) async {
  _phone(t);
  final repo = RecordingRepo(uid: 'coach1');
  await t.pumpWidget(
    host(
      ShareMealPlanView(
        repository: repo,
        subscription: sub(intake: intake),
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
  return repo;
}

Future<void> _goal(WidgetTester t, String kcal, String protein) async {
  await t.enterText(find.byKey(const ValueKey('meal-goal-kcal')), kcal);
  await t.enterText(find.byKey(const ValueKey('meal-goal-protein')), protein);
  await t.pump();
}

Future<void> _publish(WidgetTester t) async {
  await t.ensureVisible(find.byKey(const ValueKey('meal-publish')));
  await t.tap(find.byKey(const ValueKey('meal-publish')));
  await t.pumpAndSettle();
}

const _floorText =
    'For a client who is pregnant or after a birth, the lowest daily goal is '
    '1,800 kcal.';
const _proteinText = "Protein can be at most 35% of the day's calories.";

void main() {
  for (final stage in ['pregnant', 'postpartum']) {
    testWidgets('$stage: a goal under 1,800 kcal is refused with the reason', (
      t,
    ) async {
      final repo = await _open(t, intake: Intake(lifeStage: stage));
      expect(find.byKey(const ValueKey('meal-goal-safety')), findsOneWidget);
      expect(find.text(_floorText), findsWidgets);

      await _goal(t, '1500', '100');
      await _publish(t);
      expect(repo.calls, isEmpty, reason: 'nothing is sent');
      expect(find.byKey(const ValueKey('meal-error')), findsOneWidget);
      expect(find.text(_floorText), findsWidgets);
    });

    testWidgets('$stage: 1,800 kcal goes out as her goal', (t) async {
      final repo = await _open(t, intake: Intake(lifeStage: stage));
      await _goal(t, '1800', '100');
      await _publish(t);
      final body = repo.calls.single.$2['body'] as Map;
      expect(body['goal'], {'kcalPerDay': 1800, 'proteinGPerDay': 100});
    });
  }

  testWidgets('an ordinary client sees no stage line and keeps 1,200 kcal', (
    t,
  ) async {
    final repo = await _open(t, intake: const Intake());
    expect(find.byKey(const ValueKey('meal-goal-safety')), findsNothing);
    await _goal(t, '1200', '100');
    await _publish(t);
    final body = repo.calls.single.$2['body'] as Map;
    expect(body['goal'], {'kcalPerDay': 1200, 'proteinGPerDay': 100});
  });

  testWidgets('protein over 35% of the calories is refused', (t) async {
    final repo = await _open(t, intake: const Intake());
    await _goal(t, '1600', '141');
    expect(find.byKey(const ValueKey('meal-goal-safety')), findsOneWidget);
    expect(find.text(_proteinText), findsWidgets);
    await _publish(t);
    expect(repo.calls, isEmpty);

    await _goal(t, '1600', '140');
    await _publish(t);
    expect(repo.calls.single.$2['body'], isNotNull);
  });

  group('the InBody suggestion', () {
    const scan = InBodyScan(weightKg: 100, bmrKcal: 1100, heightCm: 165);
    final lose = Intake(
      goal: 'lose_steadily',
      daysPerWeek: 1,
      inbodyScan: scan,
    );

    testWidgets('is held to the floor and 35% protein', (t) async {
      await _open(t, intake: lose);
      // 1100 x 1.25 = 1375 - 400 = 975 -> 1200; protein 200 g -> 105 g.
      expect(
        find.textContaining('InBody suggested: 1200 kcal · 105g protein'),
        findsOneWidget,
      );
    });

    testWidgets('is not shown for a pregnant or postpartum client', (t) async {
      await _open(
        t,
        intake: Intake(
          goal: 'lose_steadily',
          daysPerWeek: 1,
          lifeStage: 'pregnant',
          inbodyScan: scan,
        ),
      );
      expect(
        find.byKey(const ValueKey('meal-apply-inbody-targets')),
        findsNothing,
      );
    });
  });
}
