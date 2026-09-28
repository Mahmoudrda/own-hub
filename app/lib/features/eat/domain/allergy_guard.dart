/// The safety path — G5 §5.1.
///
/// This is the one safety-critical rule in the Eat group, and it has two halves
/// that are deliberately **not** symmetrical:
///
/// | | source | where applied | on conflict |
/// |---|---|---|---|
/// | **Allergy** | `profile.allergies[]` | removed from every candidate list *before* ranking | the write is refused until she acknowledges it explicitly |
/// | **Dietary preference** | `profile.dietary[]` | removed from suggestions and recipes | **no sheet, no override, no warning** |
///
/// The asymmetry is the point. G5 §5.1: "treating a preference like an allergy
/// trains her to dismiss the sheet that matters." A woman who is sent a warning
/// every time she logs something non-vegetarian will tap through the nut warning
/// too.
///
/// ## Fail closed means three different things, and they are all here
///
///  1. **A named allergen.** Her allergies are known and the dish contains one.
///     Blocked, and the allergen is named.
///  2. **Unknown allergen data.** Her allergies are known and non-empty, and the
///     dish has no allergen list at all. `SCHEMA-SPINE.md` §1: a missing tag
///     must read as "unknown, therefore unsafe — never as safe". Blocked.
///  3. **Unknown constraints.** `profile.allergies` could not be read — a cold
///     start, no cache, a brand-new install. G5 §5.1: "An unknown constraint is
///     not an absent one." Blocked for the allergy class, while suggestions
///     still render.
///
/// Case 3 is why [DietaryConstraints.allergies] is nullable rather than
/// defaulting to empty. An empty set is a **claim** — "she has no allergies" —
/// and defaulting to it is how a guard silently turns itself off for exactly the
/// women who have not been asked yet.
///
/// ## Why `P0-EAT-01` cannot pass on this code
///
/// The guard is correct and tested. What does not exist is the content it reads:
/// `foods.allergens[]` is unauthored (`DECISIONS.md`, `SCHEMA-SPINE.md` §1,
/// `PHASE2-ACCEPTANCE.md` risk 1), and no screen in the product captures
/// `profile.allergies` (`DECISIONS.md` D3 says it should; G5 §9 Q10b and G7 Q18
/// both defer the home to the owner). So in the shipped app every assessment
/// resolves to case 2 or case 3.
///
/// Nothing here fabricates either side of that. A guard that passed its test by
/// inventing an allergen list would be a fabricated safety guarantee shown to a
/// woman with a food allergy, which is the worst outcome this feature can
/// produce.
library;

import 'package:meta/meta.dart';

import 'food_library.dart';
import 'recipe.dart';

/// What she cannot eat, and what she prefers not to.
///
/// Both fields are nullable and **null means "could not be read"**, never "she
/// has none". See the file note.
@immutable
class DietaryConstraints {
  const DietaryConstraints({this.allergies, this.dietary});

  /// Known, and empty — she was asked and named nothing.
  static const DietaryConstraints none = DietaryConstraints(
    allergies: <String>{},
    dietary: <String>{},
  );

  /// Not yet readable. The state every woman is in today, because no screen
  /// captures this.
  static const DietaryConstraints unknown = DietaryConstraints();

  /// Safety. Null = unreadable.
  final Set<String>? allergies;

  /// Preference. Null = unreadable.
  final Set<String>? dietary;

  bool get allergiesKnown => allergies != null;
  bool get hasAllergies => (allergies ?? const <String>{}).isNotEmpty;
  bool get dietaryKnown => dietary != null;

  @override
  String toString() =>
      'DietaryConstraints(allergies: ${allergies ?? "unknown"}, '
      'dietary: ${dietary ?? "unknown"})';
}

/// Why a log was refused.
enum AllergyBlockReason {
  /// The dish contains something she told us she is allergic to.
  namedAllergen,

  /// The dish has no allergen data, and she has an allergy. Unknown is unsafe.
  unknownAllergenData,

  /// Her allergies could not be read at all. An unknown constraint is not an
  /// absent one.
  constraintsUnavailable,
}

