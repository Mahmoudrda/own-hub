/// A follower count that **cannot be ranked**, by construction.
///
/// `BUILD-BRIEF.md` §2 rule 11 — *nothing is ranked by followers, weight or
/// weight lost* — and `G10-community.md` §5 names the enforcement point for the
/// social half of it as this type:
///
/// > `FollowerCount` is a value object that **does not implement `Comparable`**
/// > and has no `>` operator, so a ranking cannot be written in Dart; the index
/// > exemptions mean it cannot be written in a query either.
///
/// Both halves are required and neither is sufficient. This is the Dart half.
///
/// ## What is deliberately absent, and why each absence matters
///
/// There is no `compareTo`, no `operator >`, `<`, `>=` or `<=`, no
/// `implements Comparable`, and no static `sort`/`rankBy`/`topBy` helper. A list
/// of these cannot be passed to `List.sort()` without a comparator somebody has
/// to write by hand and a reviewer would see in the diff — which is the point.
/// The type does not make ranking *forbidden*; it makes ranking *something you
/// have to add code to do*, in a file where that code has no excuse to be.
///
/// Equality and `hashCode` are kept, because putting a count in a `Set` or
/// comparing "did it change" are not rankings. `==` cannot order anything.
///
/// ## Why it is a type at all, rather than an `int`
///
/// An `int` has `>` on it. The moment a follower count is an `int`, sorting a
/// list of women by it is one keystroke and no reviewer would catch it in a
/// hundred-line diff. Wrapping it costs one allocation and removes the
/// keystroke — the same technique `PrescribedSet` uses against rule 1.
///
/// ## It is also hidden at launch
///
/// `Feature.communityFollowerCounts` is off (`DECISIONS.md`, recorded in
/// `lib/domain/flags/feature_flags.dart`). This type is what a count *is*; the
/// flag is whether any screen may draw one. They are separate on purpose — the
/// ranking prohibition is unconditional, while the display is an owner decision
/// that can be reversed without touching this file.
library;

import 'package:meta/meta.dart';

import '../../../domain/format/number_label.dart';

@immutable
class FollowerCount {
  const FollowerCount(this.value)
    : assert(value >= 0, 'a count is not negative');

  /// Nobody at all. Distinct from "unknown" — see [FollowerCount.unknown].
  static const FollowerCount none = FollowerCount(0);

  /// The count has not been read. A profile rendered from a post's `authorCard`
  /// has no follower figure in it, and showing `0` there would be a lie about a
  /// woman rather than an absence of information.
  static const FollowerCount? unknown = null;

  final int value;

  /// "1,204" — Western digits in both languages, per `P0-A11Y-01`.
  ///
  /// A *label*, not copy: there is nothing in a numeral to translate, which is
  /// why this does not go through the dictionary. Same reasoning as
  /// `clock_label.dart` and `weight_label.dart`.
  String get label => countLabel(value);

  @override
  bool operator ==(Object other) =>
      other is FollowerCount && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'FollowerCount($value)';
}
