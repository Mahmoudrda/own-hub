/// The recipe library: a bundled seed, with Firestore allowed to win by version.
///
/// ## Why the seed is in the binary at all
///
/// `assets/content/rahma_recipes.json` is about 210 KB of UTF-8 Arabic. Against
/// the 4.8 MB of illustrations already shipped that is nothing, and it buys an
/// Eat tab that works with no network. In Egypt that is not a nicety: a woman on
/// a metro platform at 7am with one bar gets her recipes, or she gets a spinner.
///
/// ## Why the live read is one document and not a query
///
/// Firestore bills per document read. A list screen that queries N recipes on
/// every open is N reads per open; at 200 recipes, 10,000 women and three opens
/// a day that is six million reads a day, which is roughly **$360 a day**. This
/// project has already been bitten by exactly that shape of cost.
///
/// So the wire format is:
///
///   1. `meta/recipes` holds `{ version: N }`. One small read per session, and
///      skipped entirely while a cached version is current.
///   2. `recipeIndex/{locale}_v{N}` is a **single document** holding the list
///      row for every recipe: id, titles, section, tier, time, protein, EGP,
///      allergens, diet tags, mark. About 250 bytes each, so 200 recipes is
///      50 KB and the 1 MB ceiling holds to roughly 2,000. The whole list screen
///      is one read.
///   3. A full body is fetched one document at a time, on open, cache first.
///
/// Steady state is one index read plus about three recipe reads per woman per
/// day: roughly **$0.72 a month** at the same 10,000. Three orders of magnitude,
/// from one structural decision.
///
/// [RecipeLibrary] is the port that shape is written against. [SeededRecipeLibrary]
/// is the half that exists today — the bundle — and [mergeByVersion] is the rule
/// the Firestore half will use when it arrives: **the seed is the floor.** A
/// remote row replaces a seeded one only when its `version` is higher, so a
/// truncated or rolled-back server document can never take a recipe away from a
/// phone that already had it.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../domain/recipe.dart';

/// Where the seed lives. Registered in `pubspec.yaml` under `assets:`.
const String kRahmaRecipesAsset = 'assets/content/rahma_recipes.json';

/// Her book, loaded.
@immutable
class RecipeBook {
  const RecipeBook({
    required this.schemaVersion,
    required this.contentVersion,
    required this.sections,
    required this.recipes,
    required this.assemblies,
    required this.letterAr,
  });

  static const RecipeBook empty = RecipeBook(
    schemaVersion: 0,
    contentVersion: 0,
    sections: <RecipeSection>[],
    recipes: <Recipe>[],
    assemblies: <Recipe>[],
    letterAr: '',
  );

  final int schemaVersion;
  final int contentVersion;
  final List<RecipeSection> sections;

  /// Hers. [RecipeSource.book] and [RecipeSource.authored].
  final List<Recipe> recipes;

  /// [RecipeSource.assembly]. Held apart from [recipes] here rather than
  /// filtered at every call site, so no screen can accidentally draw one on her
  /// card by iterating the wrong list.
  final List<Recipe> assemblies;

  /// The closing letter, page 26. Her words, not chrome.
  final String letterAr;

  List<Recipe> inSection(String sectionId) => [
    for (final r in recipes)
      if (r.sectionId == sectionId) r,
  ]..sort((a, b) => a.orderInSection.compareTo(b.orderInSection));

  Recipe? byId(String recipeId) {
    for (final r in [...recipes, ...assemblies]) {
      if (r.recipeId == recipeId) return r;
    }
    return null;
  }

  factory RecipeBook.fromJson(Map<String, Object?> json) {
    final all = [
      for (final r in (json['recipes'] as List?) ?? const [])
        Recipe.fromJson((r as Map).cast<String, Object?>()),
      for (final a in (json['assemblies'] as List?) ?? const [])
        Recipe.fromJson((a as Map).cast<String, Object?>()),
    ];
    return RecipeBook(
      schemaVersion: json['schemaVersion'] as int? ?? 0,
      contentVersion: json['contentVersion'] as int? ?? 0,
      sections: [
        for (final s in (json['sections'] as List?) ?? const [])
          RecipeSection.fromJson((s as Map).cast<String, Object?>()),
      ]..sort((a, b) => a.order.compareTo(b.order)),
      recipes: [
        for (final r in all)
          if (r.source != RecipeSource.assembly) r,
      ],
      assemblies: [
        for (final r in all)
          if (r.source == RecipeSource.assembly) r,
      ],
      letterAr: json['letter'] as String? ?? '',
    );
  }
}

/// Where recipes come from. One implementation today; the Firestore one is
/// described in the file note and is not written yet.
abstract class RecipeLibrary {
  Future<RecipeBook> load();
}

/// The bundled seed, parsed once and kept.
class SeededRecipeLibrary implements RecipeLibrary {
  SeededRecipeLibrary({this.assetKey = kRahmaRecipesAsset, this.readAsset});

  final String assetKey;

  /// Injected by tests so the parse can be proved without a bundle. Production
  /// leaves it null and reads `rootBundle`.
  final Future<String> Function(String key)? readAsset;

  static RecipeBook? _cache;

  /// Drops the parsed copy. Tests that load a different asset call it; nothing
  /// in the app does, because the seed cannot change while the app is running.
  @visibleForTesting
  static void resetCache() => _cache = null;

  @override
  Future<RecipeBook> load() async {
    final cached = _cache;
    if (cached != null) return cached;
    final raw = await (readAsset?.call(assetKey) ??
        rootBundle.loadString(assetKey));
    final book = RecipeBook.fromJson(
      (jsonDecode(raw) as Map).cast<String, Object?>(),
    );
    return _cache = book;
  }
}

/// The seed is the floor.
///
/// A remote recipe replaces a seeded one only when its `version` is strictly
/// higher, and a remote id the seed does not carry is added. Nothing is ever
/// removed by a remote document: a truncated server response, a partial write or
/// a rollback would otherwise take a recipe off a phone that already had it, and
/// a woman halfway through cooking would watch the card disappear.
List<Recipe> mergeByVersion(List<Recipe> seeded, List<Recipe> remote) {
  final byId = {for (final r in seeded) r.recipeId: r};
  for (final r in remote) {
    final existing = byId[r.recipeId];
    if (existing == null || r.version > existing.version) byId[r.recipeId] = r;
  }
  return byId.values.toList();
}
