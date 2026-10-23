// The painted meal pictures: what is bundled is exactly what index.json says,
// every listed id is a real food or recipe, and a screen without a picture
// keeps its drawn mark.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/features/eat/domain/meal_images.dart';
import 'package:own_hub/features/eat/domain/recipe.dart';
import 'package:own_hub/features/eat/presentation/eat_widgets.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';
import 'package:own_hub/ui/hand/book_card.dart';
import 'package:own_hub/ui/hand/food_marks.dart';

const _dir = 'assets/art/meals';

List<Map<String, dynamic>> _index() =>
    (jsonDecode(File('$_dir/index.json').readAsStringSync()) as List)
        .cast<Map<String, dynamic>>();

Set<String> _ids(String file, String list, String key) =>
    ((jsonDecode(File('assets/content/$file').readAsStringSync()) as Map)[list]
            as List)
        .map((e) => (e as Map)[key] as String)
        .toSet();

Widget _host(Widget child) => MaterialApp(
  localizationsDelegates: AppL10n.localizationsDelegates,
  supportedLocales: AppL10n.supportedLocales,
  theme: buildTheme(const Locale('en')),
  home: Scaffold(body: child),
);

void main() {
  tearDown(MealImages.clear);

  test('every listed id has its files, and nothing else ships', () {
    final foods = _ids('foods_eg.json', 'foods', 'id');
    final recipes = _ids('rahma_recipes.json', 'recipes', 'recipeId');
    final expected = <String>{};
    for (final row in _index()) {
      final id = row['id'] as String;
      final kind = row['kind'] as String;
      expect(
        kind == 'food' ? foods : recipes,
        contains(id),
        reason: '$id is listed as a $kind and is not one',
      );
      final folders = kind == 'food' ? [''] : ['', '2.0x/', '3.0x/'];
      for (final folder in folders) {
        final path = '$_dir/$folder$id.webp';
        expect(File(path).existsSync(), isTrue, reason: '$path is missing');
        expected.add(path);
      }
    }
    final shipped = Directory(_dir)
        .listSync(recursive: true)
        .whereType<File>()
        .map((f) => f.path)
        .where((p) => p.endsWith('.webp'))
        .toSet();
    expect(shipped, expected, reason: 'files not in index.json ship for free');
  });

  test('the licence record covers the meal pictures', () {
    final text = File('assets/art/LICENCE.md').readAsStringSync();
    expect(text, contains('FLUX.1 [schnell]'));
    expect(text, contains('meals/'));
  });

  test('imageAsset is null until the id is installed', () {
    final id = _index().first['id'] as String;
    expect(MealImages.assetFor(id), isNull);
    MealImages.adopt(File('$_dir/index.json').readAsStringSync());
    expect(MealImages.assetFor(id), '$_dir/$id.webp');
    expect(MealImages.assetFor('not_a_real_dish'), isNull);
    MealImages.adopt('not json');
    expect(MealImages.assetFor(id), isNull);
  });

  test('a recipe falls back to the painted picture of its main dish', () {
    final rows =
        (jsonDecode(
                  File('assets/content/rahma_recipes.json').readAsStringSync(),
                )['recipes']
                as List)
            .cast<Map<String, Object?>>();
    Recipe byId(String id) =>
        Recipe.fromJson(rows.firstWhere((r) => r['recipeId'] == id));
    final shakshoka = byId('rahma_shakshoka');
    final oats = byId('rahma_overnight_oats');
    MealImages.clear();
    expect(shakshoka.imageAsset, isNull);
    // The index as it was before her own picture was painted: only the dish
    // it falls back to.
    final withoutHers = [
      for (final e in _index())
        if (e['id'] != 'rahma_shakshoka') e,
    ];
    MealImages.adopt(jsonEncode(withoutHers));
    expect(shakshoka.imageAsset, '$_dir/shakshuka.webp');
    // Once her own picture is listed, hers wins.
    MealImages.adopt(File('$_dir/index.json').readAsStringSync());
    expect(shakshoka.imageAsset, '$_dir/rahma_shakshoka.webp');
    MealImages.clear();
    expect(oats.imageAsset, isNull);
    // Every mapped dish is a real painted picture.
    final ids = _index().map((e) => e['id']).toSet();
    final recipeIds = rows.map((r) => r['recipeId']).toSet();
    for (final e in kRecipeDishPicture.entries) {
      expect(recipeIds, contains(e.key));
      expect(ids, contains(e.value));
    }
  });

  testWidgets('MealRow shows the picture when it has one', (tester) async {
    final id = _index().first['id'] as String;
    await tester.pumpWidget(
      _host(
        MealRow(
          title: 'Dish',
          meta: '10 g protein',
          logLabel: 'Log',
          imageAsset: '$_dir/$id.webp',
        ),
      ),
    );
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('MealRow without a picture draws none', (tester) async {
    await tester.pumpWidget(
      _host(const MealRow(title: 'Dish', meta: 'm', logLabel: 'Log')),
    );
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('a picture that cannot be read falls back, never a broken box', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const BookCard(
          cardId: 'x',
          markKey: FoodMarks.pot,
          imageAsset: '$_dir/missing.webp',
          child: Text('Dish'),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(FoodMark), findsOneWidget);
  });

  testWidgets('a BookCard with a picture draws it instead of the mark', (
    tester,
  ) async {
    final id = _index().first['id'] as String;
    await tester.pumpWidget(
      _host(
        BookCard(
          cardId: 'x',
          markKey: FoodMarks.pot,
          imageAsset: '$_dir/$id.webp',
          child: const Text('Dish'),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(Image), findsOneWidget);
    expect(find.byType(FoodMark), findsNothing);
  });
}
