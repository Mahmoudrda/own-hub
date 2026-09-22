/// The food pack — and the honest modelling of what it does not contain.
///
/// G5 §1.2: `foods` and `recipes` are immutable content, read **zero** times
/// from Firestore on any hot path. A signed pack ships with the app and is
/// updated out of band, which is what makes parsing free and makes E02 work on a
/// microbus with no signal.
///
/// ## `allergens[]` and `dietTags[]` do not exist, and this file says so
///
/// `SCHEMA-SPINE.md` §1 calls them "**mandatory, not enrichment**" and requires
/// that a missing tag read as "**unknown, therefore unsafe** — never as safe".
/// `DECISIONS.md` and `PHASE2-ACCEPTANCE.md` both record that the content has
/// not been authored, and that this blocks `P0-EAT-01`.
///
/// So [Food.allergens] is `Set<String>?`, and **null means unknown**. It is not
/// an empty set, because an empty set is a claim — "this dish contains none of
/// the allergens you named" — and that claim is exactly the one nobody is in a
/// position to make yet. [AllergyGuard] reads the difference and fails closed on
/// it.
///
/// A fabricated allergen list would make the guard *look* like it works. That is
/// the worst available outcome here, so it is not done: the type carries the
/// absence instead.
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
    this.grams,
  });

  /// "S" | "M" | "L", or a count like "2" for eggs.
  final String id;

  /// What she reads. Supplied by the caller from the dictionary.
  final String label;

  /// Frozen onto the item at log time, with the pack version.
  final int kcal;
  final int proteinG;

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
  });

  final String foodId;

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

  /// What she gets if she picks nothing — the middle size, which is the one she
  /// usually serves.
  FoodSize get defaultSize => sizes[sizes.length ~/ 2];

  FoodSize? sizeById(String id) {
    for (final size in sizes) {
      if (size.id == id) return size;
    }
    return null;
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
        .replaceAll(RegExp(r'[^\w؀-ۿ ]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return stripped;
  }
}
