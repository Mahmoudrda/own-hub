/// Digits as she types them, folded onto the ones a provider reads.
///
/// In the domain layer because two screens and one repository need the same
/// answer: `C06` decides whether the number is long enough, `C07` reads the
/// code, and the auth repository dials the number. An Arabic keyboard types
/// `٠١٢`, and a screen that counted only `0`-`9` kept "Send me a code" off for
/// a number that plainly reads as eleven digits.
library;

/// The digits in [input], with Arabic-Indic and Persian forms folded onto
/// `0`–`9` and everything else dropped.
///
/// Exposed because both the number and the six-digit code need it: an Arabic
/// keyboard produces `٠١٢`, and `int.parse` and Firebase alike only read ASCII.
String asciiDigits(String input) {
  const int ascii0 = 0x30;
  const int arabicIndic0 = 0x0660;
  const int extendedArabicIndic0 = 0x06F0;

  final buffer = StringBuffer();
  for (final rune in input.runes) {
    if (rune >= ascii0 && rune <= ascii0 + 9) {
      buffer.writeCharCode(rune);
    } else if (rune >= arabicIndic0 && rune <= arabicIndic0 + 9) {
      buffer.writeCharCode(ascii0 + rune - arabicIndic0);
    } else if (rune >= extendedArabicIndic0 &&
        rune <= extendedArabicIndic0 + 9) {
      buffer.writeCharCode(ascii0 + rune - extendedArabicIndic0);
    }
  }
  return buffer.toString();
}

/// A number as typed on a Western or Arabic keyboard: Arabic-Indic and Persian
/// digits fold onto `0`-`9`, and a comma or the Arabic decimal separator
/// (U+066B) reads as the decimal point. Null when it is not a number.
double? parseLocalNumber(String raw) {
  const int ascii0 = 0x30;
  const int arabicIndic0 = 0x0660;
  const int extendedArabicIndic0 = 0x06F0;
  const int arabicDecimal = 0x066B;

  final buffer = StringBuffer();
  for (final rune in raw.trim().runes) {
    if (rune >= arabicIndic0 && rune <= arabicIndic0 + 9) {
      buffer.writeCharCode(ascii0 + rune - arabicIndic0);
    } else if (rune >= extendedArabicIndic0 &&
        rune <= extendedArabicIndic0 + 9) {
      buffer.writeCharCode(ascii0 + rune - extendedArabicIndic0);
    } else if (rune == arabicDecimal || rune == 0x2C) {
      buffer.write('.');
    } else {
      buffer.writeCharCode(rune);
    }
  }
  return double.tryParse(buffer.toString());
}
