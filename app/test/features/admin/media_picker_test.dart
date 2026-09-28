// Choosing files at Z10 and Z08 — the two seams, and the honest refusal that is
// the only implementation either of them has today.
//
// `pubspec.yaml` carries no file picker and adding one is not this feature's to
// do, so the point of these tests is **not** that picking works. It is that
// nothing here can pretend it does:
//
//   * an unavailable picker says so before it is tapped, and says why;
//   * it never returns a file;
//   * and what a working picker would return is the vocabulary the console
//     already has — `MediaFile` and CSV text — so wiring a real one is a
//     dependency change rather than a rewrite.
//
// `id_capture.dart` settled this shape for the camera: "no fake that *works*
// exists to be mistaken" for the real thing. The fakes below are declared in
// this file, for one assertion each, and nothing in `lib/` can reach them.

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/admin/domain/content_schema.dart';
import 'package:own_hub/features/admin/domain/csv_parser.dart';
import 'package:own_hub/features/admin/domain/import_validator.dart';
import 'package:own_hub/features/admin/domain/media_bundle.dart';
import 'package:own_hub/features/admin/domain/media_picker.dart';
import 'package:own_hub/features/admin/domain/text_source.dart';

/// A picker that returns files, so the *shape* of a working one can be checked.
/// Deliberately local to this test: see the file note.
class _FakeMediaPicker implements MediaPicker {
  const _FakeMediaPicker(this.files);

  final List<MediaFile> files;

  @override
  bool get isAvailable => true;

  @override
  Future<MediaPickResult> pickMedia() async => MediaPickResult.picked(files);
}

class _FakeTextSource implements TextSource {
  const _FakeTextSource(this.name, this.text);

  final String name;
  final String text;

  @override
  bool get isAvailable => true;

  @override
  Future<TextPickResult> chooseText() async =>
      TextPickResult.picked(ChosenText(name: name, text: text));
}

const String _exerciseHeader =
    'exerciseId,name_en,name_ar,equipment,pattern,contraindicationTags,'
    'quiet,floorOnly,videoFile,thumbFile\n';

