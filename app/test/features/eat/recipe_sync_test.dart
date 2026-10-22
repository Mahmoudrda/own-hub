// The Firestore half of the recipe library, against a fake source.
//
// What has to hold, whatever the network does:
//   * no network, no Firebase or any error: she gets the bundled seed;
//   * a newer version is swapped in whole, never a recipe at a time;
//   * a remote set that fails the seed's own safety rules is refused whole;
//   * the version document is read at most once a day;
//   * the allergy filter treats a remote recipe exactly like a seeded one.

import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/app_state/local_persistence.dart';
import 'package:own_hub/features/eat/data/firestore_recipe_source.dart';
import 'package:own_hub/features/eat/data/recipe_sync.dart';
import 'package:own_hub/features/eat/data/seeded_recipe_library.dart';
import 'package:own_hub/features/eat/domain/allergy_guard.dart';
import 'package:own_hub/features/eat/domain/recipe_validation.dart';

late Map<String, Object?> _raw;

class _MemoryStorage implements SnapshotStorage {
  String? value;
  int writes = 0;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String snapshot) async {
    writes++;
    value = snapshot;
  }

  @override
  Future<void> erase() async => value = null;
}

class _FakeSource implements RecipeRemoteSource {
  int? version;
  Map<String, Object?>? index;
  final Map<String, Map<String, Object?>> recipes = {};

  /// Thrown from every read, as the network would.
  Object? offline;

  /// Thrown only from this one recipe read, after the others succeeded.
  String? failOn;

  int versionReads = 0;
  int indexReads = 0;
  int recipeReads = 0;

  @override
  Future<int?> readVersion() async {
    versionReads++;
    if (offline != null) throw offline!;
    return version;
  }

  @override
  Future<Map<String, Object?>?> readIndex(int version) async {
    indexReads++;
    if (offline != null) throw offline!;
    return index;
  }

  @override
  Future<Map<String, Object?>?> readRecipe(String recipeId) async {
    recipeReads++;
    if (offline != null) throw offline!;
    if (recipeId == failOn) throw const SocketException('dropped');
    return recipes[recipeId];
  }
}

class _SeedOnly implements RecipeLibrary {
  @override
  Future<RecipeBook> load() async => RecipeBook.fromJson(_raw);
}

List<Map<String, Object?>> _seedRecipes() => [
  for (final r in (_raw['recipes']! as List))
    Map<String, Object?>.from((r as Map).cast<String, Object?>()),
];

/// A complete, valid remote library at [version]: every seeded recipe, one
/// of them edited (version 2), and one new dish.
_FakeSource _remote({int version = 2}) {
  final source = _FakeSource()..version = version;
  final all = _seedRecipes();
  final lazy = all.firstWhere((r) => r['recipeId'] == 'rahma_lazy_cake');
  lazy['version'] = 2;
  lazy['titleEn'] = 'Lazy Cake, second print';
  all.add({
    ...all.first,
    'recipeId': 'rahma_new_dish',
    'titleEn': 'New dish',
    'titleSearch': ['new dish'],
    'bodyAr': 'سطر أول\nسطر تاني بالظبط زي ما هي كتبته',
    'allergensDerived': <String>[],
    'allergensExtra': <String>[],
    'allergensRemoved': <String, Object?>{},
    'allergensFinal': <String>[],
    // Nobody has cooked or checked the new dish, so it is a review row: copied
    // from a published recipe it would claim a signature it does not have.
    'status': 'review',
    'allergenReviewedBy': null,
    'allergenReviewedAt': null,
    'cookedBy': null,
    'cookedAt': null,
    // Nor has the script, and a record copied from another recipe would claim
    // it derived that recipe's allergens.
    'verification': null,
  });
  for (final r in all) {
    source.recipes[r['recipeId']! as String] = r;
  }
  source.index = {
    'version': version,
    'locale': 'en',
    'sections': _raw['sections'],
    'rows': <Object?>[
      for (final r in all)
        {
          'recipeId': r['recipeId'],
          'status': r['status'],
          'tier': r['tier'],
          'source': r['source'],
        },
    ],
  };
  return source;
}

