// Future production API. This intentionally fails to compile until F6 exists.
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/features/train/domain/progression_policy.dart';

void main() {
  ProgressionDecision decide({
    double? previous = 10,
    List<int> reps = const [10, 10, 10],
    List<double> weights = const [10, 12, 15],
    bool difficult = false,
    bool pain = false,
    bool returning = false,
    bool coached = false,
  }) => suggestProgression(
    previousWeightKg: previous,
    completedReps: reps,
    targetSets: 3,
    targetReps: 10,
    availableWeightsKg: weights,
    difficult: difficult,
    painReported: pain,
    returningAfterBreak: returning,
    coached: coached,
  );
  test('F6 no recorded history means no fabricated increase', () {
    final result = decide(previous: null, reps: []);
    expect(result.action, 'hold');
    expect(result.suggestedWeightKg, isNull);
  });
  test(
    'F6 all target sets choose next available load without mutating input',
    () {
      final weights = <double>[15, 10, 12, 12];
      final result = decide(weights: weights);
      expect(result.action, 'increase');
      expect(result.suggestedWeightKg, 12);
      expect(weights, [15, 10, 12, 12]);
    },
  );
  for (final reps in [
    <int>[],
    [10, 10],
    [10, 9, 10],
    [10, 10, 10, 10],
  ]) {
    test('F6 incomplete or ambiguous work sets hold: $reps', () {
      final result = decide(reps: reps);
      expect(result.action, 'hold');
      expect(result.suggestedWeightKg, 10);
    });
  }
  test('F6 no higher supported load means hold', () {
    expect(decide(weights: [5, 10]).action, 'hold');
    expect(decide(weights: []).suggestedWeightKg, 10);
  });
  test('F6 difficulty holds; pain and a return require review', () {
    expect(decide(difficult: true).action, 'hold');
    for (final result in [decide(pain: true), decide(returning: true)]) {
      expect(result.action, 'review');
      expect(result.suggestedWeightKg, 10);
    }
  });
  test('F6 a coached increase is only a suggestion requiring approval', () {
    expect(decide(coached: true).requiresCoachApproval, isTrue);
    expect(decide().requiresCoachApproval, isFalse);
    expect(
      decide(coached: true, difficult: true).requiresCoachApproval,
      isFalse,
    );
  });
  for (final value in [-1.0, double.nan, double.infinity]) {
    test('F6 reject invalid weight $value', () {
      expect(() => decide(previous: value), throwsArgumentError);
      expect(() => decide(weights: [value]), throwsArgumentError);
    });
  }
  test('F6 reject negative completed reps and non-positive targets', () {
    expect(() => decide(reps: [-1, 10, 10]), throwsArgumentError);
    expect(
      () => suggestProgression(
        previousWeightKg: 10,
        completedReps: [],
        targetSets: 0,
        targetReps: 10,
        availableWeightsKg: [10],
        difficult: false,
        painReported: false,
        returningAfterBreak: false,
        coached: false,
      ),
      throwsArgumentError,
    );
  });
}
