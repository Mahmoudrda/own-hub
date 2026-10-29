// Recipes the Own Hub kitchen wrote are never listed under Rahma's heading.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/eat/data/seeded_recipe_library.dart';
import 'package:own_hub/features/eat/domain/allergy_guard.dart';
import 'package:own_hub/features/eat/domain/recipe.dart';
import 'package:own_hub/features/eat/presentation/recipes_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';
import 'package:own_hub/ui/hand/hand.dart' show BookCard;

Widget _host(Widget child, Locale locale) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppL10n.localizationsDelegates,
  supportedLocales: AppL10n.supportedLocales,
  theme: buildTheme(locale),
  home: child,
);

void main() {
  late RecipeBook book;

  setUpAll(() {
    book = RecipeBook.fromJson(
      (jsonDecode(
        File('assets/content/rahma_recipes.json').readAsStringSync(),
      ) as Map).cast<String, Object?>(),
    );
  });

  for (final entry in {
    const Locale('en'): ("Rahma's recipes", 'From the Own Hub kitchen'),
    const Locale('ar'): ('وصفات رحمة', 'من مطبخ Own Hub'),
  }.entries) {
    testWidgets(
      'Own Hub\'s recipes sit under their own heading, ${entry.key}',
      (tester) async {
        tester.view.physicalSize = const Size(1170, 36000);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.reset);
        final (rahmaHeading, kitchenHeading) = entry.value;
        final ar = entry.key.languageCode == 'ar';
        String title(Recipe r) => ar ? r.titleAr! : r.titleEn;

        await tester.pumpWidget(
          _host(
            RecipesView(
              book: book,
              asked: true,
              constraints: DietaryConstraints.none,
              onSelectTab: (_) {},
            ),
            entry.key,
          ),
        );
        await tester.pumpAndSettle();

        final rahmaAt = tester.getTopLeft(find.text(rahmaHeading)).dy;
        // The badge on each card says the same words; the heading is the first.
        final kitchenAt = tester.getTopLeft(find.text(kitchenHeading).first).dy;
        expect(kitchenAt, greaterThan(rahmaAt));

        final ours = book.recipes.where((r) => r.isOwnHub).toList();
        final hers = book.recipes.where((r) => !r.isOwnHub).toList();
        expect(ours, isNotEmpty);
        for (final recipe in ours) {
          final found = find.text(title(recipe));
          expect(found, findsOneWidget, reason: recipe.recipeId);
          expect(
            tester.getTopLeft(found).dy,
            greaterThan(kitchenAt),
            reason: '${recipe.recipeId} is under the kitchen heading',
          );
        }
        for (final recipe in hers) {
          final found = find.text(title(recipe));
          expect(found, findsWidgets, reason: recipe.recipeId);
          expect(
            tester.getTopLeft(found.first).dy,
            lessThan(kitchenAt),
            reason: '${recipe.recipeId} is above the kitchen heading',
          );
        }
      },
    );
  }

  testWidgets(
    'before she has answered, all thirty-one are shown with what is in them',
    (tester) async {
      tester.view.physicalSize = const Size(1170, 36000);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _host(
          RecipesView(book: book, asked: false, onSelectTab: (_) {}),
          const Locale('en'),
        ),
      );
      await tester.pumpAndSettle();

      for (final recipe in book.recipes.where((r) => r.isOwnHub)) {
        expect(
          find.text(recipe.titleEn),
          findsOneWidget,
          reason: recipe.recipeId,
        );
      }
      expect(find.text('Checked by Own Hub'), findsNWidgets(11));
      expect(find.text("What can't you eat?"), findsOneWidget);
      // Rahma's name goes on nothing she did not review: no Own Hub card
      // carries it, and neither does the label the data layer gives them.
      for (final recipe in book.recipes.where((r) => r.isOwnHub)) {
        expect(recipe.verifiedLabel, isNot(contains('Rahma')));
        final card = find.ancestor(
          of: find.text(recipe.titleEn),
          matching: find.byType(BookCard),
        );
        expect(card, findsOneWidget, reason: recipe.recipeId);
        expect(
          find.descendant(of: card, matching: find.textContaining('Rahma')),
          findsNothing,
          reason: recipe.recipeId,
        );
      }
    },
  );

  testWidgets('a woman allergic to tree nuts sees the nut-free ones only', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 36000);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _host(
        RecipesView(
          book: book,
          asked: true,
          constraints: const DietaryConstraints(
            allergies: {'tree_nuts'},
            dietary: <String>{},
          ),
          onSelectTab: (_) {},
        ),
        const Locale('en'),
      ),
    );
    await tester.pumpAndSettle();

    final ours = book.recipes.where((r) => r.isOwnHub);
    for (final recipe in ours) {
      final holdsNuts = recipe.allergensFinal.contains('tree_nuts');
      expect(
        find.text(recipe.titleEn),
        holdsNuts || recipe.status == RecipeStatus.review ? findsNothing : findsOneWidget,
        reason: recipe.recipeId,
      );
    }
    expect(
      ours.where((r) => r.allergensFinal.contains('tree_nuts')),
      hasLength(5),
    );
    expect(find.text('From the Own Hub kitchen'), findsWidgets);
  });
}
