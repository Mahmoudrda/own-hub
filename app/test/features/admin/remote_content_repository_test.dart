// The content library behind the console, end to end into the member app.
//
// The question this answers is the one the console existed for and could not
// answer: does a recipe or a workout the owner adds actually reach anything?
// Until RemoteContentRepository, every save landed in memory on her phone.
//
//   * exercises, foods and programmes are written to their Firestore
//     collections as typed documents, and read back exactly;
//   * a recipe is written with the index and version the member app reads, and
//     the member app's own RecipeSync, reading the same documents, then holds
//     it in her library;
//   * a recipe the member app would refuse is refused here, and nothing at all
//     is written, because one bad body would freeze every phone's library;
//   * a draft is stored and is never in a member's library;
//   * with no server, a save stays on this phone and says so.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/app_state/local_persistence.dart';
import 'package:own_hub/features/admin/domain/content_documents.dart';
import 'package:own_hub/features/admin/domain/content_schema.dart';
import 'package:own_hub/features/admin/domain/import_validator.dart';
import 'package:own_hub/features/admin/domain/remote_content_repository.dart';
import 'package:own_hub/features/eat/data/recipe_sync.dart';
import 'package:own_hub/features/eat/data/seeded_recipe_library.dart';

late Map<String, Object?> _seed;

class _MemoryStorage implements SnapshotStorage {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String snapshot) async => value = snapshot;

  @override
  Future<void> erase() async => value = null;
}

class _SeedOnly implements RecipeLibrary {
  @override
  Future<RecipeBook> load() async => RecipeBook.fromJson(_seed);
}

/// The member app's reader, over the same documents the console wrote.
class _DocsSource implements RecipeRemoteSource {
  _DocsSource(this.docs);
  final InMemoryContentDocuments docs;

  @override
  Future<int?> readVersion() async =>
      (docs.docs['meta/recipes']?['version'] as num?)?.toInt();

  @override
  Future<Map<String, Object?>?> readIndex(int version) async =>
      jsonDecode(jsonEncode(docs.docs['recipeIndex/en_v$version']))
          as Map<String, Object?>?;

  @override
  Future<Map<String, Object?>?> readRecipe(String recipeId) async =>
      jsonDecode(jsonEncode(docs.docs['recipes/$recipeId']))
          as Map<String, Object?>?;
}

RemoteContentRepository _repo(ContentDocuments? docs) =>
    RemoteContentRepository(
      documents: () => docs,
      seedRecipes: () async => _seed,
    );

String get _section =>
    ((_seed['sections']! as List).first as Map)['sectionId']! as String;

Map<String, String> _recipe({
  String id = 'om_ali',
  String status = 'review',
  String reviewer = 'qa_reviewer',
  String kcal = '',
  String method = _method,
}) => {
  'recipeId': id,
  'name_en': 'Om Ali',
  'name_ar': 'om ali ar',
  'minutes': '45',
  'ingredients': 'pastry|milk|nuts',
  'allergens': 'nuts|dairy',
  'dietTags': 'vegetarian',
  'photoFile': '',
  'sectionId': _section,
  'source': 'authored',
  'status': status,
  'sourcePage': '',
  'authoredBy': 'content_team',
  'allergenReviewedBy': reviewer,
  'serves': '',
  'activeMinutes': '',
  'kcal': kcal,
  'proteinG': '',
  'carbsG': '',
  'fatG': '',
  'macroBasis': 'withheld',
  'egpPerServing': '',
  'egpPricedAt': '',
  'advisories': 'none',
  'doneness': '',
  'markKey': '',
  'tier': 'free',
  'method_ar': method,
  'method_en': '',
};

const String _method = 'step one\nstep two\n\nstep three';

Future<RecipeBook?> _memberBook(InMemoryContentDocuments docs) async {
  final sync = RecipeSync(
    seed: _SeedOnly(),
    source: () => _DocsSource(docs),
    cache: _MemoryStorage(),
    checks: _MemoryStorage(),
    now: () => DateTime.utc(2026, 10, 7, 9),
  );
  final result = await sync.refresh();
  return result.book;
}

