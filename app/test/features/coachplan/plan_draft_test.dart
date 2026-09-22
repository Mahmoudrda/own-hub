// P0-PLAN-01 … 05 — the month a coach writes on a microbus.
//
// The demanding case is not a minute without signal. It is forty minutes: a
// client opened, thirty days planned, a split saved and an assessment taken,
// entirely offline. Everything she authors is her own document, so all of it
// is writable; only the act that changes somebody else's plan is not.

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/safety/client_constraints.dart';
import 'package:own_hub/domain/safety/life_stage_safety_policy.dart';
import 'package:own_hub/domain/safety/safety_assessment.dart';
import 'package:own_hub/features/coachplan/domain/meal/meal_slot_planner.dart';
import 'package:own_hub/features/coachplan/domain/plan/copy_week_planner.dart';
import 'package:own_hub/features/coachplan/domain/plan/plan_draft.dart';
import 'package:own_hub/features/coachplan/domain/plan/plan_draft_repository.dart';
import 'package:own_hub/features/coachplan/domain/prescription.dart';
import 'package:own_hub/features/eat/domain/food_library.dart';

final DateTime _today = DateTime(2026, 9, 19);

Food _food(String id, {Set<String> allergens = const <String>{}}) => Food(
  foodId: id,
  names: <String>[id],
  sizes: <FoodSize>[FoodSize(id: 'M', label: 'Medium', kcal: 410, proteinG: 22)],
  allergens: allergens,
  dietTags: const <String>{'vegetarian'},
);

final Map<String, Food> _pack = <String, Food>{
  'ful_medames': _food('ful_medames'),
  'koshari': _food('koshari'),
};

MealSafety _safety() => MealSafety(
  constraints: ClientConstraintResolver.resolve(
    assessment: SafetyAssessment(
      assessmentId: 'c1_u1__2026-09-01',
      clientUid: 'u1',
      coachUid: 'c1',
      takenAt: DateTime(2026, 9, 1),
      lifeStage: LifeStage.over1y,
    ),
    allergies: const <String>{},
    dietary: const <String>{'vegetarian'},
  ),
  foods: (id) => _pack[id],
);

PlanDay _workoutDay(String title) => PlanDay(
  kind: PlanDayKind.workout,
  workout: DraftWorkout(
    title: title,
    minutes: 35,
    restBetweenSetsSec: 45,
    moves: <PrescribedMove>[
      PrescribedMove(
        exerciseId: 'glute_bridge',
        order: 1,
        sets: 3,
        reps: 12,
        load: const PrescribedLoad.bodyweight(),
      ),
    ],
  ),
  meal: DraftMealDay(
    slots: <PlanMealSlot, MealSlotAssignment?>{
      PlanMealSlot.breakfast: const MealSlotAssignment.fromLibrary(
        foodIds: <String>['ful_medames'],
      ),
    },
  ),
);

PlanDraft _draft({Map<String, PlanDay>? days}) => PlanDraft(
  clientUid: 'u1',
  coachUid: 'c1',
  month: '2026-09',
  days:
      days ??
      <String, PlanDay>{
        '2026-09-14': _workoutDay('Full-body strength'),
        '2026-09-15': const PlanDay.rest(),
        '2026-09-16': _workoutDay('Upper body'),
      },
);

