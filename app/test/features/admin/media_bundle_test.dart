// Z10 — the media upload, and the storage paths it writes to.
//
// G16 §4: videos and pictures go to Cloud Storage, never to Firestore, under
// `content/{collection}/{docId}/{file}` with admin write and signed-in read.
// The paths are built here rather than on a screen, so no widget is in a
// position to invent one.

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/admin/domain/content_schema.dart';
import 'package:own_hub/features/admin/domain/media_bundle.dart';

MediaFile _video(String name) =>
    MediaFile(name: name, bytes: 12 * 1024 * 1024, kind: MediaKind.video);

MediaFile _picture(String name) =>
    MediaFile(name: name, bytes: 240 * 1024, kind: MediaKind.picture);

void main() {
  group('what is in the bundle', () {
    test('names are what a CSV row is matched against', () {
      final bundle = MediaBundle([
        _video('goblet_squat.mp4'),
        _picture('koshari.jpg'),
      ]);

      expect(bundle.names, {'goblet_squat.mp4', 'koshari.jpg'});
    });

    test('an empty bundle has no names and is not an error', () {
      expect(const MediaBundle([]).names, isEmpty);
    });

    test('a file is matched by exact name, including its extension', () {
      // `goblet_squat` and `goblet_squat.mp4` are different files. Matching on
      // a stem would link a row to whichever of the two happened to sort first.
      final bundle = MediaBundle([_video('goblet_squat.mp4')]);

      expect(bundle.contains('goblet_squat.mp4'), isTrue);
      expect(bundle.contains('goblet_squat'), isFalse);
      expect(bundle.contains('goblet_squat.MP4'), isFalse);
    });
  });

  group('unlinked files lead the list', () {
    // Z10's note: "The list leads with files linked to nothing, because those
    // are the ones that will break a row at validation."
    test('a file no row names is unlinked', () {
      final bundle = MediaBundle([
        _video('goblet_squat.mp4'),
        _picture('koshari.jpg'),
      ]);

      final unlinked = bundle.unlinked(const {'goblet_squat.mp4'});

      expect(unlinked.map((f) => f.name), ['koshari.jpg']);
    });

    test('everything is unlinked when no row names anything', () {
      final bundle = MediaBundle([_video('a.mp4'), _picture('b.jpg')]);
      expect(bundle.unlinked(const {}), hasLength(2));
    });

    test('a referenced name that is not in the bundle does not appear', () {
      // It is a validation failure on the CSV side, not a file in the upload.
      // Reporting it here as well would show her a file that does not exist.
      final bundle = MediaBundle([_video('a.mp4')]);

      expect(bundle.unlinked(const {'a.mp4', 'never_uploaded.mp4'}), isEmpty);
    });
  });

  group('storage paths, per §4', () {
    test('an exercise video lands under its own exercise id', () {
      expect(
        storagePathFor(
          collection: ContentCollection.exercises,
          documentId: 'goblet_squat',
          fileName: 'goblet_squat.mp4',
        ),
        'content/exercises/goblet_squat/goblet_squat.mp4',
      );
    });

    test('a recipe photo lands under its recipe id', () {
      expect(
        storagePathFor(
          collection: ContentCollection.recipes,
          documentId: 'lentil_soup',
          fileName: 'lentil_soup.jpg',
        ),
        'content/recipes/lentil_soup/lentil_soup.jpg',
      );
    });

    test('a programme uses the collection name the file uses', () {
      // `programs`, matching programs.csv and the paths in §4 — not
      // `programmes`, which is only how the word is spelled on screen.
      expect(
        storagePathFor(
          collection: ContentCollection.programmes,
          documentId: 'beginner_foundations',
          fileName: 'cover.jpg',
        ),
        'content/programs/beginner_foundations/cover.jpg',
      );
    });

    test('every path this console can build begins with content/', () {
      // §5: "No export path may reach users/**." The same is true of uploads,
      // and the cheapest way to keep it true is for the only path-building
      // function in the feature to be incapable of producing anything else.
      for (final collection in ContentCollection.values) {
        final path = storagePathFor(
          collection: collection,
          documentId: 'x',
          fileName: 'y.jpg',
        );
        expect(path, startsWith('content/'));
        expect(path, isNot(contains('users/')));
      }
    });

    test('a document id that tries to climb out of content/ is refused', () {
      // `../../users/uid` in an id column would otherwise build a path outside
      // the content tree. The id comes from a CSV that a person typed, so it is
      // input, and it is checked like input.
      expect(
        () => storagePathFor(
          collection: ContentCollection.recipes,
          documentId: '../../users/someone',
          fileName: 'photo.jpg',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('a file name containing a slash is refused', () {
      expect(
        () => storagePathFor(
          collection: ContentCollection.recipes,
          documentId: 'soup',
          fileName: 'nested/photo.jpg',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('an empty id or file name is refused', () {
      expect(
        () => storagePathFor(
          collection: ContentCollection.foods,
          documentId: '',
          fileName: 'a.jpg',
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => storagePathFor(
          collection: ContentCollection.foods,
          documentId: 'a',
          fileName: '',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('kinds', () {
    test('videos and pictures are counted separately', () {
      final bundle = MediaBundle([
        _video('a.mp4'),
        _video('b.mp4'),
        _picture('c.jpg'),
      ]);

      expect(bundle.ofKind(MediaKind.video), hasLength(2));
      expect(bundle.ofKind(MediaKind.picture), hasLength(1));
    });
  });
}