void main() {
  group('Z10 — the media picker refuses honestly', () {
    test('it says it is unavailable before anything is tapped', () {
      // Synchronous on purpose: Z10 has to decide what to draw on the first
      // frame. A control that explains itself only after being pressed is the
      // "silently does nothing" button this seam exists to prevent.
      expect(const UnavailableMediaPicker().isAvailable, isFalse);
    });

    test('it carries the reason, and today that reason is the truth', () async {
      final result = await const UnavailableMediaPicker().pickMedia();

      expect(result, isA<MediaPickUnavailable>());
      expect(
        (result as MediaPickUnavailable).reason,
        MediaPickerUnavailableReason.notImplemented,
        reason: 'no file-picker package is in pubspec.yaml',
      );
    });

    test('a different reason survives to the screen', () async {
      // Not every refusal is the same refusal. A denied permission is
      // recoverable and a missing package is not, and a screen that could not
      // tell them apart would offer the wrong way out.
      final result = await const UnavailableMediaPicker(
        reason: MediaPickerUnavailableReason.permissionDenied,
      ).pickMedia();

      expect(
        (result as MediaPickUnavailable).reason,
        MediaPickerUnavailableReason.permissionDenied,
      );
    });

    test('it never returns a file, in any state', () async {
      final result = await const UnavailableMediaPicker().pickMedia();

      expect(result, isNot(isA<MediaPicked>()));
      expect(result, isNot(isA<MediaPickCancelled>()));
    });

    test('nothing chosen and nothing choosable are different answers', () {
      // A cancelled picker is not a defect; an unavailable one is, and it is
      // reported to the owner. Folding them together would hide the gap.
      expect(
        const MediaPickResult.cancelled(),
        isNot(isA<MediaPickUnavailable>()),
      );
    });
  });

  group('what a working picker hands back is what the console reads', () {
    test('a picked file is a MediaFile, not a parallel type', () async {
      // The conversion that does not exist is the one where a name loses its
      // extension and a row stops matching its upload.
      const picker = _FakeMediaPicker([
        MediaFile(name: 'hip_hinge.mp4', bytes: 8400000, kind: MediaKind.video),
        MediaFile(name: 'om_ali.jpg', bytes: 310000, kind: MediaKind.picture),
      ]);

      final result = await picker.pickMedia() as MediaPicked;

      expect(result.files.first, isA<MediaFile>());
      expect(result.bundle, isA<MediaBundle>());
      expect(result.bundle.names, {'hip_hinge.mp4', 'om_ali.jpg'});
      expect(
        result.bundle.ofKind(MediaKind.video).single.name,
        'hip_hinge.mp4',
      );
    });

    test('an upload satisfies the row that names it', () async {
      // The end the whole seam serves: §3.4's "a row naming a file that was
      // never uploaded is a validation failure, not a broken link discovered
      // later by a woman mid-workout".
      const picker = _FakeMediaPicker([
        MediaFile(name: 'hip_hinge.mp4', bytes: 8400000, kind: MediaKind.video),
        MediaFile(name: 'hip_hinge.jpg', bytes: 96000, kind: MediaKind.picture),
      ]);
      final picked = await picker.pickMedia() as MediaPicked;

      final plan = validateImport(
        collection: ContentCollection.exercises,
        table: parseCsv(
          '$_exerciseHeader'
          'hip_hinge,Hip hinge,الدفع بالورك,none,hinge,lower_back,true,false,'
          'hip_hinge.mp4,hip_hinge.jpg\n',
        ),
        uploadedMedia: picked.bundle.names,
        existingIds: const {},
      );

      expect(plan.problems, isEmpty, reason: '${plan.problems}');
      expect(plan.writes.single.value('videoFile'), 'hip_hinge.mp4');
    });

    test('a row naming a file nobody picked still fails', () async {
      // The negative control. Without it the assertion above would pass for a
      // validator that never checked the upload at all.
      const picker = _FakeMediaPicker([
        MediaFile(name: 'hip_hinge.mp4', bytes: 8400000, kind: MediaKind.video),
      ]);
      final picked = await picker.pickMedia() as MediaPicked;

      final plan = validateImport(
        collection: ContentCollection.exercises,
        table: parseCsv(
          '$_exerciseHeader'
          'hip_hinge,Hip hinge,الدفع بالورك,none,hinge,lower_back,true,false,'
          'hip_hinge.mp4,never_filmed.jpg\n',
        ),
        uploadedMedia: picked.bundle.names,
        existingIds: const {},
      );

      expect(
        plan.problems.map((p) => p.code),
        contains(ImportProblemCode.missingMedia),
      );
    });
  });

  group('a picked file can only be named inside the content library', () {
    test('an upload lands under content/', () {
      // `storagePathFor` stays the only way this feature names a location.
      expect(
        storagePathFor(
          collection: ContentCollection.exercises,
          documentId: 'hip_hinge',
          fileName: 'hip_hinge.mp4',
        ),
        'content/exercises/hip_hinge/hip_hinge.mp4',
      );
    });

    test('a file name that tries to climb out is refused', () {
      // A picked name is input — it comes from a device, or from a CSV a person
      // typed — and it is checked like input.
      for (final name in ['../../secrets.env', 'a/b.mp4', '']) {
        expect(
          () => storagePathFor(
            collection: ContentCollection.recipes,
            documentId: 'om_ali',
            fileName: name,
          ),
          throwsArgumentError,
          reason: 'must refuse: $name',
        );
      }
    });

    test('a document id that tries to climb out is refused', () {
      expect(
        () => storagePathFor(
          collection: ContentCollection.recipes,
          documentId: '../exercises',
          fileName: 'om_ali.jpg',
        ),
        throwsArgumentError,
      );
    });
  });

  group('Z08 — the CSV source refuses honestly too', () {
    test('it says it is unavailable, and why', () async {
      expect(const UnavailableTextSource().isAvailable, isFalse);

      final result = await const UnavailableTextSource().chooseText();
      expect(
        (result as TextPickUnavailable).reason,
        TextSourceUnavailableReason.notImplemented,
      );
    });

    test('an unreadable file is its own answer', () async {
      // A spreadsheet saved as .xlsx is not the same problem as a missing
      // package: the way out is to choose a different file, and a screen that
      // could not tell them apart would say the wrong thing.
      final result = await const UnavailableTextSource(
        reason: TextSourceUnavailableReason.unreadable,
      ).chooseText();

      expect(
        (result as TextPickUnavailable).reason,
        TextSourceUnavailableReason.unreadable,
      );
    });

    test('it never returns text', () async {
      expect(
        await const UnavailableTextSource().chooseText(),
        isNot(isA<TextPicked>()),
      );
    });

    test('what a working source returns is what parseCsv reads', () async {
      // The seam speaks the importer's language: a chosen file goes straight to
      // `parseCsv` and then to the dry run, with nothing in between to lose a
      // byte order mark or a quoted comma.
      const source = _FakeTextSource(
        'recipes.csv',
        // Widened with the recipe contract. The seam being proved is that a
        // chosen file reaches `parseCsv` byte for byte, which is why the row is
        // a whole valid row rather than a fragment.
        'recipeId,name_en,name_ar,minutes,ingredients,allergens,dietTags,photoFile,sectionId,source,status,sourcePage,authoredBy,allergenReviewedBy,serves,activeMinutes,kcal,proteinG,carbsG,fatG,macroBasis,egpPerServing,egpPricedAt,advisories,doneness,markKey,tier\n'
            'om_ali,Om Ali,أم علي,45,"pastry|milk|nuts",nuts|dairy,vegetarian,,,authored,review,,,,,,,,,,withheld,,,none,,pot,free\n',
      );

      final result = await source.chooseText() as TextPicked;
      expect(result.file.name, 'recipes.csv');

      final plan = validateImport(
        collection: ContentCollection.recipes,
        table: parseCsv(result.file.text),
        uploadedMedia: const {},
        existingIds: const {},
      );

      expect(plan.problems, isEmpty, reason: '${plan.problems}');
      expect(plan.writes.single.documentId, 'om_ali');
      expect(plan.writes.single.list('allergens'), ['nuts', 'dairy']);
    });
  });
}
