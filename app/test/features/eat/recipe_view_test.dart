// E06 — Recipe.
//
// "The recipe page ends where logging starts: cooked it, log my bowl, in her
// usual size." So the assertion that matters is that the SIZE she picked is the
// size that gets written — portions are the objects she serves, and a page that
// logged a fixed medium whatever she tapped would be the same defect
// PHASE1-FIXES §8 records on R07.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/domain/logging/log_command_bus.dart';
import 'package:own_hub/features/eat/domain/allergy_guard.dart';
import 'package:own_hub/features/eat/domain/meal_repository.dart';
import 'package:own_hub/features/eat/presentation/recipe_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/theme/app_tokens.dart';

final DateTime _lunchtime = DateTime(2026, 9, 15, 13, 12);

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

Widget _host(
  Widget child, {
  Locale locale = const Locale('en'),
  double textScale = 1.0,
}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppL10n.localizationsDelegates,
    supportedLocales: AppL10n.supportedLocales,
    theme: buildTheme(locale),
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child,
      ),
    ),
  );
}

RecipeView _recipe({
  MealRepository? repository,
  LogCommandBus? bus,
  String foodId = 'koshari_bowl',
}) {
  return RecipeView(
    constraints: DietaryConstraints.none,
    repository: repository,
    bus: bus,
    foodId: foodId,
    now: _lunchtime,
    onBack: () {},
    onBookmark: () {},
    onShare: () {},
    onSeeSteps: () {},
  );
}

void main() {
  final savedFlags = AppRouter.featureFlags;
  setUp(() {
    AppRouter.featureFlags = FeatureFlags.allOff.with_({
      for (final f in Feature.values) f: f != Feature.accountRequired,
    });
  });
  tearDown(() => AppRouter.featureFlags = savedFlags);

  testWidgets('the page is about the dish it was opened for', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_host(_recipe()));
    await tester.pumpAndSettle();

    expect(find.text('Koshari bowl'), findsOneWidget);
    // The macros are the selected portion's, from the food pack.
    expect(find.text('540 kcal · 18 g protein'), findsOneWidget);

    // What this test used to assert, and should not have.
    //
    // It was called "the page states time, servings and cost" and it pinned
    // three fixed strings — `koshariPortioned`, `n22Min4Servings14EgpA`,
    // `n540Kcal`, `n18GProtein` — on a screen that takes a `foodId` and is
    // opened from any recipe row. Tapping "Molokhia with chicken" gave a page
    // headed "Koshari, portioned · 540 kcal · 18 g protein" above a Log button
    // that wrote molokhia. The time, the yield and the cost are recipe-pack
    // content; no recipe pack exists, so they are not claimed at all.
    expect(find.text('22 min · 4 servings · 14 EGP a serving'), findsNothing);
  });

  testWidgets('another dish is that dish, not koshari', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_host(_recipe(foodId: 'molokhia_chicken')));
    await tester.pumpAndSettle();

    expect(find.text('Molokhia with chicken'), findsOneWidget);
    expect(find.text('460 kcal · 34 g protein'), findsOneWidget);
    expect(find.textContaining('Koshari'), findsNothing);
    expect(find.text('540 kcal · 18 g protein'), findsNothing);
  });

  testWidgets('portions are the objects she serves, not grams', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_host(_recipe()));
    await tester.pumpAndSettle();

    expect(find.text('Your portion'), findsOneWidget);
    expect(find.text('Medium bowl, the one you usually serve'), findsOneWidget);
    expect(find.text('S'), findsOneWidget);
    expect(find.text('M'), findsOneWidget);
    expect(find.text('L'), findsOneWidget);
  });

  testWidgets('"cooked it" logs her usual size', (tester) async {
    _phone(tester);
    final repository = InMemoryMealRepository();
    final bus = LogCommandBus();

    await tester.pumpWidget(_host(_recipe(repository: repository, bus: bus)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('I cooked it and ate a bowl'));
    await tester.pump();

    expect(repository.writes, isEmpty, reason: 'inside the undo window');
    await tester.pump(const Duration(seconds: 6));

    final item = repository.writes.single.added.single;
    expect(item.foodId, 'koshari_bowl');
    expect(item.size, 'M');
    expect(item.kcal, 540);
    expect(item.origin, MealOrigin.recipe);

    bus.dispose();
  });

  testWidgets('and logs the size she actually picked', (tester) async {
    _phone(tester);
    final repository = InMemoryMealRepository();
    final bus = LogCommandBus();

    await tester.pumpWidget(_host(_recipe(repository: repository, bus: bus)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('L'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('I cooked it and ate a bowl'));
    await tester.pump(const Duration(seconds: 6));

    final item = repository.writes.single.added.single;
    expect(
      item.size,
      'L',
      reason: 'the chip she tapped must be the portion that is written',
    );
    expect(item.kcal, 700);

    bus.dispose();
  });

  testWidgets('P1-RULE-09 — no dialog on this logging path either', (
    tester,
  ) async {
    _phone(tester);
    final bus = LogCommandBus();

    await tester.pumpWidget(_host(_recipe(bus: bus)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('I cooked it and ate a bowl'));
    await tester.pump();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(Dialog), findsNothing);
    expect(find.text('Undo'), findsOneWidget);

    bus.dispose();
  });

  testWidgets('reads in Arabic without overflowing at 1.6', (tester) async {
    _phone(tester);
    await tester.pumpWidget(
      _host(_recipe(), locale: const Locale('ar'), textScale: 1.6),
    );
    await tester.pumpAndSettle();

    expect(find.text('حصتك'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
