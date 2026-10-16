/// What one credited session actually did, for the screens that report it.
///
/// R10 and R12 used to print "+30 points" and "+15 points" whatever happened,
/// so a third session on a capped day announced points the ledger had refused.
/// This carries what was granted, not what the table lists, and the week and
/// level on either side of the credit — the figures D40's reveal is built from.
library;

import 'package:meta/meta.dart';

@immutable
class CreditOutcome {
  const CreditOutcome({
    this.alreadyCredited = false,
    this.sessionPoints = 0,
    this.weekPoints = 0,
    this.weekCountedNow = false,
    this.loggedBefore = 0,
    this.loggedAfter = 0,
    this.target = 0,
    this.levelBefore = 1,
    this.levelAfter = 1,
    this.milestonesEarned = const <String>[],
    this.milestonePoints = 0,
  });

  /// The same session id was credited before. Nothing moved.
  final bool alreadyCredited;

  /// Points the session itself was granted after the daily cap. Zero is a real
  /// answer, and the screens print nothing for it.
  final int sessionPoints;

  /// Points for the week counting, when this session counted it.
  final int weekPoints;

  /// This session took the week to its target.
  final bool weekCountedNow;

  /// Her week's sessions before and after this one, and its target.
  final int loggedBefore;
  final int loggedAfter;
  final int target;

  final int levelBefore;
  final int levelAfter;

  /// Milestone ids reached by this credit, in catalogue order.
  final List<String> milestonesEarned;

  /// What those milestones paid, as the ledger granted it.
  final int milestonePoints;

  /// Everything this credit paid: the session, the week and its milestones.
  int get pointsGranted => sessionPoints + weekPoints + milestonePoints;

  bool get levelledUp => levelAfter > levelBefore;

  @override
  String toString() =>
      'CreditOutcome(${alreadyCredited ? 'replay' : '+$pointsGranted'}, '
      'week $loggedBefore→$loggedAfter/$target'
      '${weekCountedNow ? ' counted' : ''})';
}
