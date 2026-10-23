// P0-SPLIT-05 — one split, sixty women, and a fan-out that ends.
//
// The scalability gate. Applying a split to a full book is the one action in
// this feature that multiplies: sixty clients × ~31 days. Three things have to
// be true for that to be safe, and each is a separate failure:
//
//  * **One call per client, not one per day.** The device sends sixty
//    requests carrying thirty-one days each; it never issues the ~1,860
//    document writes itself. A client-side loop over days is how a coach's
//    phone spends four minutes and half a battery on one tap.
//  * **Idempotent.** The key is `{clientUid, month, draftHash}`, so replaying
//    the whole book creates zero extra versions.
//  * **Screened per woman.** The template is the same; the months are not,
//    because each is re-screened against *her* constraints.
//
// And the fourth, which is r12 paying for itself: editing the split afterwards
// writes nothing at all.

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/safety/client_constraints.dart';
import 'package:own_hub/domain/safety/contraindication_tag.dart';
import 'package:own_hub/domain/safety/exercise_candidate_filter.dart';
import 'package:own_hub/domain/safety/life_stage_safety_policy.dart';
import 'package:own_hub/domain/safety/safety_assessment.dart';
import 'package:own_hub/features/coachplan/domain/clients/coach_client.dart';
import 'package:own_hub/features/coachplan/domain/plan/coach_plan_publisher.dart';
import 'package:own_hub/features/coachplan/domain/plan/plan_draft.dart';
import 'package:own_hub/features/coachplan/domain/plan/plan_draft_repository.dart';
import 'package:own_hub/features/coachplan/domain/prescription.dart';
import 'package:own_hub/features/coachplan/domain/split/split.dart';
import 'package:own_hub/features/coachplan/domain/split/split_applicator.dart';
import 'package:own_hub/features/coachplan/domain/split/split_assignment_guard.dart';
import 'package:own_hub/features/coachplan/domain/split/split_repository.dart';

final DateTime _today = DateTime(2026, 9, 1);

/// The month P0-SPLIT-05 costs: thirty-one days.
const int _daysInMonth = 31;

/// Firestore's batch limit. The server chunks under it; nothing here does.
const int _maxOpsPerCommit = 500;

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
};

ScreenableExercise? _catalogue(String id) => _moves[id];

PrescribedMove _move(String id, int order) => PrescribedMove(
  exerciseId: id,
  order: order,
  sets: 3,
  reps: 12,
  load: const PrescribedLoad.bodyweight(),
);

Split _split({String name = 'Upper / lower'}) => Split(
  splitId: 's_1',
  name: name,
  cycleLength: 4,
  ownerKind: SplitOwnerKind.coach,
  updatedAt: DateTime(2026, 8, 30),
  daySlots: <SplitDaySlot>[
    SplitDaySlot(
      dayIndex: 1,
      kind: DaySlotKind.session,
      title: 'Full body',
      minutes: 30,
      moves: <PrescribedMove>[
        _move('glute_bridge', 1),
        _move('goblet_squat', 2),
      ],
    ),
    SplitDaySlot(
      dayIndex: 2,
      kind: DaySlotKind.session,
      title: 'Lower body',
      minutes: 30,
      moves: <PrescribedMove>[_move('glute_bridge', 1)],
    ),
    SplitDaySlot.rest(dayIndex: 3),
    SplitDaySlot(
      dayIndex: 4,
      kind: DaySlotKind.session,
      title: 'Upper body',
      minutes: 20,
      moves: <PrescribedMove>[_move('glute_bridge', 1)],
    ),
  ],
);

ClientConstraints _constraints({Set<ContraindicationTag> avoid = const {}}) =>
    ClientConstraintResolver.resolve(
      assessment: SafetyAssessment(
        assessmentId: 'a',
        clientUid: 'u',
        coachUid: 'c1',
        takenAt: DateTime(2026, 8, 20),
        lifeStage: LifeStage.over1y,
        avoid: avoid,
      ),
      allergies: const <String>{},
      dietary: const <String>{},
    );

List<DateTime> _september() => <DateTime>[
  for (var i = 0; i < _daysInMonth; i++) _today.add(Duration(days: i)),
];

/// G2's callable, as the test can measure it: one entry per call, and a
/// version per distinct idempotency key.
class _CountingGateway implements PlanPublishGateway {
  final List<PublishRequest> requests = <PublishRequest>[];
  final Map<String, String> _versionByKey = <String, String>{};

  Set<String> get versions => _versionByKey.values.toSet();

  @override
  Future<PublishReceipt> publishCoachPlan(PublishRequest request) async {
    requests.add(request);
    final version = _versionByKey.putIfAbsent(
      request.idempotencyKey,
      () => 'v${_versionByKey.length + 1}',
    );
    return PublishReceipt(
      version: version,
      assignmentsWritten:
          (request.payload['days']! as Map<String, Object?>).length,
      mealSlotsWritten: 0,
    );
  }
}

/// The book. One woman in it avoids deep knee flexion.
String _uid(int i) => 'u${i.toString().padLeft(2, '0')}';

const String _sheAvoidsSquats = 'u07';

