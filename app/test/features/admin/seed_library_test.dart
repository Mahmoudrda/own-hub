// The seeded library, judged by the real importer — `DECISIONS.md` D20.
//
// # Why this file runs `validateImport` rather than re-stating its rules
//
// The owner's bar: "ensure that all test cases exist so you don't write tests
// that pass your own code". A test that walked the seed asserting "allergens is
// not empty" would be a second, weaker copy of the validator, and the seed could
// satisfy it while the importer still refused the file. So every row below is
// rendered back to CSV, parsed by `parseCsv` and judged by `validateImport` —
// the same two functions Z08 → Z09 runs. If the importer would reject a row, this
// goes red.
//
// # The negative control
//
// `product_rules_test.dart` and `admin_never_reads_user_data_test.dart` both
// record the same lesson: "a guard that matches nothing is indistinguishable
// from a broken one", and this codebase has shipped two matchers that could
// never fire. So before the clean seed is trusted against a validator, the
// validator is proven to reject the one defect this content exists to prevent —
// a blank safety cell — built from a real seeded row rather than from a fixture.

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/account/domain/dietary_profile.dart';
import 'package:own_hub/features/admin/domain/content_repository.dart';
import 'package:own_hub/features/admin/domain/content_schema.dart';
import 'package:own_hub/features/admin/domain/csv_parser.dart';
import 'package:own_hub/features/admin/domain/import_validator.dart';
import 'package:own_hub/features/admin/domain/seed_library.dart';
import 'package:own_hub/features/eat/domain/allergy_guard.dart';
import 'package:own_hub/features/eat/domain/food_library.dart';
import 'package:own_hub/features/onboarding/domain/intake.dart';
import 'package:own_hub/features/onboarding/domain/starting_program.dart';

/// The seed, through the importer staff actually use.
ImportPlan _import(ContentCollection collection) => validateImport(
  collection: collection,
  table: parseCsv(seedCsvFor(collection)),
  // Nothing has been filmed or photographed, so nothing may be named. A row
  // naming an absent file is a validation failure by design (G16 §3.4).
  uploadedMedia: const <String>{},
  existingIds: const <String>{},
);

ImportRow _row(ContentCollection collection, String id) =>
    seedRowsFor(collection).firstWhere((r) => r.id == id);

/// G14 §1.5, and `isTag()` in the rules. Ten tags, plus the explicit `none`.
const Set<String> _contraindicationVocabulary = {
  'high_impact',
  'jumping',
  'deep_knee_flexion',
  'loaded_twisting',
  'pelvic_floor_load',
  'breath_hold_valsalva',
  'prone_position',
  'supine_load',
  'overhead_load',
  'wrist_load',
  'none',
};

/// What a dish may declare: every `AllergenTag` wire name, the four spellings
/// the first version of that enum wrote, and `none`.
///
/// The enum widened from four tokens to sixteen when Rahma's recipe book was
/// authored — the EU/UK declarables plus `fava` and `coconut`. The four old
/// spellings stay listed because seed rows written against them still exist and
/// `AllergenTag.fromWire` still resolves every one of them; dropping them here
/// would fail a row that the guard reads correctly. The enum is asserted
/// against this set below rather than trusted from it.
///
/// `egg` is the seed's singular spelling of the enum's `eggs`. It is kept
/// because rows already carry it, and it is a content correction rather than a
/// code one.
const Set<String> _allergenVocabulary = {
  // The sixteen.
  'gluten',
  'crustaceans',
  'eggs',
  'fish',
  'peanuts',
  'soy',
  'milk',
  'tree_nuts',
  'celery',
  'mustard',
  'sesame',
  'sulphites',
  'lupin',
  'molluscs',
  'fava',
  'coconut',
  // Already written into seed rows, and still resolvable.
  'nuts',
  'dairy',
  'shellfish',
  'egg',
  'none',
};

