// The foods other women shared: read from the cache, checked once a day,
// merged into search, and gone from the phone when she deletes her data.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/account_data.dart';
import 'package:own_hub/app_state/community_foods_state.dart';
import 'package:own_hub/app_state/local_persistence.dart';
import 'package:own_hub/features/eat/data/community_foods_sync.dart';
import 'package:own_hub/features/eat/domain/community_foods.dart';
import 'package:own_hub/features/eat/domain/food_library.dart';
import 'package:own_hub/features/eat/domain/meal_scan.dart';
import 'package:own_hub/features/eat/presentation/eat_sample_library.dart';
import 'package:own_hub/l10n/app_l10n_ar.dart';
import 'package:own_hub/l10n/app_l10n_en.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Memory implements SnapshotStorage {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String snapshot) async => value = snapshot;

  @override
  Future<void> erase() async => value = null;
}

class _Source implements CommunityFoodsRemoteSource {
  _Source(this.version, this.doc);

  int? version;
  Map<String, Object?>? doc;
  int versionReads = 0;
  int listReads = 0;

  @override
  Future<int?> readVersion() async {
    versionReads++;
    return version;
  }

  @override
  Future<Map<String, Object?>?> readFoods() async {
    listReads++;
    return doc;
  }
}

Map<String, Object?> _row(String key, {String nameEn = 'Hawawshi'}) => {
  'id': 'community_$key',
  'nameEn': nameEn,
  'nameAr': 'حواوشي',
  'category': 'egyptianDishes',
  'allergens': ['gluten'],
  'kcal': 520,
  'proteinG': 24,
  'carbsG': 40,
  'fatG': 28,
  'items': [
    {'name': 'bread', 'grams': 100},
  ],
};