/// The guard's answer for one food.
@immutable
class AllergyAssessment {
  const AllergyAssessment._({required this.reason, required this.allergens});

  /// Safe to log.
  static const AllergyAssessment clear = AllergyAssessment._(
    reason: null,
    allergens: <String>{},
  );

  factory AllergyAssessment.blocked(
    AllergyBlockReason reason, {
    Set<String> allergens = const <String>{},
  }) => AllergyAssessment._(reason: reason, allergens: allergens);

  /// Null when clear.
  final AllergyBlockReason? reason;

  /// The allergens to name on the sheet, when there are any to name. Empty for
  /// the two unknown cases, because naming a specific allergen there would be
  /// stating something nobody knows.
  final Set<String> allergens;

  bool get isBlocked => reason != null;

  @override
  String toString() =>
      isBlocked ? 'AllergyAssessment.blocked($reason, $allergens)' : 'clear';
}

/// Filters candidates before ranking, and refuses a conflicting write.
///
/// Both halves matter and they are not interchangeable. [screen] is what stops a
/// conflicting food ever being *offered*; [assess] is what stops one being
/// *logged* when she reaches it another way — by name, by voice, by a coach's
/// plan, or from the lock-screen nudge.
class AllergyGuard {
  const AllergyGuard(this.constraints);

  final DietaryConstraints constraints;

  /// Removes what she must not be offered, **before** ranking.
  ///
  /// G5 §5.1: "filtering at the source, not validating after". A ranker that saw
  /// the full list and a filter that ran afterwards would put a conflicting dish
  /// at the top and then remove it, which is how an empty suggestion list gets
  /// "fixed" by moving the filter later.
  ///
  /// The three removals:
  ///
  ///  * an allergen she named, when the dish's allergens are known;
  ///  * a dish whose allergens are **unknown**, when she has any allergy at all;
  ///  * a dietary preference she stated, when the dish's tags are known.
  ///
  /// When her allergies cannot be read, suggestions still render — G5 §5.1 item
  /// 3 is explicit that the list is not emptied. [assess] is what holds the line
  /// in that case, at the moment of the log.
  List<Food> screen(Iterable<Food> candidates) {
    final allergies = constraints.allergies;
    final dietary = constraints.dietary;

    return candidates.where((food) {
      if (allergies != null && allergies.isNotEmpty) {
        final tags = food.allergens;
        // Unknown is unsafe — never "safe by default".
        if (tags == null) return false;
        if (tags.any(_matches(allergies))) return false;
      }

      if (dietary != null && dietary.isNotEmpty) {
        final tags = food.dietTags;
        // A preference is not a safety constraint: an unknown tag is NOT treated
        // as a conflict. Doing so would empty the recipe list for every woman
        // with a preference, on content that does not exist yet, and teach her
        // the filter is broken.
        if (tags != null && !_satisfies(tags, dietary)) return false;
      }

      return true;
    }).toList();
  }

  /// The verdict for a log that is about to be written.
  ///
  /// Called in the domain layer **before** the write, so every entry point hits
  /// it — including the notification quick-action, which therefore cannot
  /// one-tap-log a conflicting meal.
  ///
  /// [acknowledged] carries the allergens she has explicitly accepted on this
  /// item. She is the authority on her own body: an explicit tap clears the
  /// block and is stamped onto the item as `allergenOverride`. Note that it
  /// clears only the allergens it actually names — acknowledging sesame does not
  /// clear nuts.
  AllergyAssessment assess(
    Food food, {
    Set<String> acknowledged = const <String>{},
  }) {
    final allergies = constraints.allergies;

    // Case 3: we do not know what she cannot eat.
    if (allergies == null) {
      if (acknowledged.isNotEmpty) return AllergyAssessment.clear;
      return AllergyAssessment.blocked(
        AllergyBlockReason.constraintsUnavailable,
      );
    }

    // She was asked and named nothing. There is nothing to fail closed about,
    // and unknown allergen data on a dish is not a conflict for her.
    if (allergies.isEmpty) return AllergyAssessment.clear;

    final tags = food.allergens;

    // Case 2: she has an allergy and nobody has said what is in this dish.
    if (tags == null) {
      if (acknowledged.isNotEmpty) return AllergyAssessment.clear;
      return AllergyAssessment.blocked(AllergyBlockReason.unknownAllergenData);
    }

    // Case 1: a named allergen.
    final hits = tags.where(_matches(allergies)).toSet();
    final outstanding = hits
        .where((hit) => !acknowledged.any((ack) => _same(ack, hit)))
        .toSet();
    if (outstanding.isEmpty) return AllergyAssessment.clear;

    return AllergyAssessment.blocked(
      AllergyBlockReason.namedAllergen,
      allergens: outstanding,
    );
  }

