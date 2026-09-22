// PersonalBestDetector — the G6 half of P0-LOG-04 and P0-LOG-12, plus the four
// kinds of best P03 renders.
//
// Every figure differs from the prototype's. P03 draws 12 kg × 10, 3 × 15, a
// 45-second plank and a step-back lunge; these tests use 18 kg × 6, 22 reps and
// a 62-second hold, so a detector that recited the mockup would fail throughout.

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/rewards/personal_best_detector.dart';
import 'package:own_hub/domain/training/session.dart';

const String _session = 'sess-3b9';
const String _date = '2026-09-18';

const Map<String, ExerciseMeta> _library = <String, ExerciseMeta>{
  'hip_thrust': ExerciseMeta(exerciseId: 'hip_thrust', metric: BestMetric.load),
  'push_up': ExerciseMeta(exerciseId: 'push_up', metric: BestMetric.reps),
  'side_plank': ExerciseMeta(exerciseId: 'side_plank', metric: BestMetric.hold),
  'split_squat': ExerciseMeta(
    exerciseId: 'split_squat',
    metric: BestMetric.load,
    progressionFamily: 'squat',
    progressionRank: 3,
    siblings: <String>['box_squat', 'goblet_squat'],
  ),
};

List<PersonalBest> _detect(
  List<MeasuredSet> sets, {
  SessionSource source = SessionSource.live,
  Map<String, PersonalBest> current = const <String, PersonalBest>{},
}) {
  const detector = PersonalBestDetector();
  return detector.detect(
    source: source,
    sessionId: _session,
    dateKey: _date,
    measuredSets: sets,
    exercises: _library,
    current: current,
  );
}

