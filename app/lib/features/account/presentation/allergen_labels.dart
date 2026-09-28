/// One name per allergen, in one place.
///
/// Three screens ask her what she cannot eat: `A02`'s dietary editor, `G17` in
/// the coached intake, and `E10` in front of the recipe library. Each of them
/// used to carry its own list, which is how `G17` ended up with a comment saying
/// "the four the content team authored" while `AllergenTag` had grown to
/// sixteen. A list that exists three times is a list that will disagree with
/// itself, and disagreeing about an allergen is not a cosmetic bug.
///
/// [allergenLabel] is total over [AllergenTag] by construction: the switch has
/// no default, so adding a seventeenth tag is a compile error here rather than
/// a missing chip somewhere she is trying to declare it.
library;

import '../../../l10n/app_l10n.dart';
import '../domain/dietary_profile.dart';

/// What to call [tag] on screen, in the interface's own Modern Standard Arabic.
///
/// **This is chrome, not content.** The names are the app speaking, not Rahma,
/// so they come through the dictionary like every other label. Her colloquial
/// only ever arrives from `rahma_recipes.json`.
String allergenLabel(AppL10n l10n, AllergenTag tag) => switch (tag) {
  AllergenTag.gluten => l10n.gluten_1v1e1,
  AllergenTag.crustaceans => l10n.crustaceans,
  AllergenTag.eggs => l10n.eggs,
  AllergenTag.fish => l10n.fish,
  AllergenTag.peanuts => l10n.peanuts,
  AllergenTag.soy => l10n.soy,
  AllergenTag.milk => l10n.milkAndDairy,
  AllergenTag.treeNuts => l10n.treeNuts,
  AllergenTag.celery => l10n.celery,
  AllergenTag.mustard => l10n.mustard,
  AllergenTag.sesame => l10n.sesame,
  AllergenTag.sulphites => l10n.sulphites,
  AllergenTag.lupin => l10n.lupin,
  AllergenTag.molluscs => l10n.molluscs,
  AllergenTag.fava => l10n.favaBeans,
  AllergenTag.coconut => l10n.coconut,
};

/// What to call a wire token a recipe carries, when it is one we know.
///
/// Returns null for a token this build has never heard of, and the caller shows
/// nothing rather than the raw token. A recipe from a later content release may
/// name a tag added after this binary shipped; printing `lupin_flour` at her is
/// worse than printing nothing, and `AllergyGuard` still screens on the raw
/// string either way, so the safety behaviour does not depend on this function.
String? allergenLabelForWire(AppL10n l10n, String wire) {
  final tag = AllergenTag.fromWire(wire);
  return tag == null ? null : allergenLabel(l10n, tag);
}
