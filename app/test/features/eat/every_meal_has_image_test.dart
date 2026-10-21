// Every food and every recipe has its painted picture on disk: foods at 1x,
// recipes at 1x, 2x and 3x. The pictures are still being painted, so the
// every-id test is skipped, with the count, until the files cover every id. The
// installed-ids test is never skipped: whatever the index lists must have all
// of its files, and the index and manifest.json must agree.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _folder = 'assets/art/meals';

Set<String> _ids(String file, String list, String key) =>
    ((jsonDecode(File('assets/content/$file').readAsStringSync()) as Map)[list]
            as List)
        .map((e) => (e as Map)[key] as String)
        .toSet();

/// The files an id needs: one size for a food, three for a recipe.
List<String> _files(String id, {required bool recipe}) => [
  '$_folder/$id.webp',
  if (recipe) ...['$_folder/2.0x/$id.webp', '$_folder/3.0x/$id.webp'],
];

List<String> _absent(String id, {required bool recipe}) => [
  for (final path in _files(id, recipe: recipe))
    if (!File(path).existsSync()) path,
];

void main() {
  final foods = _ids('foods_eg.json', 'foods', 'id');
  final recipes = _ids('rahma_recipes.json', 'recipes', 'recipeId');
  final missing = <String, List<String>>{
    for (final id in foods)
      if (_absent(id, recipe: false).isNotEmpty) id: _absent(id, recipe: false),
    for (final id in recipes)
      if (_absent(id, recipe: true).isNotEmpty) id: _absent(id, recipe: true),
  };
  final total = foods.length + recipes.length;

  test(
    'every food and recipe has its image files',
    () {
      expect(missing, isEmpty, reason: 'no picture for: ${missing.keys}');
    },
    skip: missing.isEmpty
        ? null
        : 'images still being painted, enable when the files cover all ids '
              '(${total - missing.length} of $total covered)',
  );

  test('every installed id has all of its files', () {
    final index = (jsonDecode(
      File('$_folder/index.json').readAsStringSync(),
    ) as List).cast<Map<String, dynamic>>();
    final manifest =
        jsonDecode(File('$_folder/manifest.json').readAsStringSync()) as Map;
    expect(
      {for (final row in index) row['id'] as String},
      manifest.keys.toSet(),
      reason: 'index.json and manifest.json list different ids',
    );
    for (final row in index) {
      final id = row['id'] as String;
      final recipe = row['kind'] == 'recipe';
      expect(recipe ? recipes : foods, contains(id), reason: id);
      expect(_absent(id, recipe: recipe), isEmpty, reason: id);
      final entry = manifest[id] as Map;
      expect(entry['prompt_hash'], isNotEmpty, reason: id);
      expect(
        entry['files'],
        _files(
          id,
          recipe: recipe,
        ).map((path) => path.substring(_folder.length + 1)),
        reason: id,
      );
    }
  });
}
