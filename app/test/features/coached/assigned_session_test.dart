// P0-ASSIGN-01, P1-RULE-01B, and the sentence that matters most on G06/G07:
// **coach approval is never required to stop.**
//
// Her coach's numbers here are 17.5 kg × 9 with 75 seconds of rest — nothing
// like the mockup's 12 kg × 12 at 45 seconds — so a test that passed by
// recognising the fixture rather than reading the assignment would fail.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/training/prescribed_set.dart';
import 'package:own_hub/features/coached/domain/assigned_session.dart';
import 'package:own_hub/features/coached/domain/g2_contract.dart';

const _controller = AssignedSessionController();

AssignedMove _squat() => AssignedMove(
  exerciseId: 'goblet_squat',
  name: 'Goblet squat',
  coachNote: 'Keep 17.5 and stop at 7 if the knee talks.',
  restSec: 75,
  sets: [
    for (var i = 1; i <= 3; i++)
      PrescribedSet(
        exerciseId: 'goblet_squat',
        order: i,
        weightKg: 17.5,
        reps: 9,
      ),
  ],
  alternatives: const [
    ApprovedAlternative(
      exerciseId: 'box_squat',
      name: 'Box squat to a chair',
      reason: 'same muscles, less depth',
    ),
    ApprovedAlternative(
      exerciseId: 'glute_bridge',
      name: 'Glute bridge',
      reason: 'nothing standing',
    ),
  ],
);

/// A second move with **no** rest seconds, so the null case is exercised.
AssignedMove _row() => AssignedMove(
  exerciseId: 'band_row',
  name: 'Band row',
  sets: [
    for (var i = 1; i <= 2; i++)
      PrescribedSet(exerciseId: 'band_row', order: i, reps: 14),
  ],
);

CoachAssignment _assignment() => CoachAssignment(
  dateKey: '2026-09-17',
  planVersion: 'v4',
  workout: AssignedWorkout(
    title: 'Lower body',
    summary: '28 min',
    coachNote: 'Short one today.',
    moves: [_squat(), _row()],
  ),
);

