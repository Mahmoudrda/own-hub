/// What a tier's session is made of, in numbers she can compare: moves, sets
/// and reps, rest, and about how long it takes.
///
/// Home and the Train tabs show these for the tier she is looking at, and what
/// changes against the level she set, so switching Beginner, Intermediate and
/// Advanced is something she can see instead of only a different title.
///
/// Everything here is read from the session already cut to her minutes
/// ([scaleSession]); nothing is invented, so the line can never promise more
/// than the session holds. The closing stretch is not counted.
library;

import 'package:meta/meta.dart';

import '../../onboarding/domain/intake.dart' show LifeStage;
import 'programme_week.dart' as week;
import 'workout_library.dart';

/// What differs between two sessions' facts. Positive means the viewed tier has
/// more. A part that did not change is zero.
@immutable
class TierDelta {
  const TierDelta({
    this.moves = 0,
    this.sets = 0,
    this.restSeconds = 0,
    this.minutes = 0,
  });

  final int moves;
  final int sets;
  final int restSeconds;
  final int minutes;

  bool get isEmpty =>
      moves == 0 && sets == 0 && restSeconds == 0 && minutes == 0;

  @override
  bool operator ==(Object other) =>
      other is TierDelta &&
      other.moves == moves &&
      other.sets == sets &&
      other.restSeconds == restSeconds &&
      other.minutes == minutes;

  @override
  int get hashCode => Object.hash(moves, sets, restSeconds, minutes);

  @override
  String toString() =>
      'TierDelta(moves $moves, sets $sets, rest $restSeconds s, $minutes min)';
}

@immutable
class TierFacts {
  const TierFacts({
    required this.moves,
    required this.setsPerMove,
    required this.repsLabel,
    required this.restSeconds,
    required this.estimatedMinutes,
    this.versusOwn,
    this.isOwnLevel = false,
  });

  /// Strength moves, not counting the closing stretch.
  final int moves;

  /// The sets most moves have. An Advanced session can mix 5 and 4.
  final int setsPerMove;

  /// The reps most moves have, as digits ("10"). Empty when no move counts
  /// reps (every move is a hold).
  final String repsLabel;

  /// The longest rest between sets: the rest after a superset pair, which is
  /// the rest she feels.
  final int restSeconds;

  /// About how long it takes, rounded to 5 minutes.
  final int estimatedMinutes;

  /// What is different from the level she set. Null when she is looking at her
  /// own level, or when no comparison was asked for.
  final TierDelta? versusOwn;

  /// Whether she is looking at the level she set, so there is nothing to
  /// compare.
  final bool isOwnLevel;

  /// The facts of [viewed], the session of the tier she is looking at, and
  /// against [own], the same slot of the level she set. [isOwnLevel] says the
  /// tier shown is the one she set, which has no comparison. Null when [viewed]
  /// has no strength moves.
  static TierFacts? of(
    AuthoredSession? viewed, {
    AuthoredSession? own,
    bool isOwnLevel = false,
  }) {
    final facts = _read(viewed);
    if (facts == null) return null;
    if (isOwnLevel) return facts._with(isOwnLevel: true);
    final base = _read(own);
    if (base == null) return facts;
    return facts._with(versusOwn: facts.deltaFrom(base));
  }

  /// The facts of the session in slot [slot] of [viewed], cut to [minutes],
  /// against the same slot of [own], the programme of the level she set. Both
  /// are the programmes the router resolved for her answers; [stage] filters
  /// the sessions as Train does. Null when [viewed] is null or has no session
  /// for her.
  static TierFacts? ofProgrammes({
    required AuthoredProgramme? viewed,
    required AuthoredProgramme? own,
    required LifeStage? stage,
    required int slot,
    required int minutes,
    required bool isOwnLevel,
  }) {
    AuthoredSession? cut(AuthoredProgramme? programme) {
      if (programme == null) return null;
      final sessions = week.programmeSessionsFor(programme, stage);
      if (sessions.isEmpty) return null;
      return week.scaleSession(sessions[slot % sessions.length], minutes);
    }

    return of(cut(viewed), own: cut(own), isOwnLevel: isOwnLevel);
  }

  /// This tier's facts less [base]'s.
  TierDelta deltaFrom(TierFacts base) => TierDelta(
    moves: moves - base.moves,
    sets: setsPerMove - base.setsPerMove,
    restSeconds: restSeconds - base.restSeconds,
    minutes: estimatedMinutes - base.estimatedMinutes,
  );

  TierFacts _with({TierDelta? versusOwn, bool isOwnLevel = false}) => TierFacts(
    moves: moves,
    setsPerMove: setsPerMove,
    repsLabel: repsLabel,
    restSeconds: restSeconds,
    estimatedMinutes: estimatedMinutes,
    versusOwn: versusOwn,
    isOwnLevel: isOwnLevel,
  );

  static TierFacts? _read(AuthoredSession? session) {
    if (session == null) return null;
    final work = week.workMoves(session);
    if (work.isEmpty) return null;
    final reps = _mode([
      for (final m in work)
        if (m.reps != null) m.reps!,
    ]);
    final minutes = (week.estimatedMinutes(session) / 5).round() * 5;
    return TierFacts(
      moves: work.length,
      setsPerMove: _mode([for (final m in work) m.sets])!,
      repsLabel: reps == null ? '' : '$reps',
      restSeconds: work.fold<int>(
        0,
        (r, m) => m.restSeconds > r ? m.restSeconds : r,
      ),
      estimatedMinutes: minutes < 5 ? 5 : minutes,
    );
  }

  /// The most common value; the larger one on a tie.
  static int? _mode(List<int> values) {
    if (values.isEmpty) return null;
    final counts = <int, int>{};
    for (final v in values) {
      counts[v] = (counts[v] ?? 0) + 1;
    }
    int? best;
    for (final e in counts.entries) {
      if (best == null ||
          e.value > counts[best]! ||
          (e.value == counts[best] && e.key > best)) {
        best = e.key;
      }
    }
    return best;
  }

  @override
  bool operator ==(Object other) =>
      other is TierFacts &&
      other.moves == moves &&
      other.setsPerMove == setsPerMove &&
      other.repsLabel == repsLabel &&
      other.restSeconds == restSeconds &&
      other.estimatedMinutes == estimatedMinutes &&
      other.versusOwn == versusOwn &&
      other.isOwnLevel == isOwnLevel;

  @override
  int get hashCode => Object.hash(
    moves,
    setsPerMove,
    repsLabel,
    restSeconds,
    estimatedMinutes,
    versusOwn,
    isOwnLevel,
  );

  @override
  String toString() =>
      'TierFacts($moves moves, $setsPerMove x $repsLabel, $restSeconds s, '
      '~$estimatedMinutes min, $versusOwn, own: $isOwnLevel)';
}
