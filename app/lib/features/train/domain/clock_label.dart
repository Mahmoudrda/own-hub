/// Timers, rendered as text.
///
/// R04's "0:24", R06's countdown and R09's rest clock are the only strings in
/// this feature with no dictionary key, and correctly so: a clock is a *value*,
/// not copy. There is nothing in "0:38" to translate.
///
/// What it must get right is the digits. `P0-A11Y-01` requires Western numerals
/// in Arabic — "12 kg × 10", not "١٢". Dart's integer formatting is Western in
/// every locale, and the Arabic dictionary agrees: all 457 of its values that
/// contain a number use Western digits and none use Eastern ones. So this is
/// deliberately plain string formatting rather than `NumberFormat`, which would
/// switch to Eastern digits under an Arabic locale and break that agreement.
///
/// The colon is not mirrored. A clock reads the same way in both languages.
library;

/// `m:ss`, the way every timer in this product is written.
String clockLabel(Duration duration) {
  final total = duration.isNegative ? Duration.zero : duration;
  final minutes = total.inMinutes;
  final seconds = total.inSeconds.remainder(60);
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}
