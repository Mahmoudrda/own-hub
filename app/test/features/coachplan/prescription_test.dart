// P0-ASSIGN-01 and P0-ASSIGN-02, from the authoring side — plus the three
// bans that hold across the whole feature.
//
// Her session runs on the coach's numbers, so those numbers have to arrive
// intact: the order, the sets, the reps, the rest between sets, the note in
// her coach's words, and the swap her coach approved in advance. What must
// **not** arrive is anywhere to write down what she actually did. Spine C8
// makes prescribed and actual differently *typed* rather than differently
// named, so there is no single field a widget could pre-fill with a result —
// and `PrescriptionOnlyValidator` is the second line, not the first.
//
// P0-ASSIGN-02's half of this is `effectiveFrom`: a revision published while
// she is mid-session applies to future dates, so the session she is in keeps
// the numbers it started with.

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/safety/life_stage_safety_policy.dart';
import 'package:own_hub/features/coachplan/domain/plan/coach_plan_publisher.dart';
import 'package:own_hub/features/coachplan/domain/plan/plan_draft.dart';
import 'package:own_hub/features/coachplan/domain/prescription.dart';
import 'package:own_hub/features/coachplan/domain/prescription_only_validator.dart';

import 'source_scan.dart';

final DateTime _today = DateTime(2026, 9, 19);

class _RecordingGateway implements PlanPublishGateway {
  final List<PublishRequest> requests = <PublishRequest>[];
  final Map<String, String> _versions = <String, String>{};

  @override
  Future<PublishReceipt> publishCoachPlan(PublishRequest request) async {
    requests.add(request);
    return PublishReceipt(
      version: _versions.putIfAbsent(
        request.idempotencyKey,
        () => 'v${_versions.length + 1}',
      ),
      assignmentsWritten: request.payload.length,
      mealSlotsWritten: 0,
    );
  }
}

final _session = DraftWorkout(
  title: 'Legs and glutes',
  minutes: 35,
  restBetweenSetsSec: 45,
  note: 'Keep the same load as last Tuesday.',
  moves: <PrescribedMove>[
    const PrescribedMove(
      exerciseId: 'goblet_squat',
      order: 1,
      sets: 3,
      reps: 10,
      load: PrescribedLoad.kg(12),
      note: 'Slow on the way down.',
    ),
    const PrescribedMove(
      exerciseId: 'glute_bridge',
      order: 2,
      sets: 3,
      reps: 12,
      load: PrescribedLoad.bodyweight(),
    ),
    const PrescribedMove(
      exerciseId: 'side_plank',
      order: 3,
      sets: 2,
      holdSeconds: 30,
      load: PrescribedLoad.seconds(30),
    ),
  ],
  approvedAlternatives: <ApprovedAlternative>[
    ApprovedAlternative(exerciseId: 'box_squat', forExerciseId: 'goblet_squat'),
  ],
);

PlanDraft _draft({String? effectiveFrom, DraftWorkout? workout}) => PlanDraft(
  clientUid: 'u1',
  coachUid: 'c1',
  month: '2026-09',
  effectiveFrom: effectiveFrom,
  days: <String, PlanDay>{
    '2026-09-21': PlanDay(
      kind: PlanDayKind.workout,
      workout: workout ?? _session,
    ),
  },
);

Map<String, Object?> _publishedWorkout(PublishRequest request) {
  final days = request.payload['days']! as Map<String, Object?>;
  final day = days['2026-09-21']! as Map<String, Object?>;
  return day['workout']! as Map<String, Object?>;
}

