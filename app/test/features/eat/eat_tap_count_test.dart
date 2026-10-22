// Logging food is quick: a plate she has eaten before takes one tap, a new food
// takes two (the food, Add: the search box is already on the page). Counted
// through the real app.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/eat_state.dart';
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

  testWidgets('a plate she has eaten before logs in one tap', (tester) async {
    phone(tester);
    await tester.runAsync(EgyptianFoodPack.ensureLoaded);
    await tester.pumpWidget(OwnHubApp(key: UniqueKey()));
    await tester.pumpAndSettle();

    // Eaten twice, so it is one of her usual plates.
    for (var i = 0; i < 2; i++) {
      await _open(tester, 'E02');
      await tester.enterText(find.byType(TextField).first, 'koshari');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add it'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
    }
    expect(_written.length, 2);

    await _open(tester, 'E01');
    _taps = 0;
    await _tap(tester, find.byTooltip('Add Koshari bowl').first);

    expect(_taps, 1);
    expect(find.byType(AppUndoBar), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(_written.length, 3);
  });

  testWidgets('a new food takes two taps: the food, Add', (tester) async {
    phone(tester);
    // The bundled dishes are read from the asset bundle, which needs real time.
    await tester.runAsync(EgyptianFoodPack.ensureLoaded);
    await tester.pumpWidget(OwnHubApp(key: UniqueKey()));
    await tester.pumpAndSettle();
    await _open(tester, 'E01');

    await tester.enterText(find.byType(TextField).first, 'taameya');
    await tester.pumpAndSettle();
    await _tap(tester, find.byKey(const ValueKey('result-taameya')));
    await _tap(tester, find.byKey(const ValueKey('portion-add')));

    expect(_taps, 2);
    expect(find.byType(AppUndoBar), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(_written.map((i) => i.foodId), ['taameya']);
  });
}
