/// The food pack — and the honest modelling of what it does not contain.
///
/// G5 §1.2: `foods` and `recipes` are immutable content, read **zero** times
/// from Firestore on any hot path. A signed pack ships with the app and is
/// updated out of band, which is what makes parsing free and makes E02 work on a
/// microbus with no signal.
///
/// ## `allergens[]`: null means unknown, and the shipped pack no longer is
///
/// `SCHEMA-SPINE.md` §1 calls `allergens[]` and `dietTags[]` "**mandatory, not
/// enrichment**" and requires that a missing tag read as "**unknown, therefore
/// unsafe** — never as safe".
///
/// So [Food.allergens] is `Set<String>?`, and **null means unknown**. It is not
/// an empty set, because an empty set is a claim — "this dish contains none of
/// the allergens you named" — and [AllergyGuard] reads the difference and fails
/// closed on it.
///
/// The bundled Egyptian pack now carries a list for every food, derived from the
/// standard ingredients and over-inclusive, with its basis recorded in the
/// pack's `review` note (`tool/build_food_pack.py` refuses a food without one).
/// The hand-written sample foods and the foods she types in still carry null,
/// and still fail closed.
///
/// ## Names come from the caller
///
/// The 4,100-food library is content from a build-time bundle, not copy from the
/// dictionary — the same position `TrainRepository` takes on the 124 exercise
/// titles. Until that pipeline exists the sample foods are resolved from
/// `AppL10n` by the views, so nothing in this layer hardcodes a name in either
/// language and the parser still has real text to match against.
library;

import 'package:meta/meta.dart';

import 'meal_images.dart';

/// The seven shelves the pack is browsed by.
///
/// The names are the `category` strings in `assets/content/foods_eg.json`, which
/// `tool/build_food_pack.py` refuses to write with any other value.
enum FoodCategory {
  egyptianDishes,
  proteins,
  dairyAndCheese,
  grainsAndBreads,
  vegetablesAndSalads,
  fruitsAndNuts,
  snacksAndDrinks;

  /// The category a pack string names, or null for an unknown string.
  static FoodCategory? fromWire(String? wire) {
    if (wire == null) return null;
    for (final category in values) {
      if (category.name == wire) return category;
    }
    return null;
  }
}

/// One portion a woman actually serves — "medium bowl", "2 eggs".
///
/// Portions are the objects she serves, never grams (E06's design note). [grams]
/// is carried for the content pipeline and is never rendered as a choice.
@immutable
class FoodSize {
  const FoodSize({
    required this.id,
    required this.label,
    required this.kcal,
    required this.proteinG,
    this.carbsG,
    this.fatG,
    this.fiberG,
    this.grams,
  });

  /// "S" | "M" | "L", or a count like "2" for eggs.
  final String id;

  /// What she reads. Supplied by the caller from the dictionary.
  final String label;

  /// Frozen onto the item at log time, with the pack version.
  final int kcal;
  final int proteinG;

  /// Null where the pack does not say. Nothing invents them: a food without
  /// them logs without them, and its day total leaves them out.
  final int? carbsG;
  final int? fatG;
  final int? fiberG;

  final int? grams;
}

/// A food in the pack.
@immutable
class Food {
  const Food({
    required this.foodId,
    required this.names,
    required this.sizes,
    this.allergens,
    this.dietTags,
    this.popularity = 0,
    this.verified = true,
    this.category,
    this.kind,
    this.custom = false,
    this.community = false,
  });

  final String foodId;

  /// The painted picture, or null while this food has none.
  String? get imageAsset => MealImages.assetFor(foodId);

  /// Every spelling the parser may match — the display name first, then aliases
  /// and the Franco-Arabic form. §2.10: the parser can only ever emit a `foodId`
  /// that is already in this list, so it selects and never generates.
  final List<String> names;

  final List<FoodSize> sizes;

  /// **Null means unknown, not none.** See the file note — this is the field the
  /// content pipeline has not delivered, and the distinction is the whole of the
  /// fail-closed behaviour.
  final Set<String>? allergens;

  /// Null means unknown, on the same terms. A *preference* never blocks a log,
  /// so unknown here is far less consequential than unknown above.
  final Set<String>? dietTags;

  /// Drives E09's three starters — "the top-popularity Egyptian foods".
  final int popularity;

  /// The pack ships verified values only; an unverified food renders without
  /// totals rather than with invented ones.
  final bool verified;

  /// The shelf she browses it under. Null for the hand-written samples and the
  /// foods she typed in, which show only under All.
  final FoodCategory? category;

  /// The pack's kind of dish ("drink", "soup", "main"), where it has one. Units
  /// read it: only drinks and soups are measured in millilitres.
  final String? kind;

  /// True for a food she typed in herself ("Quick custom"). Its name travels
  /// with every meal it is logged in, because no pack holds it.
  final bool custom;

  /// True for a food other women confirmed and the owner approved. It is
  /// [custom] too, so its name travels with each meal it is logged in.
  final bool community;

  /// What she gets if she picks nothing — the middle size, which is the one she
  /// usually serves.
  FoodSize get defaultSize {
    for (final size in sizes) {
      if (size.id == 'M') return size;
    }
    return sizes[sizes.length ~/ 2];
  }

  FoodSize? sizeById(String id) {
    for (final size in sizes) {
      if (size.id == id) return size;
    }
    final grams = gramsOfSizeId(id);
    return grams == null ? null : sizeForGrams(grams);
  }

