/// `users/{uid}.rewards` — her currency.
///
/// Every field here is written by a Cloud Function and by nothing else. G6's
/// §2.3 argument is worth keeping next to the type: *"If the client writes
/// `rewards.points`, no rule can validate the amount — a rooted device writes
/// `increment(1000000)` and the rule sees a well-formed increment. Rules cannot
/// express 'this increment is justified by a session that really happened'."*
/// `firestore.rules` denies the whole map to clients for that reason, and
/// `rewards_untouched` is AND-ed outside every per-group slice so no future
/// block can OR the hole back open.
///
/// This type lives in `domain/rewards/` rather than in the Progress feature
/// because Today reads it too: T05 states her level and what her tier kept, and
/// a feature importing another feature's domain is how two screens end up with
/// two ideas of what a point is.
library;

import 'package:meta/meta.dart';

@immutable
class Rewards {
  const Rewards({
    this.points = 0,
    this.level = 1,
    this.pointsToNextLevel = 0,
    this.sessionsLogged = 0,
    this.bestsCount = 0,
    this.milestones = const <String, DateTime>{},
  });

  /// Increment-only, so it cannot fall — and since the level is a function of
  /// it, the level cannot fall either.
  final int points;

  /// Derived from [points] by `LevelCurve`. Stored so R10 and R12 render
  /// without arithmetic (G4's request), and computed by the same function the
  /// client uses, so the two cannot disagree.
  final int level;

  final int pointsToNextLevel;

  /// Lifetime sessions. P02's "23 of 50", R10's "Session 20".
  final int sessionsLogged;

  /// Lifetime personal bests. P01's "8 so far", and an input to the tier.
  final int bestsCount;

  /// Milestone id to the moment it was earned. At most twelve keys, so P02
  /// costs no extra reads.
  ///
  /// A milestone is earned because this map says so, never because a counter
  /// happens to be high enough right now, which is what stops one un-earning
  /// itself if a count is ever corrected downward. The one exception is
  /// removal: when she removes the session or the meal that earned it and her
  /// count no longer reaches it, it was never hers (`RewardsState`).
  final Map<String, DateTime> milestones;

  Rewards copyWith({
    int? points,
    int? level,
    int? pointsToNextLevel,
    int? sessionsLogged,
    int? bestsCount,
    Map<String, DateTime>? milestones,
  }) {
    return Rewards(
      points: points ?? this.points,
      level: level ?? this.level,
      pointsToNextLevel: pointsToNextLevel ?? this.pointsToNextLevel,
      sessionsLogged: sessionsLogged ?? this.sessionsLogged,
      bestsCount: bestsCount ?? this.bestsCount,
      milestones: milestones ?? this.milestones,
    );
  }

  @override
  String toString() => 'Rewards($points pts, level $level, $bestsCount bests)';
}