  /// True when logging [food] needs no acknowledgement at all.
  bool isClear(Food food) => !assess(food).isBlocked;

  /// Removes the recipes she must not be offered, **before** anything ranks or
  /// sorts them. The recipe half of [screen], and it fails closed twice over.
  ///
  /// Two removals, and the second is the one this method exists for:
  ///
  ///  * **A named allergen.** `allergensFinal` intersects what she declared.
  ///    Same rule as a food, same case-insensitive comparison.
  ///  * **An unsigned recipe.** `allergenReviewedBy` is null, which means
  ///    nobody has put their name to what is in this dish. That is not the same
  ///    fact as an empty allergen set, and collapsing the two is how a library
  ///    that nobody has checked comes to look checked. Extended from the
  ///    existing `allergens == null` rule for foods, for the same reason:
  ///    unknown is unsafe, never safe by default.
  ///
  /// As with foods, an unsigned recipe is removed **only for a woman who has
  /// declared an allergy**. For everyone else it stays in the list and the
  /// screen says out loud that it has not been checked, because hiding the
  /// whole library from everybody would not make anyone safer and would make
  /// the tab look broken.
  ///
  /// [Recipe.advisories] are deliberately not consulted. A pregnancy note or a
  /// favism note is not something she ticked, so filtering on it would be the
  /// app deciding something about her body that she did not tell it.
  List<Recipe> screenRecipes(Iterable<Recipe> candidates) {
    final allergies = constraints.allergies;
    final dietary = constraints.dietary;
    final declared = allergies != null && allergies.isNotEmpty;

    return candidates.where((recipe) {
      if (declared) {
        if (!recipe.allergensReviewed) return false;
        if (recipe.allergensFinal.any(_matches(allergies))) return false;
      }
      if (dietary != null && dietary.isNotEmpty) {
        // A preference is not a safety constraint, so a recipe with no diet
        // tags at all is not treated as a conflict. Doing so would empty the
        // book for every woman with a preference, on content that mostly does
        // not carry tags yet, and teach her the filter is broken.
        if (recipe.dietTags.isNotEmpty &&
            !_satisfies(recipe.dietTags, dietary)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  /// How many of [candidates] [screenRecipes] would take away.
  ///
  /// The list screen states this figure at its foot. Hiding dishes silently is
  /// worse than hiding them visibly: a woman who declared a nut allergy and
  /// then found six recipes missing has no way to tell a filter from a fault.
  int hiddenCount(Iterable<Recipe> candidates) =>
      candidates.length - screenRecipes(candidates).length;

  bool Function(String) _matches(Set<String> against) =>
      (String tag) => against.any((a) => _same(a, tag));

  /// A dish satisfies a preference set when it carries every tag she asked for.
  ///
  /// "Vegetarian on weekdays" means the dish must *be* vegetarian, so this is a
  /// containment test rather than an intersection.
  static bool _satisfies(Set<String> tags, Set<String> wanted) =>
      wanted.every((w) => tags.any((t) => _same(t, w)));

  /// Case- and whitespace-insensitive. "Sesame", "sesame " and "SESAME" are one
  /// allergen; a guard that missed on capitalisation would fail open.
  static bool _same(String a, String b) =>
      a.trim().toLowerCase() == b.trim().toLowerCase();
}
