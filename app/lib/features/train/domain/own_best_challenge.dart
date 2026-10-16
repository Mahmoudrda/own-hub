/// D38 — one weekly challenge, against her own last week.
///
/// Video 1's strongest competition was the small one people can win: not a
/// global board but the hill on the morning route. Own Hub ranks nobody, so
/// the only other competitor is her, last week. One move, one number, chosen
/// the same way every time from what she actually logged, and always beatable
/// by finishing the plan she already has:
///
/// - **Beat** — where last week fell short of this week's plan, the target is
///   one more than last week, which the plan reaches by construction.
/// - **Match** — where last week met the plan exactly, the target is last
///   week's total, which the plan reaches. A tie wins. A week that went past
///   the plan sets nothing on that move: matching it would ask for more than
///   the plan, and the plan is all she was asked for.
/// - **Nothing** — when there is no last week to compare with. A challenge
///   against an empty week would be a number she never set.
///
/// It pays no points (the award table keeps its five kinds) and it is never
/// stored: re-derived from her log each time, so a plan changed mid-week
/// re-derives quietly rather than leaving a stale target behind. Only live
/// sets count, the same eligibility personal bests use: a session recalled
/// from memory has no sets to compare.
library;

import 'package:meta/meta.dart';

import '../../../domain/training/prescribed_set.dart';
import '../../../domain/week/week_key.dart';
import 'train_repository.dart';

enum ChallengeKind { beat, match }

/// Reps for a move the plan counts in reps, seconds for a hold.
enum ChallengeUnit { reps, seconds }

/// One flushed move, as `InMemoryTrainRepository.flushes` keeps them.
typedef FlushRecord = ({
  String sessionId,
  String exerciseId,
  List<LoggedSet> sets,
});

/// Her totals for one move in one week, in both units.
typedef MoveTotal = ({int reps, int seconds, int sets});

@immutable
class WeeklyChallenge {
  const WeeklyChallenge({
    required this.week,
    required this.exerciseId,
    required this.kind,
    required this.unit,
    required this.lastWeek,
    required this.planned,
    required this.target,
  });

  final WeekKey week;
  final String exerciseId;
  final ChallengeKind kind;
  final ChallengeUnit unit;

  /// Her total last week, in [unit].
  final int lastWeek;

  /// What this week's plan adds up to, in [unit]: the move's sets times her
  /// week target.
  final int planned;

  /// Never above [planned].
  final int target;

  bool isMetBy(int total) => total >= target;

  @override
  String toString() =>
      'WeeklyChallenge($exerciseId ${kind.name} $target ${unit.name}, '
      'last $lastWeek, plan $planned)';
}

@immutable
class ChallengeProgress {
  const ChallengeProgress({required this.challenge, required this.thisWeek});

  final WeeklyChallenge challenge;

  /// Her total so far this week, in the challenge's unit.
  final int thisWeek;

  bool get met => challenge.isMetBy(thisWeek);
}

class OwnBestChallenge {
  const OwnBestChallenge();

  /// Her logged totals per move in [week].
  ///
  /// [liveDayOf] answers the `yyyy-MM-dd` day of a live session, or null for
  /// anything else, which is then left out.
  Map<String, MoveTotal> totals(
    WeekKey week,
    Iterable<FlushRecord> flushes, {
    required String? Function(String sessionId) liveDayOf,
  }) {
    final out = <String, MoveTotal>{};
    for (final flush in flushes) {
      final day = liveDayOf(flush.sessionId);
      final date = day == null ? null : DateTime.tryParse(day);
      if (date == null || WeekKey.of(date) != week) continue;
      var (:reps, :seconds, :sets) =
          out[flush.exerciseId] ?? (reps: 0, seconds: 0, sets: 0);
      for (final set in flush.sets) {
        final outcome = set.outcome;
        if (outcome == null || !outcome.isLogged) continue;
        reps += outcome.reps ?? 0;
        seconds += outcome.holdSeconds ?? 0;
        sets += 1;
      }
      out[flush.exerciseId] = (reps: reps, seconds: seconds, sets: sets);
    }
    return out;
  }

  /// This week's challenge, or null when there is nothing honest to set.
  ///
  /// Deterministic: the same plan and the same log choose the same move, the
  /// same kind and the same target, however often it is asked.
  WeeklyChallenge? choose({
    required WeekKey week,
    required List<PlannedMove> plan,
    required int sessionsTarget,
    required Map<String, MoveTotal> lastWeek,
  }) {
    if (sessionsTarget <= 0) return null;

    WeeklyChallenge? beat;
    var widest = 0.0;
    WeeklyChallenge? match;
    var mostSets = 0;

    for (final move in plan) {
      final last = lastWeek[move.exerciseId];
      if (last == null || last.sets == 0) continue;
      final unit = _unitOf(move);
      if (unit == null) continue;
      final perSession = _perSession(move, unit);
      if (perSession <= 0) continue;
      final planned = perSession * sessionsTarget;
      final did = unit == ChallengeUnit.reps ? last.reps : last.seconds;
      if (did <= 0) continue;

      if (did < planned) {
        final gap = (planned - did) / planned;
        // Strictly wider wins, so a tie goes to the earlier move in the plan.
        if (gap > widest) {
          widest = gap;
          beat = WeeklyChallenge(
            week: week,
            exerciseId: move.exerciseId,
            kind: ChallengeKind.beat,
            unit: unit,
            lastWeek: did,
            planned: planned,
            target: did + 1,
          );
        }
      } else if (did == planned && last.sets > mostSets) {
        mostSets = last.sets;
        match = WeeklyChallenge(
          week: week,
          exerciseId: move.exerciseId,
          kind: ChallengeKind.match,
          unit: unit,
          lastWeek: did,
          planned: planned,
          target: did,
        );
      }
    }
    return beat ?? match;
  }

  ChallengeProgress progress(
    WeeklyChallenge challenge,
    Map<String, MoveTotal> thisWeek,
  ) {
    final total = thisWeek[challenge.exerciseId];
    final value = total == null
        ? 0
        : challenge.unit == ChallengeUnit.reps
        ? total.reps
        : total.seconds;
    return ChallengeProgress(challenge: challenge, thisWeek: value);
  }

  /// Reps when the move's sets name reps, seconds when they name a hold, and
  /// null for a move whose sets name neither.
  static ChallengeUnit? _unitOf(PlannedMove move) {
    if (move.sets.isEmpty) return null;
    if (move.sets.every((s) => s.reps != null)) return ChallengeUnit.reps;
    if (move.sets.every((s) => s.holdSeconds != null)) {
      return ChallengeUnit.seconds;
    }
    return null;
  }

  static int _perSession(PlannedMove move, ChallengeUnit unit) {
    var total = 0;
    for (final set in move.sets) {
      total += (unit == ChallengeUnit.reps ? set.reps : set.holdSeconds) ?? 0;
    }
    return total;
  }
}
