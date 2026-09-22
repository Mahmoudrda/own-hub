// END TO END: she logs a heavier set, and a personal best exists.
//
// Every other test in this change exercises one half. This file starts at the
// repository — the same `startSession` / `flushMove` pair R03 and R07 call — and
// finishes at `bestsCount`, the number `TierLadder.shipped` gates Regular,
// Strong and Unshakeable on.
//
// The figures are hers alone: 27.5 kg x 13, 34 kg x 9, a 96-second hold. None
// of them appears in the prototype (12 kg x 10, 3 x 15, 45 s) or in the
// detector's own fixtures (18/20/16 kg, 62 s).

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/rewards/personal_best_detector.dart';
import 'package:own_hub/domain/rewards/personal_best_ledger.dart';
import 'package:own_hub/domain/training/prescribed_set.dart';
import 'package:own_hub/features/train/domain/exercise_metrics.dart';
import 'package:own_hub/features/train/domain/session_bests_bridge.dart';
import 'package:own_hub/features/train/domain/train_repository.dart';

const PrescribedSet _squatSet = PrescribedSet(
  exerciseId: 'goblet_squat',
  order: 1,
  weightKg: 12,
  reps: 10,
);

const PrescribedSet _holdSet = PrescribedSet(
  exerciseId: 'hip_thrust_hold',
  order: 1,
  holdSeconds: 30,
);

/// A day keyed the way a real assignment is — `yyyy-MM-dd`, so the best it
/// produces carries a date P03 can sort on.
const WorkoutDay _day = WorkoutDay(
  id: '2026-09-19',
  title: 'Legs and glutes',
  summary: '15 minutes, 5 moves',
  constraints: 'Quiet',
  moves: [
    PlannedMove(
      exerciseId: 'goblet_squat',
      name: 'Goblet squat',
      prescriptionLabel: '3 x 10 - 12 kg suggested',
      sets: [_squatSet],
    ),
    PlannedMove(
      exerciseId: 'hip_thrust_hold',
      name: 'Hip thrust hold',
      prescriptionLabel: '3 x 30 seconds',
      sets: [_holdSet],
    ),
  ],
);

({InMemoryTrainRepository repository, PersonalBestLedger ledger}) _wired({
  Map<String, PersonalBest>? bests,
  int bestsCount = 0,
}) {
  final ledger = PersonalBestLedger(bests: bests, bestsCount: bestsCount);
  final bridge = SessionBestsBridge(ledger: ledger);
  return (
    repository: InMemoryTrainRepository(day: _day, onFlushed: bridge.record),
    ledger: ledger,
  );
}

LoggedSet _logged(PrescribedSet prescribed, SetOutcome outcome) =>
    LoggedSet(prescribed: prescribed).recording(outcome);

