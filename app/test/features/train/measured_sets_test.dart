// The conversion that was missing: what she logged, as the detector measures it.
//
// Every figure here is unlike any fixture in
// `test/domain/rewards/personal_best_detector_test.dart` (18/20/16/22/14 kg,
// 62 s) and unlike the prototype's (12 kg x 10, 45 s), so a conversion that
// recited either would fail throughout.
//
// The negative controls are the point of the file. A skipped set and an
// unlogged set must produce NOTHING — not a zero, not an empty MeasuredSet —
// because a zero would read as a lift of no weight and could overwrite a best.

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/training/prescribed_set.dart';
import 'package:own_hub/domain/training/session.dart' as training;
import 'package:own_hub/features/train/domain/measured_sets.dart';
import 'package:own_hub/features/train/domain/train_repository.dart';

const PrescribedSet _squat = PrescribedSet(
  exerciseId: 'goblet_squat',
  order: 1,
  weightKg: 25,
  reps: 12,
);

const PrescribedSet _hold = PrescribedSet(
  exerciseId: 'hip_thrust_hold',
  order: 1,
  holdSeconds: 60,
);

void main() {
  group('what she did crosses; what she did not never does', () {
    test('a logged lift carries its weight and its reps', () {
      final measured = measuredSetsFrom([
        LoggedSet(prescribed: _squat)
            .recording(const SetOutcome(weightKg: 27.5, reps: 13)),
      ]);

      expect(measured, hasLength(1));
      expect(measured.single.exerciseId, 'goblet_squat');
      expect(measured.single.actualWeight, 27.5);
      expect(measured.single.actualReps, 13);
      expect(measured.single.actualHoldSec, isNull);
    });

    test('D19 — a hold carries its seconds across', () {
      // The whole of D19: `SetOutcome` has carried `holdSeconds` all along and
      // `MeasuredSet` has read `actualHoldSec` all along, and nothing joined
      // them. If this line is dropped, `PersonalBestDetector._hold` can never
      // fire from a real session and P03's hold row is permanently empty.
      final measured = measuredSetsFrom([
        LoggedSet(prescribed: _hold)
            .recording(const SetOutcome(holdSeconds: 96)),
      ]);

      expect(measured.single.actualHoldSec, 96);
      expect(measured.single.exerciseId, 'hip_thrust_hold');
    });

    test('the exercise id is read off the prescription, not guessed', () {
      final measured = measuredSetsFrom([
        LoggedSet(
          prescribed: const PrescribedSet(
            exerciseId: 'dead_bug',
            order: 2,
            reps: 8,
          ),
        ).recording(const SetOutcome(reps: 9)),
      ]);

      expect(measured.single.exerciseId, 'dead_bug');
    });

    test('a bodyweight move crosses with no weight rather than with zero', () {
      final measured = measuredSetsFrom([
        LoggedSet(
          prescribed: const PrescribedSet(
            exerciseId: 'glute_bridge',
            order: 1,
            reps: 12,
          ),
        ).recording(const SetOutcome(reps: 17)),
      ]);

      expect(measured.single.actualReps, 17);
      expect(
        measured.single.actualWeight,
        isNull,
        reason: '0 kg is a weight she never lifted',
      );
    });
  });

  group('NEGATIVE CONTROLS — an absence is never a zero', () {
    test('a skipped set produces nothing at all', () {
      final measured = measuredSetsFrom([
        LoggedSet(prescribed: _squat).recording(const SetOutcome.skipped()),
      ]);

      expect(
        measured,
        isEmpty,
        reason:
            'a skipped set that crossed as 0 kg would be compared against her '
            'best and is one sign flip away from overwriting it',
      );
    });

    test('a skipped set still carrying numbers produces nothing', () {
      // `isLogged` is `!skipped && (...)`. A converter that tested only for the
      // presence of numbers would let this through.
      final measured = measuredSetsFrom([
        LoggedSet(prescribed: _squat)
            .recording(const SetOutcome(weightKg: 34, reps: 9, skipped: true)),
      ]);

      expect(measured, isEmpty);
    });

    test('an unlogged set produces nothing', () {
      final measured = measuredSetsFrom([LoggedSet(prescribed: _squat)]);
      expect(measured, isEmpty);
    });

    test('an outcome with neither reps nor a hold produces nothing', () {
      // Weight alone is not a logged set: `isLogged` requires reps or a hold.
      final measured = measuredSetsFrom([
        LoggedSet(prescribed: _squat).recording(const SetOutcome(weightKg: 41)),
      ]);

      expect(measured, isEmpty);
    });

    test('RULE 1 — a prescription is never a result', () {
      // 40 kg x 20 is prescribed and nothing is logged. If the converter ever
      // read `prescribed` instead of `outcome`, this is the set that would
      // silently become a personal best she never lifted.
      final measured = measuredSetsFrom([
        LoggedSet(
          prescribed: const PrescribedSet(
            exerciseId: 'goblet_squat',
            order: 1,
            weightKg: 40,
            reps: 20,
          ),
        ),
      ]);

      expect(measured, isEmpty);
    });
  });

  group('a move as it is actually flushed', () {
    test('only the logged sets survive, in the order she did them', () {
      final measured = measuredSetsFrom([
        LoggedSet(prescribed: _squat)
            .recording(const SetOutcome(weightKg: 27.5, reps: 13)),
        LoggedSet(prescribed: _squat).recording(const SetOutcome.skipped()),
        LoggedSet(prescribed: _squat),
        LoggedSet(prescribed: _squat)
            .recording(const SetOutcome(weightKg: 34, reps: 9)),
      ]);

      expect(measured.map((s) => s.actualWeight).toList(), [27.5, 34]);
      expect(measured.map((s) => s.actualReps).toList(), [13, 9]);
    });

    test('an empty flush measures nothing', () {
      expect(measuredSetsFrom(const <LoggedSet>[]), isEmpty);
    });
  });

  group('the two SessionSource enums are joined, not assumed', () {
    // `features/train/domain/train_repository.dart` and
    // `domain/training/session.dart` each declare their own `SessionSource`.
    // They are different types with the same name, and the detector takes the
    // second. Without this mapping the bridge does not compile; with a careless
    // one, a recalled session could arrive labelled live.
    test('each train source maps to its own name in the credit enum', () {
      expect(measuredSourceOf(SessionSource.live), training.SessionSource.live);
      expect(
        measuredSourceOf(SessionSource.recalled),
        training.SessionSource.recalled,
      );
      expect(
        measuredSourceOf(SessionSource.unplanned),
        training.SessionSource.unplanned,
      );
    });

    test('the mapping is total, and the two enums cannot drift apart', () {
      expect(
        SessionSource.values.map(measuredSourceOf).toList(),
        training.SessionSource.values,
        reason:
            'a source added to one enum and not the other must fail the build '
            'rather than fall through to whichever branch runs',
      );
    });

    test('exactly one source stays eligible for a best', () {
      const credit = training.SessionCredit();
      final eligible = SessionSource.values
          .where((s) => credit.eligibleForPersonalBest(measuredSourceOf(s)))
          .toList();

      expect(eligible, [SessionSource.live]);
    });
  });
}