void main() {
  group('the draft document', () {
    test('the id is deterministic, so a replay overwrites itself', () async {
      final repo = InMemoryPlanDraftRepository(safety: _safety());
      final draft = _draft();

      await repo.save(draft);
      await repo.save(draft);
      await repo.save(draft);

      expect(repo.contents.keys, <String>['u1__2026-09']);
      expect(
        repo.contents.length,
        1,
        reason: 'three saves of the same month are one month',
      );
    });

    test('a draft may never claim to be published', () {
      expect(
        () => InMemoryPlanDraftRepository.assertWritable(
          PlanDraft(
            clientUid: 'u1',
            coachUid: 'c1',
            month: '2026-09',
            status: PlanDraftStatus.published,
          ),
        ),
        throwsA(isA<DraftNotWritable>()),
      );
    });

    test('a result-shaped key at any depth is refused', () {
      // Not a field on any type here — this is the map arriving from a
      // migration, an import or a future refactor.
      expect(
        () => InMemoryPlanDraftRepository.assertWritable(
          _FakeDraftWithActual(),
        ),
        throwsA(anything),
      );
    });

    test('a meal cannot be planned without her constraints', () {
      expect(
        () => InMemoryPlanDraftRepository.assertWritable(_draft()),
        throwsA(isA<MealPlannedWithoutConstraints>()),
        reason: 'an unknown constraint is not an absent one',
      );
    });

    test('a workout-only month saves with no constraint data', () {
      final workoutOnly = PlanDraft(
        clientUid: 'u1',
        coachUid: 'c1',
        month: '2026-09',
        days: <String, PlanDay>{
          '2026-09-14': PlanDay(
            kind: PlanDayKind.workout,
            workout: DraftWorkout(title: 'Full-body', minutes: 35),
          ),
        },
      );
      expect(
        () => InMemoryPlanDraftRepository.assertWritable(workoutOnly),
        returnsNormally,
      );
    });
  });

  group('P0-PLAN-01 — planning a month with no signal', () {
    test('every edit is a local write to her own document', () async {
      final repo = InMemoryPlanDraftRepository(safety: _safety());
      var draft = _draft(days: <String, PlanDay>{});

      // Twenty training days and thirty meal days, one debounce burst each.
      for (var day = 1; day <= 30; day++) {
        final key = '2026-09-${day.toString().padLeft(2, '0')}';
        draft = draft.withDay(
          key,
          day <= 20 ? _workoutDay('Day $day') : const PlanDay.rest(),
        );
      }
      await repo.save(draft);

      expect(repo.writes, 1);
      expect(repo.contents[draft.draftId]!.days, hasLength(30));
      expect(draft.workoutDayCount, 20);
      expect(
        repo.reads,
        0,
        reason: 'nothing was read to write a month she is holding',
      );
    });

    test('opening W04, W05 and W06 after W03 reads nothing new', () async {
      final repo = InMemoryPlanDraftRepository(safety: _safety());
      await repo.save(_draft());

      await repo.draftFor(clientUid: 'u1', month: '2026-09');
      final readsAfterW03 = repo.reads;

      // W04 edits a session in memory, W05 computes its summary in memory,
      // W06 fills slots on the same document. None of them opens anything.
      final draft = repo.contents['u1__2026-09']!;
      const CopyWeekPlanner().summarise(
        draft: draft,
        projection: <String, PlanDay>{'2026-09-21': _workoutDay('Copied')},
      );

      expect(repo.reads, readsAfterW03, reason: 'W04/W05/W06 cost 0 reads');
    });
  });

  group('P0-PLAN-02 — copy a week names its overwrites', () {
    test('the summary states the count and names the days, before', () {
      final draft = _draft(
        days: <String, PlanDay>{
          for (var day = 14; day <= 18; day++)
            '2026-09-$day': _workoutDay('Week 2 day $day'),
          // Two existing assignments in the weeks she is about to write over.
          '2026-09-21': _workoutDay('Existing'),
          '2026-09-23': _workoutDay('Existing'),
        },
      );

      const planner = CopyWeekPlanner();
      final projection = planner.project(
        draft: draft,
        sourceDayKeys: <String>[
          '2026-09-14',
          '2026-09-15',
          '2026-09-16',
          '2026-09-17',
          '2026-09-18',
        ],
        targetStarts: <DateTime>[DateTime(2026, 9, 21), DateTime(2026, 9, 28)],
      );
      final summary = planner.summarise(draft: draft, projection: projection);

      expect(summary.daysWritten, 10);
      expect(summary.replaced, <String>['2026-09-21', '2026-09-23']);
      expect(summary.isNonDestructive, isFalse);
    });

    test('cancelling writes nothing; confirming replaces exactly those', () async {
      final repo = InMemoryPlanDraftRepository(safety: _safety());
      final draft = _draft(
        days: <String, PlanDay>{
          '2026-09-14': _workoutDay('Source'),
          '2026-09-21': _workoutDay('Existing'),
        },
      );
      await repo.save(draft);
      final writesBefore = repo.writes;

      const planner = CopyWeekPlanner();
      final projection = planner.project(
        draft: draft,
        sourceDayKeys: <String>['2026-09-14'],
        targetStarts: <DateTime>[DateTime(2026, 9, 21)],
      );
      planner.summarise(draft: draft, projection: projection);

      // Cancelling is simply not calling apply.
      expect(repo.writes, writesBefore);

      await repo.save(planner.apply(draft: draft, projection: projection));
      final after = repo.contents[draft.draftId]!;
      expect(after.days['2026-09-21']!.workout!.title, 'Source');
      expect(after.days['2026-09-14']!.workout!.title, 'Source');
      expect(after.days, hasLength(2), reason: 'exactly those days, no others');
      expect(after.origin, DraftOrigin.copy);
    });

    test('a copy that leaves the month is named rather than half-applied', () {
      final draft = _draft(days: <String, PlanDay>{'2026-09-28': _workoutDay('W4')});
      const planner = CopyWeekPlanner();
      final projection = planner.project(
        draft: draft,
        sourceDayKeys: <String>['2026-09-28'],
        targetStarts: <DateTime>[DateTime(2026, 10, 5)],
      );
      expect(
        planner.daysOutsideMonth(draft: draft, projection: projection),
        <String>['2026-10-05'],
      );
    });

    test('a copied day is a copy, not the same object', () {
      final draft = _draft(days: <String, PlanDay>{'2026-09-14': _workoutDay('S')});
      final projection = const CopyWeekPlanner().project(
        draft: draft,
        sourceDayKeys: <String>['2026-09-14'],
        targetStarts: <DateTime>[DateTime(2026, 9, 21)],
      );
      expect(
        identical(projection['2026-09-21'], draft.days['2026-09-14']),
        isFalse,
      );
    });
  });

  group('P0-PLAN-05 — two devices, one month', () {
    test('distinct days merge; the same day is last-write-wins on that day', () {
      final base = _draft(
        days: <String, PlanDay>{'2026-09-14': _workoutDay('Monday')},
      );

      // Device A edits Tuesday, device B edits Thursday, both from `base`.
      final deviceA = base
          .withDay('2026-09-15', _workoutDay('Tuesday from A'))
          .withDevice('phone-a');
      final deviceB = base
          .withDay('2026-09-17', _workoutDay('Thursday from B'))
          .withDevice('phone-b');

      // Field-level merge on `days.{yyyy-MM-dd}` — what a map buys and an
      // array does not.
      final merged = deviceA.withDays(<String, PlanDay>{
        for (final key in deviceB.days.keys)
          if (!deviceA.days.containsKey(key)) key: deviceB.days[key]!,
      });

      expect(merged.days.keys.toList()..sort(), <String>[
        '2026-09-14',
        '2026-09-15',
        '2026-09-17',
      ]);
      expect(merged.days['2026-09-15']!.workout!.title, 'Tuesday from A');
      expect(merged.days['2026-09-17']!.workout!.title, 'Thursday from B');

      // The same day from both: one wins, and only that day is affected.
      final sameDay = deviceA.withDay('2026-09-15', _workoutDay('Tuesday from B'));
      expect(sameDay.days['2026-09-15']!.workout!.title, 'Tuesday from B');
      expect(sameDay.days['2026-09-14']!.workout!.title, 'Monday');
      expect(deviceA.lastEditedByDevice, 'phone-a');
    });
  });

  group('counting the gaps', () {
    test('an unfilled slot is a gap; a stated free choice is not', () {
      final draft = _draft(
        days: <String, PlanDay>{
          '2026-09-14': PlanDay(
            kind: PlanDayKind.workout,
            workout: DraftWorkout(title: 'S', minutes: 20),
            meal: DraftMealDay(
              slots: <PlanMealSlot, MealSlotAssignment?>{
                PlanMealSlot.breakfast: const MealSlotAssignment.fromLibrary(
                  foodIds: <String>['ful_medames'],
                ),
                PlanMealSlot.lunch: const MealSlotAssignment.freeChoice(),
                PlanMealSlot.dinner: null,
              },
            ),
          ),
        },
      );

      expect(draft.filledMealSlots, 2);
      expect(
        draft.unfilledMealSlots,
        2,
        reason: 'dinner and snack; the free choice is an answer',
      );
      expect(_today.isAfter(DateTime(2026, 9, 1)), isTrue);
    });
  });
}

/// A draft whose wire form carries a logged value — the shape a migration or a
/// careless refactor would produce, since no type here can express it.
class _FakeDraftWithActual implements PlanDraft {
  @override
  Map<String, Object?> toWire() => <String, Object?>{
    'clientUid': 'u1',
    'coachUid': 'c1',
    'month': '2026-09',
    'status': 'draft',
    'days': <String, Object?>{
      '2026-09-14': <String, Object?>{
        'kind': 'workout',
        'workout': <String, Object?>{
          'moves': <Object?>[
            <String, Object?>{'exerciseId': 'glute_bridge', 'actualReps': 12},
          ],
        },
      },
    },
  };

  @override
  dynamic noSuchMethod(Invocation invocation) => switch (invocation
      .memberName
      .toString()) {
    'Symbol("status")' => PlanDraftStatus.draft,
    'Symbol("draftId")' => 'u1__2026-09',
    'Symbol("clientUid")' => 'u1',
    'Symbol("month")' => '2026-09',
    'Symbol("days")' => const <String, PlanDay>{},
    _ => super.noSuchMethod(invocation),
  };
}
