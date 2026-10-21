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
}
