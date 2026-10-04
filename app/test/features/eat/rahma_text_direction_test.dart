// Rahma's words read right to left, in either language of the app.
//
// Her ingredients and steps are Egyptian Arabic with English words inside
// them ("كيس stevia"), numbered as she numbered them ("1- ..."). Laid out
// left to right in the English interface, the number landed on the wrong side
// and mixed lines broke apart. Her text is drawn right to left whatever the
// app's language; the app's own labels keep the app's direction; and her
// text is never changed.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/features/eat/data/seeded_recipe_library.dart';
import 'package:own_hub/features/eat/domain/recipe.dart';
import 'package:own_hub/features/eat/presentation/rahma_recipe_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';

Widget _host(Widget child, Locale locale) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppL10n.localizationsDelegates,
  supportedLocales: AppL10n.supportedLocales,
  theme: buildTheme(locale),
  home: child,
);

TextDirection _directionOf(WidgetTester tester, String text) {
  final paragraph = tester.renderObject<RenderParagraph>(
    find.text(text, findRichText: true).first,
  );
  return paragraph.textDirection;
}

void main() {
  late Recipe lazyCake;

  setUpAll(() async {
    final book = await SeededRecipeLibrary(
      readAsset: (path) async => File(path).readAsString(),
    ).load();
    lazyCake = book.recipes.firstWhere((r) => r.titleEn == 'Lazy Cake');
    expect(lazyCake.steps, isNotEmpty);
    expect(lazyCake.ingredients, isNotEmpty);
  });

  for (final lang in const ['en', 'ar']) {
    testWidgets('her ingredients and steps are right to left, app in $lang', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      final l10n = lookupAppL10n(Locale(lang));

      await tester.pumpWidget(
        _host(RahmaRecipeView(recipe: lazyCake), Locale(lang)),
      );
      await tester.pumpAndSettle();

      for (final step in lazyCake.steps) {
        // Verbatim: found by her exact text.
        expect(find.text(step.textAr), findsOneWidget);
        expect(_directionOf(tester, step.textAr), TextDirection.rtl);
      }
      for (final ingredient in lazyCake.ingredients) {
        expect(_directionOf(tester, ingredient.qtyLine), TextDirection.rtl);
      }

      // Her lines start at the right edge of the card, so her numbers sit on
      // the right, in both languages: her shortest step ends where her
      // longest one, which wraps across the whole column, ends.
      final bySize = lazyCake.steps.toList()
        ..sort((a, b) => a.textAr.length.compareTo(b.textAr.length));
      final shortest = tester.getRect(find.text(bySize.first.textAr));
      final longest = tester.getRect(find.text(bySize.last.textAr));
      expect((shortest.right - longest.right).abs(), lessThan(1.0));

      // The app's own labels keep the app's direction.
      expect(
        _directionOf(tester, l10n.steps),
        lang == 'ar' ? TextDirection.rtl : TextDirection.ltr,
      );
      expect(
        _directionOf(tester, l10n.ingredients),
        lang == 'ar' ? TextDirection.rtl : TextDirection.ltr,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the page as printed is right to left too', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    final en = lookupAppL10n(const Locale('en'));

    await tester.pumpWidget(
      _host(RahmaRecipeView(recipe: lazyCake), const Locale('en')),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(en.asItIsInTheBook));
    await tester.pumpAndSettle();
    await tester.tap(find.text(en.asItIsInTheBook));
    await tester.pumpAndSettle();

    expect(find.text(lazyCake.bodyAr), findsOneWidget);
    expect(_directionOf(tester, lazyCake.bodyAr), TextDirection.rtl);
  });
}