void main() {
  group('P0-ASSIGN-01 — her session runs on her coach\'s numbers', () {
    test('order, sets, reps, rest and both notes arrive unchanged', () async {
      final gateway = _RecordingGateway();
      await CoachPlanPublisher(
        gateway: gateway,
        queue: InMemoryPublishIntentQueue(),
      ).publish(
        draft: _draft(),
        context: PublishContext(lifeStage: LifeStage.over1y, today: _today),
      );

      final workout = _publishedWorkout(gateway.requests.single);
      expect(workout['minutes'], 35);
      expect(workout['restBetweenSetsSec'], 45);
      expect(workout['note'], 'Keep the same load as last Tuesday.');

      final moves = workout['moves']! as List<Object?>;
      expect(moves, hasLength(3));

      final first = moves.first! as Map<String, Object?>;
      expect(first['exerciseId'], 'goblet_squat');
      expect(first['order'], 1);
      expect(first['sets'], 3);
      expect(first['reps'], 10);
      expect(first['note'], 'Slow on the way down.');
      expect(first['prescribedLoad'], <String, Object?>{
        'kind': 'kg',
        'value': 12,
      });
    });

    test('a bodyweight move prescribes no number, not a zero', () {
      const load = PrescribedLoad.bodyweight();
      expect(load.value, isNull);
      expect(
        load.toWire().containsKey('value'),
        isFalse,
        reason:
            '"0 kg" reads as zero kilograms, which is a number nobody meant',
      );
    });

    test('a hold prescribes seconds and no reps', () {
      final hold = _session.moves.last;
      expect(hold.reps, isNull);
      expect(hold.holdSeconds, 30);
      expect(hold.toWire().containsKey('reps'), isFalse);
    });

    test('the approved swap travels, so she never waits for a reply', () async {
      final gateway = _RecordingGateway();
      await CoachPlanPublisher(
        gateway: gateway,
        queue: InMemoryPublishIntentQueue(),
      ).publish(
        draft: _draft(),
        context: PublishContext(lifeStage: LifeStage.over1y, today: _today),
      );

      expect(
        (_publishedWorkout(gateway.requests.single)['approvedAlternatives']!
                as List<Object?>)
            .single,
        <String, Object?>{
          'exerciseId': 'box_squat',
          'forExerciseId': 'goblet_squat',
        },
      );
    });

    test('nothing in a published day could gate her stopping', () async {
      final gateway = _RecordingGateway();
      await CoachPlanPublisher(
        gateway: gateway,
        queue: InMemoryPublishIntentQueue(),
      ).publish(
        draft: _draft(),
        context: PublishContext(lifeStage: LifeStage.over1y, today: _today),
      );

      final payload = gateway.requests.single.payload.toString();
      for (final banned in <String>{
        'requiresApproval',
        'needsApproval',
        'mayStop',
        'permission',
        'lockedUntil',
      }) {
        expect(payload.contains(banned), isFalse, reason: banned);
      }
    });
  });

  group('P0-ASSIGN-02 — a revision applies to future dates', () {
    test('effectiveFrom is clamped to today, mid-session or not', () async {
      final gateway = _RecordingGateway();
      await CoachPlanPublisher(
        gateway: gateway,
        queue: InMemoryPublishIntentQueue(),
      ).publish(
        draft: _draft(effectiveFrom: '2026-09-01'),
        context: PublishContext(lifeStage: LifeStage.over1y, today: _today),
      );

      expect(
        gateway.requests.single.effectiveFrom,
        '2026-09-19',
        reason: 'Monday\'s logged assignment is finished work',
      );
    });

    test('a date she chose in the future is hers to choose', () async {
      final gateway = _RecordingGateway();
      await CoachPlanPublisher(
        gateway: gateway,
        queue: InMemoryPublishIntentQueue(),
      ).publish(
        draft: _draft(effectiveFrom: '2026-09-24'),
        context: PublishContext(lifeStage: LifeStage.over1y, today: _today),
      );
      expect(gateway.requests.single.effectiveFrom, '2026-09-24');
    });

    test('a revision is a new version; a replay of one is not', () async {
      final gateway = _RecordingGateway();
      final publisher = CoachPlanPublisher(
        gateway: gateway,
        queue: InMemoryPublishIntentQueue(),
      );
      final context = PublishContext(
        lifeStage: LifeStage.over1y,
        today: _today,
      );

      final first = await publisher.publish(draft: _draft(), context: context);
      final replay = await publisher.publish(draft: _draft(), context: context);
      final revised = await publisher.publish(
        draft: _draft(
          workout: DraftWorkout(
            title: 'Legs and glutes',
            minutes: 45,
            moves: _session.moves,
          ),
        ),
        context: context,
      );

      expect(replay.receipt!.version, first.receipt!.version);
      expect(revised.receipt!.version, isNot(first.receipt!.version));
    });

    test('the request names no session and no running version', () async {
      final gateway = _RecordingGateway();
      await CoachPlanPublisher(
        gateway: gateway,
        queue: InMemoryPublishIntentQueue(),
      ).publish(
        draft: _draft(),
        context: PublishContext(lifeStage: LifeStage.over1y, today: _today),
      );

      final payload = gateway.requests.single.payload.toString();
      for (final banned in <String>{'sessionId', 'planVersion', 'inProgress'}) {
        expect(
          payload.contains(banned),
          isFalse,
          reason:
              'the session she is in is hers, and this request cannot '
              'reach into it — found "$banned"',
        );
      }
    });
  });

  group('no actual, no weight, nothing ranked — across the whole feature', () {
    test(
      'a result-shaped key is refused at any depth, and its path is named',
      () {
        final wire = <String, Object?>{
          'days': <String, Object?>{
            '2026-09-16': <String, Object?>{
              'workout': <String, Object?>{
                'moves': <Object?>[
                  <String, Object?>{'exerciseId': 'a'},
                  <String, Object?>{'exerciseId': 'b'},
                  <String, Object?>{'exerciseId': 'c', 'actualReps': 9},
                ],
              },
            },
          },
        };

        expect(
          () => PrescriptionOnlyValidator.assertPrescriptionOnly(wire),
          throwsA(
            isA<ActualFieldInPrescription>()
                .having((e) => e.key, 'key', 'actualReps')
                .having(
                  (e) => e.path,
                  'path',
                  'days.2026-09-16.workout.moves[2]',
                ),
          ),
        );
        expect(PrescriptionOnlyValidator.isPrescriptionOnly(wire), isFalse);
      },
    );

    test('every banned key is banned, one at a time', () {
      for (final key in kForbiddenResultKeys) {
        expect(
          PrescriptionOnlyValidator.isPrescriptionOnly(<String, Object?>{
            'workout': <String, Object?>{key: 1},
          }),
          isFalse,
          reason: key,
        );
      }
    });

    test('a published month carries no such field anywhere', () async {
      final gateway = _RecordingGateway();
      await CoachPlanPublisher(
        gateway: gateway,
        queue: InMemoryPublishIntentQueue(),
      ).publish(
        draft: _draft(),
        context: PublishContext(lifeStage: LifeStage.over1y, today: _today),
      );

      // Keys, not a substring search over the blob: `bodyweight` is a *load
      // kind* and must stay sayable, while a `weight` key must not exist.
      expect(
        _keysAtEveryDepth(gateway.requests.single.payload).intersection(
          <String>{...kForbiddenResultKeys, ...kForbiddenBodyMeasureKeys},
        ),
        isEmpty,
      );
      expect(
        _keysAtEveryDepth(gateway.requests.single.payload),
        contains('prescribedLoad'),
        reason: 'the walker is looking at the right document',
      );
    });

    test('and no type in the feature has a field to put one in', () {
      final offenders = <String>[];
      coachPlanSources().forEach((path, source) {
        // The validator's own deny lists have to name what they ban in order
        // to ban it — `product_rules_test.dart` draws the same exemption, for
        // the same reason.
        if (path == 'domain/prescription_only_validator.dart') return;
        for (final banned in <String>{
          ...kForbiddenResultFields,
          ...kForbiddenWeightFields,
        }) {
          if (source.contains(banned)) offenders.add('$path names $banned');
        }
      });
      expect(offenders, isEmpty);

      // And the deny list is still a deny list, rather than a renamed one.
      expect(kForbiddenResultKeys, contains('actualReps'));
      expect(kForbiddenBodyMeasureKeys, contains('weightKg'));
    });

    test('nothing in the feature sorts by anything about her body', () {
      final offenders = <String>[];
      coachPlanSources().forEach((path, source) {
        for (final banned in <String>{
          'orderBy(',
          'leaderboard',
          'rankBy',
          'sortByWeight',
        }) {
          if (source.contains(banned)) offenders.add('$path names $banned');
        }
      });
      expect(
        offenders,
        isEmpty,
        reason:
            'K19 sorts splits by when they were edited; W01 orders work by '
            'how long somebody has waited. Neither is a ranking of women.',
      );
    });
  });
}

/// Every key in [node], however deeply nested, including inside lists.
Set<String> _keysAtEveryDepth(Object? node) {
  final keys = <String>{};
  void walk(Object? value) {
    if (value is Map) {
      for (final entry in value.entries) {
        keys.add('${entry.key}');
        walk(entry.value);
      }
      return;
    }
    if (value is Iterable) value.forEach(walk);
  }

  walk(node);
  return keys;
}