void main() {
  group('the seed exists and this file is looking at it', () {
    // The vacuous-guard check. Every assertion below passes trivially over an
    // empty list, which is exactly the state this work was commissioned to end.
    test('every collection is seeded', () {
      expect(seedRowsFor(ContentCollection.foods), hasLength(20));
      expect(seedRowsFor(ContentCollection.exercises), hasLength(23));
      expect(seedRowsFor(ContentCollection.recipes), hasLength(9));
      expect(seedRowsFor(ContentCollection.programmes), hasLength(4));
      expect(seedContentLibrary(), hasLength(56));
    });

    test('the library is no longer empty for any collection', () {
      for (final collection in ContentCollection.values) {
        expect(
          seedRowsFor(collection),
          isNotEmpty,
          reason:
              '${collection.name} is unseeded, so its safety column protects '
              'nobody.',
        );
      }
    });
  });

  group('the real importer accepts every seeded row', () {
    // The headline. G16 §3.1: one failure anywhere and `writes` is empty.
    for (final collection in ContentCollection.values) {
      test('${collection.name}: no problems, and the batch may commit', () {
        final plan = _import(collection);

        expect(
          plan.problems,
          isEmpty,
          reason:
              'The seeded ${collection.name} would be refused by the importer: '
              '${plan.problems.join(', ')}',
        );
        expect(plan.canCommit, isTrue);
        expect(plan.rowsReady, seedRowsFor(collection).length);
        expect(plan.writes, hasLength(seedRowsFor(collection).length));
      });

      test('${collection.name}: no row is missing a safety tag', () {
        // The number Z01 leads with, counted across the whole file by the
        // validator itself rather than recomputed here.
        expect(_import(collection).rowsMissingASafetyTag, 0);
      });
    }

    test(
      'the validator would reject a blank safety cell in this same seed',
      () {
        // The negative control, built from a real seeded row. Without this, the
        // assertions above could be passing over a validator that never fires.
        final schema = ContentSchema.of(ContentCollection.foods);
        final seeded = seedRowsFor(ContentCollection.foods).first;

        final cells = [
          for (final name in schema.columnNames)
            if (name == 'allergens') '' else seeded.value(name),
        ];
        final plan = validateImport(
          collection: ContentCollection.foods,
          table: parseCsv(
            '${schema.columnNames.join(',')}\n${cells.join(',')}\n',
          ),
          uploadedMedia: const <String>{},
          existingIds: const <String>{},
        );

        expect(plan.canCommit, isFalse);
        expect(plan.writes, isEmpty);
        expect(
          plan.problems.map((p) => p.code),
          contains(ImportProblemCode.blankSafetyTag),
        );
        expect(plan.rowsMissingASafetyTag, 1);
      },
    );

    test('the rows handed to the repository are the rows the importer builds', () {
      // Two routes to the same content — the constructor and a CSV import — and
      // if they disagreed, what the tests above proved would not be what the app
      // actually seeds.
      for (final collection in ContentCollection.values) {
        final seeded = seedRowsFor(collection);
        final imported = _import(collection).writes;

        expect(imported.map((r) => r.id), seeded.map((r) => r.id));
        for (var i = 0; i < seeded.length; i++) {
          expect(
            imported[i].values,
            seeded[i].values,
            reason: '${collection.name} row ${seeded[i].id} differs',
          );
        }
      }
    });
  });

  group('ids are stable, and re-seeding does not duplicate', () {
    final idPattern = RegExp(r'^[a-z0-9]+(_[a-z0-9]+)*$');

    test(
      'every id is lowercase, underscore-separated, and the document id',
      () {
        for (final row in seedContentLibrary()) {
          expect(
            idPattern.hasMatch(row.id),
            isTrue,
            reason: '${row.id} is not a stable lowercase id',
          );
          expect(row.documentId, row.id);
        }
      },
    );

    test('ids are unique within each collection', () {
      for (final collection in ContentCollection.values) {
        final ids = seedRowsFor(collection).map((r) => r.id).toList();
        expect(ids.toSet(), hasLength(ids.length));
      }
    });

    test('seeding twice leaves one document per id', () async {
      // §3.5: "re-running the same file must not duplicate". The id IS the
      // document id, so the second pass replaces rather than appends.
      final repository = InMemoryContentRepository(rows: seedContentLibrary());
      final before = repository.statusNow();

      await repository.saveAll(seedContentLibrary());

      for (final collection in ContentCollection.values) {
        expect(
          repository.statusNowOf(collection).rows,
          before[collection]!.rows,
          reason: '${collection.name} grew when the same seed was re-applied',
        );
      }
    });

    test('a seeded repository reports no untagged row to Z01', () {
      // The screen's headline number, read off the real repository.
      final repository = InMemoryContentRepository(rows: seedContentLibrary());

      for (final entry in repository.statusNow().entries) {
        expect(entry.value.rows, greaterThan(0));
        expect(
          entry.value.missingASafetyTag,
          0,
          reason: '${entry.key.name} still has a row the guard cannot read',
        );
      }
    });

    test('seeding through the constructor is not recorded as a write', () {
      // It is the library's starting state, not something staff did.
      expect(
        InMemoryContentRepository(rows: seedContentLibrary()).store.writes,
        isEmpty,
      );
    });
  });

  group('the safety columns are answered, not left to a default', () {
    test('no allergens or contraindicationTags cell is blank', () {
      for (final collection in ContentCollection.values) {
        for (final column in ContentSchema.of(collection).safetyTagColumns) {
          for (final row in seedRowsFor(collection)) {
            expect(
              row.value(column).trim(),
              isNotEmpty,
              reason: '${collection.name}/${row.id} left $column blank',
            );
          }
        }
      }
    });

    test('`none` is used as a value, not as an absence', () {
      // If nothing said `none`, the seed would be avoiding the distinction
      // rather than keeping it.
      expect(_row(ContentCollection.foods, 'dates').list('allergens'), [
        'none',
      ]);
      expect(
        _row(
          ContentCollection.exercises,
          'calf_raise',
        ).list('contraindicationTags'),
        ['none'],
      );
    });

    test('every allergen token is one a dish may declare', () {
      for (final collection in [
        ContentCollection.foods,
        ContentCollection.recipes,
      ]) {
        for (final row in seedRowsFor(collection)) {
          for (final tag in row.list('allergens')) {
            expect(
              _allergenVocabulary,
              contains(tag),
              reason: '${collection.name}/${row.id} declares "$tag"',
            );
          }
        }
      }
    });

    test('the allergens she can name are spelled the way she names them', () {
      // `AllergenTag.wireName` is what lands in her profile and what must match
      // `foods.allergens[]`. A seed that spelled it "dairy_products" would be a
      // library the guard reads and never matches.
      for (final tag in AllergenTag.values) {
        expect(_allergenVocabulary, contains(tag.wireName));
      }

      final declared = {
        for (final row in seedRowsFor(ContentCollection.foods))
          ...row.list('allergens'),
      };
      expect(declared, containsAll(<String>['gluten', 'dairy', 'nuts']));
      expect(
        AllergenTag.fromWire('gluten'),
        AllergenTag.gluten,
        reason: 'the token the seed writes must resolve to the tag she picks',
      );
    });

    test('every contraindication tag is one the filter can act on', () {
      // G14 §1.5: the vocabulary is fixed and shared with her avoid list. A tag
      // outside it intersects nothing, so it reads as authored and filters
      // nothing — the failure this seed exists to end.
      for (final row in seedRowsFor(ContentCollection.exercises)) {
        for (final tag in row.list('contraindicationTags')) {
          expect(
            _contraindicationVocabulary,
            contains(tag),
            reason: '${row.id} declares "$tag", which nothing can match',
          );
        }
      }
    });
  });

  group('the seeded allergens actually drive the guard', () {
    // `AllergyGuard` is built, correct and tested, and until this content
    // existed it could protect nobody: every assessment resolved to "unknown,
    // therefore unsafe". These two tests are `P0-EAT-01`'s shape.
    //
    // The conversion below is local to this test **on purpose**: nothing in
    // `lib/` yet turns an `ImportRow` into a `Food`, and that missing adapter is
    // called out in the handover note rather than implied to exist.
    Food asFood(ImportRow row) {
      final declared = row.list('allergens');
      return Food(
        foodId: row.id,
        names: [row.value('name_en')],
        sizes: [
          FoodSize(
            id: 'M',
            label: row.value('portions').split('|').first,
            kcal: row.number('kcal')!,
            proteinG: row.number('proteinG')!,
          ),
        ],
        // `none` is an answer, and the answer is "no allergens" — an empty set,
        // which is a claim somebody is now entitled to make. Null would mean
        // nobody had checked, and would fail closed all over again.
        allergens: declared.length == 1 && declared.single == 'none'
            ? const <String>{}
            : declared.toSet(),
        dietTags: row.list('dietTags').toSet(),
      );
    }

    test('a woman who cannot eat gluten is blocked from koshari', () {
      final guard = AllergyGuard(
        const DietaryConstraints(
          allergies: <String>{'gluten'},
          dietary: <String>{},
        ),
      );

      final verdict = guard.assess(
        asFood(_row(ContentCollection.foods, 'koshary')),
      );

      expect(verdict.isBlocked, isTrue);
      expect(verdict.reason, AllergyBlockReason.namedAllergen);
      expect(verdict.allergens, {'gluten'});
    });

    test('and is still cleared for ful, because somebody checked it', () {
      // The half that a fabricated or half-authored library gets wrong: failing
      // closed on everything is not safety, it is a guard nobody can use.
      final guard = AllergyGuard(
        const DietaryConstraints(
          allergies: <String>{'gluten'},
          dietary: <String>{},
        ),
      );

      expect(
        guard
            .assess(asFood(_row(ContentCollection.foods, 'ful_medames')))
            .isBlocked,
        isFalse,
      );
    });

    test('a nut allergy removes om ali from what she is offered', () {
      final guard = AllergyGuard(
        const DietaryConstraints(
          allergies: <String>{'nuts'},
          dietary: <String>{},
        ),
      );
      final offered = guard
          .screen(seedRowsFor(ContentCollection.foods).map(asFood))
          .map((f) => f.foodId);

      expect(offered, isNot(contains('om_ali')));
      expect(offered, contains('shorbet_ads'));
    });

    test('a vegetarian preference keeps the dishes tagged vegetarian', () {
      final guard = AllergyGuard(
        const DietaryConstraints(
          allergies: <String>{},
          dietary: <String>{'vegetarian'},
        ),
      );
      final offered = guard
          .screen(seedRowsFor(ContentCollection.foods).map(asFood))
          .map((f) => f.foodId);

      expect(offered, contains('koshary'));
      expect(
        offered,
        isNot(contains('chicken_breast_grilled')),
        reason: DietaryTag.vegetarianWeekdays.requiredDishTags.toString(),
      );
    });
  });

  group('quiet and floorOnly are answered truthfully', () {
    test('what jumps is not quiet', () {
      expect(
        _row(ContentCollection.exercises, 'jumping_jack').boolean('quiet'),
        isFalse,
      );
      expect(
        _row(ContentCollection.exercises, 'squat_jump').boolean('quiet'),
        isFalse,
      );
    });

    test('what does not jump is', () {
      expect(
        _row(ContentCollection.exercises, 'glute_bridge').boolean('quiet'),
        isTrue,
      );
      expect(
        _row(ContentCollection.exercises, 'goblet_squat').boolean('quiet'),
        isTrue,
      );
    });

    test('a plank is floor only and a squat is not', () {
      expect(
        _row(ContentCollection.exercises, 'plank').boolean('floorOnly'),
        isTrue,
      );
      expect(
        _row(ContentCollection.exercises, 'dead_bug').boolean('floorOnly'),
        isTrue,
      );
      expect(
        _row(ContentCollection.exercises, 'goblet_squat').boolean('floorOnly'),
        isFalse,
      );
      expect(
        _row(ContentCollection.exercises, 'jumping_jack').boolean('floorOnly'),
        isFalse,
      );
    });

    test('at least one move is offered to a woman with neighbours below', () {
      final quiet = seedRowsFor(ContentCollection.exercises)
          .where((r) => r.boolean('quiet') == true);

      expect(quiet.length, greaterThan(15));
    });
  });

  group('the seed does not contradict what is already authored', () {
    test('beginner_foundations matches the bundled starting programme', () {
      // `selectStartingProgram` offers this programme on O05. Two different
      // answers behind one id is the defect; this is what stops it.
      final seeded = _row(ContentCollection.programmes, 'beginner_foundations');

      expect(seeded.id, beginnerFoundations.programId);
      expect(seeded.number('weeks'), beginnerFoundations.weeks);
      expect(seeded.number('daysPerWeek'), beginnerFoundations.daysPerWeek);
      expect(seeded.number('sessionLength'), beginnerFoundations.sessionLength);
      expect(seeded.boolean('quiet'), beginnerFoundations.quiet);
      expect(
        seeded.list('equipment').toSet(),
        beginnerFoundations.equipment.map((e) => e.wireName).toSet(),
      );
    });

    test('every equipment token is one her intake can express', () {
      // `Equipment.wireName`, so a programme is not filtered out as kit she does
      // not own because the library spelled it differently.
      final known = {for (final e in Equipment.values) e.wireName};

      for (final collection in [
        ContentCollection.exercises,
        ContentCollection.programmes,
      ]) {
        for (final row in seedRowsFor(collection)) {
          for (final item in row.list('equipment')) {
            expect(
              known,
              contains(item),
              reason: '${collection.name}/${row.id} needs "$item"',
            );
          }
        }
      }
    });
  });

  test('no row names a media file, because none has been uploaded', () {
    // Optional columns, deliberately blank: §3.4 refuses a row naming a file the
    // upload does not contain, and this library is imported before its filming
    // is finished.
    for (final collection in ContentCollection.values) {
      for (final column in ContentSchema.of(collection).mediaColumns) {
        for (final row in seedRowsFor(collection)) {
          expect(
            row.value(column),
            isEmpty,
            reason: '${collection.name}/${row.id} names $column',
          );
        }
      }
    }
  });

  test('macros are whole, non-negative and not all zero', () {
    // The validator enforces whole and non-negative. What it cannot tell is
    // whether a row said anything at all — 0/0/0/0 passes every rule and is not
    // a food.
    for (final row in seedRowsFor(ContentCollection.foods)) {
      final kcal = row.number('kcal')!;
      expect(kcal, greaterThan(0), reason: '${row.id} has no energy value');
      for (final macro in ['proteinG', 'carbsG', 'fatG']) {
        expect(row.number(macro), isNotNull);
        expect(row.number(macro)!, greaterThanOrEqualTo(0));
      }
    }

    for (final row in seedRowsFor(ContentCollection.recipes)) {
      expect(row.number('minutes')!, greaterThan(0));
      expect(row.list('ingredients'), isNotEmpty);
    }
  });
}