void main() {
  group('a heavier set, logged, becomes a best', () {
    test('END TO END — startSession, flushMove, best, count', () async {
      final wired = _wired();
      final session = await wired.repository.startSession(_day);

      await wired.repository.flushMove(
        sessionId: session.id,
        exerciseId: 'goblet_squat',
        sets: [_logged(_squatSet, const SetOutcome(weightKg: 27.5, reps: 13))],
      );

      final best = wired.ledger.bests['goblet_squat'];
      expect(best, isNotNull);
      expect(best!.loadKg, 27.5);
      expect(best.reps, 13);
      expect(best.metric, BestMetric.load);
      expect(best.sessionId, session.id);
      expect(
        best.dateKey,
        '2026-09-19',
        reason: 'the date comes from the session, not from the clock',
      );
      expect(
        wired.ledger.bestsCount,
        1,
        reason: 'this is the number the tier ladder reads',
      );
    });

    test('the flush still reaches "the server" exactly as before', () async {
      // The hook must not replace the write. R09 and R13 assert against
      // `flushes` to prove an undone log never arrived.
      final wired = _wired();
      final session = await wired.repository.startSession(_day);

      await wired.repository.flushMove(
        sessionId: session.id,
        exerciseId: 'goblet_squat',
        sets: [_logged(_squatSet, const SetOutcome(weightKg: 34, reps: 9))],
      );

      expect(wired.repository.flushes, hasLength(1));
      expect(wired.repository.flushes.single.exerciseId, 'goblet_squat');
    });

    test('D19 — a hold logged in a real session sets a hold best', () async {
      // The decision in one test. `SetOutcome.holdSeconds` has always existed
      // and `MeasuredSet.actualHoldSec` has always been read; nothing carried
      // the value across, so P03's hold row could never fill from a session.
      final wired = _wired();
      final session = await wired.repository.startSession(_day);

      await wired.repository.flushMove(
        sessionId: session.id,
        exerciseId: 'hip_thrust_hold',
        sets: [_logged(_holdSet, const SetOutcome(holdSeconds: 96))],
      );

      final best = wired.ledger.bests['hip_thrust_hold'];
      expect(best, isNotNull);
      expect(best!.holdSec, 96);
      expect(best.metric, BestMetric.hold);
      expect(wired.ledger.bestsCount, 1);
    });

    test('a whole move of several sets yields one best, at her heaviest', () {
      // R07's "log the whole move" flushes every set at once.
      final wired = _wired();

      return wired.repository.startSession(_day).then((session) async {
        await wired.repository.flushMove(
          sessionId: session.id,
          exerciseId: 'goblet_squat',
          sets: [
            _logged(_squatSet, const SetOutcome(weightKg: 27.5, reps: 13)),
            _logged(_squatSet, const SetOutcome(weightKg: 34, reps: 9)),
            _logged(_squatSet, const SetOutcome.skipped()),
          ],
        );

        expect(wired.ledger.bests['goblet_squat']!.loadKg, 34);
        expect(wired.ledger.bestsCount, 1);
      });
    });
  });

  group('NEGATIVE CONTROLS — what a flush must never record', () {
    test('a skipped set records nothing', () async {
      final wired = _wired();
      final session = await wired.repository.startSession(_day);

      await wired.repository.flushMove(
        sessionId: session.id,
        exerciseId: 'goblet_squat',
        sets: [_logged(_squatSet, const SetOutcome.skipped())],
      );

      expect(wired.ledger.bests, isEmpty);
      expect(wired.ledger.bestsCount, 0);
    });

    test('a skipped set does not overwrite a best she holds', () async {
      final wired = _wired(
        bests: {
          'goblet_squat': const PersonalBest(
            exerciseId: 'goblet_squat',
            metric: BestMetric.load,
            dateKey: '2026-09-05',
            sessionId: 'older',
            loadKg: 41,
            reps: 11,
          ),
        },
        bestsCount: 1,
      );
      final session = await wired.repository.startSession(_day);

      await wired.repository.flushMove(
        sessionId: session.id,
        exerciseId: 'goblet_squat',
        sets: [_logged(_squatSet, const SetOutcome.skipped())],
      );

      expect(wired.ledger.bests['goblet_squat']!.loadKg, 41);
      expect(wired.ledger.bestsCount, 1);
    });

    test('an unlogged set records nothing', () async {
      final wired = _wired();
      final session = await wired.repository.startSession(_day);

      await wired.repository.flushMove(
        sessionId: session.id,
        exerciseId: 'goblet_squat',
        sets: [const LoggedSet(prescribed: _squatSet)],
      );

      expect(wired.ledger.bestsCount, 0);
    });

    test('a lighter set than the one she holds records nothing', () async {
      final wired = _wired(
        bests: {
          'goblet_squat': const PersonalBest(
            exerciseId: 'goblet_squat',
            metric: BestMetric.load,
            dateKey: '2026-09-05',
            sessionId: 'older',
            loadKg: 41,
            reps: 11,
          ),
        },
        bestsCount: 1,
      );
      final session = await wired.repository.startSession(_day);

      await wired.repository.flushMove(
        sessionId: session.id,
        exerciseId: 'goblet_squat',
        sets: [_logged(_squatSet, const SetOutcome(weightKg: 27.5, reps: 13))],
      );

      expect(wired.ledger.bests['goblet_squat']!.loadKg, 41);
      expect(wired.ledger.bestsCount, 1);
    });

    test('a recalled session records nothing, however heavy', () async {
      final wired = _wired();
      final recalled = await wired.repository.logRecalled(
        dateKey: '2026-09-19',
        method: RecallMethod.plan,
      );

      await wired.repository.flushMove(
        sessionId: recalled.id,
        exerciseId: 'goblet_squat',
        sets: [_logged(_squatSet, const SetOutcome(weightKg: 34, reps: 9))],
      );

      expect(
        wired.ledger.bestsCount,
        0,
        reason: 'R12: the numbers were copied, not measured',
      );
    });

    test('an unplanned session records nothing', () async {
      final wired = _wired();
      final walk = await wired.repository.logUnplanned(
        dateKey: '2026-09-19',
        activity: 'walk',
        durationSec: 1800,
      );

      await wired.repository.flushMove(
        sessionId: walk.id,
        exerciseId: 'goblet_squat',
        sets: [_logged(_squatSet, const SetOutcome(weightKg: 34, reps: 9))],
      );

      expect(wired.ledger.bestsCount, 0);
    });

    test('a flush for a session the repository never minted fails closed', () {
      // Not a hypothetical: a screen that flushes under an id no session was
      // started with has no source to be judged on. Refusing is the safe
      // direction — the alternative is assuming `live` and letting a recalled
      // session set a best.
      final wired = _wired();

      return wired.repository
          .flushMove(
            sessionId: 'never-started',
            exerciseId: 'goblet_squat',
            sets: [_logged(_squatSet, const SetOutcome(weightKg: 34, reps: 9))],
          )
          .then((_) {
            expect(wired.ledger.bestsCount, 0);
            expect(wired.ledger.bests, isEmpty);
          });
    });
  });

  group('idempotent — the same flush twice', () {
    test('a replayed flush mints no second best and counts once', () async {
      final wired = _wired();
      final session = await wired.repository.startSession(_day);

      final sets = [
        _logged(_squatSet, const SetOutcome(weightKg: 34, reps: 9)),
      ];

      await wired.repository.flushMove(
        sessionId: session.id,
        exerciseId: 'goblet_squat',
        sets: sets,
      );
      await wired.repository.flushMove(
        sessionId: session.id,
        exerciseId: 'goblet_squat',
        sets: sets,
      );

      expect(wired.ledger.bestsCount, 1);
      expect(wired.ledger.bests['goblet_squat']!.loadKg, 34);
      expect(
        wired.repository.flushes,
        hasLength(2),
        reason: 'both writes arrived; only one of them counted',
      );
    });
  });

  group('the wiring a router needs', () {
    test('the repository names the live session it started', () async {
      // R07 today builds with the default `sessionId: "session"`, which no
      // session was ever started under. This is what a router passes instead.
      final wired = _wired();
      expect(wired.repository.liveSessionId, isNull);

      final session = await wired.repository.startSession(_day);
      expect(wired.repository.liveSessionId, session.id);
    });

    test(
      'a repository with no hook behaves exactly as it always did',
      () async {
        final plain = InMemoryTrainRepository(day: _day);
        final session = await plain.startSession(_day);

        await plain.flushMove(
          sessionId: session.id,
          exerciseId: 'goblet_squat',
          sets: [_logged(_squatSet, const SetOutcome(weightKg: 34, reps: 9))],
        );

        expect(plain.flushes, hasLength(1));
      },
    );

    test('the bundled pack describes every move the sample day prescribes', () {
      // The detector fails closed on an exercise it has no metric for, so an
      // untagged move costs her a best she earned. These are the five the
      // product actually prescribes today.
      for (final id in [
        'glute_bridge',
        'goblet_squat',
        'step_back_lunge',
        'hip_thrust_hold',
        'dead_bug',
      ]) {
        expect(
          bundledExerciseMetrics[id],
          isNotNull,
          reason: '$id is prescribed on R03 and has no metric',
        );
      }
    });
  });
}
