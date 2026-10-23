// Food from anywhere, in few taps: the Eat tab, Recent /
// Frequent / Favourites with a one-tap "+", units, a favourite star, a quick
// custom food, and the ring moving while the undo window is still open.
// Counted through the real app, like the tap-count test.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/app_snapshot.dart';
import 'package:own_hub/app_state/eat_state.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/features/account/domain/dietary_profile.dart';
import 'package:own_hub/features/eat/data/egyptian_food_pack.dart';
import 'package:own_hub/features/eat/domain/meal_repository.dart';
import 'package:own_hub/features/eat/presentation/eat_sample_library.dart';
import 'package:own_hub/features/eat/presentation/eat_widgets.dart'
    show PlusButton;
import 'package:own_hub/main.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/ui/app_nav_bar.dart';

NavigatorState _nav(WidgetTester tester) =>
    tester.state<NavigatorState>(find.byType(Navigator).first);

Future<void> _open(WidgetTester tester, String id) async {
  _nav(tester).pushNamed(appDestinations[id]!.name);
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _closeWindow(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 6));
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

  void clean() {
    EatAppState.instance.reset();
    EgyptianFoodPack.reset();
    _store.days.clear();
    _store.prefs = const EatPrefs();
    EatCustomFoods.current = const [];
  }

  setUp(() {
    AppRouter.featureFlags = FeatureFlags.allOff.with_({
      for (final f in Feature.values) f: f != Feature.accountRequired,
    });
    clean();
  });

  tearDown(() async {
    AppRouter.featureFlags = saved;
    clean();
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

  Future<void> boot(WidgetTester tester) async {
    phone(tester);
    await tester.runAsync(EgyptianFoodPack.ensureLoaded);
    await tester.pumpWidget(OwnHubApp(key: UniqueKey()));
    await tester.pumpAndSettle();
  }

  /// Two koshari logs, so it is one of her usual plates.
  Future<void> eatKoshariTwice(WidgetTester tester) async {
    for (var i = 0; i < 2; i++) {
      await _open(tester, 'E02');
      await tester.enterText(find.byType(TextField).first, 'koshari');
      await tester.pumpAndSettle();
      await _tap(tester, find.text('Add it'));
      await _closeWindow(tester);
    }
    expect(_written.length, 2);
  }

  testWidgets('there is no floating Log food button: Eat is a tab', (
    tester,
  ) async {
    await boot(tester);
    await _open(tester, 'E01');

    expect(find.byKey(const ValueKey('nav-log-food')), findsNothing);
    expect(find.text('Log food'), findsNothing);
  });

  testWidgets('the bar is Home, Train, Eat and Insights', (tester) async {
    await boot(tester);
    await _open(tester, 'E01');
    final bar = find.byType(AppNavBar);
    for (final tab in ['Home', 'Train', 'Eat', 'Insights']) {
      expect(
        find.descendant(of: bar, matching: find.text(tab)),
        findsOneWidget,
        reason: tab,
      );
    }
  });

  testWidgets('Recent logs a food again in one tap, at the last portion', (
    tester,
  ) async {
    await boot(tester);
    await eatKoshariTwice(tester);

    await _open(tester, 'E02');
    expect(find.byKey(const ValueKey('eat-quick-tabs')), findsOneWidget);
    await _tap(tester, find.byTooltip('Add Koshari bowl').first);
    await _closeWindow(tester);

    expect(_written.length, 3);
    expect(_written.last.foodId, _written.first.foodId);
    expect(_written.last.size, _written.first.size);
  });

  testWidgets('Frequent lists the most eaten first, and its + is one tap', (
    tester,
  ) async {
    await boot(tester);
    await eatKoshariTwice(tester);

    await _open(tester, 'E02');
    await _tap(tester, find.text('Frequent'));
    await _tap(tester, find.byTooltip('Add Koshari bowl').first);
    await _closeWindow(tester);

    expect(_written.length, 3);
  });

  testWidgets('a starred food comes back under Favourites and survives the '
      'snapshot', (tester) async {
    await boot(tester);
    await _open(tester, 'E02');
    await tester.enterText(find.byType(TextField).first, 'taameya');
    await tester.pumpAndSettle();
    await _tap(tester, find.byKey(const ValueKey('result-taameya')));
    await _tap(tester, find.byKey(const ValueKey('portion-star')));
    expect(_store.prefs.favourites, ['taameya']);
    await _tap(tester, find.byKey(const ValueKey('portion-star')));
    expect(_store.prefs.favourites, isEmpty);
    await _tap(tester, find.byKey(const ValueKey('portion-star')));

    // The round trip through what the phone keeps.
    final document = jsonEncode(AppSnapshot.capture());
    _store.prefs = const EatPrefs();
    AppSnapshot.restore(document);
    expect(_store.prefs.favourites, ['taameya']);
  });

  testWidgets('Favourites shows it with a + that logs it in one tap', (
    tester,
  ) async {
    await boot(tester);
    _store.prefs = const EatPrefs(favourites: ['taameya']);
    await _open(tester, 'E02');
    await _tap(tester, find.text('Favourites'));

    await _tap(
      tester,
      find.descendant(
        of: find.byKey(const ValueKey('favourite-taameya-M')),
        matching: find.byType(PlusButton),
      ),
    );
    expect(find.byKey(const ValueKey('portion-add')), findsNothing);
    await _closeWindow(tester);
    expect(_written.map((i) => i.foodId), ['taameya']);
  });

  testWidgets('the unit picker logs a portion by weight', (tester) async {
    await boot(tester);
    await _open(tester, 'E02');
    await tester.enterText(find.byType(TextField).first, 'taameya');
    await tester.pumpAndSettle();
    await _tap(tester, find.byKey(const ValueKey('result-taameya')));

    await _tap(tester, find.text('oz'));
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('portion-amount')),
        matching: find.byType(TextField),
      ),
      '2',
    );
    await tester.pumpAndSettle();
    // 2 oz is 56.7 g, so 57 g, and exact: no "about".
    expect(find.text('57 g'), findsOneWidget);

    await _tap(tester, find.text('piece'));
    expect(find.textContaining('About '), findsOneWidget);

    await _tap(tester, find.text('oz'));
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('portion-amount')),
        matching: find.byType(TextField),
      ),
      '2',
    );
    await tester.pumpAndSettle();
    await _tap(tester, find.byKey(const ValueKey('portion-add')));
    await _closeWindow(tester);

    // Taameya's medium portion is 97 g and 263 kcal.
    expect(_written.single.size, 'g57');
    expect(_written.single.kcal, (263 * 57 / 97).round());
  });

  testWidgets('Quick custom logs a named food with the numbers she typed', (
    tester,
  ) async {
    await boot(tester);
    await _open(tester, 'E02');
    await _tap(tester, find.byKey(const ValueKey('quick-custom-row')));

    Finder field(String key) => find.descendant(
      of: find.byKey(ValueKey(key)),
      matching: find.byType(TextField),
    );
    await tester.enterText(field('custom-name'), 'Protein bar');
    await tester.enterText(field('custom-kcal'), '210');
    await tester.enterText(field('custom-protein'), '20');
    await tester.enterText(field('custom-carbs'), '18');
    await tester.enterText(field('custom-fat'), '7');
    await tester.enterText(field('custom-fibre'), '5');
    await tester.pumpAndSettle();
    await _tap(tester, find.byKey(const ValueKey('custom-save')));
    await _closeWindow(tester);

    final item = _written.single;
    expect(item.name, 'Protein bar');
    expect(item.foodId, startsWith('custom-'));
    expect(
      [item.kcal, item.proteinG, item.carbsG, item.fatG, item.fiberG],
      [210, 20, 18, 7, 5],
    );
    // Kept, so it is a food she can find again.
    expect(_store.prefs.customFoods.single.name, 'Protein bar');
  });

  testWidgets('Quick custom needs a name and kcal, and leaves blanks unknown', (
    tester,
  ) async {
    await boot(tester);
    await _open(tester, 'E02');
    await _tap(tester, find.byKey(const ValueKey('quick-custom-row')));

    Finder field(String key) => find.descendant(
      of: find.byKey(ValueKey(key)),
      matching: find.byType(TextField),
    );

    await tester.enterText(field('custom-name'), 'Date');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('custom-save')));
    await tester.pumpAndSettle();
    expect(_written, isEmpty, reason: 'no kcal yet');

    await tester.enterText(field('custom-kcal'), '23');
    await tester.pumpAndSettle();
    await _tap(tester, find.byKey(const ValueKey('custom-save')));
    await _closeWindow(tester);

    final item = _written.single;
    expect(item.kcal, 23);
    expect(item.proteinG, 0);
    expect(item.carbsG, isNull);
    expect(item.fatG, isNull);
    expect(item.fiberG, isNull);
  });

  testWidgets('the ring moves the moment a meal is logged, inside the undo '
      'window', (tester) async {
    await boot(tester);
    await eatKoshariTwice(tester);
    await _open(tester, 'E01');

    Finder ring() => find.byKey(const ValueKey('eat-kcal-ring'));
    // Two koshari bowls already written: 2 x 540 kcal.
    expect(
      find.descendant(of: ring(), matching: find.text('1,080')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: ring(), matching: find.text('of 1,861 kcal')),
      findsOneWidget,
    );

    await _tap(tester, find.byTooltip('Add Koshari bowl').first);
    // Still inside the five seconds: nothing is written, the ring has moved.
    expect(_written.length, 2);
    expect(
      find.descendant(of: ring(), matching: find.text('1,620')),
      findsOneWidget,
    );

    // Taking it back puts the ring back.
    await _tap(tester, find.text('Undo'));
    expect(
      find.descendant(of: ring(), matching: find.text('1,080')),
      findsOneWidget,
    );
    await _closeWindow(tester);
    expect(_written.length, 2);
  });
}
