// The phone and the publish tool read one contract
// (contracts/exercise_library_contract.json). This holds the Dart side to it;
// functions/tests/test_publish_exercise_library.py holds the Python side.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/domain/safety/contraindication_tag.dart';
import 'package:own_hub/features/train/domain/exercise_library.dart';

Map<String, Object?> _json(String path) =>
    (jsonDecode(File(path).readAsStringSync()) as Map).cast<String, Object?>();

void main() {
  final contract = _json('../contracts/exercise_library_contract.json');
  List<String> list(String key) => (contract[key]! as List).cast<String>();

  test('the vocabularies are the ones this build knows', () {
    expect(list('muscles'), [for (final m in Muscle.values) m.wireName]);
    expect(list('equipment').toSet(), {
      for (final e in LibraryEquipment.values) e.wireName,
    });
    expect(list('kinds'), [for (final k in ExerciseKind.values) k.wireName]);
    expect(list('places'), [for (final p in ExercisePlace.values) p.wireName]);
    expect(list('levels'), [for (final l in ExerciseLevel.values) l.wireName]);
    expect(list('angles'), [for (final a in ClipAngle.values) a.wireName]);
    expect(list('bodyRegions').toSet(), kBodyRegions);
    expect(list('patterns').toSet(), kExercisePatterns);
    expect(
      list('contraindicationTags').toSet(),
      ContraindicationTag.wireVocabulary,
    );
  });

  test('the limits and paths are the same on both sides', () {
    final limits = (contract['limits']! as Map).cast<String, Object?>();
    expect(limits['maxClipBytes'], kMaxClipBytes);
    expect(limits['maxPosterBytes'], kMaxPosterBytes);
    expect(limits['maxTextChars'], kMaxExerciseText);
    expect(limits['maxClips'], 2);
    expect(contract['storagePrefix'], kExerciseMediaPrefix);
    expect(contract['schema'], kExerciseLibrarySchema);
    expect(contract['versionPath'], 'meta/exercises');
    expect(contract['libraryPath'], 'meta/exerciseLibrary');
  });

  test('the sample library is read whole', () {
    final sample = _json('../contracts/exercise_library_sample.json');
    final library = ExerciseLibrary.parse(sample)!;
    expect(library.exercises, hasLength((sample['exercises']! as List).length));
  });

  test('the reviewed catalogue the owner publishes is read whole too', () {
    // The catalogue holds the console's column names; the publish tool turns
    // each row into the member row this build reads. The same rule applies to
    // both: every row must survive.
    final file = File('../6-v2/content/exercise_library/catalogue.json');
    expect(
      file.existsSync(),
      isTrue,
      reason: 'the catalogue the owner publishes',
    );
    final catalogue = _json(file.path);
    final rows = [
      for (final r
          in (catalogue['exercises']! as List).cast<Map<String, Object?>>())
        {
          'id': r['exerciseId'],
          'nameEn': r['name_en'],
          'nameAr': r['name_ar'],
          'kind': r['kind'],
          'primaryMuscles': r['primaryMuscles'],
          'secondaryMuscles': r['secondaryMuscles'],
          'bodyRegion': r['bodyRegion'],
          'pattern': r['pattern'],
          'equipment': r['equipment'],
          'place': r['place'],
          'level': r['level'],
          'quiet': r['quiet'],
          'floorOnly': r['floorOnly'],
          'tags': r['contraindicationTags'],
          'clips': [
            for (final c in (r['clips']! as List).cast<Map<String, Object?>>())
              {
                'file': c['file'],
                'angle': c['angle'],
                'bytes': 1,
                'seconds': c['seconds'],
              },
          ],
          'poster': {'file': (r['poster'] as Map)['file'], 'bytes': 1},
        },
    ];
    final library = ExerciseLibrary.parse({'version': 1, 'exercises': rows})!;
    expect(library.exercises, hasLength(rows.length));
  });
}
