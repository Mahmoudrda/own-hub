/// What one finished session really was — the material D40's reveal is made of.
///
/// R10 used to report on a session it was told almost nothing about: it drew a
/// personal-best card for every live session and a fixed "+30 points" under
/// it, and it never said how much she had actually done. Everything R10 now
/// states comes from here, and everything here comes from her own log and the
/// ledger's own answer:
///
/// - the effort — moves and sets she logged, and how long it took;
/// - the credit — the points actually granted, and her week either side;
/// - personal bests that beat one she had, with that previous value, kept
///   apart from first marks on moves she had never logged before;
/// - the weekly challenge, when this session met it;
/// - her training streak, when she has it on.
///
/// Pure. Built once, when the session finishes.
library;

import 'package:meta/meta.dart';

import '../../../domain/rewards/credit_outcome.dart';
import '../../../domain/rewards/personal_best_detector.dart';
import '../../../domain/rewards/training_streak.dart';
import '../../../domain/training/energy_estimate.dart';
import 'exercise_traits.dart';
import 'load_advice.dart';
import 'own_best_challenge.dart';
import 'train_repository.dart';

/// One loaded move R10 looks ahead to: what to put on the bar next time.
///
/// [kg] is a step up when [rises], otherwise the weight she just used. It is
/// never lower than what she lifted: a hard week holds the weight, it does
/// not take it away.
@immutable
class NextTimeMove {
  const NextTimeMove({
    required this.name,
    required this.kg,
    required this.rises,
  });

  final String name;
  final double kg;
  final bool rises;

  @override
  bool operator ==(Object other) =>
      other is NextTimeMove &&
      other.name == name &&
      other.kg == kg &&
      other.rises == rises;

  @override
  int get hashCode => Object.hash(name, kg, rises);
}

/// Up to [limit] of [moves] that she logged with a weight in [sessionId], each
/// with what to lift next time, from [loadAdviceFor] read after the session
/// was put away. Bodyweight moves and moves with no weight logged are left
/// out.
List<NextTimeMove> nextTimeFor({
  required TrainRepository? repository,
  required Iterable<PlannedMove> moves,
  required Iterable<FlushRecord> flushes,
  required String sessionId,
  bool difficult = false,
  int limit = 3,
}) {
  final weighed = <String>{};
  for (final flush in flushes) {
    if (flush.sessionId != sessionId) continue;
    for (final set in flush.sets) {
      final kg = set.outcome?.weightKg;
      if (set.isLogged && kg != null && kg > 0) weighed.add(flush.exerciseId);
    }
  }
  final out = <NextTimeMove>[];
  final seen = <String>{};
  for (final move in moves) {
    if (out.length >= limit) break;
    if (!weighed.contains(move.exerciseId) || !seen.add(move.exerciseId)) {
      continue;
    }
    final traits = ExerciseTraits.of(move.exerciseId);
    final advice = loadAdviceFor(
      repository,
      move,
      difficult: difficult,
      equipment: traits?.equipment,
    );
    if (advice == null) continue;
    final up = advice.decision.suggestedWeightKg;
    final rises =
        advice.decision.action == 'increase' &&
        up != null &&
        up > advice.lastWeightKg;
    out.add(
      NextTimeMove(
        name: traits?.nameEn ?? move.name,
        kg: rises ? up : advice.lastWeightKg,
        rises: rises,
      ),
    );
  }
  return List<NextTimeMove>.unmodifiable(out);
}

@immutable
class SessionSummary {
  const SessionSummary({
    required this.sessionId,
    required this.source,
    this.moves = 0,
    this.sets = 0,
    this.minutes = 0,
    this.credit = const CreditOutcome(),
    this.newBests = const <PersonalBest>[],
    this.firstMarks = 0,
    this.challenge,
    this.challengeMetNow = false,
    this.trainingStreak,
    this.moveNames = const <String, String>{},
    this.bestPoints = 0,
    this.durationSec = 0,
    this.volumeKg = 0,
    this.totalReps = 0,
    this.repSets = 0,
    this.weightedSets = 0,
    this.nextTime = const <NextTimeMove>[],
  });

  /// Up to three loaded moves and what to lift next time. Empty for a session
  /// that was discarded or had no weighed move.
  final List<NextTimeMove> nextTime;

  /// How long the session took, in seconds as measured.
  final int durationSec;

  /// Weight lifted: the sum of kg x reps over the sets she logged with both.
  /// A bodyweight set or a hold adds nothing, so a session of those is 0 and
  /// the share card shows reps instead.
  final double volumeKg;

  /// Reps over the logged sets that had reps.
  final int totalReps;

  /// Logged sets that had reps.
  final int repSets;

  /// Logged sets that counted toward [volumeKg].
  final int weightedSets;

  /// Whole kilograms lifted, for display.
  int get volumeWholeKg => volumeKg.round();

