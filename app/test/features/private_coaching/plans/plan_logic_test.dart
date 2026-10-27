import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/my_plan_state.dart';
import 'package:own_hub/features/eat/domain/allergy_guard.dart';
import 'package:own_hub/features/private_coaching/domain/coach_plan.dart';
import 'package:own_hub/features/private_coaching/domain/coaching_contract.dart';
import 'package:own_hub/features/private_coaching/domain/session_link.dart';
import 'package:own_hub/features/private_coaching/domain/subscription.dart';
import 'package:own_hub/features/private_coaching/presentation/client/coach_plan_view.dart';
import 'package:own_hub/features/private_coaching/presentation/client/coach_today.dart';
import 'package:own_hub/features/private_coaching/presentation/plans/coach_plan_logic.dart';
import 'package:own_hub/features/private_coaching/presentation/plans/schedule_session_sheet.dart';
import 'package:own_hub/features/onboarding/domain/intake.dart' show LifeStage;
import 'package:own_hub/features/train/domain/my_plan.dart';

import '../../../helpers/exercise_library_fixture.dart';
import 'plans_support.dart';

bool _hasKey(Object? v, Set<String> keys) {
  if (v is Map) {
    return v.keys.any((k) => keys.contains(k)) ||
        v.values.any((x) => _hasKey(x, keys));
  }
  if (v is List) return v.any((x) => _hasKey(x, keys));
  return false;
}

