/// Weights, rendered as text.
///
/// The sibling of `clock_label.dart`, and it exists for the same reason: a
/// weight is a *value*, not copy. There is nothing in "12 kg" to translate
/// except the unit, which the dictionary already holds.
///
/// ## Why this is not `NumberFormat`
///
/// `P0-A11Y-01` requires Western numerals in Arabic — "12 kg × 10", never "١٢".
/// `NumberFormat` switches to Eastern digits under an Arabic locale, and the
/// Arabic dictionary agrees with the requirement rather than with `intl`: every
/// one of its values containing a number uses Western digits. So weights are
/// formatted with plain Dart, exactly as timers are.
///
/// ## Why it exists at all
///
/// Her chosen weight comes off a `List<double>`, so agreeing to 14 kg produces
/// `14.0`. Interpolated straight into the ICU message — which is what gen-l10n
/// does for a placeholder with no `format` — the undo bar read
/// "Set 2 saved · 14.0 kg × 9". A woman who lifted 14 kg should be told she
/// lifted 14 kg.
library;

/// A weight the way this product writes one: "12", "14", "12.5".
///
/// Trailing `.0` is dropped because plates are whole numbers far more often
/// than not, and a half-plate still reads correctly.
String weightLabel(num kg) {
  final rounded = kg.roundToDouble();
  if (kg == rounded) return '${rounded.toInt()}';
  return '$kg';
}
