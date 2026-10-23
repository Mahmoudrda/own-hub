// D42: the exercise library's catalogue, as the phone reads it. A bad row is
// dropped, not the library; safety tags fail closed; every muscle has a
// heading; pregnancy and the weeks after a birth hide the floor-tagged moves.

import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/domain/safety/contraindication_tag.dart';
import 'package:own_hub/features/onboarding/domain/intake.dart';
import 'package:own_hub/features/train/domain/exercise_library.dart';

import '../../helpers/exercise_library_fixture.dart';

void main() {
  group('a row', () {
    test('a good row is read, paths built under content/exercises', () {
      final e = LibraryExercise.tryParse(
        exerciseRow(
          'lat_pulldown_wide',
          primary: ['lats'],
          clips: 2,
          place: 'gym',
        ),
      )!;
      expect(
        e.clips.first.media.path,
        'content/exercises/lat_pulldown_wide/lat_pulldown_wide_front_aaaa1111.mp4',
      );
      expect(e.clips.last.angle, ClipAngle.side);
      expect(e.poster.bytes, 100);
      expect(e.place, ExercisePlace.gym);
      expect(e.section, MuscleSection.upperBack);
    });

    final bad = <String, Map<String, Object?>>{
      'no tags': exerciseRow('a', tags: const []),
      'an unknown tag': exerciseRow('a', tags: const ['bad_knees']),
      'none beside a tag': exerciseRow(
        'a',
        tags: const ['none', 'supine_load'],
      ),
      'an unknown muscle': exerciseRow('a', primary: const ['traps']),
      'no primary muscle': exerciseRow('a', primary: const []),
      'a muscle both primary and secondary': exerciseRow(
        'a',
        secondary: const ['glutes'],
      ),
      'none beside equipment': exerciseRow(
        'a',
        equipment: const ['none', 'mat'],
      ),
      'a stretch that is not mobility': exerciseRow(
        'a',
        kind: 'stretch',
        pattern: 'squat',
      ),
      'an unknown place': exerciseRow('a', place: 'home'),
      'a path in a file name': {
        ...exerciseRow('a'),
        'clips': [
          {'file': '../a.mp4', 'angle': 'front', 'bytes': 10, 'seconds': 2},
        ],
      },
      'three clips': {
        ...exerciseRow('a'),
        'clips': [
          for (final angle in ['front', 'side', 'rear'])
            {'file': 'a_$angle.mp4', 'angle': angle, 'bytes': 10, 'seconds': 2},
        ],
      },
      'two clips from one angle': {
        ...exerciseRow('a'),
        'clips': [
          {'file': 'a_1.mp4', 'angle': 'front', 'bytes': 10, 'seconds': 2},
          {'file': 'a_2.mp4', 'angle': 'front', 'bytes': 10, 'seconds': 2},
        ],
      },
      'a clip over the size limit': {
        ...exerciseRow('a'),
        'clips': [
          {
            'file': 'a.mp4',
            'angle': 'front',
            'bytes': kMaxClipBytes + 1,
            'seconds': 2,
          },
        ],
      },
      'a poster that is not webp': {
        ...exerciseRow('a'),
        'poster': {'file': 'a.jpg', 'bytes': 10},
      },
      'setup in one language only': {
        ...exerciseRow('a'),
        'setupEn': 'Feet flat.',
      },
      'no Arabic name': {...exerciseRow('a'), 'nameAr': ''},
      'quiet that is not a boolean': {...exerciseRow('a'), 'quiet': 'yes'},
      'a bad id': exerciseRow('Glute Bridge'),
    };
    for (final MapEntry(key: why, value: row) in bad.entries) {
      test(
        'refused: $why',
        () => expect(LibraryExercise.tryParse(row), isNull),
      );
    }
  });

  group('the library', () {
    test('one bad row is dropped and the rest are kept', () {
      final library = ExerciseLibrary.parse({
        'version': 2,
        'exercises': [
          exerciseRow('good_one'),
          exerciseRow('bad_one', tags: const []),
          exerciseRow('good_two'),
          exerciseRow('good_one'),
        ],
      })!;
      expect(
        [for (final e in library.exercises) e.id],
        ['good_one', 'good_two'],
      );
    });

    test('no version, or nothing it can show, is no library', () {
      expect(
        ExerciseLibrary.parse({
          'exercises': [exerciseRow('a')],
        }),
        isNull,
      );
      expect(
        ExerciseLibrary.parse({
          'version': 0,
          'exercises': [exerciseRow('a')],
        }),
        isNull,
      );
      expect(
        ExerciseLibrary.parse({
          'version': 2,
          'exercises': [exerciseRow('a', tags: const [])],
        }),
        isNull,
      );
    });

    test('it survives its own cache', () {
      final library = sampleExerciseLibrary();
      final again = ExerciseLibrary.parse(library.toJson())!;
      expect(again.version, library.version);
      expect(
        [for (final e in again.exercises) e.id],
        [for (final e in library.exercises) e.id],
      );
      expect(again.byId('lat_pulldown_wide')!.clips, hasLength(2));
      expect(again.mediaPaths, library.mediaPaths);
    });

    test('names in both languages, and search over both', () {
      final e = sampleExerciseLibrary().byId('glute_bridge')!;
      expect(e.name('ar'), 'Glute bridge');
      expect(e.name('en'), 'Glute bridge');
      expect(e.matches('bridge'), isTrue);
      expect(e.matches('جلوت'), isTrue);
      expect(e.matches('squat'), isFalse);
    });
  });

  test('every muscle has a heading, and headings come in reading order', () {
    for (final muscle in Muscle.values) {
      expect(() => sectionOf(muscle), returnsNormally);
    }
    expect(sectionOf(Muscle.lats), MuscleSection.upperBack);
    expect(sectionOf(Muscle.rearDelts), MuscleSection.shoulders);
    expect(MuscleSection.values.first, MuscleSection.glutes);
    expect(MuscleSection.values.last, MuscleSection.arms);
  });

  group('her life stage', () {
    final all = sampleExerciseLibrary().exercises;

    test('pregnant: every move with a floor tag is hidden, and only those', () {
      final screened = screenForLifeStage(all, LifeStage.pregnant);
      expect(screened.someHidden, isTrue);
      expect([
        for (final e in screened.shown) e.id,
      ], isNot(contains('glute_bridge')));
      expect(screened.shown, hasLength(all.length - 1));
      for (final e in screened.shown) {
        expect(e.tags.contains(ContraindicationTag.supineLoad), isFalse);
      }
    });

    test('after a birth: the same, read as the first six weeks', () {
      final screened = screenForLifeStage(all, LifeStage.postpartum);
      expect(screened.someHidden, isTrue);
      expect(screened.shown, hasLength(all.length - 1));
    });

    test('nothing to train around, pain, or no answer: nothing hidden', () {
      for (final stage in [LifeStage.none, LifeStage.painInjury, null]) {
        final screened = screenForLifeStage(all, stage);
        expect(screened.someHidden, isFalse, reason: '$stage');
        expect(screened.shown, hasLength(all.length));
      }
    });
  });
}