void main() {
  group('workout body', () {
    test('survives the MyPlan.toJson round trip and the publish request', () {
      final plan = workoutPlan();
      final back = MyPlan.tryParse(jsonDecode(jsonEncode(plan.toJson())));
      expect(back!.days.length, plan.days.length);
      expect(back.days.first.session.moves.first.exerciseId, 'a1');
      final req = publishPlanRequest(subId: 's', name: ' Plan ', workout: plan);
      expect(req['kind'], 'workout');
      expect(req['name'], 'Plan');
      expect(req['body'], plan.toJson());
      expect(req.containsKey('planId'), isFalse);
    });

    test('editing helpers keep a valid day and never touch her own plan', () {
      final before = MyPlanState.instance.plan;
      final edit = CoachPlanEditState(workoutPlan());
      var p = edit.current!;
      p = changeMove(p, 0, 0, sets: 5, reps: 12);
      p = removeMove(p, 0, 0);
      p = removeMove(p, 0, 0);
      expect(p.days[0].session.moves.length, 1, reason: 'the last stays');
      p = renameDay(p, 0, 'Legs');
      edit.save(p);
      expect(edit.current!.days[0].session.titleEn, 'Legs');
      expect(MyPlanState.instance.plan, same(before));
      expect(edit.hasPlan, isFalse);
    });

    test('problems: name, days, size, unknown move', () {
      expect(
        coachWorkoutProblems(const MyPlan.blank(), ''),
        containsAll([PlanProblem.noName, PlanProblem.noDays]),
      );
      expect(coachWorkoutProblems(workoutPlan(), 'Ok'), isEmpty);
      expect(coachWorkoutProblems(workoutPlan(), 'Ok', known: (_) => false), [
        PlanProblem.unknownMove,
      ]);
      expect(coachWorkoutProblems(workoutPlan(), 'x' * 61), [
        PlanProblem.noName,
      ]);
    });

    test('changeMoveDetails sets rest, note, superset and kg', () {
      final plan = planFromSplit(split());
      final beforeMove1 = plan.days[0].session.moves[1];
      final next = changeMoveDetails(
        plan,
        0,
        0,
        restSeconds: 120,
        note: '  slow   down ',
        superset: true,
        kg: 12.5,
      );
      final move0 = next.days[0].session.moves[0];
      expect(move0.restSeconds, 120);
      expect(move0.notesEn, 'slow down');
      expect(move0.notesAr, 'slow down');
      expect(move0.supersetWithNext, isTrue);
      expect(next.days[0].targetKg[0], 12.5);
      expect(next.revision, plan.revision + 1);
      expect(next.days[0].session.moves[1], beforeMove1);
    });

    test('changeMoveDetails clamps and clears', () {
      final plan = planFromSplit(split());
      final clamped = changeMoveDetails(plan, 0, 0, restSeconds: 9999, kg: 500);
      expect(clamped.days[0].session.moves[0].restSeconds, 600);
      expect(clamped.days[0].targetKg[0], 200);
      final cleared = changeMoveDetails(clamped, 0, 0, clearKg: true);
      expect(cleared.days[0].targetKg[0], isNull);
      expect(
        identical(changeMoveDetails(plan, -1, 0, restSeconds: 30), plan),
        isTrue,
      );
      expect(
        identical(changeMoveDetails(plan, 9, 0, restSeconds: 30), plan),
        isTrue,
      );
      expect(
        identical(changeMoveDetails(plan, 0, -1, restSeconds: 30), plan),
        isTrue,
      );
      expect(
        identical(changeMoveDetails(plan, 0, 9, restSeconds: 30), plan),
        isTrue,
      );
    });

    test('changeMove keeps the superset flag', () {
      final lib = sampleExerciseLibrary();
      var plan = MyPlan(
        days: [
          MyPlanDay(
            session: AuthoredSessionFor.make([
              move('glute_bridge', tags: const []),
              move('a2'),
            ]),
          ),
        ],
      );
      plan = changeMoveDetails(plan, 0, 0, superset: true);
      plan = changeMove(plan, 0, 0, sets: 5);
      expect(plan.days[0].session.moves[0].supersetWithNext, isTrue);
      final stamped = stampSafetyTags(plan, lib.byId);
      expect(stamped.days[0].session.moves[0].supersetWithNext, isTrue);
      expect(stamped.days[0].session.moves[0].contraindications, isNotEmpty);
    });
  });

  group('meal body', () {
    test('has the server keys and no nutrition figures', () {
      final json = mealBody().toJson();
      expect(json.keys, ['days']);
      final day = (json['days'] as List).first as Map;
      expect(day.keys, ['label', 'slots']);
      expect((day['slots'] as Map).keys, CoachingEnums.mealSlots);
      expect(
        _hasKey(json, {'kcal', 'proteinG', 'carbsG', 'fatG', 'calories'}),
        isFalse,
      );
      final req = publishPlanRequest(subId: 's', name: 'M', meal: mealBody());
      expect(req['kind'], 'meal');
      expect(MealPlanBody.tryParse(req['body'])!.isValid, isTrue);
    });

    test('days and items change as asked', () {
      var b = mealPlanWithDays(const MealPlanBody(), 3, (i) => 'Day $i');
      expect(b.days.map((d) => d.label), ['Day 1', 'Day 2', 'Day 3']);
      b = mealPlanWithItem(b, 1, 'snack', MealItem.free('Apple'));
      expect(b.days[1].itemsIn('snack').single.text, 'Apple');
      b = mealPlanWithoutItem(b, 1, 'snack', 0);
      expect(b.days[1].itemsIn('snack'), isEmpty);
      expect(mealPlanWithDays(b, 1, (i) => '$i').days.length, 1);
      expect(mealProblems(b, 'n'), contains(PlanProblem.noDays));
    });

    test('allergen flags: contains, unchecked, clear, free line', () {
      const c = DietaryConstraints(allergies: {'sesame'});
      final flags = flagMealPlan(mealBody(), c, catalog());
      final byKey = {for (final f in flags) '${f.slot}${f.index}': f};
      expect(byKey['dinner0']!.kind, MealFlagKind.contains);
      expect(byKey['dinner0']!.allergens, {'sesame'});
      expect(byKey['breakfast0'], isNull);
      expect(byKey['lunch0'], isNull, reason: 'food with an empty list');
      expect(byKey['lunch1'], isNull, reason: 'a free line has no verdict');
      final unknown = flagMealPlan(
        MealPlanBody(
          days: [
            MealDay(
              label: 'd',
              slots: {
                'lunch': [MealItem.recipe('r3', 1), MealItem.food('f2', 50)],
              },
            ),
          ],
        ),
        c,
        catalog(),
      );
      expect(unknown.map((f) => f.kind), everyElement(MealFlagKind.unchecked));
      expect(
        flagMealPlan(mealBody(), DietaryConstraints.none, catalog()),
        isEmpty,
      );
    });

    test('figures come from the tables; a missing one makes it partial', () {
      final n = dayNutrition(mealBody().days.first, catalog());
      // 2 x 400 recipe + 150 g of the 200 kcal / 100 g food + a recipe.
      expect(n.kcal, 800 + 300 + 400);
      expect(n.partial, isTrue, reason: 'the free line has none');
      expect(itemNutrition(MealItem.recipe('r3', 1), catalog())!.kcal, 400);
    });
  });

  group('sessions', () {
    final now = DateTime.utc(2026, 10, 24, 12);
    final s = sub();
    String? problem(String t, String l, {List<LiveSession> ss = const []}) =>
        sessionProblem(
          typedTime: t,
          link: l,
          subscription: s,
          sessions: ss,
          now: now,
        )?.name;

    test('mirrors the server checks', () {
      const ok = 'https://meet.google.com/abc-defg-hij';
      expect(problem('2026-10-26 18:30', ok), isNull);
      expect(problem('tomorrow', ok), 'time');
      expect(problem('2026-10-24 15:05', ok), 'tooSoon', reason: '15 min lead');
      expect(problem('2026-12-01 18:30', ok), 'afterEnd');
      expect(problem('2026-10-26 18:30', 'http://meet.google.com/x'), 'link');
      expect(problem('2026-10-26 18:30', 'https://evil.com/x'), 'link');
      expect(problem('2026-10-26 18:30', 'https://zoom.us:8080/x'), 'link');
      expect(sessionLinkAllowed('https://us02.zoom.us/j/1'), isTrue);
      final full = [
        for (var i = 0; i < 4; i++)
          LiveSession(id: '$i', status: SessionStatus.confirmed),
        const LiveSession(id: 'c', status: SessionStatus.cancelled),
      ];
      expect(problem('2026-10-26 18:30', ok, ss: full), 'noneLeft');
    });

    test('both parties must mark it done', () {
      final at = DateTime.utc(2026, 10, 24, 10);
      var ses = LiveSession(
        id: 'x',
        status: SessionStatus.confirmed,
        startsAt: at,
        doneBy: const ['client1'],
      );
      expect(ses.doneByMe('client1'), isTrue);
      expect(ses.waitingForOther('client1'), isTrue);
      expect(ses.waitingForOther('coach1'), isFalse);
      ses = LiveSession(
        id: 'x',
        status: SessionStatus.done,
        startsAt: at,
        doneBy: const ['client1', 'coach1'],
      );
      expect(ses.waitingForOther('client1'), isFalse);
    });
  });

  group('screening on her phone', () {
    test('a freshly picked floor-tagged move is held back when pregnant', () {
      final plan = MyPlan(
        days: [
          MyPlanDay(
            session: AuthoredSessionFor.make([
              move('standing_forward_fold'),
              move('glute_bridge', tags: const []),
              move('mystery', tags: const []),
            ]),
          ),
        ],
      );
      final lib = sampleExerciseLibrary().exercises;
      final held = heldBackMoves(plan, 0, lib, LifeStage.pregnant);
      expect(held, contains(1), reason: 'tagged move not shown');
      expect(held, contains(2), reason: 'unknown to the library');
      expect(heldBackMoves(plan, 0, lib, LifeStage.none), isEmpty);
    });

    test('days outside her stage are not offered', () {
      final p = MyPlan.fork(split(), stage: LifeStage.none);
      expect(offeredDays(p, LifeStage.painInjury), isEmpty);
      expect(offeredDays(p, LifeStage.none), [0, 1]);
    });

    test('meal day follows the publish day and repeats', () {
      final plan = CoachPlan(
        id: 'p',
        kind: PlanKind.meal,
        meal: mealPlanWithDays(mealBody(), 3, (i) => 'D$i'),
        publishedAt: DateTime.utc(2026, 10, 20, 9),
      );
      expect(todaysMealDay(plan, DateTime.utc(2026, 10, 20, 12)), 0);
      expect(todaysMealDay(plan, DateTime.utc(2026, 10, 22, 12)), 2);
      expect(todaysMealDay(plan, DateTime.utc(2026, 10, 23, 12)), 0);
    });
  });
}
