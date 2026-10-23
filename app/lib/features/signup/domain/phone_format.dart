/// The number field on `C06`, kept in one shape however it was filled.
///
/// She may type it, paste it from a contact (`+20 10 1234 5678`, `0020…`,
/// `2010…`, `010…`) or have the keyboard autofill it. All of them come out as
/// the ten digits that follow `+20`, grouped `1XX XXX XXXX`, and Arabic-Indic
/// digits are folded to `0`-`9` on the way.
library;

import 'package:flutter/widgets.dart';

import 'digits.dart';

/// Digits in an Egyptian mobile number after the country code.
const int kEgyptianMobileDigits = 10;

/// The national digits in [raw]: the country code and the trunk zero are
/// dropped, at most [kEgyptianMobileDigits] are kept.
///
/// A leading `20` is a country code only on a number long enough to carry one
/// (twelve digits), so a woman typing her own digits one at a time is never
/// stripped mid-number. A leading `0` is the trunk zero only on an eleventh
/// digit, for the same reason.
String nationalDigits(String raw) {
  var digits = asciiDigits(raw);
  if (digits.startsWith('0020')) {
    digits = digits.substring(4);
  } else if (digits.startsWith('20') && digits.length >= 12) {
    digits = digits.substring(2);
  }
  if (digits.startsWith('0') && digits.length > kEgyptianMobileDigits) {
    digits = digits.substring(1);
  }
  return digits.length > kEgyptianMobileDigits
      ? digits.substring(0, kEgyptianMobileDigits)
      : digits;
}

/// [digits] grouped for reading: `101 234 5678`.
String groupNational(String digits) {
  final out = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i == 3 || i == 6) out.write(' ');
    out.write(digits[i]);
  }
  return out.toString();
}

/// [value] normalised and grouped, with the caret kept after the same digit.
TextEditingValue formatEgyptianMobile(TextEditingValue value) {
  final text = value.text;
  final digits = nationalDigits(text);
  final grouped = groupNational(digits);
  if (grouped == text) return value;

  // Where the caret goes: after as many digits as sat before it. When the
  // normalising dropped a prefix the counts no longer line up, so it goes to
  // the end, which is where a paste leaves it anyway.
  final folded = asciiDigits(text);
  var offset = grouped.length;
  final extent = value.selection.extentOffset;
  if (value.selection.isValid && folded.length == digits.length) {
    final before = asciiDigits(text.substring(0, extent.clamp(0, text.length)));
    var seen = 0;
    var at = 0;
    while (at < grouped.length && seen < before.length) {
      if (grouped[at] != ' ') seen++;
      at++;
    }
    offset = at;
  }
  return TextEditingValue(
    text: grouped,
    selection: TextSelection.collapsed(offset: offset),
  );
}
