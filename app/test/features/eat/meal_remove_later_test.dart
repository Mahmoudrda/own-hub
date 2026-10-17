// E01/E04: a meal she logged can be taken out of its slot later, with five
// seconds to take that back too. And every meal's offer names the food and the
// slot instead of "Meal added".

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/account_data.dart';
import 'package:own_hub/app_state/eat_state.dart';
import 'package:own_hub/app_state/rewards_state.dart';
import 'package:own_hub/domain/clock/app_clock.dart';
import 'package:own_hub/domain/logging/log_command_bus.dart';
import 'package:own_hub/domain/rewards/award_table.dart';
import 'package:own_hub/features/eat/domain/food_library.dart';
import 'package:own_hub/features/eat/domain/meal_log_service.dart';
import 'package:own_hub/features/eat/domain/meal_repository.dart';
import 'package:own_hub/features/eat/presentation/meal_labels.dart';
import 'package:own_hub/features/eat/presentation/meal_log_session.dart';
import 'package:own_hub/features/eat/presentation/eat_widgets.dart';
import 'package:own_hub/features/eat/presentation/eat_day_view_model.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/l10n/app_l10n_ar.dart';
import 'package:own_hub/l10n/app_l10n_en.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _day = '2026-10-17';

MealItem _item(String id, String name, {int minute = 30}) => MealItem(
  itemId: id,
  foodId: 'nowhere-$id',
  servings: 1,
  size: 'M',
  loggedAt: DateTime(2026, 10, 17, 8, minute),
  source: MealSource.search,
  origin: MealOrigin.suggestion,
  kcal: 300,
  proteinG: 12,
  name: name,
);

MealLogPrepared _prepared(List<MealItem> items) => MealLogPrepared(
  write: MealWrite.transform(
    dayId: _day,
    slot: MealSlot.breakfast,
    tz: 'Africa/Cairo',
    libVersion: 1,
    added: items,
  ),
  items: items,
);