  /// The size id of a portion she chose by weight: `g150` is 150 g.
  static String sizeIdForGrams(int grams) => 'g$grams';

  /// The weight in a [sizeIdForGrams] id, or null for any other id.
  static int? gramsOfSizeId(String id) {
    final match = RegExp(r'^g(\d{1,5})$').firstMatch(id);
    final grams = match == null ? null : int.parse(match.group(1)!);
    return grams == null || grams < 1 ? null : grams;
  }

  /// The size whose weight is known, which every portion by weight scales from.
  FoodSize? get weighedSize {
    final middle = defaultSize;
    if (middle.grams != null && middle.grams! > 0) return middle;
    for (final size in sizes) {
      if (size.grams != null && size.grams! > 0) return size;
    }
    return null;
  }

  /// A portion of [grams], worked out from the weighed size's figures. Null
  /// when the pack gives this food no weight to scale from: nothing is
  /// invented for it.
  FoodSize? sizeForGrams(int grams) {
    final base = weighedSize;
    if (base == null || grams < 1) return null;
    final ratio = grams / base.grams!;
    int? scale(int? value) => value == null ? null : (value * ratio).round();
    return FoodSize(
      id: sizeIdForGrams(grams),
      label: '$grams g',
      kcal: (base.kcal * ratio).round(),
      proteinG: (base.proteinG * ratio).round(),
      carbsG: scale(base.carbsG),
      fatG: scale(base.fatG),
      fiberG: scale(base.fiberG),
      grams: grams,
    );
  }

  /// True when nobody has told us what is in this dish.
  bool get allergensUnknown => allergens == null;

  @override
  String toString() => 'Food($foodId)';
}

/// The pack, in memory. Every lookup is local; nothing here touches a network.
class FoodLibrary {
  const FoodLibrary(this.foods);

  /// An empty pack. Resolves nothing and invents nothing, which is the correct
  /// behaviour before the bundle has been built.
  static const FoodLibrary empty = FoodLibrary(<Food>[]);

  final List<Food> foods;

  int get count => foods.length;

  Food? byId(String foodId) {
    for (final food in foods) {
      if (food.foodId == foodId) return food;
    }
    return null;
  }

  /// Foods whose name or alias matches [fragment].
  ///
  /// §2 rule 10, the food half: **selects, never generates.** A fragment that
  /// matches nothing returns an empty list, and the caller renders it as an
  /// `unresolved` chip. It never becomes a guessed food and never acquires an
  /// invented gram figure.
  ///
  /// Matching is case-insensitive and diacritic-tolerant on both scripts, and
  /// prefers a whole-name match over a partial one so that "ful" does not beat
  /// "ful with egg" when she typed the longer phrase.
  List<Food> resolve(String fragment) {
    final needle = _normalise(fragment);
    if (needle.isEmpty) return const <Food>[];

    final exact = <Food>[];
    final partial = <Food>[];
    for (final food in foods) {
      var matched = false;
      var whole = false;
      for (final name in food.names) {
        final hay = _normalise(name);
        if (hay.isEmpty) continue;
        if (hay == needle) {
          whole = true;
          matched = true;
          break;
        }
        if (hay.contains(needle) || needle.contains(hay)) matched = true;
      }
      if (whole) {
        exact.add(food);
      } else if (matched) {
        partial.add(food);
      }
    }
    // Most popular first within each tier, so "eggs" offers the one she is
    // likeliest to mean rather than whichever was authored first.
    exact.sort((a, b) => b.popularity.compareTo(a.popularity));
    partial.sort((a, b) => b.popularity.compareTo(a.popularity));
    return [...exact, ...partial];
  }

  /// The food whose **whole name** is [text], or null.
  ///
  /// Tried before a sentence is split on its connectors, because several real
  /// Egyptian dishes contain one: "Molokhia with chicken", "Ful with egg and
  /// cumin". Splitting those first would shatter a dish she named exactly into
  /// a food plus an unresolved chip, which reads as the product not knowing a
  /// dish it does in fact know.
  Food? exact(String text) {
    final needle = _normalise(text);
    if (needle.isEmpty) return null;

    Food? best;
    for (final food in foods) {
      for (final name in food.names) {
        if (_normalise(name) == needle) {
          if (best == null || food.popularity > best.popularity) best = food;
          break;
        }
      }
    }
    return best;
  }

  /// E09's three starters: the most popular foods in the pack.
  List<Food> mostPopular(int take) {
    final sorted = [...foods]
      ..sort((a, b) => b.popularity.compareTo(a.popularity));
    return sorted.take(take).toList();
  }

  /// [input] as [resolve] compares it. Public so a caller can tell whether two
  /// spellings are the same to the matcher.
  static String normalise(String input) => _normalise(input);

  /// Lower-cases, strips Arabic diacritics and collapses whitespace.
  ///
  /// Egyptian women type Arabic with and without harakat and in Franco, so a
  /// match that depended on exact orthography would fail on most real input.
  static String _normalise(String input) {
    final stripped = input
        .toLowerCase()
        .replaceAll(RegExp(r'[ً-ْـ]'), '')
        .replaceAll(RegExp(r'[أإآ]'), 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي')
        .replaceAll(RegExp(r'[^\w؀-ۿ ]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return stripped;
  }
}
