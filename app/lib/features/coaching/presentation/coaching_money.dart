/// The one place a figure and a currency word are joined.
///
/// ## The gap this file used to be honest about, and how it closed
///
/// `app_en.arb` carried **no bare currency label**. Every EGP string in the
/// dictionary was a whole sentence with the mockup's figure inside it —
/// `n1800Egp` is `'1,800 EGP'`, `n900Egp` is `'900 EGP'` — and
/// `test/baked_in_samples_test.dart` exists precisely to stop those reaching a
/// woman as a claim about her coach. The only currency-bearing string with no
/// figure in it was `egpAMonth` (`'EGP a month'`), so a one-off package had no
/// way to state its own price and `H03` rendered none at all.
///
/// `amountEgp` — `'{amount} EGP'` — closed it. Both branches below now join a
/// runtime figure to a dictionary word:
///
///   1. A **monthly** package: the figure, then `egpAMonth`.
///   2. A **one-off** package: `amountEgp`, filled with the same figure.
///
/// The digits come from the coach's own offer document in both cases, the words
/// come from the dictionary, and `null` still means *render nothing* — a price
/// the seam could not supply is absent, never a zero and never the mockup's.
///
/// `fromPriceLine` still quotes a monthly package only, because `priceFrom` is
/// the cheapest *monthly* offer; that is a fact about the field, not a missing
/// string.
library;

import '../../../l10n/app_l10n.dart';
import '../domain/coaching_repository.dart';
import '../domain/money.dart';

/// The price as she reads it, or null when it cannot be said honestly.
///
/// Null means **render nothing** — not a dash, not a zero, not "free".
String? priceLine(
  AppL10n l10n, {
  required Money? price,
  required OfferPeriod period,
}) {
  if (price == null) return null;
  return switch (period) {
    // "1,800 EGP a month" — Western digits from the data, the words from the
    // dictionary, and the same sentence in Arabic with the digits untouched.
    OfferPeriod.monthly => '${price.amountText} ${l10n.egpAMonth}',
    // "1,800 EGP". This was withheld until today, because every EGP string in
    // the dictionary baked a sample figure into the sentence and there was no
    // bare-currency form -- so a one-off package showed no price at all and no
    // way to buy it. `amountEgp` is parameterised, so the figure is hers.
    OfferPeriod.oneOff => l10n.amountEgp(price.amountText),
  };
}

/// The "from 1,800 EGP a month" line on a directory row.
///
/// Same rule, same reason. A directory row always quotes a monthly package
/// because `priceFrom` is the cheapest *monthly* offer; a coach who publishes
/// only a one-off plan shows no figure in the list.
String? fromPriceLine(AppL10n l10n, Money? priceFrom) =>
    priceFrom == null ? null : '${priceFrom.amountText} ${l10n.egpAMonth}';

/// The rating as a figure, or null when it may not be shown.
///
/// The five-review floor lives on [DirectoryRow.ratingToDisplay]; this only
/// formats. One decimal place, Western digits, and no star character from the
/// dictionary — the star is an icon, because `'4.8 ★ (126)'` in the dictionary
/// is the defect, not the design.
String? ratingText(double? ratingToDisplay) =>
    ratingToDisplay?.toStringAsFixed(1);
