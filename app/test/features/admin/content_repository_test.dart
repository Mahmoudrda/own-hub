// The store behind the console — the seam that was missing while Z03, Z05 and
// Z09 all produced content and none of it was kept.
//
// Two writers meet here and they must not diverge. D12 asked for content to be
// addable "from within the app, with a bulk option for CSVs": Z03/Z05's form
// writes one row, Z09's commit writes a validated batch, and both are judged
// against one set of existing ids. If each kept its own idea of the library, a
// food added by hand would be invisible to the importer and duplicated by the
// next CSV that named it.
//
// ## Every fixture here is new
//
// `baked_in_samples_test.dart` records why: "the parameterised label renders
// byte-identical text. All five existing assertions pass before and after the
// change." The same trap applies to a store — a repository that ignored its
// argument and returned a constant would pass any test written with the
// codebase's usual `koshari`/`ful`/`goblet_squat`. So nothing here reuses a
// sample that exists anywhere else in this suite: the foods are molokhia,
// fattah and shorbet ads, the recipe is om ali, and the programme is a
// four-week reset.

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/admin/domain/content_repository.dart';
import 'package:own_hub/features/admin/domain/content_schema.dart';
import 'package:own_hub/features/admin/domain/csv_parser.dart';
import 'package:own_hub/features/admin/domain/import_validator.dart';

const String _foodHeader =
    'foodId,name_en,name_ar,portions,kcal,proteinG,carbsG,fatG,allergens,'
    'dietTags\n';

/// Two foods, neither of them anywhere else in this suite.
const String _twoFoods =
    'molokhia,Molokhia,ملوخية,bowl,180,9,14,8,none,vegetarian\n'
    'fattah,Fattah,فتة,plate,610,24,70,26,gluten|dairy,none\n';

ImportPlan _foodPlan(String body, {Set<String> existing = const {}}) =>
    validateImport(
      collection: ContentCollection.foods,
      table: parseCsv('$_foodHeader$body'),
      uploadedMedia: const {},
      existingIds: existing,
    );

/// A food as Z05 emits it — every column of the contract, the CSV's own keys.
Map<String, String> _foodValues({
  String id = 'shorbet_ads',
  String allergens = 'none',
  String kcal = '240',
}) => {
  'foodId': id,
  'name_en': 'Lentil soup',
  'name_ar': 'شوربة عدس',
  'portions': 'bowl',
  'kcal': kcal,
  'proteinG': '12',
  'carbsG': '38',
  'fatG': '4',
  'allergens': allergens,
  'dietTags': 'vegetarian',
};

