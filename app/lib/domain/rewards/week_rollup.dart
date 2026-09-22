/// A week, and the only arithmetic this product does on time.
///
/// §2 rule 3 is *weeks, not days*, and this file is where that stops being a
/// slogan. [WeekKey] already guarantees that a moment can only be bucketed into
/// `yyyy-Www`; what is added here is the guarantee that **a week's state is
/// decided in exactly one place, from exactly five inputs, none of which is a
/// day**. [WeekRollup.evaluate] takes a [WeekDoc] and returns one of five
/// states. There is no parameter carrying a list of dates, no run length, and no
/// type anywhere in this library capable of holding "how many days in a row".
///
/// ## `sessionsLogged` is derived, not stored
///
/// The spine lists `sessionsLogged` as a field on `users/{uid}/weeks/{id}`, and
/// G6 §4.2 says it is "reconciled to `creditedSessionIds.length` on every run".
/// Two places holding the same count is the shape of `PHASE1-FIXES.md` §8 —
/// "two sources, one of them constant" — so here the count is a **getter over
/// the id set** and cannot drift from it. The stored field remains the Cloud
/// Function's mirror of this number; nothing in the client computes it twice.
///
/// That is also what makes an offline replay free: crediting a session id that
/// is already in the set changes nothing, because the count is the set's size
/// rather than an increment applied beside it (spine C4, as corrected —
/// "commutative is not idempotent").
library;

import 'package:meta/meta.dart';

import '../week/week_key.dart';

/// The cap on credited session ids in one week document (G6 §1.2).
///
/// Bounded on purpose: the array is the idempotency key set, and an unbounded
/// key set is an unbounded document.
const int kCreditedSessionCap = 20;

/// What a week's goal is counted in.
///
/// Two units, both weekly. F38 offers "food logged on four days" as an
/// alternative goal, so the unit is a property of the week rather than an
/// assumption baked into the rollup.
enum WeekGoalKind { sessions, foodDays }

/// The five states a week can be in.
///
/// Note what is absent: there is no `failing`, no `atRisk` and no `behind`. A
/// week that has not met its goal yet is simply [open] — D5 puts the consequence
/// of skipping at the week level and never as a running failure.
enum WeekState {
  /// Not closed, goal not yet met.
  open,

  /// Not closed, goal met. `counted` is already true and the week award has
  /// already fired — see [WeekCredit.countedNow].
  met,

  /// Closed having met the goal.
  closedCounted,

  /// Closed unmet, and a banked rest week covered it. Counted all the same.
  closedRepaired,

  /// Closed unmet with an empty bank. Nothing is taken away; the run resets.
  closedMissed,
}

/// One closed week, as P01's eight-bar chart reads it.
///
/// This is the `{w,s,t,c,r}` element of `weeklyGoal.recent8` (G6 §1.2) — a fixed
/// eight-element cache on a document P01 must load anyway, which is what keeps
/// P01 at two reads instead of nine.
@immutable
class WeekBar {
  const WeekBar({
    required this.week,
    required this.sessionsLogged,
    required this.sessionsTarget,
    required this.counted,
    this.repairedByRestWeek = false,
  });

  final WeekKey week;
  final int sessionsLogged;
  final int sessionsTarget;
  final bool counted;
  final bool repairedByRestWeek;

  /// How the bar draws. Three kinds, matching `weekBars()` in
  /// `6-v2/src/kit.mjs`: a full bar for a week she earned, a pale one for a week
  /// a rest week covered ("the pale one was a rest week"), and a low neutral one
  /// for a week that did not count.
  ///
  /// The low bar is [AppColors.outlineVariant] at the call site and never red.
  /// There is no fourth kind, so there is nothing for a "missed" styling to be.
  WeekBarKind get kind {
    if (!counted) return WeekBarKind.missed;
    return repairedByRestWeek ? WeekBarKind.repaired : WeekBarKind.counted;
  }

