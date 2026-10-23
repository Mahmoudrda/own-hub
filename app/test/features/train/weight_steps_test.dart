// Weight steps that fit the kit: the ladder per equipment, the starter
// weights and the chips R08 offers.

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/training/prescribed_set.dart';
import 'package:own_hub/features/train/domain/exercise_library.dart';
import 'package:own_hub/features/train/domain/load_advice.dart';
import 'package:own_hub/features/train/presentation/change_set_view.dart';
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
  const barbell = [LibraryEquipment.barbell, LibraryEquipment.bench];
  const machine = [LibraryEquipment.machine];
  const dumbbells = [LibraryEquipment.dumbbells];

  group('ladders', () {
    test('a barbell goes 20 to 150 by 2.5', () {
      final ladder = loadLadderFor(barbell);
      expect(ladder.first, 20);
      expect(ladder.last, 150);
      expect(ladder[1], 22.5);
      expect(ladder.length, 53);
      expect(loadLadderFor(const [LibraryEquipment.smithMachine]), ladder);
    });

    test('a machine or cable goes 2.5 by 2.5, then by 5 from 25', () {
      final ladder = loadLadderFor(machine);
      expect(ladder.first, 2.5);
      expect(ladder.sublist(0, 8), [2.5, 5, 7.5, 10, 12.5, 15, 17.5, 20]);
      expect(ladder[8], 25);
      expect(ladder[9], 30);
      expect(ladder.last, 150);
      expect(loadLadderFor(const [LibraryEquipment.cable]), ladder);
    });

    test('dumbbells and kettlebells go 1 to 10, then 12.5 to 50 by 2.5', () {
      final ladder = loadLadderFor(dumbbells);
      expect(ladder.sublist(0, 10), [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
      expect(ladder[10], 12.5);
      expect(ladder.last, 50);
      expect(loadLadderFor(const [LibraryEquipment.kettlebell]), ladder);
    });

    test('unknown equipment keeps the shared ladder, now to 100', () {
      expect(loadLadderFor(null), kLoadStepsKg);
      expect(kLoadStepsKg.first, 2);
      expect(kLoadStepsKg.last, 100);
      expect(kLoadStepsKg, contains(60));
    });

    test('a bar wins over a bench, a stack over a dumbbell', () {
      expect(loadKitFor(barbell), LoadKit.barbell);
      expect(
        loadKitFor(const [
          LibraryEquipment.dumbbells,
          LibraryEquipment.machine,
        ]),
        LoadKit.machine,
      );
      expect(loadKitFor(const [LibraryEquipment.mat]), LoadKit.unknown);
    });
  });

  group('starter weights', () {
    test('barbell 20 to 40, machine 10 to 40, dumbbells as before', () {
      expect(starterWeightsFor(barbell), [20, 25, 30, 35, 40]);
      expect(starterWeightsFor(machine), [10, 15, 20, 25, 30, 40]);
      expect(starterWeightsFor(dumbbells), kStarterWeightsKg);
      expect(starterWeightsFor(null), kStarterWeightsKg);
    });
  });

  group('past 60 kg the suggestion moves up', () {
    test('leg press at 80 kg goes to 85', () async {
      final advice = loadAdviceFor(
        await _history([10, 10, 10], 80),
        _move(),
        now: soon,
        equipment: machine,
      );
      expect(advice?.decision.action, 'increase');
      expect(advice?.decision.suggestedWeightKg, 85);
      expect(advice?.optionsKg, [75, 80, 85]);
    });

    test('hip thrust at 100 kg goes to 102.5 on a barbell', () async {
      final advice = loadAdviceFor(
        await _history([10, 10, 10], 100),
        _move(),
        now: soon,
        equipment: barbell,
      );
      expect(advice?.decision.suggestedWeightKg, 102.5);
    });

    test('with no equipment named it still moves past 60', () async {
      final advice = loadAdviceFor(
        await _history([10, 10, 10], 80),
        _move(),
        now: soon,
      );
      expect(advice?.decision.suggestedWeightKg, 85);
    });

    test('dumbbells step by what the rack holds', () async {
      final advice = loadAdviceFor(
        await _history([10, 10, 10], 7),
        _move(),
        now: soon,
        equipment: dumbbells,
      );
      expect(advice?.decision.suggestedWeightKg, 8);
    });
  });

  group('the chips on R08', () {
    const set = PrescribedSet(
      exerciseId: 'row',
      order: 1,
      weightKg: 80,
      reps: 8,
    );

    test('without equipment they keep the fixed 2 kg step', () {
      expect(weightOptionsAround(set), [78, 80, 82]);
    });

    test('a barbell chips by 2.5 kg', () {
      expect(weightOptionsAround(set, equipment: barbell), [77.5, 80, 82.5]);
    });

    test('a machine chips by 5 kg up there and 2.5 down low', () {
      expect(weightOptionsAround(set, equipment: machine), [75, 80, 85]);
      const low = PrescribedSet(exerciseId: 'row', order: 1, weightKg: 15);
      expect(weightOptionsAround(low, equipment: machine), [12.5, 15, 17.5]);
    });

    test('dumbbells chip by 1 kg low down', () {
      const light = PrescribedSet(exerciseId: 'row', order: 1, weightKg: 6);
      expect(weightOptionsAround(light, equipment: dumbbells), [5, 6, 7]);
    });

    test('a planned weight off the ladder is kept among the chips', () {
      const odd = PrescribedSet(exerciseId: 'row', order: 1, weightKg: 81);
      expect(weightOptionsAround(odd, equipment: barbell), [80, 81, 82.5]);
    });
  });
}