void main() {
  group('P0-LOG-04 / P0-LOG-12 — only a live session can set a best', () {
    final strong = [
      const MeasuredSet(
        exerciseId: 'hip_thrust',
        actualWeight: 18,
        actualReps: 6,
      ),
    ];

    test('a live session sets one', () {
      expect(_detect(strong), hasLength(1));
    });

    test('a recalled session sets none', () {
      expect(
        _detect(strong, source: SessionSource.recalled),
        isEmpty,
        reason: 'the numbers were copied, not measured',
      );
    });

    test('an unplanned session sets none either', () {
      // The regression P0-LOG-12 exists for: written as `== recalled`, this
      // case fell through and a logged walk became eligible for a best.
      expect(_detect(strong, source: SessionSource.unplanned), isEmpty);
    });

    test('exactly one source is eligible', () {
      final eligible = SessionSource.values
          .where((s) => _detect(strong, source: s).isNotEmpty)
          .toList();
      expect(eligible, [SessionSource.live]);
    });
  });

  group('a best on load', () {
    test('the first ever is a best', () {
      final found = _detect([
        const MeasuredSet(
          exerciseId: 'hip_thrust',
          actualWeight: 18,
          actualReps: 6,
        ),
      ]);

      expect(found.single.exerciseId, 'hip_thrust');
      expect(found.single.metric, BestMetric.load);
      expect(found.single.loadKg, 18);
      expect(found.single.reps, 6);
      expect(found.single.previous, isNull);
      expect(found.single.dateKey, _date);
      expect(found.single.sessionId, _session);
    });

    test('heavier than before is a best, and carries the previous one', () {
      final found = _detect(
        [
          const MeasuredSet(
            exerciseId: 'hip_thrust',
            actualWeight: 20,
            actualReps: 5,
          ),
        ],
        current: {
          'hip_thrust': const PersonalBest(
            exerciseId: 'hip_thrust',
            metric: BestMetric.load,
            dateKey: '2026-09-04',
            sessionId: 'older',
            loadKg: 18,
            reps: 6,
          ),
        },
      );

      expect(found.single.loadKg, 20);
      expect(found.single.previous?.loadKg, 18);
      expect(found.single.previous?.dateKey, '2026-09-04');
    });

    test('lighter than before is not a best', () {
      final found = _detect(
        [
          const MeasuredSet(
            exerciseId: 'hip_thrust',
            actualWeight: 16,
            actualReps: 10,
          ),
        ],
        current: {
          'hip_thrust': const PersonalBest(
            exerciseId: 'hip_thrust',
            metric: BestMetric.load,
            dateKey: '2026-09-04',
            sessionId: 'older',
            loadKg: 18,
            reps: 6,
          ),
        },
      );
      expect(found, isEmpty);
    });

    test('the same load for more total work is a best', () {
      final found = _detect(
        [
          const MeasuredSet(
            exerciseId: 'hip_thrust',
            actualWeight: 18,
            actualReps: 9,
          ),
        ],
        current: {
          'hip_thrust': const PersonalBest(
            exerciseId: 'hip_thrust',
            metric: BestMetric.load,
            dateKey: '2026-09-04',
            sessionId: 'older',
            loadKg: 18,
            reps: 6,
          ),
        },
      );

      expect(found.single.loadKg, 18);
      expect(found.single.reps, 9);
    });

    test('the heaviest set in the session is the one compared', () {
      final found = _detect([
        const MeasuredSet(
          exerciseId: 'hip_thrust',
          actualWeight: 14,
          actualReps: 12,
        ),
        const MeasuredSet(
          exerciseId: 'hip_thrust',
          actualWeight: 22,
          actualReps: 4,
        ),
        const MeasuredSet(
          exerciseId: 'hip_thrust',
          actualWeight: 18,
          actualReps: 8,
        ),
      ]);

      expect(found.single.loadKg, 22);
    });
  });

  group('a best on reps', () {
    test('more reps at no less than the load she managed before', () {
      final found = _detect(
        [const MeasuredSet(exerciseId: 'push_up', actualReps: 22)],
        current: {
          'push_up': const PersonalBest(
            exerciseId: 'push_up',
            metric: BestMetric.reps,
            dateKey: '2026-09-04',
            sessionId: 'older',
            reps: 18,
          ),
        },
      );

      expect(found.single.reps, 22);
      expect(found.single.previous?.reps, 18);
    });

    test(
      'more reps at a LIGHTER load is a different set, not a better one',
      () {
        final found = _detect(
          [
            const MeasuredSet(
              exerciseId: 'push_up',
              actualWeight: 5,
              actualReps: 30,
            ),
          ],
          current: {
            'push_up': const PersonalBest(
              exerciseId: 'push_up',
              metric: BestMetric.reps,
              dateKey: '2026-09-04',
              sessionId: 'older',
              loadKg: 12,
              reps: 18,
            ),
          },
        );

        expect(
          found,
          isEmpty,
          reason:
              'dropping to a lighter weight and doing more reps must not read '
              'as progress',
        );
      },
    );

    test('fewer reps is not a best', () {
      final found = _detect(
        [const MeasuredSet(exerciseId: 'push_up', actualReps: 12)],
        current: {
          'push_up': const PersonalBest(
            exerciseId: 'push_up',
            metric: BestMetric.reps,
            dateKey: '2026-09-04',
            sessionId: 'older',
            reps: 18,
          ),
        },
      );
      expect(found, isEmpty);
    });
  });

  group('a best on a hold', () {
    test('a longer hold is a best', () {
      final found = _detect(
        [const MeasuredSet(exerciseId: 'side_plank', actualHoldSec: 62)],
        current: {
          'side_plank': const PersonalBest(
            exerciseId: 'side_plank',
            metric: BestMetric.hold,
            dateKey: '2026-09-04',
            sessionId: 'older',
            holdSec: 48,
          ),
        },
      );

      expect(found.single.holdSec, 62);
      expect(found.single.previous?.holdSec, 48);
    });

    test('nothing populates actualHoldSec today, so nothing is detected', () {
      // G6 §7.3 request 1: `sets[].actualHoldSec` is absent from G4's
      // measuredSets payload, so P03's "Plank hold" cannot be detected from a
      // real session yet. This test states the gap rather than hiding it: a set
      // that carries no hold produces no hold best, which is exactly what every
      // real session currently looks like.
      final found = _detect([
        const MeasuredSet(exerciseId: 'side_plank', actualReps: 3),
      ]);
      expect(found, isEmpty);
    });
  });

  group('a best that is not a bigger number', () {
    test('moving to a harder version of the movement counts', () {
      final found = _detect(
        [
          const MeasuredSet(
            exerciseId: 'split_squat',
            actualWeight: 8,
            actualReps: 8,
          ),
        ],
        current: {
          'box_squat': const PersonalBest(
            exerciseId: 'box_squat',
            metric: BestMetric.load,
            dateKey: '2026-08-20',
            sessionId: 'older',
            loadKg: 20,
            rank: 1,
          ),
        },
      );

      expect(found.single.metric, BestMetric.variation);
      expect(found.single.rank, 3);
      expect(found.single.previous?.rank, 1);
    });

    test('it does not fire when she already trains at that version', () {
      final found = _detect(
        [
          const MeasuredSet(
            exerciseId: 'split_squat',
            actualWeight: 8,
            actualReps: 8,
          ),
        ],
        current: {
          'split_squat': const PersonalBest(
            exerciseId: 'split_squat',
            metric: BestMetric.load,
            dateKey: '2026-09-04',
            sessionId: 'older',
            loadKg: 10,
            rank: 3,
          ),
        },
      );

      // Not a variation — and 8 kg is lighter than the 10 kg she holds, so not
      // a load best either.
      expect(found, isEmpty);
    });

    test('it does not fire with no history in the family at all', () {
      final found = _detect([
        const MeasuredSet(
          exerciseId: 'split_squat',
          actualWeight: 8,
          actualReps: 8,
        ),
      ]);

      // A first best on this exercise, on its own metric — not a "level up",
      // because there was nothing lower to move up from.
      expect(found.single.metric, BestMetric.load);
    });
  });

  group('it fails closed and reads only what she did', () {
    test('an exercise the pack does not describe sets no best', () {
      final found = _detect([
        const MeasuredSet(
          exerciseId: 'a_move_with_no_metadata',
          actualWeight: 40,
          actualReps: 20,
        ),
      ]);
      expect(
        found,
        isEmpty,
        reason: 'a missing content tag must cost a best, never invent a metric',
      );
    });

    test('a set with nothing logged sets nothing', () {
      // An unlogged set is an absence, not a zero (spine C8).
      final found = _detect([const MeasuredSet(exerciseId: 'hip_thrust')]);
      expect(found, isEmpty);
    });

    test('several exercises in one session each get at most one best', () {
      final found = _detect([
        const MeasuredSet(
          exerciseId: 'hip_thrust',
          actualWeight: 18,
          actualReps: 6,
        ),
        const MeasuredSet(
          exerciseId: 'hip_thrust',
          actualWeight: 20,
          actualReps: 4,
        ),
        const MeasuredSet(exerciseId: 'push_up', actualReps: 22),
      ]);

      expect(found, hasLength(2));
      expect(found.map((b) => b.exerciseId).toSet(), {'hip_thrust', 'push_up'});
    });
  });
}
