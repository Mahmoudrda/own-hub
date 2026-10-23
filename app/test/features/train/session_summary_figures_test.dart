// What a finished session lifted and how much effort it was: the figures the
// share card is made of.

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/rewards/credit_outcome.dart';
import 'package:own_hub/domain/training/energy_estimate.dart';
import 'package:own_hub/domain/training/prescribed_set.dart';
import 'package:own_hub/features/train/domain/own_best_challenge.dart';
import 'package:own_hub/features/train/domain/session_summary.dart';
import 'package:own_hub/features/train/domain/train_repository.dart';

LoggedSet _set({double? kg, int? reps, int? hold, bool skipped = false}) =>
    LoggedSet(
      prescribed: const PrescribedSet(exerciseId: 'x', order: 0),
      outcome: skipped
          ? const SetOutcome.skipped()
          : SetOutcome(weightKg: kg, reps: reps, holdSeconds: hold),
    );

FlushRecord _flush(String move, List<LoggedSet> sets, {String id = 's1'}) =>
    (sessionId: id, exerciseId: move, sets: sets);

SessionSummary _sum(List<FlushRecord> flushes, {int seconds = 1800}) =>
    summarise(
      sessionId: 's1',
      source: SessionSource.live,
      flushes: flushes,
      durationSec: seconds,
      credit: const CreditOutcome(),
    );

void main() {
  test('weight lifted is kg x reps over the sets she logged', () {
    final s = _sum([
      _flush('squat', [
        _set(kg: 40, reps: 10),
        _set(kg: 40, reps: 8),
        _set(kg: 42.5, reps: 6),
      ]),
      _flush('row', [_set(kg: 20, reps: 12)]),
    ]);
    // 400 + 320 + 255 + 240
    expect(s.volumeKg, 1215);
    expect(s.volumeWholeKg, 1215);
    expect(s.weightedSets, 4);
    expect(s.totalReps, 36);
    expect(s.moves, 2);
    expect(s.sets, 4);
    expect(s.durationSec, 1800);
  });

  test('a bodyweight session lifted none, and says its reps', () {
    final s = _sum([
      _flush('push_up', [_set(reps: 12), _set(reps: 10)]),
      _flush('plank', [_set(hold: 40)]),
    ]);
    expect(s.volumeKg, 0);
    expect(s.weightedSets, 0);
    expect(s.totalReps, 22);
    expect(s.sets, 3);
  });

  test('a skipped or unlogged set adds nothing', () {
    final s = _sum([
      _flush('squat', [
        _set(kg: 50, reps: 10),
        _set(skipped: true),
        const LoggedSet(prescribed: PrescribedSet(exerciseId: 'x', order: 2)),
      ]),
    ]);
    expect(s.sets, 1);
    expect(s.volumeKg, 500);
  });

  test('a hold with a load is not weight x reps', () {
    final s = _sum([
      _flush('carry', [_set(kg: 16, hold: 30)]),
    ]);
    expect(s.volumeKg, 0);
    expect(s.sets, 1);
  });

  test('another session\'s flushes are not counted', () {
    final s = _sum([
      _flush('squat', [_set(kg: 40, reps: 10)], id: 'other'),
      _flush('squat', [_set(kg: 10, reps: 10)]),
    ]);
    expect(s.volumeKg, 100);
  });

  test('zero sets: no weight, no reps and no calories', () {
    final s = _sum(const []);
    expect(s.sets, 0);
    expect(s.volumeKg, 0);
    expect(s.totalReps, 0);
    expect(s.estimatedKcal(), 0);
  });

  group('estimated calories', () {
    final steady = _sum([
      _flush('squat', [for (var i = 0; i < 10; i++) _set(kg: 30, reps: 10)]),
    ], seconds: 1800);

    test('use her body weight when she has set it', () {
      expect(steady.effort, EffortKind.steady);
      // 3.5 x 70 x 0.5
      expect(steady.estimatedKcal(bodyWeightKg: 70), 123);
    });

    test('assume 65 kg when she has not', () {
      // 3.5 x 65 x 0.5
      expect(steady.estimatedKcal(), 114);
    });

    test('a dense session is hard and costs more per hour', () {
      final dense = _sum([
        _flush('burpee', [for (var i = 0; i < 20; i++) _set(reps: 10)]),
      ], seconds: 1200);
      expect(dense.effort, EffortKind.hard);
      // 5.0 x 65 x (1/3)
      expect(dense.estimatedKcal(), 108);
    });
  });
}
