// The Eat tab: E01 "What I ate today" and E02 "Find and add" on one page. A
// search field with the camera inside it stays put over the day; Recipes and
// Plan are two rows under the meals; typing searches foods in place; every
// logging path is the one the separate screens had.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/features/eat/data/egyptian_food_pack.dart';
import 'package:own_hub/features/eat/data/seeded_recipe_library.dart';
import 'package:own_hub/features/eat/domain/allergy_guard.dart';
import 'package:own_hub/features/eat/domain/food_library.dart';
import 'package:own_hub/features/eat/domain/meal_repository.dart';
import 'package:own_hub/features/eat/domain/meal_sentence_parser.dart';
import 'package:own_hub/features/eat/presentation/eat_hub_view.dart';
import 'package:own_hub/features/eat/presentation/eat_sample_library.dart';
import 'package:own_hub/features/eat/presentation/eat_widgets.dart'
    show FoodResultRow;
import 'package:own_hub/features/eat/presentation/meal_log_session.dart';
import 'package:own_hub/features/eat/presentation/recipes_view.dart'
    show RecipeMeal, recipeMealOf;
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/theme/app_tokens.dart';
import 'package:own_hub/ui/app_undo_bar.dart';

final DateTime _lunchtime = DateTime(2026, 9, 15, 13, 12);

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

