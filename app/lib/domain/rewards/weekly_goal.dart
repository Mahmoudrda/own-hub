/// `users/{uid}.weeklyGoal` — her goal, and everything counted in weeks.
///
/// Every counter here is monotonic or bounded, and not one of them can express a
/// day. [countedWeeks] only rises, [bestRun] only rises, [restWeeksBanked] is
/// capped at two, [recent8] is capped at eight. There is no `missedDays`, no
/// `dailyStreak` and no field a count of consecutive anything could live in —
/// spine C6 enforced by the shape of the type rather than by review.
///
/// ## Which fields are hers and which are the server's
///
/// Exactly three are client-writable — `sessionsTarget`, `tz` and `goalKind`
/// (G6 §6 item 3). Every other field on this object is written by a Cloud
/// Function, because a client that can write its own counters can mint any tier.
/// The rules enforce that; this type documents it so the split is visible where
/// the fields are declared.
library;

import 'package:meta/meta.dart';

import '../week/week_key.dart';
import 'week_rollup.dart';

/// How many earned counted weeks buy a rest week (G6 §3.1).
const int kCountedWeeksPerRestWeek = 4;

/// The most rest weeks she can hold at once.
const int kRestWeekBankCap = 2;

/// How many closed weeks P01's chart and the tier's recency floor look back over.
const int kRecentWeekWindow = 8;

/// Her weekly goal and the counters kept against it.
@immutable
class WeeklyGoal {
  const WeeklyGoal({
    this.sessionsTarget = 3,
    this.countedWeeks = 0,
    this.restWeeksBanked = 0,
    this.restWeekProgress = 0,
    this.currentRun = 0,
    this.bestRun = 0,
    this.recent8 = const <WeekBar>[],
    this.lastClosedWeek,
    this.lastRepairedWeek,
    this.tierSlippedWeek,
    this.goalKind = WeekGoalKind.sessions,
    this.tz = kDefaultTimezone,
  });

  /// 2–4. **Hers**, and the only counter on this object she may write.
  final int sessionsTarget;

  /// Cumulative and monotonic. A repaired week increments this exactly as an
  /// earned one does — D5: "a banked rest week protects her completely and must
  /// never reduce a reward."
  final int countedWeeks;

  /// 0–[kRestWeekBankCap].
  final int restWeeksBanked;

  /// Earned counted weeks since the last rest week was banked, 0–3.
  ///
  /// Advanced **only** by a week that was `counted && !repairedByRestWeek`
  /// (G6 §3.1), so repair cannot fund itself. Kept as its own counter rather
  /// than derived from [countedWeeks], because [countedWeeks] includes repaired
  /// weeks and deriving from it would let a repaired week buy the next one.
  final int restWeekProgress;

  /// Weeks in the current run. Resettable — this is the one counter that falls,
  /// and it falls to zero rather than going negative or being displayed in red.
  final int currentRun;

  /// Monotonic. P01's "best run 9".
  final int bestRun;

  /// The last [kRecentWeekWindow] **closed** weeks, oldest first.
  ///
  /// A fixed-size cache on a document P01 already loads. The `weeks` collection
  /// stays the source of truth; this is what keeps P01 at two reads rather than
  /// nine (G6 §2.1 — Firestore bills per document returned, so "last 8 weeks"
  /// is eight reads, not one).
  final List<WeekBar> recent8;

  /// The lazy close's watermark.
  final WeekKey? lastClosedWeek;

  /// Published for G3, so T04 can report a repair from the user document it
  /// already read instead of paying a fifth Monday read.
  final WeekKey? lastRepairedWeek;

  /// Published for G3, so T05 knows there is a slip to report. Whether it was
  /// *shown* is G3's `notices/` ledger, not this field.
  final WeekKey? tierSlippedWeek;

  final WeekGoalKind goalKind;

  /// IANA zone. **Hers, never the handset's** (G6 §3.1): a Cairo→Gulf move must
  /// not recompute a boundary that has already passed.
  final String tz;

