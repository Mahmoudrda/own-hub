/// The daily ceiling on points.
///
/// Sixty points a day, on the repeatable kinds only. The cap exists to stop
/// grinding — logging nine short sessions in an evening should not out-earn
/// training properly twice — and it applies to exactly the awards that *can* be
/// repeated. A counted week and a milestone sit outside it because their award
/// ids can only be created once, so there is nothing to grind.
///
/// Personal bests carry a second, tighter limit: at most three a day. A single
/// session can touch six exercises, and six simultaneous bests on the day she
/// first uses heavier dumbbells is a windfall rather than a signal.
///
/// ## The one deliberate read-then-write in the product
///
/// G8's K5 lint forbids read-modify-write counters, because they lose data on an
/// offline reconnect race. A cap has to **compare** against a ceiling, so it
/// cannot be expressed as a bare increment. G6 §4.2 scopes that lint to `lib/`
/// and exempts the Functions, on the grounds that the race K5 protects against
/// does not exist inside a single-document server transaction.
///
/// This class is the pure decision half of that transaction: it takes the state
/// it is given and returns the state that should be written. It holds no mutable
/// state of its own, so it cannot itself lose a write.
library;

import 'package:meta/meta.dart';

import 'award_table.dart';

/// Points a day, across the repeatable kinds.
const int kDailyPointsCap = 60;

/// Personal bests a day.
const int kBestAwardsPerDay = 3;

/// Why an award was reduced or refused.
enum CapReason {
  /// Nothing was withheld.
  none,

  /// The 60-point daily ceiling.
  dailyPoints,

  /// The three-bests-a-day ceiling.
  bestsPerDay,
}

/// What has been awarded today.
///
/// Note the day key: the cap is per calendar day in her timezone, and rolling
/// over is a **comparison of two `yyyy-MM-dd` strings**, never a duration or a
/// count of days elapsed. Rule 3 is not at risk here because nothing accumulates
/// across days — the counters reset rather than building a run.
@immutable
class DailyCapState {
  const DailyCapState({
    required this.dayKey,
    this.pointsToday = 0,
    this.bestsToday = 0,
  });

  /// A day with nothing awarded yet.
  const DailyCapState.fresh(String dayKey) : this(dayKey: dayKey);

  /// `yyyy-MM-dd`, in her timezone.
  final String dayKey;

  final int pointsToday;
  final int bestsToday;

  @override
  bool operator ==(Object other) =>
      other is DailyCapState &&
      other.dayKey == dayKey &&
      other.pointsToday == pointsToday &&
      other.bestsToday == bestsToday;

  @override
  int get hashCode => Object.hash(dayKey, pointsToday, bestsToday);

  @override
  String toString() =>
      'DailyCapState($dayKey, $pointsToday pts, $bestsToday bests)';
}

/// What the cap decided.
@immutable
class CapDecision {
  const CapDecision({
    required this.granted,
    required this.state,
    required this.reason,
  });

  /// Points actually awarded — never more than the award asked for, and never
  /// less than zero.
  final int granted;

  /// The state to store afterwards.
  final DailyCapState state;

  final CapReason reason;

  /// True when the full amount went through.
  bool get inFull => reason == CapReason.none;
}

/// Applies the ceiling.
class DailyCap {
  const DailyCap({
    this.dailyPoints = kDailyPointsCap,
    this.bestsPerDay = kBestAwardsPerDay,
  });

  final int dailyPoints;
  final int bestsPerDay;

  /// Decides what [award] is worth today.
  ///
  /// A partial grant is deliberate: with 50 points used and a 30-point session
  /// arriving, she receives the remaining 10 rather than nothing. `P0-RWD-02`
  /// asks that "points stop at the daily cap", and stopping at it is exactly
  /// what reaching it and no further means. Refusing the whole award would also
  /// make the total depend on the order things synced in, which is precisely the
  /// non-determinism the ledger exists to remove.
  CapDecision apply({
    required DailyCapState state,
    required String dayKey,
    required Award award,
  }) {
    // A new day starts clean. String equality, not elapsed time.
    final today = state.dayKey == dayKey ? state : DailyCapState.fresh(dayKey);

    if (!award.underDailyCap) {
      return CapDecision(
        granted: award.points,
        // An uncapped award neither consumes the budget nor is limited by it.
        state: today,
        reason: CapReason.none,
      );
    }

    if (award.kind == AwardKind.personalBest &&
        today.bestsToday >= bestsPerDay) {
      return CapDecision(
        granted: 0,
        state: today,
        reason: CapReason.bestsPerDay,
      );
    }

    final headroom = dailyPoints - today.pointsToday;
    if (headroom <= 0) {
      return CapDecision(
        granted: 0,
        state: today,
        reason: CapReason.dailyPoints,
      );
    }

    final granted = award.points <= headroom ? award.points : headroom;
    return CapDecision(
      granted: granted,
      state: DailyCapState(
        dayKey: dayKey,
        pointsToday: today.pointsToday + granted,
        bestsToday: award.kind == AwardKind.personalBest
            ? today.bestsToday + 1
            : today.bestsToday,
      ),
      reason: granted == award.points ? CapReason.none : CapReason.dailyPoints,
    );
  }
}
