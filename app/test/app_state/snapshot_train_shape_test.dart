// The training section of the snapshot: what it writes, what it costs, and
// what it can still read.
//
// A session's sets used to go to the phone twice — once as the prescriptions
// under `train.sessions`, and again, with her outcomes, under `train.flushes`.
// Both halves are needed in memory (`set_history.dart` explains why), but only
// one copy of a prescription needs to be on disk. Schema 2 writes the second
// copy as a set number pointing at the first.
//
// Measured on the document the app really writes, 400 sessions of five moves
// and three sets each — two years of training at four sessions a week:
//
//   document     1802 KB  ->   953 KB
//   per session   4.50 KB  ->  2.38 KB
//   jsonEncode    10.5 ms  ->   6.6 ms   (host; a budget Android is 4-6x)
//   jsonDecode    13.9 ms  ->   5.3 ms
//
// Three things have to stay true for that saving to be worth having, and each
// is a case below: nothing of hers is lost by the short form, a prescription
// the session does NOT hold is still written out in full, and a document
// written by the build before this one still restores.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/app_snapshot.dart';
import 'package:own_hub/domain/training/prescribed_set.dart';
import 'package:own_hub/features/train/domain/train_repository.dart';
import 'package:own_hub/routing/app_router.dart';

import '../qa/round6/history_fixture.dart';

/// Capture, encode, wipe the repository, decode, restore. The wipe is what
/// makes this a test: without it a decoder that restored nothing would pass.
void _roundTrip() {
  final document = jsonEncode(AppSnapshot.capture());
  AppRouter.trainRepository.reset();
  expect(AppRouter.trainRepository.sessions, isEmpty);
  AppSnapshot.restore(document);
}

/// The train section as it is written, decoded back into plain maps.
Map<String, Object?> _writtenTrain() =>
    jsonDecode(jsonEncode(AppSnapshot.capture()))['train']
        as Map<String, Object?>;

List<Object?> _flushSets(Map<String, Object?> train, int index) =>
    ((train['flushes']! as List<Object?>)[index]
            as Map<String, Object?>)['sets']!
        as List<Object?>;

PrescribedSet _p(
  String exerciseId,
  int order, {
  double? weightKg,
  int? reps,
  int? holdSeconds,
}) => PrescribedSet(
  exerciseId: exerciseId,
  order: order,
  weightKg: weightKg,
  reps: reps,
  holdSeconds: holdSeconds,
);