void main() {
  group('an empty library claims nothing', () {
    test('it holds no rows and no ids', () async {
      final repository = InMemoryContentRepository();

      expect(await repository.rowsIn(ContentCollection.foods), isEmpty);
      expect(await repository.existingIds(ContentCollection.foods), isEmpty);
      expect(repository.store.writes, isEmpty);
    });

    test('every collection reports zero, not an absence', () async {
      // Z01 renders a count per collection. Once there is a store to read, "0
      // rows" is a claim this console can support — which is a different thing
      // from the screen's older state of knowing nothing at all.
      final status = await InMemoryContentRepository().status();

      expect(status.keys, ContentCollection.values.toSet());
      expect(status[ContentCollection.programmes]!.rows, 0);
      expect(status[ContentCollection.programmes]!.missingASafetyTag, 0);
    });
  });

  group('one row at a time — Z03 and Z05', () {
    test('a row authored on the form is stored under its id column', () async {
      final repository = InMemoryContentRepository();

      await repository.saveValues(
        collection: ContentCollection.foods,
        values: _foodValues(),
      );

      final rows = await repository.rowsIn(ContentCollection.foods);
      expect(rows.single.documentId, 'shorbet_ads');
      expect(rows.single.value('name_ar'), 'شوربة عدس');
      expect(rows.single.value('kcal'), '240');
      expect(rows.single.collection, ContentCollection.foods);
    });

    test('the id is never minted, and a blank one is refused', () async {
      // §3.5: "an id that moves repoints every reference to it." A generated id
      // is worse than a refusal — the row could never be updated again, by the
      // next import of the same file or by anything else.
      final repository = InMemoryContentRepository();

      expect(
        () => repository.saveValues(
          collection: ContentCollection.foods,
          values: _foodValues(id: ''),
        ),
        throwsArgumentError,
      );
      expect(repository.store.writes, isEmpty, reason: 'nothing was written');
    });

    test('saving the same id twice updates rather than duplicating', () async {
      final repository = InMemoryContentRepository();

      await repository.saveValues(
        collection: ContentCollection.foods,
        values: _foodValues(kcal: '240'),
      );
      await repository.saveValues(
        collection: ContentCollection.foods,
        values: _foodValues(kcal: '255'),
      );

      final rows = await repository.rowsIn(ContentCollection.foods);
      expect(rows, hasLength(1));
      expect(rows.single.value('kcal'), '255');
    });

    test('the second save knows it is an update', () async {
      // Taken from the store rather than from the form, which cannot know: a
      // create that claimed to be one would overwrite a row somebody else
      // authored without ever reporting it.
      final repository = InMemoryContentRepository();

      await repository.saveValues(
        collection: ContentCollection.foods,
        values: _foodValues(),
      );
      await repository.saveValues(
        collection: ContentCollection.foods,
        values: _foodValues(),
      );

      final rows = await repository.rowsIn(ContentCollection.foods);
      expect(rows.single.isUpdate, isTrue);
    });

    test('a collection is not written into by a save to another', () async {
      final repository = InMemoryContentRepository();

      await repository.saveValues(
        collection: ContentCollection.foods,
        values: _foodValues(),
      );

      expect(await repository.rowsIn(ContentCollection.recipes), isEmpty);
      expect(await repository.rowsIn(ContentCollection.exercises), isEmpty);
    });
  });

  group('a whole batch — Z09', () {
    test('a validated plan lands in full', () async {
      final repository = InMemoryContentRepository();
      final plan = _foodPlan(_twoFoods);

      expect(plan.canCommit, isTrue, reason: 'fixture must be importable');
      await repository.saveAll(plan.writes);

      final rows = await repository.rowsIn(ContentCollection.foods);
      expect(rows.map((r) => r.documentId), ['molokhia', 'fattah']);
      expect(rows.last.value('kcal'), '610');
    });

    test('a batch that cannot commit carries nothing to write', () async {
      // The importer already guarantees it — `writes` is empty unless the whole
      // file passed — and this is the store's half of the same promise: given
      // that empty list, nothing lands.
      final repository = InMemoryContentRepository();
      final plan = _foodPlan(
        '$_twoFoods'
        'besara,Besara,بصارة,bowl,190,10,22,7,,vegetarian\n',
      );

      expect(plan.canCommit, isFalse);
      await repository.saveAll(plan.writes);

      expect(await repository.rowsIn(ContentCollection.foods), isEmpty);
      expect(repository.store.writes, isEmpty);
    });

    test('a batch holding an unwritable row writes none of it', () async {
      // All or nothing, checked before anything lands. §3.1: "If any row fails,
      // nothing is written at all" — a half-applied import is the one outcome
      // the dry run exists to prevent.
      final repository = InMemoryContentRepository();
      final good = _foodPlan(_twoFoods).writes;

      expect(
        () => repository.saveAll([
          ...good,
          ImportRow(
            collection: ContentCollection.foods,
            id: '',
            isUpdate: false,
            values: const {'foodId': ''},
          ),
        ]),
        throwsArgumentError,
      );
      expect(await repository.rowsIn(ContentCollection.foods), isEmpty);
    });
  });

  group('§3.5 — re-importing the same file updates, never duplicates', () {
    test('the second run creates nothing and the library does not grow', () async {
      final repository = InMemoryContentRepository();

      await repository.saveAll(_foodPlan(_twoFoods).writes);

      // The second run is judged against what is actually in the store — which
      // is the whole reason the repository has to expose its ids.
      final second = _foodPlan(
        _twoFoods,
        existing: await repository.existingIds(ContentCollection.foods),
      );

      expect(second.creates, isEmpty, reason: 'nothing new the second time');
      expect(second.updates, hasLength(2));

      await repository.saveAll(second.writes);

      expect(await repository.rowsIn(ContentCollection.foods), hasLength(2));
    });

    test('an edited file updates the row in place', () async {
      final repository = InMemoryContentRepository();
      await repository.saveAll(_foodPlan(_twoFoods).writes);

      final edited = _foodPlan(
        'molokhia,Molokhia,ملوخية,bowl,180,9,14,8,none,vegetarian\n'
        'fattah,Fattah,فتة,plate,585,24,70,26,gluten|dairy|nuts,none\n',
        existing: await repository.existingIds(ContentCollection.foods),
      );
      await repository.saveAll(edited.writes);

      final rows = await repository.rowsIn(ContentCollection.foods);
      expect(rows, hasLength(2));
      final fattah = rows.firstWhere((r) => r.documentId == 'fattah');
      expect(fattah.value('kcal'), '585');
      expect(fattah.list('allergens'), ['gluten', 'dairy', 'nuts']);
    });

    test('the form and the importer write to the same document', () async {
      // The divergence this file exists to prevent: a food added by hand and
      // then named in a CSV must be one row, not two.
      final repository = InMemoryContentRepository();

      await repository.saveValues(
        collection: ContentCollection.foods,
        values: _foodValues(kcal: '240'),
      );

      final plan = _foodPlan(
        'shorbet_ads,Lentil soup,شوربة عدس,bowl,265,12,38,4,none,vegetarian\n',
        existing: await repository.existingIds(ContentCollection.foods),
      );
      expect(plan.updates.map((r) => r.id), [
        'shorbet_ads',
      ], reason: 'the importer must see the hand-authored row as existing');

      await repository.saveAll(plan.writes);

      final rows = await repository.rowsIn(ContentCollection.foods);
      expect(rows, hasLength(1));
      expect(rows.single.value('kcal'), '265');
    });

    test('the document id is the id column, in the write log too', () async {
      // The log names `collection/id` with the collection spelled the way the
      // rules match on it — `programmes` is `programs` everywhere but on screen.
      final repository = InMemoryContentRepository();

      await repository.saveAll(_foodPlan(_twoFoods).writes);
      await repository.saveValues(
        collection: ContentCollection.programmes,
        values: const {
          'programId': 'four_week_reset',
          'name_en': 'Four week reset',
          'name_ar': 'إعادة ضبط في أربعة أسابيع',
          'weeks': '4',
          'daysPerWeek': '3',
          'sessionLength': '35',
          'quiet': 'true',
          'equipment': 'none',
        },
      );

      expect(repository.store.writes, [
        'foods/molokhia',
        'foods/fattah',
        'programs/four_week_reset',
      ]);
    });
  });

  group('Z01 — blank is not "none"', () {
    test('a blank safety tag is counted and "none" is not', () async {
      // §3.2, and the number Z01 leads with. "none" means she checked; blank
      // means nobody did, and `AllergyGuard` reads the blank as unknown and
      // fails closed on a woman who has no allergy at all.
      final repository = InMemoryContentRepository();

      await repository.saveValues(
        collection: ContentCollection.foods,
        values: _foodValues(id: 'molokhia', allergens: 'none'),
      );
      await repository.saveValues(
        collection: ContentCollection.foods,
        values: _foodValues(id: 'fattah', allergens: 'gluten|dairy'),
      );
      // A row nothing in this console would author — the form refuses it and
      // the importer refuses it — but one a library imported before the rule,
      // or a future server-side path, can perfectly well hold. Counting it is
      // the entire point of the number.
      await repository.saveValues(
        collection: ContentCollection.foods,
        values: _foodValues(id: 'besara', allergens: ''),
      );

      final status = await repository.statusOf(ContentCollection.foods);
      expect(status.rows, 3);
      expect(status.missingASafetyTag, 1);
    });

    test('a cell holding only spaces is blank', () async {
      // A spreadsheet produces these constantly, and a guard cannot tell one
      // from an answer.
      final repository = InMemoryContentRepository();

      await repository.saveValues(
        collection: ContentCollection.foods,
        values: _foodValues(allergens: '   '),
      );

      final status = await repository.statusOf(ContentCollection.foods);
      expect(status.missingASafetyTag, 1);
    });

    test('a collection with no safety column can never be missing one', () async {
      // Programmes carry no safety column, and that is a decision rather than a
      // gap: a programme holds no ingredient and no movement of its own.
      final repository = InMemoryContentRepository();

      await repository.saveValues(
        collection: ContentCollection.programmes,
        values: const {
          'programId': 'four_week_reset',
          'name_en': 'Four week reset',
          'name_ar': 'إعادة ضبط في أربعة أسابيع',
          'weeks': '4',
          'daysPerWeek': '3',
          'sessionLength': '35',
          'quiet': 'true',
          'equipment': '',
        },
      );

      final status = await repository.statusOf(ContentCollection.programmes);
      expect(status.rows, 1);
      expect(status.missingASafetyTag, 0);
      expect(
        ContentSchema.of(ContentCollection.programmes).safetyTagColumns,
        isEmpty,
        reason: 'if this ever gains one, the count above must start moving',
      );
    });

    test('the whole landing tab is counted in one read', () async {
      final repository = InMemoryContentRepository();

      await repository.saveAll(_foodPlan(_twoFoods).writes);
      await repository.saveValues(
        collection: ContentCollection.recipes,
        values: const {
          'recipeId': 'om_ali',
          'name_en': 'Om Ali',
          'name_ar': 'أم علي',
          'minutes': '45',
          'ingredients': 'pastry|milk|nuts',
          'allergens': '',
          'dietTags': 'vegetarian',
          'photoFile': '',
        },
      );

      final status = await repository.status();
      expect(status[ContentCollection.foods]!.rows, 2);
      expect(status[ContentCollection.foods]!.missingASafetyTag, 0);
      expect(status[ContentCollection.recipes]!.rows, 1);
      expect(status[ContentCollection.recipes]!.missingASafetyTag, 1);
      expect(status[ContentCollection.exercises]!.rows, 0);
    });
  });

  group('the shape a Firestore implementation drops into', () {
    test('a change names the collection that changed', () async {
      final repository = InMemoryContentRepository();
      final seen = <ContentCollection>[];
      final subscription = repository.watch().listen(seen.add);

      await repository.saveValues(
        collection: ContentCollection.foods,
        values: _foodValues(),
      );
      await repository.saveAll(_foodPlan(_twoFoods).writes);
      await pumpEventQueue();

      expect(seen, [ContentCollection.foods, ContentCollection.foods]);
      await subscription.cancel();
      await repository.dispose();
    });

    test('a read hands back a copy, not the store itself', () async {
      // A caller that could mutate the returned list would be a second writer
      // with none of the rules above applied to it.
      final repository = InMemoryContentRepository();
      await repository.saveAll(_foodPlan(_twoFoods).writes);

      final rows = await repository.rowsIn(ContentCollection.foods);
      expect(() => rows.removeLast(), throwsUnsupportedError);

      final ids = await repository.existingIds(ContentCollection.foods);
      expect(() => ids.add('mahshi'), throwsUnsupportedError);
    });

    test('a seeded store is a restored snapshot, not a write', () async {
      // Seeding is how a cached snapshot arrives. It is not staff writing
      // anything, so it does not appear in the write log.
      final repository = InMemoryContentRepository(
        rows: _foodPlan(_twoFoods).writes,
      );

      expect(await repository.rowsIn(ContentCollection.foods), hasLength(2));
      expect(repository.store.writes, isEmpty);
    });

    test('the synchronous reads agree with the asynchronous ones', () async {
      // The router renders from cache rather than awaiting a read on every
      // build, exactly as `InMemoryCycleRepository.store` lets it.
      final repository = InMemoryContentRepository();
      await repository.saveAll(_foodPlan(_twoFoods).writes);

      expect(
        repository.rowsNow(ContentCollection.foods).map((r) => r.id),
        (await repository.rowsIn(ContentCollection.foods)).map((r) => r.id),
      );
      expect(
        repository.existingIdsNow(ContentCollection.foods),
        await repository.existingIds(ContentCollection.foods),
      );
      expect(
        repository.statusNowOf(ContentCollection.foods).rows,
        (await repository.statusOf(ContentCollection.foods)).rows,
      );
      expect(repository.statusNow().keys, ContentCollection.values.toSet());
    });

    test('the in-memory store is a ContentRepository to its callers', () {
      // The screens and the router depend on the interface, so the Firestore
      // implementation is a new class beside this one rather than a rewrite.
      expect(InMemoryContentRepository(), isA<ContentRepository>());
    });
  });
}
