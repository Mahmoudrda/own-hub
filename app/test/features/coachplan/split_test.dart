// P0-SPLIT-01 … 04 and P1-RULE-18 — **a split is a template, not a plan.**
//
// The rule the whole feature is shaped around: "there is therefore no code path
// by which editing a split reaches a published plan — not a guard, an absence."
// The last group below is the one that proves it. It publishes a month from a
// split, edits the split every way K20 allows, and then compares the published
// payload byte for byte.

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/safety/client_constraints.dart';
import 'package:own_hub/domain/safety/contraindication_tag.dart';
import 'package:own_hub/domain/safety/exercise_candidate_filter.dart';
import 'package:own_hub/domain/safety/life_stage_safety_policy.dart';
import 'package:own_hub/domain/safety/safety_assessment.dart';
import 'package:own_hub/features/coachplan/domain/plan/coach_plan_publisher.dart';
import 'package:own_hub/features/coachplan/domain/plan/plan_draft.dart';
import 'package:own_hub/features/coachplan/domain/plan/plan_draft_repository.dart';
import 'package:own_hub/features/coachplan/domain/prescription.dart';
import 'package:own_hub/features/coachplan/domain/split/split.dart';
import 'package:own_hub/features/coachplan/domain/split/split_applicator.dart';
import 'package:own_hub/features/coachplan/domain/split/split_assignment_guard.dart';
import 'package:own_hub/features/coachplan/domain/split/split_repository.dart';
import 'package:own_hub/features/coachplan/domain/split/split_validator.dart';

final DateTime _today = DateTime(2026, 9, 19);

// ---------------------------------------------------------------- the library

const _moves = <String, ScreenableExercise>{
  'glute_bridge': ScreenableExercise(
    exerciseId: 'glute_bridge',
    tags: <ContraindicationTag>{ContraindicationTag.none},
    quiet: true,
    floorOnly: true,
  ),
  'goblet_squat': ScreenableExercise(
    exerciseId: 'goblet_squat',
    tags: <ContraindicationTag>{ContraindicationTag.deepKneeFlexion},
    quiet: true,
    floorOnly: false,
  ),
  'box_jump': ScreenableExercise(
    exerciseId: 'box_jump',
    tags: <ContraindicationTag>{
      ContraindicationTag.jumping,
      ContraindicationTag.highImpact,
    },
    quiet: false,
    floorOnly: false,
  ),
};

ScreenableExercise? _catalogue(String id) => _moves[id];

PrescribedMove _move(String id, int order) => PrescribedMove(
  exerciseId: id,
  order: order,
  sets: 3,
  reps: 12,
  load: const PrescribedLoad.bodyweight(),
);

Split _fourDaySplit({bool carryApproved = true, String name = 'Upper / lower'}) =>
    Split(
      splitId: 's_1',
      name: name,
      cycleLength: 4,
      ownerKind: SplitOwnerKind.coach,
      carryApproved: carryApproved,
      updatedAt: DateTime(2026, 9, 1),
      daySlots: <SplitDaySlot>[
        SplitDaySlot(
          dayIndex: 1,
          kind: DaySlotKind.session,
          title: 'Full-body strength',
          minutes: 35,
          restBetweenSetsSec: 45,
          moves: <PrescribedMove>[
            _move('glute_bridge', 1),
            _move('goblet_squat', 2),
            _move('box_jump', 3),
          ],
          approvedAlternatives: const <ApprovedAlternative>[
            ApprovedAlternative(
              exerciseId: 'glute_bridge',
              forExerciseId: 'goblet_squat',
            ),
          ],
        ),
        SplitDaySlot(
          dayIndex: 2,
          kind: DaySlotKind.session,
          title: 'Upper body',
          minutes: 20,
          moves: <PrescribedMove>[_move('glute_bridge', 1)],
        ),
        SplitDaySlot.rest(dayIndex: 3),
        SplitDaySlot(
          dayIndex: 4,
          kind: DaySlotKind.session,
          title: 'Legs and glutes',
          minutes: 30,
          moves: <PrescribedMove>[_move('glute_bridge', 1)],
        ),
      ],
    );

ClientConstraints _constraints({
  Set<ContraindicationTag> avoid = const <ContraindicationTag>{},
}) => ClientConstraintResolver.resolve(
  assessment: SafetyAssessment(
    assessmentId: 'c1_u1__2026-09-01',
    clientUid: 'u1',
    coachUid: 'c1',
    takenAt: DateTime(2026, 9, 1),
    lifeStage: LifeStage.over1y,
    avoid: avoid,
  ),
  allergies: const <String>{},
  dietary: const <String>{},
);