void main() {
  tearDown(AppRouter.trainRepository.reset);

  group('a flush names the session prescription instead of repeating it', () {
    test('every set she logged comes back, outcome for outcome', () {
      final prescriptions = <PrescribedSet>[
        _p('goblet_squat', 1, weightKg: 12.5, reps: 10),
        _p('goblet_squat', 2, weightKg: 12.5, reps: 10),
        // Bodyweight: no weight prescribed, and null must not become zero.
        _p('hip_bridge', 1, reps: 12),
        // A hold: no reps at all.
        _p('side_plank', 1, holdSeconds: 30),
      ];
      AppRouter.trainRepository.restore(
        sessions: <TrainSession>[
          TrainSession(
            id: 'live-1',
            source: SessionSource.live,
            dateKey: '2026-09-01',
            sets: [for (final p in prescriptions) LoggedSet(prescribed: p)],
            durationSec: 1500,
            endedReason: EndedReason.finished,
            completed: true,
          ),
        ],
        flushes: [
          (
            sessionId: 'live-1',
            exerciseId: 'goblet_squat',
            sets: <LoggedSet>[
              LoggedSet(prescribed: prescriptions[0])
                  .recording(const SetOutcome(weightKg: 12.5, reps: 10)),
              // A set she explicitly skipped. Not an absence, and the one
              // outcome field that is false by default.
              LoggedSet(prescribed: prescriptions[1])
                  .recording(const SetOutcome.skipped()),
            ],
          ),
          (
            sessionId: 'live-1',
            exerciseId: 'hip_bridge',
            sets: <LoggedSet>[
              LoggedSet(prescribed: prescriptions[2])
                  .recording(const SetOutcome(reps: 14)),
            ],
          ),
          (
            sessionId: 'live-1',
            exerciseId: 'side_plank',
            sets: <LoggedSet>[
              LoggedSet(prescribed: prescriptions[3])
                  .recording(const SetOutcome(holdSeconds: 42)),
            ],
          ),
        ],
        sessionCounter: 1,
      );

      _roundTrip();

      final flushes = AppRouter.trainRepository.flushes;
      expect(flushes.map((f) => f.exerciseId), [
        'goblet_squat',
        'hip_bridge',
        'side_plank',
      ]);

      final squat = flushes[0].sets;
      expect(squat[0].prescribed.exerciseId, 'goblet_squat');
      expect(squat[0].prescribed.order, 1);
      expect(squat[0].prescribed.weightKg, 12.5);
      expect(squat[0].prescribed.reps, 10);
      expect(squat[0].outcome?.weightKg, 12.5);
      expect(squat[0].outcome?.reps, 10);
      expect(squat[0].outcome?.skipped, isFalse);
      expect(squat[1].prescribed.order, 2);
      expect(squat[1].outcome?.skipped, isTrue);
      expect(squat[1].outcome?.isLogged, isFalse);

      final bridge = flushes[1].sets.single;
      expect(
        bridge.prescribed.weightKg,
        isNull,
        reason: 'bodyweight, not 0 kg',
      );
      expect(bridge.prescribed.reps, 12);
      expect(bridge.outcome?.reps, 14);
      expect(bridge.outcome?.weightKg, isNull);

      final plank = flushes[2].sets.single;
      expect(plank.prescribed.holdSeconds, 30);
      expect(plank.outcome?.holdSeconds, 42);
      expect(plank.outcome?.reps, isNull);

      // The session's own sets are untouched by all of this: still the
      // prescriptions, still with nothing logged on them (spine C8).
      final session = AppRouter.trainRepository.sessionById('live-1')!;
      expect(session.sets.length, 4);
      expect(session.sets.every((s) => s.outcome == null), isTrue);
      expect(session.completed, isTrue);
      expect(session.durationSec, 1500);
    });

    test('the second copy of the prescription is not written', () {
      fillTrainHistory(sessions: 1);
      final train = _writtenTrain();
      final sets = _flushSets(train, 0);
      expect(sets, hasLength(kSetsPerMove));
      for (final raw in sets) {
        final row = raw! as Map<String, Object?>;
        expect(
          row.containsKey('prescribed'),
          isFalse,
          reason: 'the session already carries it; the flush names it',
        );
        expect(row['order'], isA<int>());
        expect(row['outcome'], isA<Map<String, Object?>>());
      }
      // And the prescription it names is still on disk exactly once, under the
      // session.
      final session =
          (train['sessions']! as List<Object?>).single as Map<String, Object?>;
      expect(
        (session['sets']! as List<Object?>).length,
        kMoves.length * kSetsPerMove,
      );
    });

    test('a prescription the session does not hold is written in full', () {
      // A move she swapped in: the flush is real, the session was never born
      // with that exercise, so there is nothing for the short form to point at.
      final inSession = _p('goblet_squat', 1, weightKg: 12.5, reps: 10);
      final swappedIn = _p('leg_press', 1, weightKg: 30, reps: 12);
      AppRouter.trainRepository.restore(
        sessions: <TrainSession>[
          TrainSession(
            id: 'live-1',
            source: SessionSource.live,
            dateKey: '2026-09-01',
            sets: <LoggedSet>[LoggedSet(prescribed: inSession)],
          ),
        ],
        flushes: [
          (
            sessionId: 'live-1',
            exerciseId: 'leg_press',
            sets: <LoggedSet>[
              LoggedSet(prescribed: swappedIn)
                  .recording(const SetOutcome(weightKg: 32.5, reps: 12)),
            ],
          ),
        ],
        sessionCounter: 1,
      );

      final row =
          _flushSets(_writtenTrain(), 0).single! as Map<String, Object?>;
      expect(
        row['prescribed'],
        isA<Map<String, Object?>>(),
        reason: 'nothing else on disk holds this prescription',
      );

      _roundTrip();
      final set = AppRouter.trainRepository.flushes.single.sets.single;
      expect(set.prescribed.exerciseId, 'leg_press');
      expect(set.prescribed.weightKg, 30);
      expect(set.outcome?.weightKg, 32.5);
    });

    test('a prescription that changed under the same set number is kept', () {
      // Same exercise, same set number, a different weight: a plan republished
      // between the session and the flush. Pointing at the session's copy would
      // quietly rewrite what she was asked for, so this one is written out.
      final asked = _p('goblet_squat', 1, weightKg: 12.5, reps: 10);
      final flushed = _p('goblet_squat', 1, weightKg: 14, reps: 10);
      AppRouter.trainRepository.restore(
        sessions: <TrainSession>[
          TrainSession(
            id: 'live-1',
            source: SessionSource.live,
            dateKey: '2026-09-01',
            sets: <LoggedSet>[LoggedSet(prescribed: asked)],
          ),
        ],
        flushes: [
          (
            sessionId: 'live-1',
            exerciseId: 'goblet_squat',
            sets: <LoggedSet>[
              LoggedSet(prescribed: flushed)
                  .recording(const SetOutcome(weightKg: 14, reps: 9)),
            ],
          ),
        ],
        sessionCounter: 1,
      );

      final row =
          _flushSets(_writtenTrain(), 0).single! as Map<String, Object?>;
      expect(row['prescribed'], isA<Map<String, Object?>>());

      _roundTrip();
      final repository = AppRouter.trainRepository;
      expect(
        repository.sessionById('live-1')!.sets.single.prescribed.weightKg,
        12.5,
      );
      expect(repository.flushes.single.sets.single.prescribed.weightKg, 14);
    });

    test('her outcome survives a sessions row that came back corrupt', () {
      // The short form points at a prescription under `sessions`, and `sessions`
      // is the one row that did not survive the write. Her outcome is the half
      // nothing else on the phone holds, so it is kept.
      fillTrainHistory(sessions: 1);
      final document =
          jsonDecode(jsonEncode(AppSnapshot.capture())) as Map<String, Object?>;
      (document['train']! as Map<String, Object?>)['sessions'] = 'not a list';
      AppRouter.trainRepository.reset();

      AppSnapshot.restore(jsonEncode(document));

      final repository = AppRouter.trainRepository;
      expect(repository.sessions, isEmpty);
      expect(repository.flushes, hasLength(kMoves.length));
      final set = repository.flushes.first.sets.first;
      expect(set.outcome?.reps, isNotNull, reason: 'what she did is hers');
      expect(set.prescribed.exerciseId, kMoves.first);
      expect(
        set.prescribed.reps,
        isNull,
        reason:
            'this document no longer says what she was asked for, so it '
            'says nothing rather than guessing',
      );
    });

    test('a flush under a session this phone no longer holds survives', () {
      final orphan = _p('goblet_squat', 1, weightKg: 12.5, reps: 10);
      AppRouter.trainRepository.restore(
        flushes: [
          (
            sessionId: 'live-99',
            exerciseId: 'goblet_squat',
            sets: <LoggedSet>[
              LoggedSet(prescribed: orphan)
                  .recording(const SetOutcome(weightKg: 12.5, reps: 10)),
            ],
          ),
        ],
      );

      _roundTrip();
      final set = AppRouter.trainRepository.flushes.single.sets.single;
      expect(set.prescribed.weightKg, 12.5);
      expect(set.outcome?.reps, 10);
    });
  });

  group('what the document costs', () {
    test('two years of training stays under a megabyte', () {
      fillTrainHistory(sessions: 400);
      final bytes = jsonEncode(AppSnapshot.capture()).length;
      // 953 KB when this was written, against 1802 KB before the flush stopped
      // repeating prescriptions. The ceiling has headroom for a field or two
      // and none at all for the duplication coming back.
      expect(
        bytes,
        lessThan(1200 * 1024),
        reason: 'two years of training, at ${(bytes / 1024).round()} KB',
      );
      expect(
        bytes / 400,
        lessThan(3 * 1024),
        reason: 'per session, at ${(bytes / 400 / 1024).toStringAsFixed(2)} KB',
      );
    });
  });

  group('a document written by an older build still restores', () {
    test('schema 1, with the prescription repeated inside every flush', () {
      // Hand-written in the shape `app_snapshot.dart` wrote before this change,
      // because the encoder that produced it no longer exists. A woman who
      // updates the app has one of these on her phone, and losing her history
      // to a format change would be a worse failure than the one the schema
      // number guards against.
      const document = '''
{
  "schema": 1,
  "savedAt": "2026-09-01T07:14:22.000Z",
  "train": {
    "sessions": [
      {
        "id": "live-1",
        "source": "live",
        "dateKey": "2026-09-01",
        "sets": [
          {
            "prescribed": {
              "exerciseId": "goblet_squat",
              "order": 1,
              "weightKg": 12.5,
              "reps": 10,
              "holdSeconds": null
            }
          }
        ],
        "assignmentId": null,
        "planVersion": null,
        "workoutId": null,
        "activity": null,
        "recallMethod": null,
        "endedReason": "finished",
        "durationSec": 1500,
        "completed": true
      }
    ],
    "flushes": [
      {
        "sessionId": "live-1",
        "exerciseId": "goblet_squat",
        "sets": [
          {
            "prescribed": {
              "exerciseId": "goblet_squat",
              "order": 1,
              "weightKg": 12.5,
              "reps": 10,
              "holdSeconds": null
            },
            "outcome": {
              "weightKg": 12.5,
              "reps": 9,
              "holdSeconds": null,
              "skipped": false
            }
          }
        ]
      }
    ],
    "swaps": [{"from": "goblet_squat", "to": "leg_press"}],
    "counter": 1
  }
}
''';
      AppRouter.trainRepository.reset();
      expect(AppSnapshot.restore(document), 1);

      final repository = AppRouter.trainRepository;
      expect(repository.sessionById('live-1')?.durationSec, 1500);
      expect(repository.sessionById('live-1')?.completed, isTrue);
      final set = repository.flushes.single.sets.single;
      expect(set.prescribed.weightKg, 12.5);
      expect(set.outcome?.reps, 9);
      expect(repository.swaps.single.to, 'leg_press');
      expect(repository.sessionCounter, 1);
    });

    test('a schema this build has never heard of is refused whole', () {
      fillTrainHistory(sessions: 1);
      final captured = AppSnapshot.capture();
      captured['schema'] = kSnapshotSchema + 1;
      AppRouter.trainRepository.reset();
      expect(AppSnapshot.restore(jsonEncode(captured)), 0);
      expect(AppRouter.trainRepository.sessions, isEmpty);
      expect(AppRouter.trainRepository.flushes, isEmpty);
    });
  });
}