void main() {
  group('P1-RULE-01B — a prescription is never a result', () {
    test('every set is born with no outcome', () {
      final session = _controller.start(_assignment());
      for (final move in session.moves) {
        for (final set in move.sets) {
          expect(set.outcome, isNull);
          expect(set.isLogged, isFalse);
        }
      }
      expect(session.setsLogged, 0);
      expect(session.setsPrescribed, 5);
    });

    test('the summary counts outcomes, not prescriptions', () {
      var session = _controller.start(_assignment());
      session = _controller.recordSet(
        session,
        moveIndex: 0,
        setIndex: 0,
        outcome: const SetOutcome(weightKg: 17.5, reps: 9),
      );
      session = _controller.recordSet(
        session,
        moveIndex: 0,
        setIndex: 1,
        outcome: const SetOutcome(weightKg: 17.5, reps: 7),
      );
      session = _controller.finish(session, durationSec: 1_380);

      final summary = _controller.summarise(session);
      expect(summary.setsCompleted, 2);
      expect(summary.setsPrescribed, 5);
      expect(summary.ratio, closeTo(0.4, 0.001));
    });

    test('a session built from the contract is always born clean', () {
      // A coached session is a second way into the player, and a second way in
      // is where a rule quietly stops applying. The assertion is restated at
      // this boundary for exactly that reason.
      final prefilled = CoachAssignment(
        dateKey: '2026-09-18',
        planVersion: 'v4',
        workout: AssignedWorkout(
          title: 'Upper body',
          moves: [
            AssignedMove(
              exerciseId: 'press',
              name: 'Press',
              sets: const [
                PrescribedSet(exerciseId: 'press', order: 1, reps: 10),
              ],
            ),
          ],
        ),
      );
      // Nothing in the contract can express a pre-filled set, so the guard is
      // exercised by the session that is built from it: it must be clean.
      final session = _controller.start(prefilled);
      expect(session.moves.single.sets.single.outcome, isNull);
    });
  });

  group('P0-ASSIGN-01 — her coach\'s numbers, and her own decisions', () {
    test('the coach\'s rest seconds are used, and a null is not a zero', () {
      final session = _controller.start(_assignment());
      expect(_controller.restFor(session, 0), 75);
      expect(
        _controller.restFor(session, 1),
        isNull,
        reason:
            'the coach set no rest on this move. Null is "she set none", and '
            'the screen may not claim she set zero.',
      );
    });

    test('her note travels with the move', () {
      final session = _controller.start(_assignment());
      expect(session.workout.coachNote, 'Short one today.');
      expect(session.moves.first.assigned.coachNote, contains('17.5'));
    });

    test('a coach-approved swap completes the session with no reply', () {
      var session = _controller.start(_assignment());
      session = _controller.swap(
        session,
        moveIndex: 0,
        toExerciseId: 'box_squat',
      );

      expect(session.moves.first.name, 'Box squat to a chair');
      // The prescription underneath is unchanged: a swap is today only.
      expect(session.moves.first.assigned.exerciseId, 'goblet_squat');
      expect(session.moves.first.sets, hasLength(3));
    });

    test(
      'an unapproved swap is refused — "approved" is a fact, not a label',
      () {
        final session = _controller.start(_assignment());
        expect(
          () => _controller.swap(
            session,
            moveIndex: 0,
            toExerciseId: 'barbell_back_squat',
          ),
          throwsA(isA<StateError>()),
        );
      },
    );

    test('skipping needs nobody', () {
      var session = _controller.start(_assignment());
      session = _controller.skipMove(session, moveIndex: 1);
      expect(session.skippedMoves, ['Band row']);
    });
  });

  group('coach approval is never required to stop', () {
    test('stop() takes no coach, no reason and sends nothing', () {
      var session = _controller.start(_assignment());
      session = _controller.recordSet(
        session,
        moveIndex: 0,
        setIndex: 0,
        outcome: const SetOutcome(weightKg: 17.5, reps: 9),
      );

      final stopped = _controller.stop(session, durationSec: 420);

      expect(stopped.end, SessionEnd.stoppedEarly);
      // What she did is kept. Stopping is a decision, not a failure.
      expect(_controller.summarise(stopped).setsCompleted, 1);
      expect(_controller.summarise(stopped).end, SessionEnd.stoppedEarly);
    });

    test('this file cannot send a message at all', () {
      // The strongest form of "no approval required": the session domain does
      // not import the message repository, so there is no call it could make
      // that waits for a coach.
      final source = _sourceOf(
        'lib/features/coached/domain/assigned_session.dart',
      );
      expect(source.contains('message_repository'), isFalse);
      expect(RegExp(r'\bMessageRepository\b').hasMatch(source), isFalse);
      expect(RegExp(r'\bawaitApproval\b').hasMatch(source), isFalse);
    });
  });

  group('P0-ASSIGN-02 — a revision mid-session changes nothing running', () {
    test('the session keeps the version it started on', () {
      var session = _controller.start(_assignment());
      expect(session.planVersion, 'v4');

      // The coach publishes v5 while this is open. Nothing in this object can
      // hear about it: there is no setter and no re-read.
      session = _controller.recordSet(
        session,
        moveIndex: 0,
        setIndex: 0,
        outcome: const SetOutcome(weightKg: 17.5, reps: 9),
      );
      session = _controller.finish(session, durationSec: 900);

      expect(session.planVersion, 'v4');
      expect(session.moves.first.sets.first.prescribed.weightKg, 17.5);
    });

    test('the session id is deterministic, so a replay collides', () {
      final a = _controller.start(_assignment());
      final b = _controller.start(_assignment());
      expect(a.id, b.id);
    });
  });

  group('negative controls', () {
    test('starting a rest day is a caller error, not an empty screen', () {
      expect(
        () => _controller.start(
          const CoachAssignment(dateKey: '2026-09-20', planVersion: 'v4'),
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('an empty session reports null adherence rather than zero', () {
      final summary = SessionSummary(
        setsCompleted: 0,
        setsPrescribed: 0,
        setsSkipped: 0,
        skippedMoves: const [],
        end: SessionEnd.finished,
      );
      expect(summary.ratio, isNull);
    });

    test('a skipped set is distinct from an unlogged one', () {
      var session = _controller.start(_assignment());
      session = _controller.recordSet(
        session,
        moveIndex: 1,
        setIndex: 0,
        outcome: const SetOutcome.skipped(),
      );
      expect(session.setsSkipped, 1);
      expect(session.setsLogged, 0);
    });
  });
}

String _sourceOf(String path) => File(path).readAsStringSync();
