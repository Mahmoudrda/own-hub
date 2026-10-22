// The calorie estimate: MET x body weight x hours, always an estimate.

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/training/energy_estimate.dart';

void main() {
  group('classifyEffort', () {
    test('an ordinary strength session is steady', () {
      // 12 sets in 24 minutes: two minutes a set, rests included.
      expect(
        classifyEffort(
          durationSec: 24 * 60,
          sets: 12,
          repSets: 12,
          totalReps: 120,
        ),
        EffortKind.steady,
      );
    });

    test('short rests read as circuit style', () {
      // 12 sets in 12 minutes: a minute a set.
      expect(classifyEffort(durationSec: 12 * 60, sets: 12), EffortKind.hard);
    });

    test('the cut-off is inclusive at 75 seconds a set', () {
      expect(classifyEffort(durationSec: 750, sets: 10), EffortKind.hard);
      expect(classifyEffort(durationSec: 760, sets: 10), EffortKind.steady);
    });

    test('high reps with a tight cycle read as hard, with a loose one not', () {
      expect(
        classifyEffort(durationSec: 900, sets: 10, repSets: 10, totalReps: 160),
        EffortKind.hard,
      );
      expect(
        classifyEffort(
          durationSec: 1200,
          sets: 10,
          repSets: 10,
          totalReps: 160,
        ),
        EffortKind.steady,
      );
      // Ordinary reps at the same cycle stay steady.
      expect(
        classifyEffort(durationSec: 900, sets: 10, repSets: 10, totalReps: 100),
        EffortKind.steady,
      );
    });

    test('no sets or no time is steady, never a division by zero', () {
      expect(classifyEffort(durationSec: 600, sets: 0), EffortKind.steady);
      expect(classifyEffort(durationSec: 0, sets: 5), EffortKind.steady);
    });
  });

  group('estimateKcal', () {
    test('steady strength: 3.5 x 65 kg x half an hour', () {
      expect(
        estimateKcal(
          durationSec: 1800,
          kind: EffortKind.steady,
          bodyWeightKg: 65,
        ),
        114,
      );
    });

    test('hard work: 5.0 x 60 kg x one hour', () {
      expect(
        estimateKcal(
          durationSec: 3600,
          kind: EffortKind.hard,
          bodyWeightKg: 60,
        ),
        300,
      );
    });

    test('an unset weight is 65 kg', () {
      expect(
        estimateKcal(durationSec: 3600, kind: EffortKind.steady),
        estimateKcal(
          durationSec: 3600,
          kind: EffortKind.steady,
          bodyWeightKg: defaultBodyWeightKg,
        ),
      );
      expect(estimateKcal(durationSec: 3600, kind: EffortKind.steady), 228);
    });

    test('an impossible weight falls back to the default', () {
      expect(bodyWeightOrDefault(5), 65);
      expect(bodyWeightOrDefault(400), 65);
      expect(bodyWeightOrDefault(72.5), 72.5);
      expect(bodyWeightOrDefault(null), 65);
    });

    test('no time is zero', () {
      expect(estimateKcal(durationSec: 0, kind: EffortKind.hard), 0);
      expect(estimateKcal(durationSec: -5, kind: EffortKind.hard), 0);
    });

    test('a session left open for hours stops counting at three', () {
      final three = estimateKcal(
        durationSec: maxEstimatedSeconds,
        kind: EffortKind.steady,
      );
      expect(
        estimateKcal(durationSec: 10 * 3600, kind: EffortKind.steady),
        three,
      );
    });
  });
}