List<DateTime> _dates(int count) => <DateTime>[
  for (var i = 0; i < count; i++) _today.add(Duration(days: i)),
];

class _RecordingGateway implements PlanPublishGateway {
  final List<PublishRequest> requests = <PublishRequest>[];

  @override
  Future<PublishReceipt> publishCoachPlan(PublishRequest request) async {
    requests.add(request);
    return PublishReceipt(
      version: 'v${requests.length}',
      assignmentsWritten: request.payload.length,
      mealSlotsWritten: 0,
    );
  }
}

void main() {
  group('P0-SPLIT-01 — a coach builds a split', () {
    test('one document, four slots, and nothing naming a client', () async {
      final repo = InMemorySplitRepository();
      await repo.save(_fourDaySplit());

      final stored = repo.contents['s_1']!;
      expect(stored.daySlots, hasLength(4));
      expect(stored.cycleLength, 4);
      expect(stored.ownerKind, SplitOwnerKind.coach);
      expect(stored.appliedCount, 0);

      final wire = stored.toWire();
      for (final banned in kForbiddenTemplateKeys) {
        expect(
          wire.containsKey(banned),
          isFalse,
          reason: 'a template is not about a person',
        );
      }
    });

    test('K19 lists newest-edited first, never by how many women are on it', () async {
      final repo = InMemorySplitRepository(
        splits: <Split>[
          _fourDaySplit(name: 'Popular').withChanges(
            updatedAt: DateTime(2026, 8, 1),
          ),
          Split(
            splitId: 's_2',
            name: 'Edited yesterday',
            cycleLength: 3,
            ownerKind: SplitOwnerKind.coach,
            updatedAt: DateTime(2026, 9, 18),
            daySlots: <SplitDaySlot>[
              SplitDaySlot.rest(dayIndex: 1),
              SplitDaySlot.rest(dayIndex: 2),
              SplitDaySlot.rest(dayIndex: 3),
            ],
          ),
        ],
      );
      // The popular one is applied to many women and still sorts second.
      repo
        ..serverIncrementAppliedCount('s_1')
        ..serverIncrementAppliedCount('s_1')
        ..serverIncrementAppliedCount('s_1');

      final listed = await repo.splits();
      expect(listed.first.splitId, 's_2');
      expect(
        listed.last.appliedCount,
        3,
        reason: 'displayed on the card, and never a sort key',
      );
    });

    test('a device may not move appliedCount', () async {
      final repo = InMemorySplitRepository(splits: <Split>[_fourDaySplit()]);
      repo.serverIncrementAppliedCount('s_1');

      expect(
        () => repo.save(
          Split(
            splitId: 's_1',
            name: 'Upper / lower',
            cycleLength: 4,
            ownerKind: SplitOwnerKind.coach,
            daySlots: _fourDaySplit().daySlots,
            appliedCount: 9,
          ),
        ),
        throwsA(isA<AppliedCountNotWritable>()),
      );
    });

    test('a split with a missing day is never saved', () {
      final short = Split(
        splitId: 's_3',
        name: 'Four days',
        cycleLength: 4,
        ownerKind: SplitOwnerKind.coach,
        daySlots: <SplitDaySlot>[
          SplitDaySlot.rest(dayIndex: 1),
          SplitDaySlot.rest(dayIndex: 2),
          SplitDaySlot.rest(dayIndex: 3),
        ],
      );
      expect(
        () => const SplitValidator().assertValid(short),
        throwsA(
          isA<SplitInvalid>().having(
            (e) => e.problem,
            'problem',
            SplitProblem.slotCountMismatch,
          ),
        ),
      );
    });
  });

  group('P0-SPLIT-02 — the trainee builds her own (D7)', () {
    test('the identical validator runs, and two fields do not exist', () async {
      final hers = Split(
        splitId: 's_self',
        name: 'My five days',
        cycleLength: 5,
        ownerKind: SplitOwnerKind.self,
        source: SplitSource.own,
        daySlots: <SplitDaySlot>[
          for (var i = 1; i <= 5; i++)
            SplitDaySlot(
              dayIndex: i,
              kind: DaySlotKind.session,
              title: 'Day $i',
              minutes: 20,
              moves: <PrescribedMove>[_move('glute_bridge', 1)],
            ),
        ],
      );

      expect(const SplitValidator().isValid(hers), isTrue);

      final wire = hers.toWire();
      expect(wire.containsKey('appliedCount'), isFalse);
      expect(wire['ownerKind'], 'self');
      for (final slot in wire['daySlots']! as List<Map<String, Object?>>) {
        expect(slot.containsKey('approvedAlternatives'), isFalse);
      }
    });

    test('her split may not carry a coach-only field', () {
      final wrong = Split(
        splitId: 's_self2',
        name: 'Mine',
        cycleLength: 3,
        ownerKind: SplitOwnerKind.self,
        appliedCount: 4,
        daySlots: <SplitDaySlot>[
          SplitDaySlot.rest(dayIndex: 1),
          SplitDaySlot.rest(dayIndex: 2),
          SplitDaySlot.rest(dayIndex: 3),
        ],
      );
      expect(
        const SplitValidator().problems(wrong).map((p) => p.problem),
        contains(SplitProblem.clientSplitCarriesCoachOnlyField),
      );
    });
  });

  group('P0-SPLIT-03 — only a coach may assign', () {
    test('a client applying her split to another uid throws', () {
      expect(
        () => const SplitApplicator().materialise(
          split: _fourDaySplit(),
          clientUid: 'someone_else',
          dates: _dates(4),
          actor: const PlanningActor.client('u1'),
          hasActiveRelationship: false,
          constraints: _constraints(),
          catalogue: _catalogue,
        ),
        throwsA(isA<NotYourClient>()),
      );
    });

    test('applying her own split to herself passes', () {
      final applied = const SplitApplicator().materialise(
        split: _fourDaySplit(),
        clientUid: 'u1',
        dates: _dates(4),
        actor: const PlanningActor.client('u1'),
        hasActiveRelationship: false,
        constraints: _constraints(),
        catalogue: _catalogue,
      );
      expect(applied.days, hasLength(4));
    });

    test('a coach without an active relationship is a stranger', () {
      expect(
        SplitAssignmentGuard.mayAssign(
          actor: const PlanningActor.coach('c1'),
          targetUid: 'u1',
          hasActiveRelationship: false,
        ),
        isFalse,
      );
    });
  });

  group('P0-SPLIT-04 — applying a split to a month', () {
    test('the days are filled by value, and re-screened against HER list', () {
      final applied = const SplitApplicator().materialise(
        split: _fourDaySplit(),
        clientUid: 'u1',
        dates: _dates(8),
        actor: const PlanningActor.coach('c1'),
        hasActiveRelationship: true,
        constraints: _constraints(
          avoid: <ContraindicationTag>{ContraindicationTag.deepKneeFlexion},
        ),
        catalogue: _catalogue,
      );

      expect(applied.days, hasLength(8), reason: 'the cycle repeats');
      expect(applied.templateRef, 'coaches/c1/splits/s_1');

      final firstDay = applied.days['2026-09-19']!;
      final ids = firstDay.workout!.moves.map((m) => m.exerciseId).toList();
      expect(
        ids,
        <String>['glute_bridge'],
        reason:
            'her avoid list removed the squat; the box jump was never hers to '
            'begin with — both absent, not greyed out',
      );
      expect(
        applied.suppressedExerciseIds,
        containsAll(<String>['goblet_squat', 'box_jump']),
      );
      expect(
        firstDay.workout!.moves.first.order,
        1,
        reason: 'the order she reads is renumbered, not left with holes',
      );
      expect(
        firstDay.workout!.approvedAlternatives,
        isEmpty,
        reason: 'an alternative for a move she no longer has is not an option',
      );
      expect(applied.days['2026-09-21']!.isRest, isTrue);
    });

    test('nothing in the draft is the same object as in the template', () {
      final split = _fourDaySplit();
      final applied = const SplitApplicator().materialise(
        split: split,
        clientUid: 'u1',
        dates: _dates(1),
        actor: const PlanningActor.coach('c1'),
        hasActiveRelationship: true,
        constraints: _constraints(),
        catalogue: _catalogue,
      );

      final templateMove = split.daySlots.first.moves.first;
      final draftMove = applied.days['2026-09-19']!.workout!.moves.first;
      expect(draftMove.exerciseId, templateMove.exerciseId);
      expect(
        identical(draftMove, templateMove),
        isFalse,
        reason: 'copied by value: there is no shared object to reach through',
      );
    });

    test('carryApproved off leaves the easier options behind', () {
      final applied = const SplitApplicator().materialise(
        split: _fourDaySplit(carryApproved: false),
        clientUid: 'u1',
        dates: _dates(1),
        actor: const PlanningActor.coach('c1'),
        hasActiveRelationship: true,
        constraints: _constraints(),
        catalogue: _catalogue,
      );
      expect(applied.days['2026-09-19']!.workout!.approvedAlternatives, isEmpty);
    });
  });

  group('P1-RULE-18 — editing a split reaches nothing', () {
    test('the published version is byte-identical afterwards', () async {
      final splitRepo = InMemorySplitRepository();
      final draftRepo = InMemoryPlanDraftRepository();
      final gateway = _RecordingGateway();
      final publisher = CoachPlanPublisher(
        gateway: gateway,
        queue: InMemoryPublishIntentQueue(),
      );

      final split = _fourDaySplit();
      await splitRepo.save(split);

      final applied = const SplitApplicator().materialise(
        split: split,
        clientUid: 'u1',
        dates: _dates(4),
        actor: const PlanningActor.coach('c1'),
        hasActiveRelationship: true,
        constraints: _constraints(),
        catalogue: _catalogue,
      );

      final draft = PlanDraft(
        clientUid: 'u1',
        coachUid: 'c1',
        month: '2026-09',
        days: applied.days,
        origin: DraftOrigin.split,
        templateRef: applied.templateRef,
      );
      await draftRepo.save(draft);

      final outcome = await publisher.publish(
        draft: draft,
        context: PublishContext(
          lifeStage: LifeStage.over1y,
          today: _today,
          source: 'split',
        ),
      );
      expect(outcome.isPublished, isTrue);

      final publishedPayload = gateway.requests.single.payload.toString();
      final draftsWritten = draftRepo.writes;

      // Now edit the split every way K20 offers.
      await splitRepo.save(
        split.withChanges(
          name: 'Renamed entirely',
          carryApproved: false,
          updatedAt: DateTime(2026, 9, 20),
          daySlots: <SplitDaySlot>[
            SplitDaySlot(
              dayIndex: 1,
              kind: DaySlotKind.session,
              title: 'Something else',
              minutes: 10,
              moves: <PrescribedMove>[_move('box_jump', 1)],
            ),
            SplitDaySlot.rest(dayIndex: 2),
            SplitDaySlot.rest(dayIndex: 3),
            SplitDaySlot.rest(dayIndex: 4),
          ],
        ),
      );

      expect(
        gateway.requests.single.payload.toString(),
        publishedPayload,
        reason: 'the published version is untouched by an edit to its template',
      );
      expect(
        draftRepo.writes,
        draftsWritten,
        reason: 'editing a split writes zero documents outside splits/*',
      );
      expect(
        draftRepo.contents[draft.draftId]!.days['2026-09-19']!.workout!.moves
            .map((m) => m.exerciseId),
        <String>['glute_bridge', 'goblet_squat', 'box_jump'],
        reason: 'her month is what it was when it was written',
      );
      expect(
        draftRepo.contents[draft.draftId]!.templateRef,
        'coaches/c1/splits/s_1',
        reason: 'provenance survives, and is still never dereferenced',
      );
    });

    test('deleting the split leaves the month standing', () async {
      final splitRepo = InMemorySplitRepository(
        splits: <Split>[_fourDaySplit()],
      );
      final draftRepo = InMemoryPlanDraftRepository();

      final applied = const SplitApplicator().materialise(
        split: _fourDaySplit(),
        clientUid: 'u1',
        dates: _dates(4),
        actor: const PlanningActor.coach('c1'),
        hasActiveRelationship: true,
        constraints: _constraints(),
        catalogue: _catalogue,
      );
      final draft = PlanDraft(
        clientUid: 'u1',
        coachUid: 'c1',
        month: '2026-09',
        days: applied.days,
        templateRef: applied.templateRef,
      );
      await draftRepo.save(draft);

      await splitRepo.delete('s_1');

      final after = await draftRepo.draftFor(clientUid: 'u1', month: '2026-09');
      expect(after!.days, hasLength(4));
      expect(
        after.templateRef,
        'coaches/c1/splits/s_1',
        reason: 'a dangling provenance string breaks nothing, because nothing '
            'reads it',
      );
    });
  });
}
