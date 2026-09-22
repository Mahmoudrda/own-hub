/// One screening answer — G14 §1.4's `screening[i]` and §3.2's state machine.
///
/// ```
/// UNSET ──coach answers──► PASS
///                        ├► MODIFY
///                        └► REFER ──carried into every re-assessment──► REFER
///                                  └──coach clears, with a reason──► CLEARED
/// ```
///
/// `REFER → CLEARED` is the only exit, and the reason is not optional. The
/// constructor **throws** rather than asserting, because an assert is compiled
/// out in release and this is the invariant that stops a referral being cleared
/// by a blank field on a coach's screen.
///
/// The symmetric refusal matters just as much: a reason on an outcome that is
/// not `cleared` would let a `refer` be stamped with text that the next
/// component along reads as "resolved".
library;

import 'package:meta/meta.dart';

import 'contraindication_tag.dart';

/// Per-item outcome. Note there is deliberately no `error` or `failed` value:
/// HANDOFF 14 says `refer` is not a failure state, and the cheapest way to stop
/// a screen rendering it as one is to give it nothing failure-shaped to read.
enum ScreeningOutcome { unset, pass, modify, refer, cleared }

/// One screened item, and the tags it suppresses while referred.
@immutable
class ScreeningItem {
  ScreeningItem({
    required this.id,
    required this.outcome,
    Set<ContraindicationTag> suppresses = const {},
    this.clearedReason,
    this.clearedAt,
  }) : suppresses = Set.unmodifiable(suppresses) {
    final reason = clearedReason;
    if (outcome == ScreeningOutcome.cleared) {
      if (reason == null || reason.trim().isEmpty) {
        throw ArgumentError.value(
          clearedReason,
          'clearedReason',
          'A referral is cleared only by an explicit action carrying a reason',
        );
      }
    } else if (reason != null) {
      throw ArgumentError.value(
        clearedReason,
        'clearedReason',
        'Only a cleared outcome may carry a reason (G14 §3.2)',
      );
    }
  }

  final String id;
  final ScreeningOutcome outcome;

  /// The tags this item suppresses — G14 §1.5's vocabulary, so the avoid list
  /// and a referral cannot disagree.
  final Set<ContraindicationTag> suppresses;

  /// Why it was cleared. Non-null exactly when [outcome] is `cleared`.
  final String? clearedReason;

  final DateTime? clearedAt;

  /// True while this item is suppressing moves.
  bool get isActiveReferral => outcome == ScreeningOutcome.refer;

  @override
  String toString() => 'ScreeningItem($id, ${outcome.name})';
}