Future<List<PublishOutcome>> _applyAndPublishAll({
  required Split split,
  required InMemoryPlanDraftRepository drafts,
  required CoachPlanPublisher publisher,
}) async {
  final outcomes = <PublishOutcome>[];
  for (var i = 0; i < kClientCap; i++) {
    final clientUid = _uid(i);
    final applied = const SplitApplicator().materialise(
      split: split,
      clientUid: clientUid,
      dates: _september(),
      actor: const PlanningActor.coach('c1'),
      hasActiveRelationship: true,
      constraints: _constraints(
        avoid: clientUid == _sheAvoidsSquats
            ? <ContraindicationTag>{ContraindicationTag.deepKneeFlexion}
            : const <ContraindicationTag>{},
      ),
      catalogue: _catalogue,
    );
    final draft = PlanDraft(
      clientUid: clientUid,
      coachUid: 'c1',
      month: '2026-09',
      days: applied.days,
      origin: DraftOrigin.split,
      templateRef: applied.templateRef,
    );
    await drafts.save(draft);
    outcomes.add(
      await publisher.publish(
        draft: draft,
        context: PublishContext(
          lifeStage: LifeStage.over1y,
          today: _today,
          source: 'split',
        ),
      ),
    );
  }
  return outcomes;
}

void main() {
  group('P0-SPLIT-05 — one split applied to a full book', () {
    test(
      'sixty calls carrying thirty-one days each, not 1,860 writes',
      () async {
        final gateway = _CountingGateway();
        final drafts = InMemoryPlanDraftRepository();
        final outcomes = await _applyAndPublishAll(
          split: _split(),
          drafts: drafts,
          publisher: CoachPlanPublisher(
            gateway: gateway,
            queue: InMemoryPublishIntentQueue(),
          ),
        );

        expect(outcomes.every((o) => o.isPublished), isTrue);
        expect(
          gateway.requests,
          hasLength(kClientCap),
          reason: 'one callable per client — the device never loops over days',
        );

        final serverWrites = gateway.requests.fold<int>(
          0,
          (total, r) =>
              total + (r.payload['days']! as Map<String, Object?>).length,
        );
        expect(serverWrites, kClientCap * _daysInMonth);
        expect(
          (serverWrites / _maxOpsPerCommit).ceil(),
          lessThanOrEqualTo(4),
          reason: 'the server chunks the fan-out; it is bounded and one-time',
        );
        expect(drafts.writes, kClientCap);
      },
    );

    test('replaying the whole book creates zero extra versions', () async {
      final gateway = _CountingGateway();
      final drafts = InMemoryPlanDraftRepository();
      final publisher = CoachPlanPublisher(
        gateway: gateway,
        queue: InMemoryPublishIntentQueue(),
      );

      await _applyAndPublishAll(
        split: _split(),
        drafts: drafts,
        publisher: publisher,
      );
      final versionsAfterFirstPass = gateway.versions;

      // The coach's phone lost signal and retried the lot.
      await _applyAndPublishAll(
        split: _split(),
        drafts: drafts,
        publisher: publisher,
      );

      expect(gateway.requests, hasLength(kClientCap * 2));
      expect(
        gateway.versions,
        versionsAfterFirstPass,
        reason: 'keyed on {clientUid, month, draftHash}',
      );
      expect(gateway.versions, hasLength(kClientCap));
    });

    test(
      'each month is screened against her own list, not the last one\'s',
      () async {
        final gateway = _CountingGateway();
        await _applyAndPublishAll(
          split: _split(),
          drafts: InMemoryPlanDraftRepository(),
          publisher: CoachPlanPublisher(
            gateway: gateway,
            queue: InMemoryPublishIntentQueue(),
          ),
        );

        String movesOn(String clientUid) {
          final request = gateway.requests.firstWhere(
            (r) => r.clientUid == clientUid,
          );
          final days = request.payload['days']! as Map<String, Object?>;
          final day = days['2026-09-01']! as Map<String, Object?>;
          final workout = day['workout']! as Map<String, Object?>;
          return (workout['moves']! as List<Object?>)
              .map((m) => (m! as Map<String, Object?>)['exerciseId'])
              .join(',');
        }

        expect(movesOn(_uid(0)), 'glute_bridge,goblet_squat');
        expect(
          movesOn(_sheAvoidsSquats),
          'glute_bridge',
          reason: 'the squat is absent from hers, and from nobody else\'s',
        );
      },
    );

    test('editing the split afterwards writes zero documents', () async {
      final gateway = _CountingGateway();
      final drafts = InMemoryPlanDraftRepository();
      final splits = InMemorySplitRepository();
      final split = _split();
      await splits.save(split);

      await _applyAndPublishAll(
        split: split,
        drafts: drafts,
        publisher: CoachPlanPublisher(
          gateway: gateway,
          queue: InMemoryPublishIntentQueue(),
        ),
      );
      final draftWrites = drafts.writes;
      final calls = gateway.requests.length;
      final published = gateway.requests
          .map((r) => r.payload.toString())
          .toList();

      await splits.save(
        split.withChanges(
          name: 'Renamed for the autumn',
          updatedAt: DateTime(2026, 9, 2),
          daySlots: <SplitDaySlot>[
            SplitDaySlot(
              dayIndex: 1,
              kind: DaySlotKind.session,
              title: 'Something else entirely',
              minutes: 10,
              moves: <PrescribedMove>[_move('goblet_squat', 1)],
            ),
            SplitDaySlot.rest(dayIndex: 2),
            SplitDaySlot.rest(dayIndex: 3),
            SplitDaySlot.rest(dayIndex: 4),
          ],
        ),
      );

      expect(drafts.writes, draftWrites);
      expect(gateway.requests, hasLength(calls));
      expect(
        gateway.requests.map((r) => r.payload.toString()).toList(),
        published,
        reason: 'sixty months, none of them reachable from the template',
      );
      expect(splits.writes, 2, reason: 'the split document, and only it');
    });

    test('the fan-out is bounded by the cap, not by the calendar', () {
      expect(ClientQueue.hasRoomFor(kClientCap), isFalse);
      expect(kClientCap * _daysInMonth, lessThan(2000));
    });
  });
}
