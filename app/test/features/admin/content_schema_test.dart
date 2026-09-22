// The four CSV contracts, asserted against the plan and the shipped templates.
//
// G16 §3.4 names the columns. `6-v2/content/templates/*.csv` are working files
// an admin is told to fill in and import. If the schema in the code and the
// header line in the template ever disagree, the template she was handed is
// rejected by the importer that was built for it — so the template files are
// read here and compared, rather than the columns being retyped twice.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/admin/domain/content_schema.dart';

/// The templates live outside `app/`, beside the plan that specifies them.
const String _templateDir = '../6-v2/content/templates';

List<String> _templateHeaders(String file) {
  final f = File('$_templateDir/$file');
  expect(
    f.existsSync(),
    isTrue,
    reason:
        '$file is the template an admin is told to fill in. If it has moved, '
        'the importer and the documentation have come apart.',
  );
  return f.readAsLinesSync().first.split(',');
}

void main() {
  group('the columns match G16 §3.4', () {
    test('exercises', () {
      expect(ContentSchema.of(ContentCollection.exercises).columnNames, [
        'exerciseId',
        'name_en',
        'name_ar',
        'equipment',
        'pattern',
        'contraindicationTags',
        'quiet',
        'floorOnly',
        'videoFile',
        'thumbFile',
      ]);
    });

    test('foods', () {
      expect(ContentSchema.of(ContentCollection.foods).columnNames, [
        'foodId',
        'name_en',
        'name_ar',
        'portions',
        'kcal',
        'proteinG',
        'carbsG',
        'fatG',
        'allergens',
        'dietTags',
      ]);
    });

    test('recipes', () {
      expect(ContentSchema.of(ContentCollection.recipes).columnNames, [
        'recipeId',
        'name_en',
        'name_ar',
        'minutes',
        'ingredients',
        'allergens',
        'dietTags',
        'photoFile',
      ]);
    });

    test('programmes', () {
      expect(ContentSchema.of(ContentCollection.programmes).columnNames, [
        'programId',
        'name_en',
        'name_ar',
        'weeks',
        'daysPerWeek',
        'sessionLength',
        'quiet',
        'equipment',
      ]);
    });
  });

  group('the shipped templates import cleanly against their own schema', () {
    // The templates are documentation that runs. A header the importer would
    // reject is a broken instruction handed to staff.
    test('every template header line matches its schema exactly', () {
      final pairs = {
        ContentCollection.exercises: 'exercises.csv',
        ContentCollection.foods: 'foods.csv',
        ContentCollection.recipes: 'recipes.csv',
        ContentCollection.programmes: 'programs.csv',
      };

      pairs.forEach((collection, file) {
        expect(
          _templateHeaders(file),
          ContentSchema.of(collection).columnNames,
          reason: '$file disagrees with the ${collection.name} schema',
        );
      });
    });

    test('the file name the plan gives each collection is the one used', () {
      // §5: an export produces "one CSV per collection, in exactly the import
      // schema — so an export can be edited and re-imported". That round trip
      // only works if the two halves agree on the file name as well.
      expect(
        ContentSchema.of(ContentCollection.exercises).fileName,
        'exercises.csv',
      );
      expect(ContentSchema.of(ContentCollection.foods).fileName, 'foods.csv');
      expect(
        ContentSchema.of(ContentCollection.recipes).fileName,
        'recipes.csv',
      );
      expect(
        ContentSchema.of(ContentCollection.programmes).fileName,
        'programs.csv',
        reason:
            'the plan and the template both say programs.csv, not '
            'programmes.csv — the collection is spelled one way in prose and '
            'another in the file, and the file wins',
      );
    });
  });

  group('the id column', () {
    test('each collection has its own id column, and it is the first', () {
      // §3.4: "`id` is stable and is what an update matches on."
      expect(
        ContentSchema.of(ContentCollection.exercises).idColumn,
        'exerciseId',
      );
      expect(ContentSchema.of(ContentCollection.foods).idColumn, 'foodId');
      expect(ContentSchema.of(ContentCollection.recipes).idColumn, 'recipeId');
      expect(
        ContentSchema.of(ContentCollection.programmes).idColumn,
        'programId',
      );

      for (final c in ContentCollection.values) {
        final schema = ContentSchema.of(c);
        expect(schema.columnNames.first, schema.idColumn);
      }
    });
  });

  group('which columns carry a mandatory safety tag', () {
    // §3.5, and the reason the whole console exists: SCHEMA-SPINE §1 marks
    // these "mandatory, not enrichment … without them the safety rules are
    // decorative".
    test('exercises carry contraindicationTags', () {
      expect(ContentSchema.of(ContentCollection.exercises).safetyTagColumns, [
        'contraindicationTags',
      ]);
    });

    test('foods and recipes carry allergens', () {
      expect(ContentSchema.of(ContentCollection.foods).safetyTagColumns, [
        'allergens',
      ]);
      expect(ContentSchema.of(ContentCollection.recipes).safetyTagColumns, [
        'allergens',
      ]);
    });

    test('programmes carry none, and that is not an oversight', () {
      // A programme is a shape — weeks, days, session length. It holds no
      // ingredient and no movement of its own, so there is nothing for a guard
      // to read off it. Asserted so that "programmes have no safety column"
      // stays a decision rather than a gap someone fills in later.
      expect(
        ContentSchema.of(ContentCollection.programmes).safetyTagColumns,
        isEmpty,
      );
    });

    test('a safety column is always also a required column', () {
      // The two ideas are different — `dietTags` is required and is not a
      // safety tag — but a safety column that was somehow optional would be a
      // guard that can be switched off by leaving a cell out.
      for (final c in ContentCollection.values) {
        final schema = ContentSchema.of(c);
        for (final name in schema.safetyTagColumns) {
          expect(
            schema.column(name)!.required,
            isTrue,
            reason: '$name is a safety column and must be required',
          );
        }
      }
    });
  });

  group('the bilingual pair', () {
    test('both name columns are required in every collection', () {
      // §3.3: the library "carries its own display text because it is content
      // from a build-time bundle, not copy from the dictionary". A row with
      // only `name_en` is invisible to half the product's users.
      for (final c in ContentCollection.values) {
        final schema = ContentSchema.of(c);
        expect(schema.column('name_en')!.required, isTrue);
        expect(schema.column('name_ar')!.required, isTrue);
      }
    });
  });

  group('media columns', () {
    test('only exercises and recipes reference media files', () {
      expect(ContentSchema.of(ContentCollection.exercises).mediaColumns, [
        'videoFile',
        'thumbFile',
      ]);
      expect(ContentSchema.of(ContentCollection.recipes).mediaColumns, [
        'photoFile',
      ]);
      expect(ContentSchema.of(ContentCollection.foods).mediaColumns, isEmpty);
      expect(
        ContentSchema.of(ContentCollection.programmes).mediaColumns,
        isEmpty,
      );
    });

    test('a media column is optional — a row may legitimately have no video', () {
      // §3.4 only says a file NAMED must exist. It does not say every row must
      // name one, and requiring it would block importing a library before its
      // filming is done.
      expect(
        ContentSchema.of(ContentCollection.exercises)
            .column('videoFile')!
            .required,
        isFalse,
      );
    });
  });

  group('list and numeric columns', () {
    test('list columns are the pipe-separated ones the README names', () {
      // "List columns are pipe-separated: dumbbell|barbell, vegetarian|vegan."
      expect(
        ContentSchema.of(ContentCollection.foods).listColumns,
        containsAll(['portions', 'allergens', 'dietTags']),
      );
      expect(
        ContentSchema.of(ContentCollection.exercises).listColumns,
        containsAll(['equipment', 'contraindicationTags']),
      );
      expect(
        ContentSchema.of(ContentCollection.recipes).listColumns,
        containsAll(['ingredients', 'allergens', 'dietTags']),
      );
    });

    test('macros and durations are numeric', () {
      // §3.5: "macros numeric and non-negative".
      expect(
        ContentSchema.of(ContentCollection.foods).numericColumns,
        containsAll(['kcal', 'proteinG', 'carbsG', 'fatG']),
      );
      expect(
        ContentSchema.of(ContentCollection.recipes).numericColumns,
        contains('minutes'),
      );
      expect(
        ContentSchema.of(ContentCollection.programmes).numericColumns,
        containsAll(['weeks', 'daysPerWeek', 'sessionLength']),
      );
    });

    test('a column is never both numeric and a list', () {
      for (final c in ContentCollection.values) {
        final schema = ContentSchema.of(c);
        for (final name in schema.numericColumns) {
          expect(schema.listColumns, isNot(contains(name)));
        }
      }
    });
  });

  test('every collection knows its Cloud Storage prefix', () {
    // §4: content/exercises/{exerciseId}/{file}. The prefix is part of the
    // schema so that no screen has to build a storage path by hand.
    expect(
      ContentSchema.of(ContentCollection.exercises).storagePrefix,
      'content/exercises',
    );
    expect(
      ContentSchema.of(ContentCollection.foods).storagePrefix,
      'content/foods',
    );
    expect(
      ContentSchema.of(ContentCollection.recipes).storagePrefix,
      'content/recipes',
    );
    expect(
      ContentSchema.of(ContentCollection.programmes).storagePrefix,
      'content/programs',
    );

    for (final c in ContentCollection.values) {
      expect(
        ContentSchema.of(c).storagePrefix,
        startsWith('content/'),
        reason: 'nothing in this console addresses anything but content/',
      );
    }
  });
}