  @override
  bool operator ==(Object other) =>
      other is WeekBar &&
      other.week == week &&
      other.sessionsLogged == sessionsLogged &&
      other.sessionsTarget == sessionsTarget &&
      other.counted == counted &&
      other.repairedByRestWeek == repairedByRestWeek;

  @override
  int get hashCode => Object.hash(
    week,
    sessionsLogged,
    sessionsTarget,
    counted,
    repairedByRestWeek,
  );

  @override
  String toString() =>
      'WeekBar(${week.id} $sessionsLogged/$sessionsTarget ${kind.name})';
}

/// The three ways a closed week draws. Never four, and none of them is a failure.
enum WeekBarKind { counted, repaired, missed }

/// `users/{uid}/weeks/{yyyy-Www}` — one week, as the client reads it.
///
/// Client-read-only in production: every field here is written by a Cloud
/// Function (G6 §1.1), and `firestore.rules` publishes `allow write: if false`
/// on the path. What a woman writes is evidence; what the server writes is the
/// score.
@immutable
class WeekDoc {
  const WeekDoc({
    required this.week,
    required this.sessionsTarget,
    this.counted = false,
    this.repairedByRestWeek = false,
    this.closedAt,
    this.creditedSessionIds = const <String>[],
    this.foodDaysLogged = 0,
    this.goalKind = WeekGoalKind.sessions,
  });

  final WeekKey week;

  /// Copied in at creation, then lowered only while the week is open and never
  /// once it counts — see [WeekRollup.retarget].
  final int sessionsTarget;

  /// Irreversible. Once a week counts it counts forever, so a late-syncing
  /// session can never un-count it.
  final bool counted;

  /// True when a banked rest week closed this one. Such a week counts, awards
  /// nothing, and earns no progress toward the next rest week.
  final bool repairedByRestWeek;

  /// Write-once. Non-null means the week is closed and settled.
  final DateTime? closedAt;

  /// The idempotency key set (G6 §4.2), applied with `arrayUnion`. Bounded at
  /// [kCreditedSessionCap].
  final List<String> creditedSessionIds;

  final int foodDaysLogged;
  final WeekGoalKind goalKind;

  /// Sessions credited to this week. **Derived from the id set**, so the count
  /// and the set cannot disagree — see the library comment.
  int get sessionsLogged => creditedSessionIds.length;

  /// Progress toward this week's goal, in whichever unit the goal is set in.
  int get progress =>
      goalKind == WeekGoalKind.sessions ? sessionsLogged : foodDaysLogged;

  bool get isClosed => closedAt != null;

  /// True once the goal is met. Deliberately `>=`: logging a fourth session
  /// against a goal of three is not an error and does not un-meet the week.
  bool get goalMet => progress >= sessionsTarget;

  WeekDoc copyWith({
    int? sessionsTarget,
    bool? counted,
    bool? repairedByRestWeek,
    DateTime? closedAt,
    List<String>? creditedSessionIds,
    int? foodDaysLogged,
  }) {
    return WeekDoc(
      week: week,
      sessionsTarget: sessionsTarget ?? this.sessionsTarget,
      // `counted` is irreversible: a copyWith cannot walk it back to false.
      counted: (counted ?? false) || this.counted,
      repairedByRestWeek:
          (repairedByRestWeek ?? false) || this.repairedByRestWeek,
      // Write-once, enforced here rather than remembered at four call sites.
      closedAt: this.closedAt ?? closedAt,
      creditedSessionIds: creditedSessionIds ?? this.creditedSessionIds,
      foodDaysLogged: foodDaysLogged ?? this.foodDaysLogged,
      goalKind: goalKind,
    );
  }

  /// The bar P01 draws for this week once it is closed.
  WeekBar toBar() => WeekBar(
    week: week,
    sessionsLogged: sessionsLogged,
    sessionsTarget: sessionsTarget,
    counted: counted,
    repairedByRestWeek: repairedByRestWeek,
  );

  @override
  String toString() =>
      'WeekDoc(${week.id} $sessionsLogged/$sessionsTarget '
      'counted:$counted repaired:$repairedByRestWeek closed:${closedAt != null})';
}