  /// The pattern of the session, from how dense its sets were.
  EffortKind get effort => classifyEffort(
    durationSec: durationSec,
    sets: sets,
    repSets: repSets,
    totalReps: totalReps,
  );

  /// Estimated kilocalories (MET x body weight x hours). Zero with no time or
  /// no logged set. Always shown as an estimate.
  int estimatedKcal({double? bodyWeightKg}) => sets <= 0
      ? 0
      : estimateKcal(
          durationSec: durationSec,
          kind: effort,
          bodyWeightKg: bodyWeightKg,
        );

  /// Points the ledger paid for this session's bests as they were found
  /// mid-session. Part of what R10 says she earned.
  final int bestPoints;

  /// The session's move names by exercise id, swaps included, so a best or a
  /// challenge is named the way she saw the move.
  final Map<String, String> moveNames;

  String nameOf(String exerciseId) => moveNames[exerciseId] ?? exerciseId;

  final String sessionId;
  final SessionSource source;

  /// Moves with at least one set she logged.
  final int moves;

  /// Sets she logged. A skipped set is not one.
  final int sets;

  /// Whole minutes, at least one when the session took any time at all.
  final int minutes;

  final CreditOutcome credit;

  /// Bests that beat one she already had. Each carries `previous`.
  final List<PersonalBest> newBests;

  /// Moves she logged for the very first time. A record, not an improvement.
  final int firstMarks;

  /// The weekly challenge after this session, when there is one.
  final ChallengeProgress? challenge;

  /// This session is the one that met it.
  final bool challengeMetNow;

  /// Null when she has the streak switched off.
  final StreakStatus? trainingStreak;

  bool get isLive => source == SessionSource.live;

  /// The one moment on R10 that is bigger than the rest, when there is one:
  /// the week counting, then a real best, then the challenge.
  bool get hasBigMoment =>
      credit.weekCountedNow || newBests.isNotEmpty || challengeMetNow;
}

/// Builds the summary of [sessionId] from its flushed moves.
///
/// [flushes] may hold every session's moves; only this one's are read.
/// [bests] are the bests the ledger counted for this session, first marks
/// included — they are split here, by whether a previous value existed.
SessionSummary summarise({
  required String sessionId,
  required SessionSource source,
  required Iterable<FlushRecord> flushes,
  required int durationSec,
  required CreditOutcome credit,
  Iterable<PersonalBest> bests = const <PersonalBest>[],
  ChallengeProgress? challengeBefore,
  ChallengeProgress? challengeAfter,
  StreakStatus? trainingStreak,
  Map<String, String> moveNames = const <String, String>{},
  int bestPoints = 0,
  List<NextTimeMove> nextTime = const <NextTimeMove>[],
}) {
  final movesLogged = <String>{};
  var sets = 0;
  var volumeKg = 0.0;
  var totalReps = 0;
  var repSets = 0;
  var weightedSets = 0;
  for (final flush in flushes) {
    if (flush.sessionId != sessionId) continue;
    for (final set in flush.sets) {
      if (!set.isLogged) continue;
      sets += 1;
      movesLogged.add(flush.exerciseId);
      final outcome = set.outcome;
      final reps = outcome?.reps;
      if (reps != null && reps > 0) {
        repSets += 1;
        totalReps += reps;
        final kg = outcome?.weightKg;
        if (kg != null && kg > 0) {
          weightedSets += 1;
          volumeKg += kg * reps;
        }
      }
    }
  }

  // One line per move: the detector can report a load and a reps best on the
  // same move, and R10 states the move once. A real improvement wins over a
  // first mark on the same move, whichever was reported first.
  final byMove = <String, PersonalBest>{};
  for (final best in bests) {
    final kept = byMove[best.exerciseId];
    if (kept == null || (kept.previous == null && best.previous != null)) {
      byMove[best.exerciseId] = best;
    }
  }
  final improved = [
    for (final best in byMove.values)
      if (best.previous != null) best,
  ];
  final firstMarks = byMove.values.where((b) => b.previous == null).length;

  final rounded = (durationSec + 30) ~/ 60;
  final minutes = durationSec <= 0 ? 0 : (rounded < 1 ? 1 : rounded);

  return SessionSummary(
    sessionId: sessionId,
    source: source,
    moves: movesLogged.length,
    sets: sets,
    minutes: minutes,
    credit: credit,
    newBests: List<PersonalBest>.unmodifiable(improved),
    firstMarks: firstMarks,
    challenge: challengeAfter,
    challengeMetNow:
        challengeAfter != null &&
        challengeAfter.met &&
        !(challengeBefore?.met ?? false),
    trainingStreak: trainingStreak,
    moveNames: Map<String, String>.unmodifiable(moveNames),
    bestPoints: bestPoints,
    durationSec: durationSec < 0 ? 0 : durationSec,
    volumeKg: volumeKg,
    totalReps: totalReps,
    repSets: repSets,
    weightedSets: weightedSets,
    nextTime: nextTime,
  );
}
