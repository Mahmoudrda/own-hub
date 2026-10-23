// The history of one move: finished sessions only, newest first, and the
// "last time" reads skipping a discarded workout.

import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/domain/training/prescribed_set.dart';
import 'package:own_hub/features/train/domain/set_history.dart';
import 'package:own_hub/features/train/domain/train_repository.dart';

LoggedSet _set(String id, int order, {double? kg, int? reps, int? hold}) =>
    LoggedSet(
      prescribed: PrescribedSet(exerciseId: id, order: order, reps: 10),
      outcome: SetOutcome(weightKg: kg, reps: reps, holdSeconds: hold),
    );

TrainSession _session(
  String id,
  String day, {
  bool completed = true,
  EndedReason reason = EndedReason.finished,
}) => TrainSession(
  id: id,
  source: SessionSource.live,
  dateKey: day,
  sets: const [],
  completed: completed,
  endedReason: completed ? reason : null,
);

typedef _Flush = ({String sessionId, String exerciseId, List<LoggedSet> sets});

_Flush _flush(String session, String move, List<LoggedSet> sets) =>
    (sessionId: session, exerciseId: move, sets: sets);

InMemoryTrainRepository _repo(List<TrainSession> s, List<_Flush> f) =>
    InMemoryTrainRepository()..restore(sessions: s, flushes: f);

void main() {
  const move = 'hip_thrust';

  group('abandoned sessions are not history', () {
    final repo = _repo(
      [
        _session('a', '2026-10-01'),
        _session('b', '2026-10-08', reason: EndedReason.abandoned),
      ],
      [
        _flush('a', move, [_set(move, 1, kg: 40, reps: 10)]),
        _flush('b', move, [_set(move, 1, kg: 80, reps: 12)]),
      ],
    );

    test('lastLoggedOutcome skips the discarded workout', () {
      expect(lastLoggedOutcome(repo, move)!.weightKg, 40);
    });

    test('lastSessionSets skips the discarded workout', () {
      final last = lastSessionSets(repo, move)!;
      expect(last.dateKey, '2026-10-01');
      expect(last.sets.single.weightKg, 40);
    });

    test('moveHistory skips the discarded workout', () {
      expect(moveHistory(repo, move).map((h) => h.sessionId), ['a']);
    });
  });

  group('moveHistory', () {
    test('is newest first, capped at the limit', () {
      final repo = _repo(
        [for (var i = 1; i <= 7; i++) _session('s$i', '2026-10-0$i')],
        [
          for (var i = 1; i <= 7; i++)
            _flush('s$i', move, [_set(move, 1, kg: 10.0 * i, reps: 8)]),
        ],
      );
      final all = moveHistory(repo, move);
      expect(all.map((h) => h.sessionId), ['s7', 's6', 's5', 's4', 's3']);
      expect(moveHistory(repo, move, limit: 2), hasLength(2));
    });

    test('lists the sets in order and picks the heaviest as best', () {
      final repo = _repo(
        [_session('a', '2026-10-01')],
        [
          _flush('a', move, [
            _set(move, 1, kg: 40, reps: 10),
            _set(move, 2, kg: 45, reps: 8),
            _set(move, 3, kg: 45, reps: 9),
          ]),
        ],
      );
      final row = moveHistory(repo, move).single;
      expect(row.dateKey, '2026-10-01');
      expect(row.sets.map((s) => s.reps), [10, 8, 9]);
      expect(row.best!.weightKg, 45);
      expect(row.best!.reps, 9);
    });

    test('a hold has seconds and the longest is best', () {
      final repo = _repo(
        [_session('a', '2026-10-01')],
        [
          _flush('a', 'plank', [
            _set('plank', 1, hold: 30),
            _set('plank', 2, hold: 45),
          ]),
        ],
      );
      expect(moveHistory(repo, 'plank').single.best!.holdSeconds, 45);
    });

    test('a session still under way is left out', () {
      final repo = _repo(
        [_session('live', '2026-10-09', completed: false)],
        [
          _flush('live', move, [_set(move, 1, kg: 50, reps: 5)]),
        ],
      );
      expect(moveHistory(repo, move), isEmpty);
    });

    test('empty for no repository or another move', () {
      expect(moveHistory(null, move), isEmpty);
      expect(moveHistory(_repo([], []), move), isEmpty);
    });
  });

  test('completedSessions: finished only, newest day first', () {
    final repo = _repo([
      _session('old', '2026-09-01'),
      _session('new', '2026-10-02'),
      _session('gone', '2026-10-05', reason: EndedReason.abandoned),
      _session('live', '2026-10-06', completed: false),
    ], []);
    expect(repo.completedSessions().map((s) => s.id), ['new', 'old']);
    expect(repo.completedSessions(limit: 1), hasLength(1));
  });
}
