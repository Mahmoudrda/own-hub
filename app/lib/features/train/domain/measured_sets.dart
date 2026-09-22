/// Turning what she logged into what a best is measured from.
///
/// This is the conversion G4 performs on the server when it derives
/// `measuredSets` from a session's `sets[]`, written once here so the in-memory
/// product behaves the way the Function will.
///
/// ## An unlogged set is an absence, not a zero
///
/// [SetOutcome.isLogged] is the rule — `!skipped && (reps != null ||
/// holdSeconds != null)` — and this file applies it rather than restating it. A
/// set she skipped is dropped entirely instead of crossing as a lift of no
/// weight, because a zero would be compared against her best and is one
/// comparison away from replacing it.
///
/// ## Rule 1, again
///
/// Only [LoggedSet.outcome] is read. [PrescribedSet] is never consulted for a
/// number — the one field taken from it is the exercise id, which is not a
/// result. [MeasuredSet] has no field capable of holding a prescription, so
/// there is nowhere for one to arrive even by accident.
///
/// ## D19 — `actualHoldSec`
///
/// `SetOutcome.holdSeconds` has existed all along and
/// `MeasuredSet.actualHoldSec` has been read all along; nothing joined them, so
/// `PersonalBestDetector` documented the hold branch as undetectable and P03's
/// hold row could never fill from a real session. The join is one line below,
/// and it is the whole of the decision.
library;

import '../../../domain/rewards/personal_best_detector.dart';
import '../../../domain/training/prescribed_set.dart';
import '../../../domain/training/session.dart' as credit;
import 'train_repository.dart';

/// The measured sets in a flush. Sets she did not log produce nothing.
List<MeasuredSet> measuredSetsFrom(Iterable<LoggedSet> sets) {
  final measured = <MeasuredSet>[];
  for (final set in sets) {
    final outcome = set.outcome;
    if (outcome == null || !outcome.isLogged) continue;

    measured.add(
      MeasuredSet(
        exerciseId: set.prescribed.exerciseId,
        actualWeight: outcome.weightKg,
        actualReps: outcome.reps,
        // D19. Everything else on this screen already worked.
        actualHoldSec: outcome.holdSeconds,
      ),
    );
  }
  return measured;
}

/// Joins the Train feature's [SessionSource] to the credit enum's.
///
/// There are two types with this name — one in `train_repository.dart` for what
/// a session *is*, one in `domain/training/session.dart` for what a session
/// *earns* — and the detector takes the second. This is the only place they
/// meet.
///
/// Written as an exhaustive switch with no default, so a fourth source added to
/// either enum fails the build and somebody has to decide what it earns, rather
/// than inheriting whichever branch happens to run. That is the regression
/// `P0-LOG-12` exists for: when `unplanned` was added, a rule phrased as "not
/// recalled" silently made a logged walk eligible for a personal best.
credit.SessionSource measuredSourceOf(SessionSource source) => switch (source) {
  SessionSource.live => credit.SessionSource.live,
  SessionSource.recalled => credit.SessionSource.recalled,
  SessionSource.unplanned => credit.SessionSource.unplanned,
};
