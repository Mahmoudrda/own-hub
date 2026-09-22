/// Whole numbers, rendered as text.
///
/// The third member of the family that starts with `clock_label.dart` and
/// `weight_label.dart`, and it exists for the same reason: a count is a
/// *value*, not copy. There is nothing in "1,106" to translate.
///
/// ## Why this is not `NumberFormat`
///
/// `P0-A11Y-01` requires Western numerals in Arabic — "1,106 kcal", never
/// "١٬١٠٦". `intl`'s `NumberFormat` switches to Eastern digits under an Arabic
/// locale, and the Arabic dictionary agrees with the requirement rather than
/// with `intl`: every one of its values containing a number uses Western
/// digits. So this is plain Dart, exactly as timers and weights are.
///
/// ## Why it exists at all
///
/// E04 states her running total. Written with bare interpolation that reads
/// "About 1106 kcal so far today", which looks like a glitch; written with
/// `NumberFormat` it reads "١١٠٦" to an Arabic reader, which is worse. The
/// separator has to be added by hand, so it is added in one place.
library;

/// A count the way this product writes one: "0", "950", "1,106", "12,400".
///
/// The separator is a comma in both languages. Arabic conventionally uses "٬",
/// but this product writes Western digits inside Arabic text throughout, and a
/// Western digit group with an Arabic separator reads as neither.
String countLabel(int value) {
  final digits = value.abs().toString();
  final out = StringBuffer();

  for (var i = 0; i < digits.length; i++) {
    // A separator every three digits from the right, never leading.
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
    out.write(digits[i]);
  }

  return value < 0 ? '-$out' : out.toString();
}
