// Z11 — the export. "Content only. Never her."
//
// G16 §5 and DECISIONS.md D12 both put this in the strongest terms in either
// document: "No export path may reach `users/**`, cycle data, check-ins,
// measurements, progress photos, meal or session logs, phone numbers, names, or
// verification results."
//
// §5 also says how that is to be enforced: "A test asserts the export manifest
// contains no `users/` path, in the same spirit as the guard that makes a daily
// streak unstorable: **the rule is enforced by the code being unable to express
// the violation**, not by remembering."
//
// So there are two kinds of test here. The ones that check a manifest is right,
// and the ones that check a wrong manifest cannot be built at all.

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/admin/domain/content_schema.dart';
import 'package:own_hub/features/admin/domain/csv_parser.dart';
import 'package:own_hub/features/admin/domain/export_manifest.dart';
import 'package:own_hub/features/admin/domain/import_validator.dart';

/// Rows for [collection], read back through the importer so the round-trip
/// test below is using the same shape the library stores.
List<ImportRow> _rows(ContentCollection collection, String csv) {
  final plan = validateImport(
    collection: collection,
    table: parseCsv(csv),
    uploadedMedia: const {'goblet_squat.mp4', 'goblet_squat.jpg'},
    existingIds: const {},
  );
  expect(plan.problems, isEmpty, reason: 'fixture must be valid: $csv');
  return plan.writes;
}

const String _exercisesCsv =
    'exerciseId,name_en,name_ar,equipment,pattern,contraindicationTags,quiet,floorOnly,videoFile,thumbFile\n'
    'goblet_squat,Goblet squat,G,dumbbell,squat,none,true,false,goblet_squat.mp4,goblet_squat.jpg\n';

const String _foodsCsv =
    'foodId,name_en,name_ar,portions,kcal,proteinG,carbsG,fatG,allergens,dietTags\n'
    'koshari,Koshari,K,plate,430,13,78,7,gluten,vegetarian\n';