class _Clock {
  DateTime now = DateTime.utc(2026, 10, 4, 9);
  DateTime call() => now;
}

RecipeSync _sync({
  RecipeRemoteSource? source,
  bool available = true,
  _MemoryStorage? cache,
  _MemoryStorage? checks,
  _Clock? clock,
}) => RecipeSync(
  seed: _SeedOnly(),
  source: () => available ? source : null,
  cache: cache ?? _MemoryStorage(),
  checks: checks ?? _MemoryStorage(),
  now: (clock ?? _Clock()).call,
);

void main() {
  setUpAll(() {
    _raw = (jsonDecode(
      File('assets/content/rahma_recipes.json').readAsStringSync(),
    ) as Map).cast<String, Object?>();
  });

  group('the seed is the fallback', () {
    test('offline gives the seed, and nothing is cached', () async {
      final source = _remote()..offline = const SocketException('no signal');
      final cache = _MemoryStorage();
      final sync = _sync(source: source, cache: cache);

      final result = await sync.refresh();
      expect(result.outcome, RecipeRefreshOutcome.failed);
      expect(result.book, isNull);

      final book = await sync.load();
      expect(book.contentVersion, 1);
      expect(book.byId('rahma_new_dish'), isNull);
      expect(cache.value, isNull);
    });

    test('Firebase unavailable gives the seed and reads nothing', () async {
      final source = _remote();
      final sync = _sync(source: source, available: false);

      final result = await sync.refresh();
      expect(result.outcome, RecipeRefreshOutcome.unavailable);
      expect(source.versionReads, 0);
      expect((await sync.load()).contentVersion, 1);
    });

    test('a corrupt cache is ignored and the seed is used', () async {
      final cache = _MemoryStorage()..value = '{not json';
      final book = await _sync(cache: cache).load();
      expect(book.contentVersion, 1);
      expect(book.recipes, hasLength(50));
    });
  });

  group('a newer version', () {
    test('is swapped in whole, cached, and survives a restart', () async {
      final source = _remote();
      final cache = _MemoryStorage();
      final sync = _sync(source: source, cache: cache);

      final result = await sync.refresh();
      expect(result.outcome, RecipeRefreshOutcome.updated);
      final book = result.book!;
      expect(book.contentVersion, 2);
      expect(book.recipes, hasLength(51));
      expect(book.byId('rahma_lazy_cake')!.titleEn, 'Lazy Cake, second print');
      // Her letter is not in the remote set and stays.
      expect(book.letterAr, RecipeBook.fromJson(_raw).letterAr);

      // A fresh start reads the cache, not the network.
      final again = await _sync(source: _FakeSource(), cache: cache).load();
      expect(again.contentVersion, 2);
      expect(again.byId('rahma_new_dish'), isNotNull);
    });

    test('recipe text arrives exactly as written', () async {
      final source = _remote();
      final book = (await _sync(source: source).refresh()).book!;
      expect(
        book.byId('rahma_new_dish')!.bodyAr,
        'سطر أول\nسطر تاني بالظبط زي ما هي كتبته',
      );
    });

    test(
      'a read that fails halfway swaps nothing and caches nothing',
      () async {
        final source = _remote()..failOn = 'rahma_new_dish';
        final cache = _MemoryStorage();
        final sync = _sync(source: source, cache: cache);

        final result = await sync.refresh();
        expect(result.outcome, RecipeRefreshOutcome.failed);
        expect(result.book, isNull);
        expect(cache.value, isNull);
        expect((await sync.load()).contentVersion, 1);
      },
    );

    test(
      'the same version reads one small document and nothing else',
      () async {
        final source = _remote(version: 1);
        final result = await _sync(source: source).refresh();
        expect(result.outcome, RecipeRefreshOutcome.upToDate);
        expect(source.versionReads, 1);
        expect(source.indexReads, 0);
        expect(source.recipeReads, 0);
      },
    );

    test('a pro row is not fetched while nothing can be sold', () async {
      final source = _remote();
      (source.index!['rows']! as List).add({
        'recipeId': 'rahma_pro_only',
        'status': 'review',
        'tier': 'pro',
        'source': 'authored',
      });
      final result = await _sync(source: source).refresh();
      expect(result.outcome, RecipeRefreshOutcome.updated);
      expect(result.book!.byId('rahma_pro_only'), isNull);
    });
  });

  group('an invalid remote set is refused whole', () {
    Future<void> expectRejected(_FakeSource source) async {
      final cache = _MemoryStorage();
      final sync = _sync(source: source, cache: cache);
      final result = await sync.refresh();
      expect(result.outcome, RecipeRefreshOutcome.rejected);
      expect(result.book, isNull);
      expect(cache.value, isNull);
      final book = await sync.load();
      expect(book.contentVersion, 1);
      expect(book.byId('rahma_new_dish'), isNull);
    }

    test('an allergen dropped without a reason', () async {
      final source = _remote();
      source.recipes['rahma_lazy_cake']!['allergensFinal'] = ['eggs', 'gluten'];
      await expectRejected(source);
    });

    test('a removed allergen with no written reason', () async {
      final source = _remote();
      final r = source.recipes['rahma_lazy_cake']!;
      r['allergensRemoved'] = {'milk': ' '};
      r['allergensFinal'] = ['eggs', 'gluten'];
      await expectRejected(source);
    });

    test('a signature by the author herself', () async {
      final source = _remote();
      final dish = source.recipes['rahma_new_dish']!;
      dish['authoredBy'] = 'rahma_mohsen';
      dish['allergenReviewedBy'] = 'rahma_mohsen';
      await expectRejected(source);
    });

    test('a recipe the index names but the server does not have', () async {
      final source = _remote();
      source.recipes.remove('rahma_new_dish');
      await expectRejected(source);
    });

    test('a document whose id does not match its row', () async {
      final source = _remote();
      source.recipes['rahma_new_dish']!['recipeId'] = 'something_else';
      await expectRejected(source);
    });

    test('a recipe in a section nobody declared', () async {
      final source = _remote();
      source.recipes['rahma_new_dish']!['sectionId'] = 'no_such_section';
      await expectRejected(source);
    });

    test('a field of the wrong type', () async {
      final source = _remote();
      source.recipes['rahma_new_dish']!['version'] = 'two';
      await expectRejected(source);
    });

    test('an index for a different version', () async {
      final source = _remote();
      source.index!['version'] = 3;
      await expectRejected(source);
    });

    test('an empty index', () async {
      final source = _remote();
      source.index!['rows'] = <Object?>[];
      await expectRejected(source);
    });

    test('a dash the seed would never ship', () async {
      final source = _remote();
      source.recipes['rahma_new_dish']!['bodyAr'] = 'من ٥ \u2013 ٦ دقايق';
      await expectRejected(source);
    });

    test('a pro tier on a row that said free', () async {
      final source = _remote();
      source.recipes['rahma_new_dish']!['tier'] = 'pro';
      await expectRejected(source);
    });
  });

  group('cheap reads', () {
    test('the version is read once a day, across restarts', () async {
      final source = _remote(version: 1);
      final checks = _MemoryStorage();
      final clock = _Clock();

      await _sync(source: source, checks: checks, clock: clock).refresh();
      final sync = _sync(source: source, checks: checks, clock: clock);
      clock.now = clock.now.add(const Duration(hours: 5));
      expect((await sync.refresh()).outcome, RecipeRefreshOutcome.notDue);
      expect((await sync.refresh()).outcome, RecipeRefreshOutcome.notDue);
      // A restart later the same day.
      clock.now = clock.now.add(const Duration(hours: 10));
      await _sync(source: source, checks: checks, clock: clock).refresh();
      expect(source.versionReads, 1);

      clock.now = clock.now.add(const Duration(hours: 10));
      await _sync(source: source, checks: checks, clock: clock).refresh();
      expect(source.versionReads, 2);
    });

    test(
      'a failed check backs off instead of retrying on every open',
      () async {
        final source = _remote()..offline = const SocketException('no signal');
        final clock = _Clock();
        final sync = _sync(source: source, clock: clock);
        await sync.refresh();
        await sync.refresh();
        expect(source.versionReads, 1);
        clock.now = clock.now.add(const Duration(hours: 2));
        source.offline = null;
        expect((await sync.refresh()).outcome, RecipeRefreshOutcome.updated);
        expect(source.versionReads, 2);
      },
    );

    test('a download cut short leaves no "checked" stamp, so the next launch '
        'asks again', () async {
      final source = _remote();
      final checks = _MemoryStorage();
      final cache = _MemoryStorage();
      final clock = _Clock();
      source.failOn = source.recipes.keys.first;

      final first = await _sync(
        source: source,
        cache: cache,
        checks: checks,
        clock: clock,
      ).refresh();
      expect(first.outcome, RecipeRefreshOutcome.failed);
      expect(checks.value, isNull);
      expect(cache.value, isNull);

      source.failOn = null;
      final second = await _sync(
        source: source,
        cache: cache,
        checks: checks,
        clock: clock,
      ).refresh();
      expect(second.outcome, RecipeRefreshOutcome.updated);
      expect(checks.value, isNotNull);
      expect(source.versionReads, 2);
    });

    test('a server read gives up after ten seconds', () {
      expect(FirestoreRecipeSource.readTimeout, const Duration(seconds: 10));
    });

    test('a full fetch happens only on a version bump', () async {
      final source = _remote();
      final cache = _MemoryStorage();
      final checks = _MemoryStorage();
      final clock = _Clock();
      await _sync(
        source: source,
        cache: cache,
        checks: checks,
        clock: clock,
      ).refresh();
      final fetched = source.recipeReads;
      expect(source.indexReads, 1);

      clock.now = clock.now.add(const Duration(days: 2));
      final result = await _sync(
        source: source,
        cache: cache,
        checks: checks,
        clock: clock,
      ).refresh();
      expect(result.outcome, RecipeRefreshOutcome.upToDate);
      expect(source.indexReads, 1);
      expect(source.recipeReads, fetched);
    });
  });

  group('the allergy filter still applies', () {
    test(
      'an unsigned remote recipe is hidden from a woman with an allergy',
      () async {
        final source = _remote();
        source.recipes['rahma_signed_nuts'] = {
          ...source.recipes['rahma_new_dish']!,
          'recipeId': 'rahma_signed_nuts',
          'allergensDerived': ['tree_nuts'],
          'allergensFinal': ['tree_nuts'],
          'allergenReviewedBy': 'qa_dietitian',
        };
        source.recipes['rahma_signed_plain'] = {
          ...source.recipes['rahma_new_dish']!,
          'recipeId': 'rahma_signed_plain',
          'allergenReviewedBy': 'qa_dietitian',
        };
        (source.index!['rows']! as List).addAll(<Object?>[
          {'recipeId': 'rahma_signed_nuts', 'status': 'review', 'tier': 'free'},
          {
            'recipeId': 'rahma_signed_plain',
            'status': 'review',
            'tier': 'free',
          },
        ]);
        final book = (await _sync(source: source).refresh()).book!;

        const allergic = DietaryConstraints(
          allergies: {'tree_nuts'},
          dietary: <String>{},
        );
        final shown = AllergyGuard(allergic).screenRecipes(book.recipes);
        final ids = shown.map((r) => r.recipeId).toSet();
        expect(ids, isNot(contains('rahma_new_dish')));
        expect(ids, isNot(contains('rahma_signed_nuts')));
        expect(ids, contains('rahma_signed_plain'));

        // Without a declared allergy the unsigned dish is still there, as the
        // seeded ones are.
        final everyone = AllergyGuard(DietaryConstraints.none)
            .screenRecipes(book.recipes)
            .map((r) => r.recipeId);
        expect(everyone, contains('rahma_new_dish'));
      },
    );
  });

  group('a remote recipe verified by the automated check', () {
    Map<String, Object?> checked(String id, List<String> allergens) => {
      ..._seedRecipes().firstWhere(
        (r) => r['recipeId'] == 'ownhub_shish_tawook_bowl',
      ),
      'recipeId': id,
      'allergensDerived': allergens,
      'allergensExtra': <String>[],
      'allergensRemoved': <String, Object?>{},
      'allergensFinal': allergens,
      'verification': {
        'method': 'ownhub-auto-check-v1',
        'checkedAt': '2026-10-21T00:00:00Z',
        'macroDeltaPct': 0.0,
        'allergensDerived': allergens,
      },
    };

    test('publishes with no signature and reaches an allergic woman', () async {
      final source = _remote();
      source.recipes['rahma_checked_plain'] = checked('rahma_checked_plain', [
        'milk',
      ]);
      source.recipes['rahma_checked_nuts'] = checked('rahma_checked_nuts', [
        'tree_nuts',
      ]);
      (source.index!['rows']! as List).addAll(<Object?>[
        {'recipeId': 'rahma_checked_plain', 'status': 'published'},
        {'recipeId': 'rahma_checked_nuts', 'status': 'published'},
      ]);
      final result = await _sync(source: source).refresh();
      expect(result.outcome, RecipeRefreshOutcome.updated);

      final shown = AllergyGuard(
        const DietaryConstraints(allergies: {'tree_nuts'}, dietary: {}),
      ).screenRecipes(result.book!.recipes).map((r) => r.recipeId).toSet();
      expect(shown, contains('rahma_checked_plain'));
      expect(shown, isNot(contains('rahma_checked_nuts')));
    });

    test('a record that omits what it derived refuses the whole set', () async {
      final source = _remote();
      final bad = checked('rahma_checked_bad', ['milk']);
      (bad['verification']! as Map)['allergensDerived'] = ['milk', 'peanuts'];
      source.recipes['rahma_checked_bad'] = bad;
      (source.index!['rows']! as List).add(<String, Object?>{
        'recipeId': 'rahma_checked_bad',
        'status': 'published',
      });
      final result = await _sync(source: source).refresh();
      expect(result.outcome, RecipeRefreshOutcome.rejected);
    });

    test(
      'published with neither a signature nor a record is refused',
      () async {
        final source = _remote();
        final bare = checked('rahma_checked_bare', ['milk'])
          ..['verification'] = null;
        source.recipes['rahma_checked_bare'] = bare;
        (source.index!['rows']! as List).add(<String, Object?>{
          'recipeId': 'rahma_checked_bare',
          'status': 'published',
        });
        final result = await _sync(source: source).refresh();
        expect(result.outcome, RecipeRefreshOutcome.rejected);
      },
    );
  });

  group('the same rules as the seed', () {
    test('every shipped recipe passes the remote validator', () {
      final book = RecipeBook.fromJson(_raw);
      final sections = {for (final s in book.sections) s.sectionId};
      for (final r in book.recipes) {
        expect(
          recipeProblems(r, sectionIds: sections),
          isEmpty,
          reason: r.recipeId,
        );
      }
    });
  });

  group('Firestore values', () {
    test('a timestamp becomes the ISO string the model reads', () {
      final plain = plainFirestoreData({
        'allergenReviewedAt': Timestamp.fromDate(DateTime.utc(2026, 9, 1)),
        'steps': [
          {'textAr': 'كما هي', 'at': Timestamp.fromDate(DateTime.utc(2026))},
        ],
      });
      expect(plain['allergenReviewedAt'], '2026-09-01T00:00:00.000Z');
      expect(((plain['steps']! as List).first as Map)['textAr'], 'كما هي');
    });
  });
}