/// The result of crediting one session to a week.
@immutable
class WeekCredit {
  const WeekCredit({
    required this.week,
    required this.countedNow,
    required this.alreadyCredited,
  });

  final WeekDoc week;

  /// True **only** on the credit that crossed the target — the one moment the
  /// 40-point week award may fire. `P0-WEEK-01`: "Points award once."
  ///
  /// A fourth session in a three-session week returns false here, and so does a
  /// replay of the third.
  final bool countedNow;

  /// True when this session id was already in the set, so nothing changed.
  /// The offline-replay case (`P0-RWD-01`, `P0-LOG-09`).
  final bool alreadyCredited;
}

/// Decides a week's state, and is incapable of deciding anything else.
///
/// Every method is pure and takes a [WeekDoc]. None takes a clock, a date range
/// or a list of days, so there is no signature here through which a
/// consecutive-day count could be computed even by a caller who wanted one.
class WeekRollup {
  const WeekRollup();

  /// The week's state — one of five, none of which counts days.
  WeekState evaluate(WeekDoc week) {
    if (!week.isClosed) return week.goalMet ? WeekState.met : WeekState.open;
    if (!week.counted) return WeekState.closedMissed;
    return week.repairedByRestWeek
        ? WeekState.closedRepaired
        : WeekState.closedCounted;
  }

  /// Credits one session to the week, idempotently.
  ///
  /// The session id is the idempotency key (spine C1): deterministic for a
  /// recalled or unplanned session and a once-minted UUID for a live one. A
  /// replayed credit re-unions the same element and changes nothing, which is
  /// why the award bound to [WeekCredit.countedNow] cannot fire twice.
  ///
  /// A closed week refuses credit outright — `closedAt` is write-once and
  /// `counted` irreversible, "so a late-syncing session can never un-count or
  /// reopen a week" (G6 §3.1).
  WeekCredit creditSession({required WeekDoc week, required String sessionId}) {
    if (week.isClosed || week.creditedSessionIds.contains(sessionId)) {
      return WeekCredit(
        week: week,
        countedNow: false,
        alreadyCredited: week.creditedSessionIds.contains(sessionId),
      );
    }

    if (week.creditedSessionIds.length >= kCreditedSessionCap) {
      // The week is already credited far past any goal; dropping the overflow
      // is correct and silent. Refusing the write would be worse: it would fail
      // a log she made for a week that has long since counted.
      return WeekCredit(week: week, countedNow: false, alreadyCredited: false);
    }

    final next = week.copyWith(
      creditedSessionIds: [...week.creditedSessionIds, sessionId],
    );

    final crossed = !week.counted && next.goalMet;
    return WeekCredit(
      week: crossed ? next.copyWith(counted: true) : next,
      countedNow: crossed,
      alreadyCredited: false,
    );
  }

  /// Records a food day. Same idempotency story, keyed by the date instead.
  WeekDoc creditFoodDay({required WeekDoc week, required int foodDaysLogged}) {
    if (week.isClosed) return week;
    // Absolute, never an increment: G5 writes the day count it observed, so a
    // replay writes the same number again and changes nothing.
    final next = week.copyWith(foodDaysLogged: foodDaysLogged);
    return next.goalMet ? next.copyWith(counted: true) : next;
  }

  /// Changes the week's goal.
  ///
  /// **Lowering only, and only while open.** T05 offers "Make this week 2
  /// sessions" because a goal she can meet beats a goal she abandons; raising a
  /// target mid-week could un-count a week that already counted, which is the
  /// one thing this group must never permit (G6 §4.3).
  WeekDoc retarget(WeekDoc week, int target) {
    if (week.isClosed || week.counted) return week;
    if (target >= week.sessionsTarget) return week;
    final next = week.copyWith(sessionsTarget: target);
    // Lowering the bar can itself meet the goal, and that counts — she is being
    // measured against the goal she holds now.
    return next.goalMet ? next.copyWith(counted: true) : next;
  }
}