void main() {
  setUpAll(() {
    _seed = (jsonDecode(
      File('assets/content/rahma_recipes.json').readAsStringSync(),
    ) as Map).cast<String, Object?>();
  });

  group('workouts and foods', () {
    test('an exercise is a typed document in exercises/', () async {
      final docs = InMemoryContentDocuments();
      final repo = _repo(docs);
      final outcome = await repo.saveToLibrary(
        collection: ContentCollection.exercises,
        values: {
          'exerciseId': 'glute_bridge',
          'name_en': 'Glute bridge',
          'name_ar': 'jisr',
          'equipment': 'mat',
          'pattern': 'hinge',
          'contraindicationTags': 'supine_load',
          'quiet': 'true',
          'floorOnly': 'true',
          'videoFile': '',
          'thumbFile': '',
        },
      );
      expect(outcome, ContentSaveOutcome.saved);
      final doc = docs.docs['exercises/glute_bridge']!;
      expect(doc['equipment'], ['mat']);
      expect(doc['contraindicationTags'], ['supine_load']);
      expect(doc['quiet'], isTrue);
      expect(doc['name_ar'], 'jisr');
      expect(
        repo.rowsNow(ContentCollection.exercises).single.id,
        'glute_bridge',
      );
    });

    test(
      'a food keeps its numbers as numbers, and reads back as written',
      () async {
        final docs = InMemoryContentDocuments();
        final values = {
          'foodId': 'koshari',
          'name_en': 'Koshari',
          'name_ar': 'koshari ar',
          'portions': 'bowl|plate',
          'kcal': '430',
          'proteinG': '14',
          'carbsG': '80',
          'fatG': '6',
          'allergens': 'gluten',
          'dietTags': 'vegetarian|vegan',
        };
        await _repo(docs)
            .saveToLibrary(collection: ContentCollection.foods, values: values);
        expect(docs.docs['foods/koshari']!['kcal'], 430);

        final again = _repo(docs);
        expect(await again.loadFromServer(), isTrue);
        final row = again.rowsNow(ContentCollection.foods).single;
        expect(row.values, values);
      },
    );

    test(
      'a programme is stored in programs/, the spelling the rules use',
      () async {
        final docs = InMemoryContentDocuments();
        await _repo(docs).saveToLibrary(
          collection: ContentCollection.programmes,
          values: {
            'programId': 'quiet_start',
            'name_en': 'Quiet start',
            'name_ar': 'bidaya',
            'weeks': '4',
            'daysPerWeek': '3',
            'sessionLength': '20',
            'quiet': 'true',
            'equipment': 'none',
          },
        );
        expect(docs.docs.keys, contains('programs/quiet_start'));
        expect(docs.docs['programs/quiet_start']!['weeks'], 4);
      },
    );

    test('a bulk import writes its rows in one commit', () async {
      final docs = InMemoryContentDocuments();
      await _repo(docs).saveAll([
        ImportRow(
          collection: ContentCollection.foods,
          id: 'a',
          isUpdate: false,
          values: const {'foodId': 'a', 'name_en': 'A'},
        ),
        ImportRow(
          collection: ContentCollection.foods,
          id: 'b',
          isUpdate: false,
          values: const {'foodId': 'b', 'name_en': 'B'},
        ),
      ]);
      expect(docs.commits, [
        ['foods/a', 'foods/b'],
      ]);
    });

    test('a refused write leaves the cache as it was', () async {
      final docs = InMemoryContentDocuments()
        ..refuseWith = StateError('permission-denied');
      final repo = _repo(docs);
      await expectLater(
        repo.saveToLibrary(
          collection: ContentCollection.foods,
          values: const {'foodId': 'x', 'name_en': 'X'},
        ),
        throwsStateError,
      );
      expect(repo.rowsNow(ContentCollection.foods), isEmpty);
    });

    test('with no server, a save stays on this phone and says so', () async {
      final repo = _repo(null);
      final outcome = await repo.saveToLibrary(
        collection: ContentCollection.foods,
        values: const {'foodId': 'x', 'name_en': 'X'},
      );
      expect(outcome, ContentSaveOutcome.savedHereOnly);
      expect(repo.rowsNow(ContentCollection.foods).single.id, 'x');
    });
  });

  group('a recipe reaches the member app', () {
    test('it is in her library after the member app\'s own sync', () async {
      final docs = InMemoryContentDocuments();
      await _repo(
        docs,
      ).saveToLibrary(collection: ContentCollection.recipes, values: _recipe());

      final seedVersion = (_seed['contentVersion']! as num).toInt();
      expect(docs.docs['meta/recipes'], {'version': seedVersion + 1});
      expect(
        docs.docs.keys,
        containsAll([
          'recipes/om_ali',
          'recipeIndex/en_v${seedVersion + 1}',
          'recipeIndex/ar_v${seedVersion + 1}',
        ]),
      );
      expect(docs.commits, hasLength(1), reason: 'one batch, all or nothing');

      final book = await _memberBook(docs);
      expect(book, isNotNull, reason: 'the member app refused the set');
      final recipe = book!.recipes.firstWhere((r) => r.recipeId == 'om_ali');
      expect(recipe.titleEn, 'Om Ali');
      expect(recipe.titleAr, 'om ali ar');
      expect(
        [for (final s in recipe.steps) s.textAr],
        ['step one', 'step two', 'step three'],
      );
      expect(recipe.allergensFinal, {'nuts', 'dairy'});
      // The seed is still the floor.
      expect(book.recipes.length, greaterThan(1));
    });

    test('a second recipe keeps the first in the index', () async {
      final docs = InMemoryContentDocuments();
      final repo = _repo(docs);
      await repo.saveToLibrary(
        collection: ContentCollection.recipes,
        values: _recipe(),
      );
      await repo.saveToLibrary(
        collection: ContentCollection.recipes,
        values: _recipe(id: 'basbousa'),
      );
      final book = await _memberBook(docs);
      final ids = {for (final r in book!.recipes) r.recipeId};
      expect(ids, containsAll(['om_ali', 'basbousa']));
    });

    test(
      'an edit bumps the recipe\'s own version so it replaces the old',
      () async {
        final docs = InMemoryContentDocuments();
        final repo = _repo(docs);
        await repo.saveToLibrary(
          collection: ContentCollection.recipes,
          values: _recipe(),
        );
        await repo.saveToLibrary(
          collection: ContentCollection.recipes,
          values: {..._recipe(), 'name_en': 'Om Ali, warm'},
        );
        expect(docs.docs['recipes/om_ali']!['version'], 2);
        final book = await _memberBook(docs);
        expect(
          book!.recipes.firstWhere((r) => r.recipeId == 'om_ali').titleEn,
          'Om Ali, warm',
        );
      },
    );

    test('a draft is stored, and never in a member\'s library', () async {
      final docs = InMemoryContentDocuments();
      await _repo(docs).saveToLibrary(
        collection: ContentCollection.recipes,
        values: _recipe(status: 'draft', method: ''),
      );
      expect(docs.docs.keys, contains('recipes/om_ali'));
      final book = await _memberBook(docs);
      expect(
        (book?.recipes ?? const []).where((r) => r.recipeId == 'om_ali'),
        isEmpty,
      );
    });

    test(
      'one the member app would refuse is refused, and nothing is written',
      () async {
        final docs = InMemoryContentDocuments();
        final repo = _repo(docs);
        for (final bad in [
          // No steps.
          (values: _recipe(), method: '   '),
          // The author checked her own allergens.
          (values: _recipe(reviewer: 'content_team'), method: _method),
          // Half the macros.
          (values: _recipe(kcal: '300'), method: _method),
          // A section her book does not have.
          (values: {..._recipe(), 'sectionId': 'nowhere'}, method: _method),
        ]) {
          await expectLater(
            repo.saveToLibrary(
              collection: ContentCollection.recipes,
              values: {...bad.values, 'method_ar': bad.method},
            ),
            throwsA(isA<RecipeNotReady>()),
          );
        }
        expect(docs.docs, isEmpty);
        expect(repo.rowsNow(ContentCollection.recipes), isEmpty);
      },
    );

    test('the console opens it again exactly as it was saved', () async {
      final docs = InMemoryContentDocuments();
      await _repo(
        docs,
      ).saveToLibrary(collection: ContentCollection.recipes, values: _recipe());
      final again = _repo(docs);
      await again.loadFromServer();
      expect(again.rowsNow(ContentCollection.recipes).single.values, _recipe());
      expect(
        again.rowsNow(ContentCollection.recipes).single.value('method_ar'),
        _method,
      );
    });
  });
}