void _small(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Widget _host(
  Widget child, {
  Locale locale = const Locale('en'),
  double textScale = 1.0,
}) => MaterialApp(
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

void main() {
  final savedFlags = AppRouter.featureFlags;
  late RecipeBook book;
  late String packJson;

  setUpAll(() {
    packJson = File('assets/content/foods_eg.json').readAsStringSync();
    EgyptianFoodPack.adopt(packJson);
    book = RecipeBook.fromJson(
      (jsonDecode(
        File('assets/content/rahma_recipes.json').readAsStringSync(),
      ) as Map).cast<String, Object?>(),
    );
  });
  tearDownAll(EgyptianFoodPack.reset);

  setUp(() => AppRouter.featureFlags = FeatureFlags.everything);
  tearDown(() => AppRouter.featureFlags = savedFlags);

  late InMemoryMealRepository repository;
  late MealLogSession session;

  setUp(() {
    repository = InMemoryMealRepository();
    session = MealLogSession(repository: repository);
  });

  tearDown(() async {
    await session.bus.flushAll();
    session.dispose();
  });

  EatHubView hub({
    DietaryConstraints constraints = DietaryConstraints.none,
    List<ParsedItem> history = const <ParsedItem>[],
    List<ParsedItem> frequent = const <ParsedItem>[],
    List<ParsedItem> Function(AppL10n l10n)? historyOf,
    bool asked = true,
    VoidCallback? onAnswerAllergies,
    ValueChanged<String>? onOpenRecipe,
    ValueChanged<String>? onSearch,
    Future<void> Function(PlanDay day)? onPickDinner,
    List<String> fillFrom = const <String>[],
    VoidCallback? onSnap,
    VoidCallback? onSpeak,
    EatHubSegment initialSegment = EatHubSegment.log,
    String? initialText,
  }) => EatHubView(
    constraints: constraints,
    repository: repository,
    session: session,
    now: _lunchtime,
    history: history,
    frequent: frequent,
    historyOf: historyOf,
    book: book,
    asked: asked,
    onAnswerAllergies: onAnswerAllergies,
    onOpenRecipe: onOpenRecipe,
    onSearch: onSearch,
    onPickDinner: onPickDinner,
    fillFrom: fillFrom,
    recipeTitle: (id) => book.byId(id)?.titleEn,
    recipeOf: book.byId,
    onSnap: onSnap,
    onSpeak: onSpeak,
    initialSegment: initialSegment,
    initialText: initialText,
  );

  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(child);
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pump();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> type(WidgetTester tester, String text) async {
    await tester.enterText(find.byKey(const ValueKey('eat-hub-search')), text);
    await tester.pumpAndSettle();
  }

  /// Taps the search field: the page becomes E02, "Find and add".
  Future<void> enterFind(WidgetTester tester) =>
      tap(tester, find.byKey(const ValueKey('eat-hub-search')));

  Future<void> openRecipes(WidgetTester tester) =>
      tap(tester, find.byKey(const ValueKey('eat-hub-open-recipes')));

  Future<void> openPlan(WidgetTester tester) =>
      tap(tester, find.byKey(const ValueKey('eat-hub-open-plan')));

  Future<void> backToDay(WidgetTester tester) =>
      tap(tester, find.byKey(const ValueKey('eat-hub-back')));

  Future<void> settleWindow(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
  }

  ParsedItem koshari(AppL10n l10n) {
    final food = eatSampleLibrary(l10n).resolve('koshari').first;
    return ParsedItem(
      food: food,
      size: food.defaultSize,
      servings: 1,
      sourceText: food.names.first,
    );
  }

  Future<AppL10n> english() => AppL10n.delegate.load(const Locale('en'));

  group('the page', () {
    testWidgets('has one search field, two quiet rows and no segments', (
      tester,
    ) async {
      _phone(tester);
      await pump(tester, _host(hub()));

      expect(find.byKey(const ValueKey('eat-hub-search')), findsOneWidget);
      expect(find.byKey(const ValueKey('eat-hub-segments')), findsNothing);
      expect(
        find.byKey(const ValueKey('eat-hub-open-recipes')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('eat-hub-open-plan')), findsOneWidget);
      // The Eat tab is the active tab.
      expect(find.text('You'), findsOneWidget);

      final before = tester.getTopLeft(
        find.byKey(const ValueKey('eat-hub-search')),
      );
      await tester.drag(
        find.byKey(const ValueKey('eat-hub-scroll')),
        const Offset(0, -600),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('eat-hub-search'))),
        before,
        reason: 'the bar does not scroll away',
      );
    });

    testWidgets('E01 shows the day: hero, four meals, nothing to search yet', (
      tester,
    ) async {
      _phone(tester);
      await pump(tester, _host(hub()));

      for (final meal in const ['breakfast', 'lunch', 'dinner', 'snack']) {
        expect(find.byKey(ValueKey('eat-diary-$meal')), findsOneWidget);
      }
      expect(find.byKey(const ValueKey('eat-hero')), findsOneWidget);
      // Recent, Frequent, Favourites and Quick custom belong to E02.
      expect(find.byKey(const ValueKey('eat-quick-tabs')), findsNothing);
      expect(find.byKey(const ValueKey('quick-custom-row')), findsNothing);
      // No second search box, no second camera and no links to the screens it
      // replaces.
      expect(find.byKey(const ValueKey('eat-search-pill')), findsNothing);
      expect(find.byKey(const ValueKey('eat-snap-card')), findsNothing);
      expect(find.byKey(const ValueKey('eat-day-one-week-plan')), findsNothing);
    });

    testWidgets('E02 opens on a tap in the field and closes with its X', (
      tester,
    ) async {
      _phone(tester);
      await pump(tester, _host(hub()));
      await enterFind(tester);

      expect(find.byKey(const ValueKey('eat-diary-lunch')), findsNothing);
      expect(find.byKey(const ValueKey('eat-quick-tabs')), findsOneWidget);
      expect(find.text('Recent'), findsOneWidget);
      expect(find.text('Frequent'), findsOneWidget);
      expect(find.text('Favourites'), findsOneWidget);
      expect(find.byKey(const ValueKey('quick-custom-row')), findsOneWidget);

      await tap(tester, find.byKey(const ValueKey('eat-hub-clear')));
      expect(find.byKey(const ValueKey('eat-diary-lunch')), findsOneWidget);
      expect(find.byKey(const ValueKey('eat-quick-tabs')), findsNothing);
    });

    testWidgets('Recipes and Plan open in the page and the arrow comes back', (
      tester,
    ) async {
      _phone(tester);
      await pump(tester, _host(hub()));

      await openRecipes(tester);
      expect(find.byKey(const ValueKey('hub-recipes')), findsOneWidget);
      expect(find.byKey(const ValueKey('eat-diary-lunch')), findsNothing);
      expect(find.byKey(const ValueKey('eat-hub-search')), findsNothing);

      await backToDay(tester);
      expect(find.byKey(const ValueKey('eat-diary-lunch')), findsOneWidget);

      await openPlan(tester);
      expect(find.byKey(const ValueKey('hub-recipes')), findsNothing);
      expect(find.text('Grocery list'), findsOneWidget);

      await backToDay(tester);
      expect(find.byKey(const ValueKey('eat-diary-lunch')), findsOneWidget);
    });
  });

  group('logging from the bar', () {
    testWidgets('typing a food and tapping Add it logs it, with an undo bar', (
      tester,
    ) async {
      _phone(tester);
      final heard = <String>[];
      await pump(tester, _host(hub(onSearch: heard.add)));

      await type(tester, 'koshari');
      expect(heard.last, 'koshari');
      // The results replace the day while there is a query.
      expect(find.byKey(const ValueKey('eat-diary-lunch')), findsNothing);
      expect(find.byType(FoodResultRow), findsWidgets);

      await tap(tester, find.byKey(const ValueKey('type-it-add')));

      expect(session.pending, hasLength(1));
      // Back on the day, the box empty, the meal and its undo bar showing.
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText).first)
            .controller
            .text,
        isEmpty,
      );
      expect(find.byKey(const ValueKey('eat-diary-lunch')), findsOneWidget);
      expect(find.byType(AppUndoBar), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);

      await tap(tester, find.text('Undo'));
      expect(session.pending, isEmpty);
      await settleWindow(tester);
    });

    testWidgets(
      'one tap on Undo before five seconds means nothing was written',
      (tester) async {
        _phone(tester);
        await pump(tester, _host(hub()));
        await type(tester, 'koshari');
        await tap(tester, find.byKey(const ValueKey('type-it-add')));
        expect(session.pending, hasLength(1));

        // Moving to Recipes and back does not close the window.
        await openRecipes(tester);
        await tester.pump(const Duration(seconds: 2));
        expect(session.pending, hasLength(1));
        await backToDay(tester);
        await tap(tester, find.text('Undo'));
        expect(session.pending, isEmpty);
        await settleWindow(tester);
      },
    );

    testWidgets('a + with no usual plate aims the next food at that meal', (
      tester,
    ) async {
      _phone(tester);
      await pump(tester, _host(hub()));

      await tap(tester, find.byTooltip('Log Dinner'));
      expect(find.byKey(const ValueKey('eat-hub-adding-to')), findsOneWidget);
      expect(find.text('Adding to Dinner'), findsOneWidget);

      await type(tester, 'koshari');
      await tap(tester, find.byKey(const ValueKey('type-it-add')));
      expect(session.pending.single.slot, MealSlot.dinner);
      // Logged, so the aim is spent.
      expect(find.byKey(const ValueKey('eat-hub-adding-to')), findsNothing);
      await settleWindow(tester);
    });

    testWidgets('a sentence becomes rows she can log in one tap', (
      tester,
    ) async {
      _phone(tester);
      await pump(tester, _host(hub()));
      await type(tester, 'koshari and 2 eggs');
      expect(find.text("We'll add"), findsOneWidget);
      await tap(tester, find.byKey(const ValueKey('meal-result-yes')));
      expect(session.pending, hasLength(1));
      await settleWindow(tester);
    });

    testWidgets('the camera is inside the field, the microphone joins in E02', (
      tester,
    ) async {
      _phone(tester);
      var snaps = 0;
      var speaks = 0;
      await pump(
        tester,
        _host(hub(onSnap: () => snaps++, onSpeak: () => speaks++)),
      );
      final camera = find.descendant(
        of: find.byKey(const ValueKey('eat-hub-search')),
        matching: find.byKey(const ValueKey('eat-snap-meal')),
      );
      expect(camera, findsOneWidget);
      expect(find.byKey(const ValueKey('eat-hub-mic')), findsNothing);
      await tap(tester, camera);
      expect(snaps, 1);

      await enterFind(tester);
      await tap(tester, find.byKey(const ValueKey('eat-hub-mic')));
      expect(speaks, 1);
      // One camera, never a second card for it.
      expect(find.byKey(const ValueKey('eat-snap-meal')), findsOneWidget);
      expect(find.byKey(const ValueKey('eat-snap-card')), findsNothing);
    });

    testWidgets('without a camera or a microphone neither is drawn', (
      tester,
    ) async {
      _phone(tester);
      await pump(tester, _host(hub()));
      expect(find.byKey(const ValueKey('eat-snap-meal')), findsNothing);
      expect(find.byKey(const ValueKey('eat-hub-mic')), findsNothing);
      expect(find.byKey(const ValueKey('eat-snap-card')), findsNothing);
    });

    testWidgets('opens already searching when given the sentence', (
      tester,
    ) async {
      _phone(tester);
      await pump(tester, _host(hub(initialText: 'koshari')));
      expect(find.byType(FoodResultRow), findsWidgets);
      expect(find.byKey(const ValueKey('eat-diary-lunch')), findsNothing);
    });
  });

  group('Recent, Frequent and Favourites', () {
    testWidgets('Recent logs a food again in one tap', (tester) async {
      _phone(tester);
      final l10n = await english();
      await pump(tester, _host(hub(history: [koshari(l10n)])));
      await enterFind(tester);

      await tap(tester, find.byTooltip('Add Koshari bowl').first);
      expect(session.pending, hasLength(1));
      await settleWindow(tester);
    });

    testWidgets('Frequent and Favourites have their own lists', (tester) async {
      _phone(tester);
      final l10n = await english();
      repository.store.prefs = const EatPrefs(favourites: ['taameya']);
      await pump(tester, _host(hub(frequent: [koshari(l10n)])));
      await enterFind(tester);

      await tap(tester, find.text('Frequent'));
      expect(find.byTooltip('Add Koshari bowl'), findsWidgets);

      await tap(tester, find.text('Favourites'));
      expect(find.byKey(const ValueKey('favourite-taameya-M')), findsOneWidget);
    });
  });

  group('the page stays open while things change under it', () {
    testWidgets('an allergy declared elsewhere takes recipes off at once', (
      tester,
    ) async {
      _phone(tester);
      await pump(tester, _host(hub(initialSegment: EatHubSegment.recipes)));
      int cards() => find
          .byWidgetPredicate((w) => w.runtimeType.toString() == 'BookCard')
          .evaluate()
          .length;
      final before = cards();
      expect(before, book.recipes.length);

      // The router rebuilds the tab root with her new answer.
      await pump(
        tester,
        _host(
          hub(
            initialSegment: EatHubSegment.recipes,
            constraints: const DietaryConstraints(
              allergies: {'tree_nuts'},
              dietary: <String>{},
            ),
          ),
        ),
      );
      expect(cards(), lessThan(before));
    });

    testWidgets('Recent picks up a meal logged on the page', (tester) async {
      _phone(tester);
      final l10n = await english();
      var recent = <ParsedItem>[];
      final hadRows = find.byWidgetPredicate(
        (w) => w.key.toString().startsWith("[<'had-"),
      );
      await pump(tester, _host(hub(historyOf: (_) => recent)));
      expect(hadRows, findsNothing);

      await type(tester, 'koshari');
      await tap(tester, find.byKey(const ValueKey('type-it-add')));
      // Her plates move once the five seconds are up.
      recent = [koshari(l10n)];
      await settleWindow(tester);

      // Back on the day after the log; Recent lives in E02.
      await enterFind(tester);
      expect(hadRows, findsOneWidget);
    });
  });

  group('all the Egyptian dishes', () {
    testWidgets('Show all lists every one of them', (tester) async {
      _phone(tester);
      final l10n = await english();
      final expected = AllergyGuard(DietaryConstraints.none).screenSuggestions([
        for (final food in eatSampleLibrary(l10n).foods)
          if (food.category == FoodCategory.egyptianDishes) food,
      ]).length;
      expect(expected, 72);

      await pump(tester, _host(hub()));
      await enterFind(tester);
      await tap(tester, find.byKey(const ValueKey('type-it-show-egyptian')));

      expect(find.byType(FoodResultRow), findsNWidgets(expected));
    });
  });

  group('Recipes', () {
    int cards(WidgetTester tester) => find
        .byWidgetPredicate((w) => w.runtimeType.toString() == 'BookCard')
        .evaluate()
        .length;

    testWidgets('shows the whole book before the allergy question', (
      tester,
    ) async {
      _phone(tester);
      await pump(tester, _host(hub(asked: false)));
      await openRecipes(tester);

      expect(
        find.byKey(const ValueKey('e05-allergy-prompt')),
        findsOneWidget,
        reason: 'the way to answer it sits on top',
      );
      expect(cards(tester), book.recipes.length);
      expect(book.recipes.length, greaterThanOrEqualTo(50));
    });

    testWidgets('the meal row narrows to breakfast, lunch, dinner or sweets', (
      tester,
    ) async {
      _phone(tester);
      await pump(tester, _host(hub()));
      await openRecipes(tester);
      final all = cards(tester);

      final meals = find.byKey(const ValueKey('hub-recipe-meals'));
      for (final label in ['Breakfast', 'Lunch', 'Dinner', 'Sweets']) {
        expect(
          find.descendant(of: meals, matching: find.text(label)),
          findsOneWidget,
          reason: label,
        );
      }
      await tap(
        tester,
        find.descendant(of: meals, matching: find.text('Dinner')),
      );
      final dinners = [
        for (final r in book.recipes)
          if (recipeMealOf(r) == RecipeMeal.dinner) r,
      ];
      expect(cards(tester), dinners.length);
      expect(cards(tester), lessThan(all));
    });

    testWidgets('filter chips narrow the list and can be turned off', (
      tester,
    ) async {
      _phone(tester);
      await pump(tester, _host(hub()));
      await openRecipes(tester);
      final all = cards(tester);
      final filters = find.byKey(const ValueKey('hub-recipe-filters'));

      await tap(
        tester,
        find.descendant(of: filters, matching: find.text('High protein')),
      );
      final high = cards(tester);
      expect(high, lessThan(all));
      expect(
        high,
        book.recipes.where((r) => r.dietTags.contains('high_protein')).length,
      );

      await tap(
        tester,
        find.descendant(of: filters, matching: find.text('Under 20 min')),
      );
      expect(cards(tester), lessThanOrEqualTo(high));

      await tap(
        tester,
        find.descendant(of: filters, matching: find.text('High protein')),
      );
      await tap(
        tester,
        find.descendant(of: filters, matching: find.text('Under 20 min')),
      );
      expect(cards(tester), all);
    });

    testWidgets('searching by name finds the recipe, and a miss says so', (
      tester,
    ) async {
      _phone(tester);
      await pump(tester, _host(hub()));
      await openRecipes(tester);
      final title = book.recipes.first.titleEn;

      await tester.enterText(
        find.byKey(const ValueKey('hub-recipe-search')),
        title,
      );
      await tester.pumpAndSettle();
      expect(cards(tester), greaterThanOrEqualTo(1));
      expect(cards(tester), lessThan(book.recipes.length));

      await tester.enterText(
        find.byKey(const ValueKey('hub-recipe-search')),
        'zzzzzz',
      );
      await tester.pumpAndSettle();
      expect(cards(tester), 0);
      expect(find.byKey(const ValueKey('hub-recipes-empty')), findsOneWidget);
    });

    testWidgets('Safe for me is a chip she turns on, never a gate', (
      tester,
    ) async {
      _phone(tester);
      var asks = 0;
      await pump(
        tester,
        _host(hub(asked: false, onAnswerAllergies: () => asks++)),
      );
      await openRecipes(tester);
      final all = cards(tester);
      final filters = find.byKey(const ValueKey('hub-recipe-filters'));

      // Not on by default: everything is listed.
      expect(all, book.recipes.length);

      // Until she has said what she avoids it asks, and claims nothing.
      await tap(
        tester,
        find.descendant(of: filters, matching: find.text('Safe for me')),
      );
      expect(asks, 1);
      expect(cards(tester), all);
    });

    testWidgets(
      'once she has answered, Safe for me keeps only checked dishes',
      (tester) async {
        _phone(tester);
        await pump(tester, _host(hub(asked: true)));
        await openRecipes(tester);
        final filters = find.byKey(const ValueKey('hub-recipe-filters'));
        await tap(
          tester,
          find.descendant(of: filters, matching: find.text('Safe for me')),
        );
        expect(
          cards(tester),
          book.recipes.where((r) => r.allergensKnown).length,
        );
      },
    );

    testWidgets('a tapped recipe opens it', (tester) async {
      _phone(tester);
      final opened = <String>[];
      await pump(tester, _host(hub(onOpenRecipe: opened.add)));
      await openRecipes(tester);
      await tap(
        tester,
        find
            .byWidgetPredicate((w) => w.runtimeType.toString() == 'BookCard')
            .first,
      );
      expect(opened, hasLength(1));
    });

    testWidgets('an allergy removes recipes that hold it', (tester) async {
      _phone(tester);
      await pump(
        tester,
        _host(
          hub(
            constraints: const DietaryConstraints(
              allergies: {'tree_nuts'},
              dietary: <String>{},
            ),
          ),
        ),
      );
      await openRecipes(tester);
      final shown = cards(tester);
      expect(shown, lessThan(book.recipes.length));
    });
  });

  group('Plan', () {
    testWidgets('fills the week and draws the grocery list under it', (
      tester,
    ) async {
      _phone(tester);
      final dinners = [
        for (final r in book.recipes)
          if (recipeMealOf(r) == RecipeMeal.dinner) r.recipeId,
      ];
      await pump(
        tester,
        _host(hub(initialSegment: EatHubSegment.plan, fillFrom: dinners)),
      );

      expect(find.text('Grocery list'), findsOneWidget);
      await tap(tester, find.byKey(const ValueKey('e07-fill-week')));
      for (final day in ['mon', 'tue', 'wed', 'thu', 'fri']) {
        expect(find.byKey(ValueKey('e07-day-$day')), findsOneWidget);
      }
      // The list under the dinners was read again after the week changed.
      expect(find.text('Plan your week first'), findsNothing);
      expect(find.byKey(const ValueKey('e07-rearrange')), findsOneWidget);
    });

    testWidgets('picking a dinner goes through the pick flow', (tester) async {
      _phone(tester);
      final picked = <PlanDay>[];
      await pump(
        tester,
        _host(
          hub(
            initialSegment: EatHubSegment.plan,
            onPickDinner: (day) async => picked.add(day),
          ),
        ),
      );
      await tap(tester, find.byKey(const ValueKey('e07-plan-week')));
      expect(picked, [PlanDay.mon]);
    });
  });

  group('flags', () {
    testWidgets('Plan goes when E07 is off, and Recipes stay', (tester) async {
      _phone(tester);
      AppRouter.featureFlags = FeatureFlags.everything.with_({
        Feature.weekPlan: false,
      });
      await pump(tester, _host(hub()));
      expect(
        find.byKey(const ValueKey('eat-hub-open-recipes')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('eat-hub-open-plan')), findsNothing);
    });

    testWidgets('with Recipes off there are no rows under the meals', (
      tester,
    ) async {
      _phone(tester);
      // The plan is built from recipes, so switching recipes off takes both.
      AppRouter.featureFlags = FeatureFlags.everything.with_({
        Feature.recipes: false,
      });
      await pump(tester, _host(hub()));
      expect(find.byKey(const ValueKey('eat-hub-open-recipes')), findsNothing);
      expect(find.byKey(const ValueKey('eat-hub-open-plan')), findsNothing);
      expect(find.byKey(const ValueKey('eat-diary-lunch')), findsOneWidget);
    });

    testWidgets('the grocery list goes when E08 is off', (tester) async {
      _phone(tester);
      AppRouter.featureFlags = FeatureFlags.everything.with_({
        Feature.groceryList: false,
      });
      await pump(tester, _host(hub(initialSegment: EatHubSegment.plan)));
      expect(find.text('Grocery list'), findsNothing);
    });
  });

  group('large text and Arabic', () {
    for (final locale in const [Locale('en'), Locale('ar')]) {
      for (final segment in EatHubSegment.values) {
        testWidgets(
          '${locale.languageCode} ${segment.name} at 2.0 on a small screen',
          (tester) async {
            _small(tester);
            await pump(
              tester,
              _host(
                hub(initialSegment: segment, onSnap: () {}, onSpeak: () {}),
                locale: locale,
                textScale: 2.0,
              ),
            );
            expect(tester.takeException(), isNull);
            if (segment != EatHubSegment.log) {
              // Recipes and Plan carry their own header with a way back.
              expect(
                find.byKey(const ValueKey('eat-hub-back')),
                findsOneWidget,
              );
              await backToDay(tester);
              expect(tester.takeException(), isNull);
            }
            expect(
              find.byKey(const ValueKey('eat-hub-search')),
              findsOneWidget,
            );

            // Searching at this size is fine too.
            await type(tester, 'koshari');
            expect(tester.takeException(), isNull);
            expect(find.byType(FoodResultRow), findsWidgets);
          },
        );
      }
    }

    for (final scale in const [1.3, 1.5]) {
      testWidgets('a phone at $scale keeps the bar pinned and fits in Arabic', (
        tester,
      ) async {
        _phone(tester);
        await pump(
          tester,
          _host(
            hub(onSnap: () {}, onSpeak: () {}),
            locale: const Locale('ar'),
            textScale: scale,
          ),
        );
        expect(tester.takeException(), isNull);
        final before = tester.getTopLeft(
          find.byKey(const ValueKey('eat-hub-search')),
        );
        await tester.drag(
          find.byKey(const ValueKey('eat-hub-scroll')),
          const Offset(0, -400),
        );
        await tester.pumpAndSettle();
        expect(
          tester.getTopLeft(find.byKey(const ValueKey('eat-hub-search'))),
          before,
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Arabic names the two rows and reads right to left', (
      tester,
    ) async {
      _phone(tester);
      await pump(tester, _host(hub(), locale: const Locale('ar')));
      expect(find.text('الوصفات'), findsOneWidget);
      expect(find.text('الخطة'), findsOneWidget);
      expect(
        Directionality.of(tester.element(find.byType(EatHubView))),
        TextDirection.rtl,
      );
    });

    testWidgets('on a short screen at 2.0 the bar scrolls with the page', (
      tester,
    ) async {
      _small(tester);
      await pump(tester, _host(hub(), textScale: 2.0));
      final before = tester.getTopLeft(
        find.byKey(const ValueKey('eat-hub-search')),
      );
      await tester.drag(
        find.byKey(const ValueKey('eat-hub-scroll')),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('eat-hub-search'))).dy,
        lessThan(before.dy),
      );
    });

    testWidgets('tap targets in the bar are at least 48 high', (tester) async {
      _phone(tester);
      await pump(tester, _host(hub(onSnap: () {}, onSpeak: () {})));
      await type(tester, 'k');
      for (final key in const [
        'eat-hub-mic',
        'eat-hub-clear',
        'eat-snap-meal',
      ]) {
        final size = tester.getSize(find.byKey(ValueKey(key)));
        expect(size.height, greaterThanOrEqualTo(48), reason: key);
        expect(size.width, greaterThanOrEqualTo(48), reason: key);
      }
    });
  });
}
