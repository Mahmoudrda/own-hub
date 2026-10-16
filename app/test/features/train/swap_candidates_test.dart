// R05's candidates come from the exercise library: the same heading as the
// move she is on, where she trains and with what she has, never the move
// itself, and nothing the life-stage screen holds back.

import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/features/onboarding/domain/intake.dart';
import 'package:own_hub/features/train/domain/exercise_library.dart';

import '../../helpers/exercise_library_fixture.dart';

void main() {
  final library = ExerciseLibrary.parse({
    'version': 1,
    'schema': 1,
    'exercises': [
      exerciseRow(
        'hip_thrust',
        pattern: 'hip_thrust_bridge',
        equipment: ['bench'],
      ),
      exerciseRow(
        'glute_bridge',
        pattern: 'hip_thrust_bridge',
        equipment: ['mat'],
        tags: ['supine_load'],
      ),
      exerciseRow(
        'band_kickback',
        pattern: 'isolation_lower',
        equipment: ['bands'],
      ),
      exerciseRow(
        'cable_kickback',
        pattern: 'isolation_lower',
        equipment: ['cable'],
        place: 'gym',
      ),
      exerciseRow('glute_stretch', kind: 'stretch', equipment: ['none']),
      exerciseRow('goblet_squat', primary: ['quads'], equipment: ['dumbbells']),
    ],
  })!;
  List<String> ids(
    String of, {
    TrainingPlace place = TrainingPlace.home,
    Set<Equipment> equipment = const {Equipment.none},
    LifeStage? stage,
  }) => [
    for (final e in swapCandidatesFor(
      screenForLifeStage(library.exercises, stage).shown,
      library.byId(of)!,
      place: place,
      equipment: equipment,
    ))
      e.id,
  ];

  test('same heading, never itself, never a stretch', () {
    final out = ids('hip_thrust', place: TrainingPlace.ladiesGym);
    expect(out, ['glute_bridge', 'band_kickback', 'cable_kickback']);
  });

  test('at home only what she has, and nothing gym-only', () {
    expect(ids('hip_thrust', equipment: {Equipment.mat}), ['glute_bridge']);
    expect(ids('hip_thrust', equipment: {Equipment.mat, Equipment.bands}), [
      'glute_bridge',
      'band_kickback',
    ]);
  });

  test('the life-stage screen still applies', () {
    expect(
      ids(
        'hip_thrust',
        place: TrainingPlace.ladiesGym,
        stage: LifeStage.pregnant,
      ),
      isNot(contains('glute_bridge')),
    );
  });

  test('a heading of one has no swap', () {
    expect(ids('goblet_squat', place: TrainingPlace.ladiesGym), isEmpty);
  });
}
