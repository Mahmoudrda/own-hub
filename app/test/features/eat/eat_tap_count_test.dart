// Logging food is quick: her usual plate for a meal takes one tap (the "+" on
// that meal's row), a new food takes three at most (the field or a "+", the
// food, Add). Counted through the real app.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/eat_state.dart';
import 'package:own_hub/domain/clock/app_clock.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/features/account/domain/dietary_profile.dart';
import 'package:own_hub/features/eat/data/egyptian_food_pack.dart';
import 'package:own_hub/features/eat/domain/meal_repository.dart';
import 'package:own_hub/main.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/ui/app_undo_bar.dart';

int _taps = 0;

Future<void> _tap(WidgetTester tester, Finder finder) async {
  _taps++;
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

NavigatorState _nav(WidgetTester tester) =>
    tester.state<NavigatorState>(find.byType(Navigator).first);

Future<void> _open(WidgetTester tester, String id) async {
  _nav(tester).pushNamed(appDestinations[id]!.name);
  await tester.pumpAndSettle();
}

MealStore get _store => AppRouter.mealRepository.store;

String get _todayId {
  final now = DateTime.now();
  return '${now.year.toString().padLeft(4, '0')}-'
      '${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';
}

List<MealItem> get _written =>
    _store.days[_todayId]?.allItems.toList() ?? const <MealItem>[];

void main() {
  final saved = AppRouter.featureFlags;

  setUp(() {
    AppRouter.featureFlags = FeatureFlags.allOff.with_({
      for (final f in Feature.values) f: f != Feature.accountRequired,
    });
    EatAppState.instance.reset();
    EgyptianFoodPack.reset();
    _store.days.clear();
    _store.prefs = const EatPrefs();
    _taps = 0;
  });

  tearDown(() async {
    AppClock.debugNow = null;
    AppRouter.featureFlags = saved;
    EatAppState.instance.reset();
    EgyptianFoodPack.reset();
    _store.days.clear();
    _store.prefs = const EatPrefs();
    await AppRouter.dietaryRepository.save(
      allergies: const <AllergenTag>{},
      dietary: const <DietaryTag>{},
    );
  });

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('her usual breakfast logs in one tap, with Undo', (tester) async {
    phone(tester);
    final today = DateTime.now();
    final breakfastTime = DateTime(today.year, today.month, today.day, 8);
    AppClock.debugNow = () => breakfastTime;
    String dayKey(int daysAgo) {
      final d = breakfastTime.subtract(Duration(days: daysAgo));
      return '${d.year.toString().padLeft(4, '0')}-'
          '${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}';
    }

    // Koshari for breakfast on two earlier days: it is her usual.
    _store.prefs = EatPrefs(
      plates: {
        'plate_koshari_bowl': Plate(
          plateId: 'plate_koshari_bowl',
          items: [PlateItem(foodId: 'koshari_bowl', size: 'M')],
          dayCounts: {dayKey(7): 1, dayKey(1): 1},
          slotCounts: const {MealSlot.breakfast: 2},
          dowCounts: {breakfastTime.weekday: 2},
          lastAt: breakfastTime.subtract(const Duration(days: 1)),
        ),
      },
    );
    await tester.runAsync(EgyptianFoodPack.ensureLoaded);
    await tester.pumpWidget(OwnHubApp(key: UniqueKey()));
    await tester.pumpAndSettle();
    await _open(tester, 'E01');
    expect(_written, isEmpty);

    _taps = 0;
    final plus = find.descendant(
      of: find.byKey(const ValueKey('eat-diary-breakfast')),
      matching: find.byTooltip('Add Koshari bowl'),
    );
    await _tap(tester, plus);

    expect(_taps, 1);
    expect(find.byType(AppUndoBar), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(_written.map((i) => i.foodId), ['koshari_bowl']);
    // Eaten, so the meal no longer offers it again.
    expect(find.byTooltip('Add Koshari bowl'), findsNothing);
  });

  testWidgets('Undo takes a one-tap breakfast back before it is written', (
    tester,
  ) async {
    phone(tester);
    final today = DateTime.now();
    final breakfastTime = DateTime(today.year, today.month, today.day, 8);
    AppClock.debugNow = () => breakfastTime;
    String dayKey(int daysAgo) {
      final d = breakfastTime.subtract(Duration(days: daysAgo));
      return '${d.year.toString().padLeft(4, '0')}-'
          '${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}';
    }

    _store.prefs = EatPrefs(
      plates: {
        'plate_koshari_bowl': Plate(
          plateId: 'plate_koshari_bowl',
          items: [PlateItem(foodId: 'koshari_bowl', size: 'M')],
          dayCounts: {dayKey(7): 1, dayKey(1): 1},
          slotCounts: const {MealSlot.breakfast: 2},
          dowCounts: {breakfastTime.weekday: 2},
          lastAt: breakfastTime.subtract(const Duration(days: 1)),
        ),
      },
    );
    await tester.runAsync(EgyptianFoodPack.ensureLoaded);
    await tester.pumpWidget(OwnHubApp(key: UniqueKey()));
    await tester.pumpAndSettle();
    await _open(tester, 'E01');

    await _tap(tester, find.byTooltip('Add Koshari bowl'));
    await _tap(tester, find.text('Undo'));
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(_written, isEmpty);
    expect(find.byTooltip('Add Koshari bowl'), findsOneWidget);
  });

  testWidgets('a new food takes three taps: the field, the food, Add', (
    tester,
  ) async {
    phone(tester);
    // The bundled dishes are read from the asset bundle, which needs real time.
    await tester.runAsync(EgyptianFoodPack.ensureLoaded);
    await tester.pumpWidget(OwnHubApp(key: UniqueKey()));
    await tester.pumpAndSettle();
    await _open(tester, 'E01');

    await _tap(tester, find.byKey(const ValueKey('eat-hub-search')));
    await tester.enterText(find.byType(TextField).first, 'taameya');
    await tester.pumpAndSettle();
    await _tap(tester, find.byKey(const ValueKey('result-taameya')));
    await _tap(tester, find.byKey(const ValueKey('portion-add')));

    expect(_taps, 3);
    expect(find.byType(AppUndoBar), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(_written.map((i) => i.foodId), ['taameya']);
  });

  testWidgets('a new food from a meal\'s + takes three taps as well', (
    tester,
  ) async {
    phone(tester);
    await tester.runAsync(EgyptianFoodPack.ensureLoaded);
    await tester.pumpWidget(OwnHubApp(key: UniqueKey()));
    await tester.pumpAndSettle();
    await _open(tester, 'E01');

    await _tap(tester, find.byTooltip('Log Dinner'));
    await tester.enterText(find.byType(TextField).first, 'taameya');
    await tester.pumpAndSettle();
    await _tap(tester, find.byKey(const ValueKey('result-taameya')));
    await _tap(tester, find.byKey(const ValueKey('portion-add')));

    expect(_taps, 3);
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(_written.single.foodId, 'taameya');
    expect(_store.days[_todayId]!.itemsIn(MealSlot.dinner), hasLength(1));
  });
}
