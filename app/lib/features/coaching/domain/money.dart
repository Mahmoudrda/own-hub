/// Money, in Egyptian piastres, with no formatter and no zero.
///
/// ## Why a type and not an `int`
///
/// Three defects this removes by construction:
///
///  * **A fabricated zero.** There is no `Money.zero`, no default constructor
///    and no `Money?` that degrades to 0. Where a figure is unknown the field
///    is `null`, and null renders *nothing* — never "0 EGP". A zero is a claim
///    about her bank account; absence is the truth when the seam is silent.
///  * **A mixed unit.** Piastres in, piastres out. A price that is 1,800 in one
///    file and 180,000 in another is how a woman is charged a hundred times too
///    much, and it is the kind of thing a plain `int` invites.
///  * **Arabic-Indic digits.** [amountText] formats from `int.toString()`, which
///    is ASCII by the language specification, and groups with a literal comma.
///    `NumberFormat` is never used anywhere in this product: under an `ar`
///    locale it renders ١٨٠٠، which the spec forbids for every figure.
///
/// ## What this type deliberately cannot do
///
/// It has no `+`, no `-` and no `*`. Nothing in the client computes a price, a
/// share, a discount or a total — those are the server's, priced from the
/// coach's own offer document (`G11` §3.2, `P0-PAY-09`). A type that could add
/// money is a type a screen can be tempted to do arithmetic with.
library;

import 'package:meta/meta.dart';

/// The one currency this product takes. Not a parameter: a second currency is a
/// product decision with a settlement account behind it, not a constructor
/// argument somebody can pass by accident.
const String kCurrencyCode = 'EGP';

/// An amount of money that really exists.
@immutable
class Money implements Comparable<Money> {
  /// The amount in piastres. Negative is rejected: a negative price is not a
  /// refund, it is a bug, and a refund has its own type.
  const Money.piastres(this.piastres)
    : assert(piastres >= 0, 'A price is never negative.');

  /// Whole pounds, which is how every offer in Egypt is actually written.
  const Money.pounds(int pounds) : piastres = pounds * 100;

  final int piastres;

  /// The pounds part. Used for display only.
  int get pounds => piastres ~/ 100;

  /// The piastres part, 0–99.
  int get fraction => piastres % 100;

  /// The figure as she reads it: Western digits, comma-grouped, no currency.
  ///
  /// `180000` → `1,800`. `180050` → `1,800.50`.
  ///
  /// The currency **word** is not appended here, because it is a word and
  /// therefore belongs to the dictionary. See `presentation/coaching_money.dart`
  /// for the one place the two are joined, and for what happens when the
  /// dictionary has no word for the period in question.
  String get amountText {
    final whole = _group(pounds);
    if (fraction == 0) return whole;
    return '$whole.${fraction.toString().padLeft(2, '0')}';
  }

  @override
  int compareTo(Money other) => piastres.compareTo(other.piastres);

  bool operator <=(Money other) => piastres <= other.piastres;

  bool operator >=(Money other) => piastres >= other.piastres;

  @override
  bool operator ==(Object other) =>
      other is Money && other.piastres == piastres;

  @override
  int get hashCode => piastres.hashCode;

  @override
  String toString() => 'Money($amountText $kCurrencyCode)';
}

/// Comma-grouped Western digits, written out rather than delegated.
///
/// `int.toString()` is specified to produce U+0030–U+0039 regardless of locale,
/// so the digits are Western by construction rather than by configuration. The
/// separator is a literal `,` for the same reason: an Arabic build must show
/// `1,800`, and a locale-aware grouper would show `١٬٨٠٠`.
String _group(int value) {
  final digits = value.toString();
  final out = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
    out.write(digits[i]);
  }
  return out.toString();
}
