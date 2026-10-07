/// One console recipe, as the member app reads it.
///
/// The member app's recipe library (`eat/data/recipe_sync.dart`) reads
/// `meta/recipes` for a version, `recipeIndex/{locale}_v{N}` for the list and
/// `recipes/{id}` for each body, parses every body with `Recipe.fromJson` and
/// refuses the **whole** set if any one of them breaks `recipeProblems`. So a
/// recipe the console writes must be in exactly that shape and must pass
/// exactly those rules before it is written, or one save would freeze every
/// woman's library on the version before it.
///
/// That is what this file does. It builds the body and its index row from the
/// console's CSV-shaped row and the method she typed, and runs the member
/// app's own parser and rules over the result. The caller refuses to write
/// anything that comes back with problems.
///
/// The method is the row's `method_ar` (and `method_en`) column: one step a
/// line, or ` | ` between steps where a spreadsheet flattened the cell. The
/// row itself is kept on the document as `adminRow` so the console can open it
/// again exactly as it was saved.
library;

import 'package:meta/meta.dart';

import '../../eat/domain/recipe.dart';
import '../../eat/domain/recipe_validation.dart';

@immutable
class RecipePublication {
  const RecipePublication({
    required this.document,
    required this.indexRow,
    required this.problems,
  });

  /// `recipes/{id}`.
  final Map<String, Object?> document;

  /// Its row in `recipeIndex/{locale}_v{N}`.
  final Map<String, Object?> indexRow;

  /// Why the member app would refuse it. Empty means it may be written.
  final List<String> problems;

  bool get isDraft => document['status'] == RecipeStatus.draft.name;
}

List<String> _tags(String cell) => [
  for (final part in cell.split('|'))
    if (part.trim().isNotEmpty && part.trim().toLowerCase() != 'none')
      part.trim().toLowerCase(),
];

int? _int(String? cell) => int.tryParse((cell ?? '').trim());

String? _text(String? cell) {
  final v = (cell ?? '').trim();
  return v.isEmpty ? null : v;
}

/// The method as steps: one per line, numbered from 1. A cell with no line
/// break is read as steps separated by `|`, the separator `content_schema.dart`
/// documents for an export that flattens a cell.
List<String> methodSteps(String method) {
  final text = method.replaceAll('\r\n', '\n').trim();
  final parts = text.contains('\n') ? text.split('\n') : text.split('|');
  return [
    for (final part in parts)
      if (part.trim().isNotEmpty) part.trim(),
  ];
}

RecipePublication publishRecipe({
  required Map<String, String> values,
  required int version,
  required Set<String> sectionIds,
}) {
  final id = (values['recipeId'] ?? '').trim();
  final titleEn = (values['name_en'] ?? '').trim();
  final titleAr = _text(values['name_ar']);
  final steps = methodSteps(values['method_ar'] ?? '');
  final stepsEn = methodSteps(values['method_en'] ?? '');
  final photo = _text(values['photoFile']);
  final ingredients = [
    for (final part in (values['ingredients'] ?? '').split('|'))
      if (part.trim().isNotEmpty) part.trim(),
  ];
  final allergens = _tags(values['allergens'] ?? '');
  final macros = [
    _int(values['kcal']),
    _int(values['proteinG']),
    _int(values['carbsG']),
    _int(values['fatG']),
  ];
  final computed = macros.every((m) => m != null);
  final minutes = _int(values['minutes']);

  final document = <String, Object?>{
    'recipeId': id,
    'source': _text(values['source']) ?? RecipeSource.authored.name,
    'sectionId': (values['sectionId'] ?? '').trim(),
    'orderInSection': 0,
    'status': _text(values['status']) ?? RecipeStatus.draft.name,
    'version': version,
    'titleEn': titleEn,
    'titleAr': titleAr,
    'titleSearch': [if (titleEn.isNotEmpty) titleEn.toLowerCase(), ?titleAr],
    'bodyAr': steps.join('\n'),
    'closingAr': null,
    'ingredients': [
      for (var i = 0; i < ingredients.length; i++)
        {
          'ingredientRef': '${id}_${i + 1}',
          'foodId': null,
          'qtyTextAr': ingredients[i],
          'gramsBasis': GramsBasis.unknown.name,
        },
    ],
    'ingredientsBasis': ingredients.isEmpty
        ? IngredientsBasis.none.name
        : IngredientsBasis.few.name,
    'steps': [
      for (var i = 0; i < steps.length; i++)
        {'index': i + 1, 'textAr': steps[i], 'usesRefs': <String>[]},
    ],
    'variants': const <Object?>[],
    'components': const <Object?>[],
    'serves': _int(values['serves']),
    'activeMinutes': _int(values['activeMinutes']) ?? minutes,
    'totalMinutes': minutes,
    'kcal': macros[0],
    'proteinG': macros[1],
    'carbsG': macros[2],
    'fatG': macros[3],
    'macroBasis': computed
        ? MacroBasis.computed.name
        : MacroBasis.withheld.name,
    'egpPerServing': _int(values['egpPerServing']),
    'egpPricedAt': _text(values['egpPricedAt']),
    'allergensDerived': allergens,
    'allergensExtra': const <String>[],
    'allergensRemoved': const <String, String>{},
    'allergensFinal': allergens,
    'advisories': _tags(values['advisories'] ?? ''),
    'dietTags': _tags(values['dietTags'] ?? ''),
    'doneness': _text(values['doneness']),
    'sourcePage': _int(values['sourcePage']),
    'authoredBy': (values['authoredBy'] ?? '').trim(),
    'allergenReviewedBy': _text(values['allergenReviewedBy']),
    'markKey': _text(values['markKey']),
    'tier': _text(values['tier']) ?? RecipeTier.free.name,
    'brandHints': const <String, String>{},
    // Her picture, uploaded with `tool/admin_access.sh upload-media` to the
    // one place the content rules let an admin write.
    'photoPath': photo == null ? null : 'content/recipes/$id/$photo',
    // Kept beside the Arabic method, which is what a member is shown.
    'stepsEn': stepsEn,
    // The console's own copy, to open it again as it was saved. The member
    // app's parser ignores it.
    'adminRow': Map<String, String>.of(values),
  };

  final problems = <String>[];
  if (id.isEmpty) problems.add('no id');
  try {
    final recipe = Recipe.fromJson(document);
    problems.addAll(recipeProblems(recipe, sectionIds: sectionIds));
  } catch (error) {
    problems.add('$id: does not parse ($error)');
  }

  final indexRow = <String, Object?>{
    'recipeId': id,
    'titleEn': titleEn,
    'titleAr': titleAr,
    'sectionId': document['sectionId'],
    'orderInSection': 0,
    'source': document['source'],
    'status': document['status'],
    'tier': document['tier'],
    'totalMinutes': minutes,
    'proteinG': macros[1],
    'egpPerServing': document['egpPerServing'],
    'allergensFinal': allergens,
    'allergenReviewedBy': document['allergenReviewedBy'],
    'dietTags': document['dietTags'],
    'markKey': document['markKey'],
    'titleSearch': document['titleSearch'],
    'photoPath': document['photoPath'],
  };

  return RecipePublication(
    document: document,
    indexRow: indexRow,
    problems: List.unmodifiable(problems),
  );
}
