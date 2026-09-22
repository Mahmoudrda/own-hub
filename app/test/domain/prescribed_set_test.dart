// Implements TEST-CASES.csv: P1-RULE-01 (a prescribed value is never a result)
// and the type half of spine C8.
//
// These tests are mostly about what does NOT exist. A test that a field is
// absent looks odd until you remember that the defect this guards against is
// someone helpfully adding it.

import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/domain/training/prescribed_set.dart';

void main() {
  const prescribed = PrescribedSet(
    exerciseId: 'goblet_squat',
    order: 1,
    weightKg: 12,
    reps: 10,
  );

  group('P1-RULE-01 — a prescribed value is never a result', () {
    test(
      'a set with a prescription is not logged until an outcome is recorded',
      () {
        const set = LoggedSet(prescribed: prescribed);
        expect(set.outcome, isNull);
        expect(set.isLogged, isFalse);
      },
    );

    test('recording requires her numbers to be supplied explicitly', () {
      // There is no zero-argument "log as prescribed": the caller must state what
      // she did. If she did exactly the prescription, the UI says so with values.
      final done = const LoggedSet(prescribed: prescribed)
          .recording(const SetOutcome(weightKg: 12, reps: 10));
      expect(done.isLogged, isTrue);
      expect(done.outcome!.weightKg, 12);

      // The prescription is untouched by recording against it.
      expect(done.prescribed.weightKg, 12);
      expect(done.prescribed.reps, 10);
    });

    test('a harder set never rewrites the prescription', () {
      final done = const LoggedSet(prescribed: prescribed)
          .recording(const SetOutcome(weightKg: 14, reps: 8));
      expect(done.outcome!.weightKg, 14);
      expect(
        done.prescribed.weightKg,
        12,
        reason:
            'the plan said 12 kg; that it was hard does not change the plan',
      );
    });

    test('an unlogged set is not a zero', () {
      const set = LoggedSet(prescribed: prescribed);
      expect(set.isLogged, isFalse);
      // Adherence must not treat it as a failure either — see below.
    });

    test('skipping is a decision, and distinct from not logging', () {
      final skipped = const LoggedSet(prescribed: prescribed)
          .recording(const SetOutcome.skipped());
      expect(skipped.outcome, isNotNull);
      expect(skipped.isLogged, isFalse, reason: 'skipped is not done');
      expect(skipped.outcome!.skipped, isTrue);
    });
  });

  group('adherence counts only what she logged', () {
    const calc = AdherenceCalculator();

    test('an empty session has no adherence, not zero adherence', () {
      expect(calc.ratio(const []), isNull);
    });

    test('counts logged sets over prescribed sets', () {
      final sets = [
        const LoggedSet(prescribed: prescribed)
            .recording(const SetOutcome(weightKg: 12, reps: 10)),
        const LoggedSet(prescribed: prescribed),
        const LoggedSet(prescribed: prescribed)
            .recording(const SetOutcome.skipped()),
        const LoggedSet(prescribed: prescribed)
            .recording(const SetOutcome(weightKg: 12, reps: 9)),
      ];
      expect(calc.ratio(sets), 0.5);
    });

    test('a live session must be born with nothing logged', () {
      // Spine C8 at the storage boundary.
      final clean = [
        const LoggedSet(prescribed: prescribed),
        const LoggedSet(prescribed: prescribed),
      ];
      expect(calc.hasNoPrefill(clean), isTrue);

      final prefilled = [
        const LoggedSet(prescribed: prescribed)
            .recording(const SetOutcome(weightKg: 12, reps: 10)),
      ];
      expect(calc.hasNoPrefill(prefilled), isFalse);
    });
  });

  group('bodyweight and time-based moves', () {
    test('a move may prescribe no weight and no reps', () {
      const plank = PrescribedSet(
        exerciseId: 'plank',
        order: 1,
        holdSeconds: 40,
      );
      expect(plank.weightKg, isNull);
      expect(plank.reps, isNull);
      expect(plank.holdSeconds, 40);
    });

    test('a hold counts as logged when the seconds are recorded', () {
      const plank = PrescribedSet(
        exerciseId: 'plank',
        order: 1,
        holdSeconds: 40,
      );
      final done = const LoggedSet(prescribed: plank)
          .recording(const SetOutcome(holdSeconds: 35));
      expect(done.isLogged, isTrue);
    });
  });
}