  /// Closed weeks in [recent8] that counted — the input to the tier's recency
  /// floor, and never a count of days.
  int get countedInRecentWindow => recent8.where((b) => b.counted).length;

  /// True when a rest week is one earned counted week away.
  bool get restWeekAlmostBanked =>
      restWeeksBanked < kRestWeekBankCap &&
      restWeekProgress == kCountedWeeksPerRestWeek - 1;

  WeeklyGoal copyWith({
    int? sessionsTarget,
    int? countedWeeks,
    int? restWeeksBanked,
    int? restWeekProgress,
    int? currentRun,
    int? bestRun,
    List<WeekBar>? recent8,
    WeekKey? lastClosedWeek,
    WeekKey? lastRepairedWeek,
    WeekKey? tierSlippedWeek,
    WeekGoalKind? goalKind,
    String? tz,
  }) {
    final nextCounted = countedWeeks ?? this.countedWeeks;
    final nextBestRun = bestRun ?? this.bestRun;
    return WeeklyGoal(
      sessionsTarget: sessionsTarget ?? this.sessionsTarget,
      // Monotonic by construction. Nothing earned is taken away, and a caller
      // that passes a smaller number gets the larger one rather than silently
      // rewriting her history downward.
      countedWeeks: nextCounted > this.countedWeeks
          ? nextCounted
          : this.countedWeeks,
      restWeeksBanked: (restWeeksBanked ?? this.restWeeksBanked).clamp(
        0,
        kRestWeekBankCap,
      ),
      restWeekProgress: restWeekProgress ?? this.restWeekProgress,
      currentRun: currentRun ?? this.currentRun,
      bestRun: nextBestRun > this.bestRun ? nextBestRun : this.bestRun,
      recent8: recent8 ?? this.recent8,
      lastClosedWeek: lastClosedWeek ?? this.lastClosedWeek,
      lastRepairedWeek: lastRepairedWeek ?? this.lastRepairedWeek,
      tierSlippedWeek: tierSlippedWeek ?? this.tierSlippedWeek,
      goalKind: goalKind ?? this.goalKind,
      tz: tz ?? this.tz,
    );
  }

  /// Appends a closed week to [recent8], keeping the newest eight.
  WeeklyGoal withClosedBar(WeekBar bar) {
    final next = [...recent8, bar];
    return copyWith(
      recent8: next.length <= kRecentWeekWindow
          ? next
          : next.sublist(next.length - kRecentWeekWindow),
      lastClosedWeek: bar.week,
    );
  }

  @override
  String toString() =>
      'WeeklyGoal(target:$sessionsTarget counted:$countedWeeks '
      'banked:$restWeeksBanked run:$currentRun/$bestRun)';
}

/// The week boundary used when hers has never been recorded.
///
/// `DECISIONS.md` D17: the app is international, and the week follows the phone
/// she is holding. **That is already true of the boundary itself** — every
/// caller hands `WeekKey.of` a device-local `DateTime`, and nothing in this app
/// calls `toUtc()` — so a session logged at 23:00 in Dubai lands in the week it
/// was Sunday in for her, not in Cairo. [WeekKey.current] says so explicitly.
///
/// What was wrong was this constant's name and its claim. It read as *her*
/// zone, so every goal asserted `Africa/Cairo` whether or not she had ever been
/// there — and G6 §3.1 is specifically about the very large Egyptian population
/// in the Gulf at UTC+3/+4.
///
/// [WeeklyGoal.tz] stays **stored rather than re-read**, which is the other half
/// of §3.1 and the reason this is a fallback and not a lookup: a Cairo→Gulf
/// move must not recompute a boundary that has already passed, or last month's
/// sessions would quietly change which week they belong to. New weeks follow
/// her phone; closed weeks keep the boundary they were closed under.
/// Moved to [WeekKey.fallbackTimezone], which is where a week-boundary concern
/// belongs: Eat needs the same fallback for a meal's day key and should not
/// import the rewards domain to get it.
const String kDefaultTimezone = WeekKey.fallbackTimezone;