void main() {
  group('removing a logged meal', () {
    late InMemoryMealRepository repository;
    late MealLogSession session;

    setUp(() async {
      repository = InMemoryMealRepository();
      session = MealLogSession(
        repository: repository,
        bus: LogCommandBus(window: const Duration(milliseconds: 50)),
        rememberPlates: false,
      );
      session.submit(
        _prepared([_item('a', 'Ful'), _item('b', 'Baladi bread')]),
        slot: MealSlot.breakfast,
        describe: 'Ful and 1 more added to Breakfast',
      );
      session.flushNow();
      await Future<void>.delayed(Duration.zero);
    });

    tearDown(() => session.reset());

    test('the slot loses the item at once, and the write waits', () async {
      final stored = await repository.day(_day);
      expect(stored.itemsIn(MealSlot.breakfast), hasLength(2));

      session.remove(
        dayId: _day,
        slot: MealSlot.breakfast,
        items: [stored.itemsIn(MealSlot.breakfast).first],
        describe: 'Ful removed from Breakfast',
      );

      final shown = session.project(await repository.day(_day));
      expect(shown.itemsIn(MealSlot.breakfast).map((i) => i.name), [
        'Baladi bread',
      ]);
      // Nothing written yet: Undo would mean nothing was ever removed.
      expect(
        (await repository.day(_day)).itemsIn(MealSlot.breakfast),
        hasLength(2),
      );

      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(
        (await repository.day(_day))
            .itemsIn(MealSlot.breakfast)
            .map((i) => i.name),
        ['Baladi bread'],
      );
    });

    test('Undo puts it back and writes nothing', () async {
      final stored = await repository.day(_day);
      final handle = session.remove(
        dayId: _day,
        slot: MealSlot.breakfast,
        items: [stored.itemsIn(MealSlot.breakfast).first],
        describe: 'Ful removed from Breakfast',
      );

      expect(session.undo(handle), isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 120));

      final shown = session.project(await repository.day(_day));
      expect(shown.itemsIn(MealSlot.breakfast), hasLength(2));
      expect(
        (await repository.day(_day)).itemsIn(MealSlot.breakfast),
        hasLength(2),
      );
    });
  });

  group('a removal leaves the day its own', () {
    test(
      'the zone and the pack version the day was logged under stay',
      () async {
        final repository = InMemoryMealRepository();
        final session = MealLogSession(
          repository: repository,
          bus: LogCommandBus(window: const Duration(milliseconds: 50)),
          rememberPlates: false,
        );
        final items = [_item('a', 'Ful'), _item('b', 'Baladi bread')];
        session.submit(
          MealLogPrepared(
            write: MealWrite.transform(
              dayId: _day,
              slot: MealSlot.breakfast,
              tz: 'Europe/Berlin',
              libVersion: 7,
              added: items,
            ),
            items: items,
          ),
          slot: MealSlot.breakfast,
          describe: 'Ful and 1 more added to Breakfast',
        );
        session.flushNow();
        await Future<void>.delayed(Duration.zero);

        session.remove(
          dayId: _day,
          slot: MealSlot.breakfast,
          items: [items.first],
          describe: 'Ful removed from Breakfast',
        );
        session.flushNow();
        await Future<void>.delayed(Duration.zero);

        final day = await repository.day(_day);
        expect(day.itemsIn(MealSlot.breakfast), hasLength(1));
        expect(day.tz, 'Europe/Berlin');
        expect(day.libVersion, 7);
        session.reset();
      },
    );
  });

  group('removing the last meal of the day, as Undo would have', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues(const <String, Object>{});
      AppClock.debugNow = () => DateTime(2026, 10, 17, 9);
      await const ThisPhoneWipe().clearPersistence();
    });
    tearDown(() async {
      await const ThisPhoneWipe().clearPersistence();
      AppClock.debugNow = null;
    });

    Future<MealItem> logOne(String id, {int minute = 30}) async {
      final item = _item(id, 'Ful', minute: minute);
      EatAppState.instance.session.submit(
        _prepared([item]),
        slot: MealSlot.breakfast,
        describe: 'Ful added to Breakfast',
      );
      EatAppState.instance.session.flushNow();
      await Future<void>.delayed(Duration.zero);
      return item;
    }

    Future<void> removeOne(MealItem item) async {
      EatAppState.instance.session.remove(
        dayId: _day,
        slot: MealSlot.breakfast,
        items: [item],
        describe: 'Ful removed from Breakfast',
      );
      EatAppState.instance.session.flushNow();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
    }

    test('Home, her plates and the food points go back', () async {
      final item = await logOne('a');
      final today = AppRouter.todayRepository;
      final progress = AppRouter.progressStore;
      expect(today.day.mealLoggedAt, isNotNull);
      expect(today.day.plates, isNotEmpty);
      expect(RewardsState.instance.awardIds, contains('meal:$_day'));
      expect(progress.rewards.points, kFoodDayPoints);

      await removeOne(item);

      expect(
        AppRouter.mealRepository.store.days[_day]!.itemsIn(MealSlot.breakfast),
        isEmpty,
      );
      expect(today.day.mealLoggedAt, isNull);
      expect(today.day.plates, isEmpty);
      expect(EatAppState.instance.usualPlates, isEmpty);
      expect(RewardsState.instance.awardIds, isNot(contains('meal:$_day')));
      expect(progress.rewards.points, 0);
    });

    test(
      'a meal of two foods, taken out one at a time, leaves nothing',
      () async {
        final ful = _item('a', 'Ful');
        final bread = _item('b', 'Baladi bread');
        EatAppState.instance.session.submit(
          _prepared([ful, bread]),
          slot: MealSlot.breakfast,
          describe: 'Ful and 1 more added to Breakfast',
        );
        EatAppState.instance.session.flushNow();
        await Future<void>.delayed(Duration.zero);
        expect(EatAppState.instance.usualPlates, hasLength(1));
        expect(AppRouter.mealRepository.store.prefs.plates, hasLength(1));

        await removeOne(ful);
        // The plate she logged is broken by the first removal.
        expect(EatAppState.instance.usualPlates, isEmpty);
        expect(AppRouter.todayRepository.day.mealLoggedAt, isNotNull);
        expect(RewardsState.instance.awardIds, contains('meal:$_day'));

        await removeOne(bread);
        expect(AppRouter.todayRepository.day.mealLoggedAt, isNull);
        expect(AppRouter.todayRepository.day.plates, isEmpty);
        expect(RewardsState.instance.awardIds, isNot(contains('meal:$_day')));
        expect(AppRouter.progressStore.rewards.points, 0);
        // E01 does not offer it back either.
        final plate = AppRouter.mealRepository.store.prefs.plates.values.single;
        expect(plate.dayCounts[_day], isNull);
      },
    );

    test('a day with a meal left keeps Home and its points', () async {
      await logOne('a');
      // A second log, a few minutes later.
      final second = await logOne('b', minute: 45);
      final points = AppRouter.progressStore.rewards.points;

      await removeOne(second);

      expect(AppRouter.todayRepository.day.mealLoggedAt, isNotNull);
      expect(RewardsState.instance.awardIds, contains('meal:$_day'));
      expect(AppRouter.progressStore.rewards.points, points);
      expect(EatAppState.instance.usualPlates.single.timesEaten, 1);
    });
  });

  group('what the offer says', () {
    final AppL10n en = AppL10nEn();
    final AppL10n ar = AppL10nAr();

    test('names the food and the slot', () {
      expect(
        mealAddedLabel(en, ['Ful'], MealSlot.breakfast),
        'Ful added to Breakfast',
      );
      expect(
        mealAddedLabel(en, ['Ful', 'Baladi bread', 'Tea'], MealSlot.lunch),
        'Ful and 2 more added to Lunch',
      );
      expect(
        mealRemovedLabel(en, 'Ful', MealSlot.dinner),
        'Ful removed from Dinner',
      );
      expect(mealAddedLabel(ar, ['فول'], MealSlot.breakfast), contains('فول'));
    });

    test('falls back to "Meal added" when nothing has a name', () {
      expect(mealAddedLabel(en, const [], MealSlot.snack), en.mealAdded);
      expect(mealFoodNames(FoodLibrary.empty, [_item('x', '  ')]), isEmpty);
    });
  });

  testWidgets('a filled slot is tappable, an empty one is not', (tester) async {
    var opened = 0;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: Scaffold(
          body: Row(
            children: [
              SlotColumn(
                name: 'Breakfast',
                value: 'Ful',
                status: SlotStatus.done,
                onTap: () => opened++,
              ),
              const SlotColumn(
                name: 'Lunch',
                value: 'Now',
                status: SlotStatus.now,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.text('Ful'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Now'));
    await tester.pumpAndSettle();
    expect(opened, 1);
  });
}
