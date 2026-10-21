// The weight R07 and R08 suggest for a loaded move, from her own history.
//
// It is a suggestion: nothing here may prefill an outcome or invent history.

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/training/prescribed_set.dart';
import 'package:own_hub/features/train/domain/load_advice.dart';
import 'package:own_hub/features/train/domain/train_repository.dart';

PlannedMove _move({bool loaded = true, int sets = 3, int reps = 10}) =>
    PlannedMove(
      exerciseId: 'row',
      name: 'Row',
      prescriptionLabel: '$sets × $reps',
      needsEquipment: loaded,
      sets: [
        for (var i = 1; i <= sets; i++)
          PrescribedSet(exerciseId: 'row', order: i, reps: reps),
      ],
    );

/// A session of [day] in which she logged [reps] at [kg].
Future<InMemoryTrainRepository> _history(
  List<int> reps,
  double? kg, {
  String day = '2026-10-01',
}) async {
  final repository = InMemoryTrainRepository();
  final session = await repository.startSession(
    WorkoutDay(
      id: day,
      title: 'Upper',
      summary: '',
      constraints: '',
      moves: [_move()],
    ),
  );
  await repository.flushMove(
    sessionId: session.id,
    exerciseId: 'row',
    sets: [
      for (var i = 0; i < reps.length; i++)
        LoggedSet(
          prescribed: PrescribedSet(exerciseId: 'row', order: i + 1),
        ).recording(SetOutcome(weightKg: kg, reps: reps[i])),
    ],
  );
  return repository;
}

void main() {
  final soon = DateTime(2026, 10, 3);

  test('no history means no advice and nothing invented', () {
    expect(
      loadAdviceFor(InMemoryTrainRepository(), _move(), now: soon),
      isNull,
    );
  });

  test('a bodyweight move has none', () async {
    final repository = await _history([10, 10, 10], 10);
    expect(loadAdviceFor(repository, _move(loaded: false), now: soon), isNull);
  });

  test(
    'every set finished goes up one step and offers the step below',
    () async {
      final repository = await _history([10, 10, 10], 10);
      final advice = loadAdviceFor(repository, _move(), now: soon)!;
      expect(advice.decision.action, 'increase');
      expect(advice.lastWeightKg, 10);
      expect(advice.startKg, 12);
      expect(advice.optionsKg, [8, 10, 12]);
    },
  );

  test('a short set holds the weight', () async {
    final repository = await _history([10, 9, 10], 10);
    final advice = loadAdviceFor(repository, _move(), now: soon)!;
    expect(advice.decision.action, 'hold');
    expect(advice.startKg, 10);
  });

  test(
    'a hard stretch holds the weight even when every set was finished',
    () async {
      final repository = await _history([10, 10, 10], 10);
      final advice = loadAdviceFor(
        repository,
        _move(),
        difficult: true,
        now: soon,
      )!;
      expect(advice.decision.action, 'hold');
      expect(advice.startKg, 10);
      expect(advice.optionsKg, [8, 10]);
    },
  );

  test('a history with no weight in it gives none', () async {
    final repository = await _history([10, 10, 10], null);
    expect(loadAdviceFor(repository, _move(), now: soon), isNull);
  });

  test('three weeks away asks for a lighter start', () async {
    final repository = await _history([10, 10, 10], 10);
    final advice = loadAdviceFor(
      repository,
      _move(),
      now: DateTime(2026, 10, 25),
    )!;
    expect(advice.decision.action, 'review');
    expect(advice.startKg, 8);
  });

  test('the live session is not its own history', () async {
    final repository = await _history([10, 10, 10], 10);
    final live = repository.sessions.single.id;
    expect(
      loadAdviceFor(repository, _move(), exceptSessionId: live, now: soon),
      isNull,
    );
  });

  test(
    'the suggested weight is carried on the sets and named in the label',
    () {
      final move = withSuggestedWeight(_move(), 12, '12 kg');
      expect(move.prescriptionLabel, '12 kg · 3 × 10');
      expect(move.sets.map((s) => s.weightKg), [12, 12, 12]);
    },
  );
}
