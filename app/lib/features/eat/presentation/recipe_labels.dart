/// The sentences the recipe screens read out of the dictionary, named.
///
/// Two jobs, and both of them are about keeping a generated getter out of a
/// screen.
///
/// ## Plural agreement
///
/// "39 dishes are hidden" is one sentence in English and five in Arabic: a
/// count between 11 and 99 takes the singular in the accusative, so `39 أطباق`
/// is ungrammatical and `39 طبقًا` is right. The dictionary carries the whole
/// plural message and `gen_l10n` picks the form, which is the only way this can
/// be correct for every count without anybody writing the rule down twice.
///
/// The cost is that the generated getter is named after the ICU source string,
/// so it comes out as `countPluralOne1DishIsHidden`. That name says nothing at
/// a call site, and the two hidden-count messages differ only by a
/// disambiguating fingerprint, which is exactly the kind of thing that gets
/// swapped by accident. So each one is wrapped here once, under a name that
/// says which reason it states, and the screens call these.
///
/// **The fingerprint suffix is the fragile part, and it is pinned by test, not
/// by hope.** `build-flutter.mjs` gives the plain slug to whichever of two
/// colliding sources it reaches first and fingerprints the other, so a
/// reordering of `6-v2/i18n/ar-extra.json` could quietly make
/// `countPluralOne1DishIsHidden` the *allergen* message — which would have the
/// screen tell a woman that her body is the reason for something that is not
/// about her body. That is the exact failure these two functions exist to
/// prevent, so it cannot be left to a naming convention.
///
/// What holds it: `rahma_book_view_test.dart` asserts the unchecked sentence
/// appears and the allergen one does not when nothing she named is in the book,
/// and asserts the reverse when the dish really does contain her allergen. A
/// swap fails both.
///
/// ## Time
///
/// A recipe has two times and the cards drew the wrong one. Overnight oats is
/// five minutes of work and a day in the fridge, and the card said "1,445 min".
library;

import '../../../domain/format/number_label.dart';
import '../../../l10n/app_l10n.dart';
import '../domain/recipe.dart' show RecipeSection;

/// "39 dishes are hidden because nobody has checked what is in them yet."
///
/// The reason that is true of the library. It must never be stated as though it
/// were true of her body: today every recipe is unsigned, so a woman who
/// declares molluscs — which appear in none of the thirty-nine — loses the
/// whole book, and telling her that happened "because of what you avoid" is the
/// app blaming her for its own caution.
String dishesHiddenUnchecked(AppL10n l10n, int count) =>
    l10n.countPluralOne1DishIsHidden(count);

/// "3 dishes are hidden because they contain something you avoid."
///
/// The reason that *is* about her. The only one of the two entitled to say so.
String dishesHiddenByAllergen(AppL10n l10n, int count) =>
    l10n.countPluralOne1DishIsHidden_1hlr5(count);

/// The hands-on time, which is the figure a woman choosing a dish is choosing
/// on. Null when the recipe does not state one.
String? handsOnLabel(AppL10n l10n, int? activeMinutes) =>
    activeMinutes == null ? null : l10n.nMinHandsOn(countLabel(activeMinutes));

/// Past two hours a minute figure stops being readable: overnight oats is 1,445
/// of them. Rounded to the nearest hour and **said** to be rounded, rather than
/// printing a true number nobody can use.
const int kHoursFromMinutes = 120;

/// The total time, beside [handsOnLabel]. Null when the recipe does not state
/// one.
String? totalTimeLabel(AppL10n l10n, int? totalMinutes) {
  if (totalMinutes == null) return null;
  if (totalMinutes < kHoursFromMinutes) {
    return l10n.nMinInAll(countLabel(totalMinutes));
  }
  return l10n.countPluralOneAbout1HourIn((totalMinutes / 60).round());
}

/// A section of Rahma's book, named in the language on screen. Her own Arabic
/// title wins where the book carries one.
String sectionTitle(AppL10n l10n, RecipeSection section) =>
    section.titleAr != null && l10n.localeName == 'ar'
    ? section.titleAr!
    : switch (section.sectionId) {
        'sweet_tooth_breakfast' => l10n.sweetToothBreakfast,
        'salty_fulling_breakfast' => l10n.saltyFullingBreakfast,
        'lunchy_junky_yum' => l10n.lunchyJunkyYum,
        'comfy_dinner' => l10n.comfyDinner,
        _ => section.titleEn,
      };
