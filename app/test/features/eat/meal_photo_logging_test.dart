// Carbs, fat and fibre from the plate she checked on E13 to every place a
// meal lives: the write, the day's totals, the snapshot on the phone and the
// copy in the cloud. And a meal logged before they existed still reads back
// exactly as it was written.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/account_data.dart';
import 'package:own_hub/app_state/app_snapshot.dart';
import 'package:own_hub/app_state/cloud_documents.dart';
import 'package:own_hub/app_state/eat_state.dart';
import 'package:own_hub/domain/week/week_key.dart';
import 'package:own_hub/features/eat/domain/allergy_guard.dart';
import 'package:own_hub/features/eat/domain/day_totals.dart';
import 'package:own_hub/features/eat/domain/food_library.dart';
import 'package:own_hub/features/eat/domain/meal_check.dart';
import 'package:own_hub/features/eat/domain/meal_day_reader.dart';
import 'package:own_hub/features/eat/domain/meal_log_service.dart';
import 'package:own_hub/features/eat/domain/meal_repository.dart';
import 'package:own_hub/features/eat/presentation/meal_log_session.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _day = '2026-10-17';
final DateTime _at = DateTime(2026, 10, 17, 13, 30);

const List<CheckedEntry> _plate = [
  CheckedEntry(
    foodId: '${kPhotoFoodPrefix}dish_koshary',
    name: 'Koshary',
    grams: 300,
    kcal: 450,
    proteinG: 15,
    carbsG: 81,
    fatG: 8,
    fiberG: 9,
  ),
  CheckedEntry(
    foodId: '${kPhotoFoodPrefix}usda_173424',
    name: 'Boiled egg',
    grams: 50,
    kcal: 78,
    proteinG: 6,
    carbsG: 1,
    fatG: 5,
  ),
];

MealLogService _service(
  MealRepository repository, {
  DietaryConstraints constraints = DietaryConstraints.none,
}) => MealLogService(
  repository: repository,
  library: FoodLibrary.empty,
  guard: AllergyGuard(constraints),
);

MealItem _photoItem() => MealItem(
  itemId: 'photo-1',
  foodId: '${kPhotoFoodPrefix}dish_koshary',
  servings: 1,
  size: '',
  loggedAt: _at,
  source: MealSource.search,
  origin: MealOrigin.photo,
  kcal: 450,
  proteinG: 15,
  carbsG: 81,
  fatG: 8,
  fiberG: 9,
  name: 'Koshary',
  grams: 300,
);