void main() {
  group('what an export contains', () {
    test('one CSV per chosen collection', () {
      final manifest = buildExportManifest({
        ContentCollection.exercises: _rows(
          ContentCollection.exercises,
          _exercisesCsv,
        ),
        ContentCollection.foods: _rows(ContentCollection.foods, _foodsCsv),
      });

      expect(manifest.csvPaths, ['exercises.csv', 'foods.csv']);
    });

    test('the media those rows reference, and nothing else', () {
      final manifest = buildExportManifest({
        ContentCollection.exercises: _rows(
          ContentCollection.exercises,
          _exercisesCsv,
        ),
      });

      expect(manifest.mediaPaths, [
        'content/exercises/goblet_squat/goblet_squat.mp4',
        'content/exercises/goblet_squat/goblet_squat.jpg',
      ]);
    });

    test('a collection with no media contributes no media paths', () {
      final manifest = buildExportManifest({
        ContentCollection.foods: _rows(ContentCollection.foods, _foodsCsv),
      });

      expect(manifest.csvPaths, ['foods.csv']);
      expect(manifest.mediaPaths, isEmpty);
    });

    test('choosing nothing produces an empty manifest, not an error', () {
      final manifest = buildExportManifest(const {});

      expect(manifest.csvPaths, isEmpty);
      expect(manifest.mediaPaths, isEmpty);
      expect(manifest.isEmpty, isTrue);
    });

    test('a row naming no media adds no path', () {
      final manifest = buildExportManifest({
        ContentCollection.exercises: _rows(
          ContentCollection.exercises,
          'exerciseId,name_en,name_ar,equipment,pattern,contraindicationTags,quiet,floorOnly,videoFile,thumbFile\n'
          'a,A,A,none,squat,none,true,false,,\n',
        ),
      });

      expect(manifest.mediaPaths, isEmpty);
    });
  });

  group('the round trip §5 promises', () {
    test('an exported CSV re-imports to the same rows', () {
      // "One CSV per collection, in exactly the import schema — so an export can
      // be edited and re-imported." If the writer and the reader disagree about
      // quoting or column order, that sentence is false and nobody finds out
      // until an admin has edited a file that will not load.
      final original = _rows(ContentCollection.foods, _foodsCsv);
      final written = writeCsv(ContentCollection.foods, original);

      final reread = validateImport(
        collection: ContentCollection.foods,
        table: parseCsv(written),
        uploadedMedia: const {},
        existingIds: const {},
      );

      expect(reread.problems, isEmpty);
      expect(reread.writes.single.id, original.single.id);
      expect(
        reread.writes.single.value('allergens'),
        original.single.value('allergens'),
      );
      expect(reread.writes.single.number('kcal'), 430);
    });

    test('a value containing a comma survives the round trip quoted', () {
      // RFC 4180 rule 6: a field containing a comma is enclosed in double
      // quotes. `portions` routinely holds "plate, half plate" once somebody
      // types it that way.
      final rows = _rows(
        ContentCollection.foods,
        'foodId,name_en,name_ar,portions,kcal,proteinG,carbsG,fatG,allergens,dietTags\n'
        'k,"Koshari, small",K,plate,430,13,78,7,gluten,vegetarian\n',
      );

      final written = writeCsv(ContentCollection.foods, rows);
      expect(written, contains('"Koshari, small"'));

      final reread = validateImport(
        collection: ContentCollection.foods,
        table: parseCsv(written),
        uploadedMedia: const {},
        existingIds: const {},
      );

      expect(reread.problems, isEmpty);
      expect(reread.writes.single.value('name_en'), 'Koshari, small');
    });

    test('a value containing a quote survives, doubled per rule 7', () {
      final rows = _rows(
        ContentCollection.foods,
        'foodId,name_en,name_ar,portions,kcal,proteinG,carbsG,fatG,allergens,dietTags\n'
        'k,"say ""hi""",K,plate,430,13,78,7,gluten,vegetarian\n',
      );

      final written = writeCsv(ContentCollection.foods, rows);
      final reread = parseCsv(written);

      expect(reread.rows.single.values[1], 'say "hi"');
    });

    test('the written header is exactly the schema, in order', () {
      final written = writeCsv(
        ContentCollection.foods,
        _rows(ContentCollection.foods, _foodsCsv),
      );

      expect(
        written.split('\n').first,
        ContentSchema.of(ContentCollection.foods).columnNames.join(','),
      );
    });

    test('the Excel signature can be written, and re-imports cleanly', () {
      // The Unicode FAQ (https://www.unicode.org/faq/utf_bom.html) calls the
      // UTF-8 BOM a signature — "an indication that an otherwise unmarked text
      // file is in UTF-8". Excel needs it: without it, a double-clicked CSV is
      // read in the system codepage and every `name_ar` opens as mojibake,
      // which is how an exported Arabic library comes back ruined after
      // somebody edits it in the one program staff actually have.
      //
      // It costs nothing on the way back in, because parseCsv strips a leading
      // U+FEFF — so §5's round trip survives it.
      final written = writeCsv(
        ContentCollection.foods,
        _rows(ContentCollection.foods, _foodsCsv),
        byteOrderMark: true,
      );

      expect(written.codeUnitAt(0), 0xFEFF);

      final reread = validateImport(
        collection: ContentCollection.foods,
        table: parseCsv(written),
        uploadedMedia: const {},
        existingIds: const {},
      );

      expect(reread.problems, isEmpty);
      expect(reread.writes.single.id, 'koshari');
    });

    test('it is off by default, so a plain export carries no signature', () {
      final written = writeCsv(
        ContentCollection.foods,
        _rows(ContentCollection.foods, _foodsCsv),
      );

      expect(written.codeUnitAt(0), isNot(0xFEFF));
    });

    test('Arabic content is written through unchanged', () {
      // The library is bilingual content (§3.3). An exporter that mangled
      // `name_ar` would quietly empty the Arabic half of the product.
      final rows = _rows(
        ContentCollection.foods,
        'foodId,name_en,name_ar,portions,kcal,proteinG,carbsG,fatG,allergens,dietTags\n'
        'k,Koshari,كشري,plate,430,13,78,7,gluten,vegetarian\n',
      );

      final written = writeCsv(ContentCollection.foods, rows);
      expect(written, contains('كشري'));
    });
  });

  group('it never contains her — §5, and the reason it is a test', () {
    test('no path in a manifest mentions users/', () {
      final manifest = buildExportManifest({
        for (final c in [ContentCollection.exercises, ContentCollection.foods])
          c: _rows(
            c,
            c == ContentCollection.exercises ? _exercisesCsv : _foodsCsv,
          ),
      });

      for (final path in manifest.allPaths) {
        expect(path, isNot(contains('users/')));
      }
    });

    test('every path is under content/ or is a bare CSV file name', () {
      final manifest = buildExportManifest({
        ContentCollection.exercises: _rows(
          ContentCollection.exercises,
          _exercisesCsv,
        ),
      });

      for (final path in manifest.mediaPaths) {
        expect(path, startsWith('content/'));
      }
      for (final path in manifest.csvPaths) {
        expect(path, isNot(contains('/')));
      }
    });

    test('none of the forbidden subjects can appear in a path', () {
      // The list is D12's own: logs, cycle, check-ins, measurements, progress
      // photos, phone numbers, names, verification.
      const forbidden = [
        'users/',
        'cycle',
        'periods',
        'checkins',
        'measurements',
        'progress',
        'logs',
        'meals/',
        'sessions/',
        'verification',
        'phone',
        'user-exports',
        'user-media',
      ];

      final manifest = buildExportManifest({
        for (final c in ContentCollection.values)
          c: c == ContentCollection.exercises
              ? _rows(ContentCollection.exercises, _exercisesCsv)
              : const <ImportRow>[],
      });

      for (final path in manifest.allPaths) {
        for (final word in forbidden) {
          expect(
            path.toLowerCase(),
            isNot(contains(word)),
            reason: '"$word" must be unreachable from an export path: $path',
          );
        }
      }
    });

    test('the manifest refuses a path it did not build itself', () {
      // The positive control. A guard that has never been shown to reject
      // anything is indistinguishable from one that cannot — product_rules_test
      // records that this codebase has already shipped a vacuous guard that
      // passed for weeks by not looking. So the refusal is proven.
      expect(
        () => ExportManifest.of(
          csvPaths: const ['foods.csv'],
          mediaPaths: const ['users/abc/progress/photo.jpg'],
        ),
        throwsA(isA<ArgumentError>()),
        reason:
            'if this does not throw, the manifest can express the one thing '
            'D12 says it must never contain',
      );
    });

    test('the refusal is not fooled by a path that merely starts right', () {
      expect(
        () => ExportManifest.of(
          csvPaths: const [],
          mediaPaths: const ['content/../users/abc/photo.jpg'],
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('a legitimate manifest is accepted, so the guard is not vacuous', () {
      expect(
        ExportManifest.of(
          csvPaths: const ['foods.csv'],
          mediaPaths: const ['content/recipes/soup/soup.jpg'],
        ).allPaths,
        hasLength(2),
      );
    });
  });
}
