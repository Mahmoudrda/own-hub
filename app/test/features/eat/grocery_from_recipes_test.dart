// E08 — the list is her dinners' own ingredients.
//
// Lines are Rahma's ingredient text, grouped by dinner. A tick is kept under
// recipe id plus her ingredientRef, so building the list again keeps it. With
// no dinner of hers on the week there is no list, only a way to E07.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/week/week_key.dart';
import 'package:own_hub/features/eat/data/seeded_recipe_library.dart';
import 'package:own_hub/features/eat/domain/grocery_from_recipes.dart';
import 'package:own_hub/features/eat/domain/meal_repository.dart';
import 'package:own_hub/features/eat/presentation/eat_sample_library.dart';
import 'package:own_hub/features/eat/presentation/grocery_list_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';

final DateTime _tuesday = DateTime(2026, 9, 15, 13, 12);
final String _weekId = WeekKey.of(_tuesday).id;

late RecipeBook _book;

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

Widget _host(Widget child) => MaterialApp(
  localizationsDelegates: AppL10n.localizationsDelegates,
  supportedLocales: AppL10n.supportedLocales,
  theme: buildTheme(const Locale('en')),
  home: child,
);

void main() {
  setUpAll(() {
    _book = RecipeBook.fromJson(
      (jsonDecode(
        File('assets/content/rahma_recipes.json').readAsStringSync(),
      ) as Map).cast<String, Object?>(),
    );
  });

  test('a line is her own text, keyed by recipe and ingredientRef', () {
    final plan = MealPlan(
      weekId: _weekId,
      dinners: const {
        PlanDay.mon: 'rahma_bagel',
        PlanDay.wed: 'rahma_bagel',
        PlanDay.tue: 'molokhia_chicken',
      },
    );
    final lines = groceryLinesFor(plan, _book.byId);
    final bagel = _book.byId('rahma_bagel')!;
    expect(lines, hasLength(bagel.ingredients.length));
    expect(lines.every((l) => l.recipeId == 'rahma_bagel'), isTrue);
    final first = lines.first;
    expect(
      first.itemKey,
      'rahma_bagel:${bagel.ingredients.first.ingredientRef}',
    );
    expect(first.text, bagel.ingredients.first.qtyLine);
    expect(first.text, isNot(contains('\n')));
  });

  test('an older line has no text and no recipe', () {
    const old = GroceryLine(
      itemKey: 'k',
      ingredientId: 'tomatoes',
      group: GroceryGroup.vegetables,
    );
    expect(old.text, isNull);
    expect(old.recipeId, isNull);
    expect(old.copyWith(ticked: true).text, isNull);
  });

  testWidgets(
    'shows her lines under the dinner, and a tick survives a rebuild',
    (tester) async {
      _phone(tester);
      final repo = InMemoryMealRepository(
        plans: {
          _weekId: MealPlan(
            weekId: _weekId,
            dinners: const {PlanDay.mon: 'rahma_cheese_cake'},
            // A sample line from before: replaced once there are real ones.
            groceries: {
              'old': const GroceryLine(
                itemKey: 'old',
                ingredientId: 'tomatoes',
                group: GroceryGroup.vegetables,
              ),
            },
          ),
        },
      );
      Widget list() => _host(
        GroceryListView(
          repository: repo,
          now: _tuesday,
          recipeOf: _book.byId,
          recipeTitle: (id) => _book.byId(id)?.titleEn,
          onPlanWeek: () {},
        ),
      );

      await tester.pumpWidget(list());
      await tester.pumpAndSettle();

      final cake = _book.byId('rahma_cheese_cake')!;
      expect(find.text(cake.titleEn), findsOneWidget);
      expect(find.text(cake.ingredients.first.qtyLine), findsOneWidget);
      expect(find.text('Tomatoes 1 kg'), findsNothing);

      await tester.tap(find.text(cake.ingredients.first.qtyLine));
      await tester.pumpAndSettle();

      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(list());
      await tester.pumpAndSettle();

      final plan = (await repo.mealPlan(_weekId))!;
      expect(
        plan
            .groceries[recipeGroceryKey(
              cake.recipeId,
              cake.ingredients.first.ingredientRef,
            )]!
            .ticked,
        isTrue,
      );
      expect(plan.groceries.containsKey('old'), isFalse);
    },
  );

  testWidgets('with no dinner of hers there is no list, only E07', (
    tester,
  ) async {
    _phone(tester);
    var planned = 0;
    final repo = InMemoryMealRepository(
      plans: {_weekId: sampleMealPlan(_weekId)},
    );
    await tester.pumpWidget(
      _host(
        GroceryListView(
          repository: repo,
          now: _tuesday,
          recipeOf: (id) => _book.byId(id),
          onPlanWeek: () => planned++,
        ),
      ),
    );
    await tester.pumpAndSettle();
    // A week that already holds lines (the tour's sample) draws them.
    expect(find.text('Plan your week first'), findsNothing);
    expect(find.text('Tomatoes 1 kg'), findsOneWidget);

    final empty = InMemoryMealRepository();
    await tester.pumpWidget(
      _host(
        GroceryListView(
          key: const ValueKey('empty'),
          repository: empty,
          now: _tuesday,
          recipeOf: (id) => _book.byId(id),
          onPlanWeek: () => planned++,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Plan your week first'), findsOneWidget);
    await tester.tap(find.text('Plan my week'));
    expect(planned, 1);
  });
}