MealItem _oldItem() => MealItem(
  itemId: 'old-1',
  foodId: 'koshari_bowl',
  servings: 1,
  size: 'M',
  loggedAt: _at.subtract(const Duration(hours: 4)),
  source: MealSource.search,
  origin: MealOrigin.search,
  kcal: 540,
  proteinG: 18,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('logChecked', () {
    test('writes carbs, fat, fibre, her name and the weight she approved', () {
      final outcome = _service(InMemoryMealRepository()).logChecked(
        day: const MealDay(dayId: _day),
        slot: MealSlot.lunch,
        entries: _plate,
        at: _at,
      );
      final prepared = outcome as MealLogPrepared;
      final koshary = prepared.items.first;
      expect(koshary.origin, MealOrigin.photo);
      expect(koshary.source, MealSource.search);
      expect(koshary.name, 'Koshary');
      expect(koshary.grams, 300);
      expect(koshary.carbsG, 81);
      expect(koshary.fatG, 8);
      expect(koshary.fiberG, 9);
      expect(prepared.items[1].fiberG, isNull);
      expect(prepared.write.kcalDelta, 528);
      expect(prepared.write.carbsDelta, 82);
      expect(prepared.write.fatDelta, 13);
      expect(prepared.write.fiberDelta, 9);
      expect(prepared.items.map((i) => i.itemId).toSet(), hasLength(2));
    });

    test('nothing reaches the repository until the bus commits it', () async {
      final repository = InMemoryMealRepository();
      final session = MealLogSession(repository: repository);
      final prepared = _service(repository).logChecked(
        day: const MealDay(dayId: _day),
        slot: MealSlot.lunch,
        entries: _plate,
        at: _at,
      ) as MealLogPrepared;
      expect(repository.writes, isEmpty, reason: 'building is not writing');

      session.submit(prepared, slot: MealSlot.lunch, describe: 'Meal added');
      expect(repository.writes, isEmpty, reason: 'inside the undo window');

      session.flushNow();
      await Future<void>.delayed(Duration.zero);
      final day = await repository.day(_day);
      expect(day.itemsIn(MealSlot.lunch).first.carbsG, 81);
      expect(
        (await repository.prefs()).plates,
        isEmpty,
        reason:
            'a photographed plate is never offered back as a one-tap '
            'plate it cannot be logged from',
      );
    });

    test('a woman with an allergy still logs a photographed plate', () {
      final outcome =
          _service(
            InMemoryMealRepository(),
            constraints: const DietaryConstraints(
              allergies: {'nuts'},
              dietary: <String>{},
            ),
          ).logChecked(
            day: const MealDay(dayId: _day),
            slot: MealSlot.lunch,
            entries: _plate,
            at: _at,
          );
      expect(outcome, isA<MealLogPrepared>());
    });

    test('an empty plate writes nothing', () {
      expect(
        _service(InMemoryMealRepository()).logChecked(
          day: const MealDay(dayId: _day),
          slot: MealSlot.lunch,
          entries: const [],
          at: _at,
        ),
        isA<MealLogRefused>(),
      );
    });
  });

  group('the day totals', () {
    test('include carbs, fat and fibre over the items that carry them', () {
      final totals = DayTotals.recompute([_photoItem(), _oldItem()]);
      expect(totals.kcalSoFar, 990);
      expect(totals.proteinSoFar, 33);
      expect(totals.carbsSoFar, 81);
      expect(totals.fatSoFar, 8);
      expect(totals.fiberSoFar, 9);
      expect(totals.hasMoreMacros, isTrue);
    });

    test('a day of older meals carries none of them, not zeros', () {
      final totals = const MealDayReader().totals(
        MealDay(
          dayId: _day,
          slots: {
            MealSlot.lunch: [_oldItem()],
          },
        ),
      );
      expect(totals.carbsSoFar, isNull);
      expect(totals.fatSoFar, isNull);
      expect(totals.fiberSoFar, isNull);
      expect(totals.hasMoreMacros, isFalse);
    });
  });

  group('where meals are kept', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues(const <String, Object>{});
      await const ThisPhoneWipe().clearPersistence();
    });
    tearDown(() async => const ThisPhoneWipe().clearPersistence());

    void logBoth() {
      AppRouter.mealRepository.store.apply(
        MealWrite.transform(
          dayId: _day,
          slot: MealSlot.lunch,
          tz: WeekKey.fallbackTimezone,
          libVersion: 1,
          added: [_oldItem(), _photoItem()],
        ),
      );
    }

    test('the snapshot round trip keeps every new field', () async {
      logBoth();
      final document = jsonEncode(AppSnapshot.capture());
      await const ThisPhoneWipe().clearPersistence();
      AppSnapshot.restore(document);

      final items = AppRouter.mealRepository.store.days[_day]!.itemsIn(
        MealSlot.lunch,
      );
      final photo = items.firstWhere((i) => i.itemId == 'photo-1');
      expect(photo.origin, MealOrigin.photo);
      expect(photo.carbsG, 81);
      expect(photo.fatG, 8);
      expect(photo.fiberG, 9);
      expect(photo.name, 'Koshary');
      expect(photo.grams, 300);
      final old = items.firstWhere((i) => i.itemId == 'old-1');
      expect(old.carbsG, isNull);
      expect(old.name, isNull);
      expect(old.grams, isNull);
    });

    test('a snapshot written before carbs, fat and fibre still loads', () {
      logBoth();
      final document =
          jsonDecode(jsonEncode(AppSnapshot.capture())) as Map<String, Object?>;
      // Take the new keys back out, as an older build wrote them.
      final text = jsonEncode(document)
          .replaceAll(RegExp(r',"carbsG":\d+'), '')
          .replaceAll(RegExp(r',"fatG":\d+'), '')
          .replaceAll(RegExp(r',"fiberG":\d+'), '')
          .replaceAll(RegExp(r',"name":"Koshary"'), '')
          .replaceAll(RegExp(r',"grams":\d+'), '');
      expect(text.contains('carbsG'), isFalse);
      return const ThisPhoneWipe().clearPersistence().then((_) async {
        AppSnapshot.restore(text);
        final items = AppRouter.mealRepository.store.days[_day]!.itemsIn(
          MealSlot.lunch,
        );
        expect(items, hasLength(2));
        expect(items.every((i) => i.carbsG == null), isTrue);
        expect(items.map((i) => i.kcal), containsAll(<int>[540, 450]));
      });
    });

    test('the cloud copy carries them, and its totals add them up', () async {
      logBoth();
      final captured = CloudDocuments.capture();
      final day = captured.firstWhere(
        (d) => d.collection == 'meals' && d.id == _day,
      );
      final totals = day.data['totals']! as Map<String, Object?>;
      expect(totals['kcal'], 990);
      expect(totals['protein'], 33);
      expect(totals['carbs'], 81);
      expect(totals['fat'], 8);
      expect(totals['fiber'], 9);
      final lunch =
          (day.data['slots']! as Map<String, Object?>)['lunch']!
              as List<Object?>;
      final old = lunch.cast<Map<String, Object?>>().firstWhere(
        (i) => i['itemId'] == 'old-1',
      );
      expect(old.containsKey('carbsG'), isFalse, reason: 'unknown, not zero');

      await const ThisPhoneWipe().clearPersistence();
      CloudDocuments.mergeIn(captured);
      final back = AppRouter.mealRepository.store.days[_day]!
          .itemsIn(MealSlot.lunch)
          .firstWhere((i) => i.itemId == 'photo-1');
      expect(back.fiberG, 9);
      expect(back.name, 'Koshary');
      expect(back.grams, 300);
    });

    test('a cloud day from before them reads back with none', () async {
      CloudDocuments.mergeIn([
        CloudDoc(
          collection: 'meals',
          id: _day,
          data: <String, Object?>{
            'slots': <String, Object?>{
              'lunch': <Object?>[
                <String, Object?>{
                  'itemId': 'old-1',
                  'foodId': 'koshari_bowl',
                  'servings': 1,
                  'size': 'M',
                  'loggedAt': _at,
                  'source': 'search',
                  'origin': 'search',
                  'kcal': 540,
                  'proteinG': 18,
                },
              ],
            },
            'totals': <String, Object?>{'kcal': 540, 'protein': 18},
            'tz': 'Africa/Cairo',
            'libVersion': 1,
          },
        ),
      ]);
      final item = AppRouter.mealRepository.store.days[_day]!
          .itemsIn(MealSlot.lunch)
          .single;
      expect(item.kcal, 540);
      expect(item.carbsG, isNull);
      expect(item.fiberG, isNull);
      expect(item.name, isNull);
    });

    test('a photographed meal is not remembered as a plate on Home', () {
      EatAppState.instance.reset();
      // The committed hook is private; the session it is wired to is the
      // public way in.
      final prepared = _service(AppRouter.mealRepository).logChecked(
        day: const MealDay(dayId: _day),
        slot: MealSlot.lunch,
        entries: _plate,
        at: _at,
      ) as MealLogPrepared;
      EatAppState.instance.session.submit(
        prepared,
        slot: MealSlot.lunch,
        describe: 'Meal added',
      );
      EatAppState.instance.session.flushNow();
      return Future<void>.delayed(Duration.zero).then((_) {
        expect(EatAppState.instance.usualPlates, isEmpty);
        expect(
          AppRouter.mealRepository.store.days[_day]!.itemsIn(MealSlot.lunch),
          hasLength(2),
        );
      });
    });
  });
}