Map<String, Object?> _doc(int version, [List<Object?>? foods]) => {
  'version': version,
  'foods': foods ?? [_row('hawawshi')],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final state = CommunityFoodsState.instance;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    state.reset();
  });
  tearDown(state.reset);

  group('parsing', () {
    test('a good food keeps its allergens, category and figures', () {
      final list = CommunityFoods.parse(_doc(3))!;
      expect(list.version, 3);
      final food = list.foods.single;
      expect(food.allergens, {'gluten'});
      expect(food.category, FoodCategory.egyptianDishes);
      expect(food.kcal, 520);
    });

    test('a food with no items key parses and merges', () {
      final row = _row('plain')..remove('items');
      final list = CommunityFoods.parse(_doc(2, [row]))!;
      expect(list.foods.map((f) => f.id), ['community_plain']);
      expect(list.foods.single.toFood(arabic: false).community, isTrue);
      expect(list.foods.single.toJson().keys, isNot(contains('items')));
    });

    test('a bad row is dropped, not the list; no allergen record is bad', () {
      final noAllergens = _row('x')..remove('allergens');
      final list = CommunityFoods.parse(
        _doc(1, [
          _row('ok'),
          noAllergens,
          {'id': 'other_1', 'nameEn': 'x'},
          'junk',
          {..._row('z'), 'kcal': 0},
        ]),
      )!;
      expect(list.foods.map((f) => f.id), ['community_ok']);
      expect(CommunityFoods.parse('nope'), isNull);
    });

    test('as a food: one serving, her language first, marked community', () {
      final row = CommunityFood.parse(_row('hawawshi'))!;
      final ar = row.toFood(arabic: true);
      expect(ar.names, ['حواوشي', 'Hawawshi']);
      expect(ar.community, isTrue);
      expect(ar.custom, isTrue);
      expect(ar.sizes.single.kcal, 520);
      expect(ar.allergens, {'gluten'});
      expect(row.toFood(arabic: false).names.first, 'Hawawshi');
    });
  });

  group('the daily check', () {
    late _Memory cache;
    late _Memory checks;
    late DateTime now;

    CommunityFoodsSync syncOver(_Source source) => CommunityFoodsSync(
      source: () => source,
      cache: cache,
      checks: checks,
      now: () => now,
    );

    setUp(() {
      cache = _Memory();
      checks = _Memory();
      now = DateTime.utc(2026, 10, 20, 9);
    });

    test(
      'fetches the list only when the version is newer, then caches',
      () async {
        final source = _Source(2, _doc(2));
        final sync = syncOver(source);
        final (outcome, foods) = await sync.refresh();
        expect(outcome, CommunityFoodsRefreshOutcome.updated);
        expect(foods!.foods, hasLength(1));
        expect((await sync.load()).version, 2);
        expect(jsonDecode(cache.value!)['version'], 2);

        now = now.add(const Duration(days: 1, minutes: 1));
        source.listReads = 0;
        final again = await syncOver(source).refresh();
        expect(again.$1, CommunityFoodsRefreshOutcome.upToDate);
        expect(source.listReads, 0);
      },
    );

    test('at most once a day once she holds a list', () async {
      final source = _Source(2, _doc(2));
      await syncOver(source).refresh();
      now = now.add(const Duration(hours: 5));
      source.versionReads = 0;
      final again = await syncOver(source).refresh();
      expect(again.$1, CommunityFoodsRefreshOutcome.notDue);
      expect(source.versionReads, 0);
    });

    test('offline keeps the cached list and says unavailable', () async {
      cache.value = jsonEncode(CommunityFoods.parse(_doc(5))!.toJson());
      final sync = CommunityFoodsSync(
        source: () => null,
        cache: cache,
        checks: checks,
        now: () => now,
      );
      expect(
        (await sync.refresh()).$1,
        CommunityFoodsRefreshOutcome.unavailable,
      );
      expect((await sync.load()).version, 5);
    });

    test('a list whose version disagrees is refused and not cached', () async {
      final sync = syncOver(_Source(4, _doc(3)));
      expect((await sync.refresh()).$1, CommunityFoodsRefreshOutcome.rejected);
      expect(cache.value, isNull);
    });
  });

  group('search', () {
    test('community foods are merged into the library and found by name', () {
      state.list = CommunityFoods.parse(_doc(1))!;
      final en = eatSampleLibrary(AppL10nEn());
      final food = en.byId('community_hawawshi');
      expect(food, isNotNull);
      expect(food!.community, isTrue);
      expect(
        en.resolve('hawawshi').map((f) => f.foodId),
        contains('community_hawawshi'),
      );
      final ar = eatSampleLibrary(AppL10nAr());
      expect(
        ar.resolve('حواوشي').map((f) => f.foodId),
        contains('community_hawawshi'),
      );
      expect(ar.byId('community_hawawshi')!.names.first, 'حواوشي');
    });

    test('with no list, the library is what it was', () {
      expect(
        eatSampleLibrary(AppL10nEn()).foods.where((f) => f.community),
        isEmpty,
      );
    });

    test('refresh adopts the cached list at once', () async {
      final cache = _Memory()
        ..value = jsonEncode(CommunityFoods.parse(_doc(7))!.toJson());
      state.sync = CommunityFoodsSync(
        source: () => null,
        cache: cache,
        checks: _Memory(),
      );
      await state.refresh();
      expect(state.list.version, 7);
      expect(state.foodsFor(arabic: false).single.foodId, 'community_hawawshi');
    });
  });

  group('this phone', () {
    test(
      'deleting her data removes the list, its check and her choice',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          kCommunityFoodsCacheKey: '{"version":3}',
          kCommunityFoodsCheckKey: '2026-10-14T08:00:00.000Z',
          kShareDishesKey: true,
          kShareDishesSeenKey: true,
          'unrelated.key': 'kept',
        });
        state.list = CommunityFoods.parse(_doc(3))!;
        await state.loadSettings();
        expect(state.sharing, isTrue);

        await const ThisPhoneWipe().clearPersistence();
        await pumpEventQueue();

        final prefs = await SharedPreferences.getInstance();
        for (final key in [
          kCommunityFoodsCacheKey,
          kCommunityFoodsCheckKey,
          kShareDishesKey,
          kShareDishesSeenKey,
        ]) {
          expect(prefs.containsKey(key), isFalse, reason: key);
        }
        expect(prefs.getString('unrelated.key'), 'kept');
        expect(state.list.isEmpty, isTrue);
        expect(state.sharing, isFalse, reason: 'back to the default: off');
      },
    );
  });

  test('a scan answer says whether it came from the cache', () {
    final base = {
      'items': [
        {'nameEn': 'Egg', 'nameAr': 'بيض', 'grams': 50},
      ],
    };
    expect(MealScanResult.fromWire({...base, 'cached': true})!.cached, isTrue);
    expect(
      MealScanResult.fromWire({...base, 'cached': false})!.cached,
      isFalse,
    );
    expect(MealScanResult.fromWire(base)!.cached, isFalse);
  });
}
