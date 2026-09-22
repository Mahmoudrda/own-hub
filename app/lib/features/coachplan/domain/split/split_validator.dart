/// What a split must be before it can be saved — G14 §1.1, §1.3, §6.
///
/// The interesting rule is `daySlots.length == cycleLength`. `P2-ERR-K20`:
/// change the cycle length and save without filling the new slot, and "the
/// write is refused with a stated reason naming the unfilled slot. A split with
/// a missing day is never saved." A four-day split with three days is not a
/// smaller split; it is a template that will materialise a hole into somebody's
/// month.
library;

import '../prescription.dart';
import 'split.dart';

/// Why a split was refused. Each value names something a screen can say.
enum SplitProblem {
  nameMissing,
  nameTooLong,
  cycleLengthOutOfRange,
  slotCountMismatch,
  duplicateDayIndex,
  dayIndexOutOfRange,
  sessionWithoutTitle,
  restCarriesSession,
  minutesNotOffered,
  restBetweenSetsNotOffered,
  tooManyMoves,
  tooManyAlternatives,
  clientSplitCarriesCoachOnlyField,
}

/// A refusal, carrying the day it is about so the screen can point at it.
class SplitInvalid implements Exception {
  const SplitInvalid(this.problem, {this.dayIndex});

  final SplitProblem problem;

  /// 1-based, when the problem is about one slot.
  final int? dayIndex;

  @override
  String toString() =>
      'SplitInvalid(${problem.name}'
      '${dayIndex == null ? '' : ', day $dayIndex'})';
}

/// The validator both entry points run — the coach's builder and, per D7, the
/// trainee's. One validator, so the two copies of one model cannot drift.
class SplitValidator {
  const SplitValidator();

  /// Every problem with [split], in day order. Empty means saveable.
  List<SplitInvalid> problems(Split split) {
    final found = <SplitInvalid>[];

    if (split.name.trim().isEmpty) {
      found.add(const SplitInvalid(SplitProblem.nameMissing));
    } else if (split.name.length > kMaxSplitNameLength) {
      found.add(const SplitInvalid(SplitProblem.nameTooLong));
    }

    if (split.cycleLength < kMinCycleLength ||
        split.cycleLength > kMaxCycleLength) {
      found.add(const SplitInvalid(SplitProblem.cycleLengthOutOfRange));
    }

    if (split.daySlots.length != split.cycleLength) {
      found.add(const SplitInvalid(SplitProblem.slotCountMismatch));
    }

    final seen = <int>{};
    for (final slot in split.daySlots) {
      if (!seen.add(slot.dayIndex)) {
        found.add(
          SplitInvalid(SplitProblem.duplicateDayIndex, dayIndex: slot.dayIndex),
        );
      }
      if (slot.dayIndex < 1 || slot.dayIndex > split.cycleLength) {
        found.add(
          SplitInvalid(SplitProblem.dayIndexOutOfRange, dayIndex: slot.dayIndex),
        );
      }
      if (slot.isRest) {
        if (slot.title != null ||
            slot.minutes != null ||
            slot.moves.isNotEmpty) {
          found.add(
            SplitInvalid(SplitProblem.restCarriesSession, dayIndex: slot.dayIndex),
          );
        }
        continue;
      }
      if ((slot.title ?? '').trim().isEmpty) {
        found.add(
          SplitInvalid(SplitProblem.sessionWithoutTitle, dayIndex: slot.dayIndex),
        );
      }
      final minutes = slot.minutes;
      if (minutes != null && !kSessionMinuteOptions.contains(minutes)) {
        found.add(
          SplitInvalid(SplitProblem.minutesNotOffered, dayIndex: slot.dayIndex),
        );
      }
      final rest = slot.restBetweenSetsSec;
      if (rest != null && !kRestBetweenSetsOptions.contains(rest)) {
        found.add(
          SplitInvalid(
            SplitProblem.restBetweenSetsNotOffered,
            dayIndex: slot.dayIndex,
          ),
        );
      }
      if (slot.moves.length > kMaxMovesPerDay) {
        found.add(
          SplitInvalid(SplitProblem.tooManyMoves, dayIndex: slot.dayIndex),
        );
      }
      if (slot.approvedAlternatives.length > kMaxApprovedAlternatives) {
        found.add(
          SplitInvalid(SplitProblem.tooManyAlternatives, dayIndex: slot.dayIndex),
        );
      }
      // D7: "approved" means approved *by a coach*. A woman choosing her own
      // easier move is editing her own split, not approving a substitution.
      if (split.ownerKind == SplitOwnerKind.self &&
          slot.approvedAlternatives.isNotEmpty) {
        found.add(
          SplitInvalid(
            SplitProblem.clientSplitCarriesCoachOnlyField,
            dayIndex: slot.dayIndex,
          ),
        );
      }
    }

    // The client copy counts nothing, because there is nothing to count.
    if (split.ownerKind == SplitOwnerKind.self && split.appliedCount != 0) {
      found.add(
        const SplitInvalid(SplitProblem.clientSplitCarriesCoachOnlyField),
      );
    }

    return found;
  }

  bool isValid(Split split) => problems(split).isEmpty;

  /// Throws the first problem. Called by every repository before a write.
  void assertValid(Split split) {
    final found = problems(split);
    if (found.isNotEmpty) throw found.first;
  }
}
