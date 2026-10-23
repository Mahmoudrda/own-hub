/// D37 — a training streak she controls.
///
/// Video 1 of the two studies behind DECISIONS D37 names the streak as the
/// most dangerous mechanic there is when it cannot be paused, influenced or
/// escaped, and the safe version as one wrapped in her own choices. Every rule
/// below is one of those choices, and every one is a property of this file
/// rather than a promise about how a screen uses it:
///
/// - **Her week decides, not the calendar.** A day she trains keeps it. A day
///   she rests keeps it too, for as long as her own week's target can still be
///   reached — and always, in a week that reached it. Only a day that puts the
///   target out of reach in a week that then falls short ends it.
/// - **A rest week she earned covers a week that slips** (D5), the same test
///   `RestWeekRepair` uses. Nothing is bought.
/// - **She can pause it**, for a week, two weeks or until she comes back, and
///   paused days neither count nor end anything.
/// - **Her best is never taken away.** [StreakSettings.best] only rises.
/// - **Today never ends it.** A day is judged once it is over.
///
/// Nothing here is stored as a running count. The length is derived, every
/// time, from what she logged — the per-day session counts the caller keeps —
/// so there is no counter for a bug, a sync or a clock change to corrupt, and
/// nothing to write to the server (`firestore.rules` `noRunCounter()` refuses
/// it anyway). Pure: no I/O, no clock, no randomness.
library;

import 'package:meta/meta.dart';

import '../format/day_key.dart';
import '../week/week_key.dart';

/// How long she asked to pause for.
enum StreakPauseLength { week, fortnight, untilResumed }

/// One pause, as two day ids. Both ends inclusive; no end means until she
/// resumes.
@immutable
class StreakPause {
  const StreakPause({required this.start, this.end});

  /// `yyyy-MM-dd`.
  final String start;

  /// `yyyy-MM-dd`, or null while it runs until she comes back.
  final String? end;

  /// Whether [day] (`yyyy-MM-dd`) falls inside this pause. Day ids sort, so
  /// this is two string comparisons — see `day_key.dart`.
  bool covers(String day) =>
      day.compareTo(start) >= 0 && (end == null || day.compareTo(end!) <= 0);

  @override
  bool operator ==(Object other) =>
      other is StreakPause && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'StreakPause($start..${end ?? 'open'})';
}

/// What she chose. The only part of D37 that is stored.
@immutable
class StreakSettings {
  const StreakSettings({
    this.enabled = true,
    required this.since,
    this.pauses = const <StreakPause>[],
    this.best = 0,
  });

  /// A fresh start on [today]: on, nothing paused, nothing yet.
  factory StreakSettings.startingOn(DateTime today) =>
      StreakSettings(since: dayKey(today));

  /// Her switch, in Profile and on the sheet. Off means nothing is shown
  /// anywhere and nothing is judged.
  final bool enabled;

  /// `yyyy-MM-dd`. Days before this are never judged, so switching it on, or
  /// updating to the build that has it, starts her fresh rather than judging a
  /// past she was never told about.
  final String since;

  final List<StreakPause> pauses;

  /// Her longest, in days. Rises or stays.
  final int best;

  /// The pause covering [day], if one does.
  StreakPause? activeOn(DateTime day) {
    final key = dayKey(day);
    for (final pause in pauses) {
      if (pause.covers(key)) return pause;
    }
    return null;
  }

  /// Pauses from [today] for [length]. A pause already running is replaced, so
  /// choosing again changes the end rather than stacking two.
  StreakSettings pausedFrom(DateTime today, StreakPauseLength length) {
    final start = dayKey(today);
    final end = switch (length) {
      StreakPauseLength.week => dayKey(_addDays(today, 6)),
      StreakPauseLength.fortnight => dayKey(_addDays(today, 13)),
      StreakPauseLength.untilResumed => null,
    };
    final kept = _closedBefore(today);
    return _copy(
      pauses: [
        ...kept,
        StreakPause(start: start, end: end),
      ],
    );
  }

  /// Ends any pause covering [today]. Today itself is no longer paused, so a
  /// session today counts the moment she resumes.
  StreakSettings resumedOn(DateTime today) =>
      _copy(pauses: _closedBefore(today));

  /// On again, from [today]. A fresh start: the days she had it off are not
  /// judged after the fact. Her best is kept.
  StreakSettings switchedOn(DateTime today) =>
      _copy(enabled: true, since: dayKey(today), pauses: const <StreakPause>[]);

  /// Off. Nothing is shown and nothing is judged. Her best is kept.
  StreakSettings switchedOff() => _copy(enabled: false);

  /// Raises [best] to [days] when that is longer. Never lowers it.
  StreakSettings withBest(int days) => days > best ? _copy(best: days) : this;

  /// Every pause, with any that covers [today] cut off the day before — or
  /// dropped, when it only started today.
  List<StreakPause> _closedBefore(DateTime today) {
    final key = dayKey(today);
    final yesterday = dayKey(_addDays(today, -1));
    return [
      for (final pause in pauses)
        if (!pause.covers(key))
          pause
        else if (pause.start.compareTo(key) < 0)
          StreakPause(start: pause.start, end: yesterday),
    ];
  }

  StreakSettings _copy({
    bool? enabled,
    String? since,
    List<StreakPause>? pauses,
    int? best,
  }) => StreakSettings(
    enabled: enabled ?? this.enabled,
    since: since ?? this.since,
    pauses: pauses ?? this.pauses,
    best: best ?? this.best,
  );

  @override
  String toString() =>
      'StreakSettings(${enabled ? 'on' : 'off'} since $since, '
      '${pauses.length} pauses, best $best)';
}

/// How one day was judged. [StreakDayKind.trained] and [StreakDayKind.rest]
/// add a day; nothing else does, and only [StreakDayKind.ended] ends a run.
enum StreakDayKind {
  /// She logged at least one session.
  trained,

  /// No session, and her week's target was still within reach after it.
  rest,

  /// The week slipped, and a rest week she earned covers it.
  covered,

  /// Inside a pause, or a slipped day in a week she paused in.
  paused,

  /// The day her week's target went out of reach. The run before it ends.
  ended,

  /// Today, not yet over and not trained. Judged tomorrow.
  pending,

  /// Before her first session, or after an ended run with no session yet.
  waiting,
}

/// What the screens are given.
@immutable
class StreakStatus {
  const StreakStatus({
    required this.enabled,
    required this.days,
    required this.best,
    this.trainedToday = false,
    this.pausedToday = false,
    this.pauseEndsOn,
  });

  /// She switched it off. Every surface draws nothing for this.
  static const StreakStatus off = StreakStatus(
    enabled: false,
    days: 0,
    best: 0,
  );

  final bool enabled;

  /// The current run, in days. Zero is "day 1 starts with your next session",
  /// never a failure.
  final int days;

  /// Her longest, in days, this one included.
  final int best;

  final bool trainedToday;
  final bool pausedToday;

  /// The last paused day, while a pause with an end runs. Null for "until I
  /// come back", and when nothing is paused.
  final DateTime? pauseEndsOn;

  /// A pause is running today with no end date.
  bool get pausedUntilResumed => pausedToday && pauseEndsOn == null;

  @override
  String toString() =>
      'StreakStatus(${enabled ? '$days days, best $best' : 'off'}'
      '${pausedToday ? ', paused' : ''})';
}

/// One judged day, for tests and for the rule table in the guide.
typedef StreakDay = ({String day, StreakDayKind kind});

/// Judges her days.
class TrainingStreak {
  const TrainingStreak({this.lookback = 400});

  /// How far back a run is followed, in days. A run longer than this still
  /// reads as this long, which nobody will mind; the cap is what keeps the walk
  /// cheap however long ago she switched it on.
  final int lookback;

  /// Her run as of [today].
  ///
  /// [sessionsByDay] is sessions logged per `yyyy-MM-dd`, live and recalled
  /// alike. [targetFor] is that ISO week's target. [coveredByRestWeek] says
  /// whether a rest week she earned covers that week.
  StreakStatus evaluate({
    required StreakSettings settings,
    required Map<String, int> sessionsByDay,
    required int Function(WeekKey week) targetFor,
    required bool Function(WeekKey week) coveredByRestWeek,
    required DateTime today,
  }) {
    if (!settings.enabled) return StreakStatus.off;
    final walk = _walk(
      settings: settings,
      sessionsByDay: sessionsByDay,
      targetFor: targetFor,
      coveredByRestWeek: coveredByRestWeek,
      today: today,
    );
    final pause = settings.activeOn(today);
    final end = pause?.end;
    return StreakStatus(
      enabled: true,
      days: walk.run,
      best: walk.best > settings.best ? walk.best : settings.best,
      trainedToday: (sessionsByDay[dayKey(today)] ?? 0) > 0,
      pausedToday: pause != null,
      pauseEndsOn: end == null ? null : DateTime.parse(end),
    );
  }

  /// Every judged day, oldest first. The same walk [evaluate] does.
  List<StreakDay> trace({
    required StreakSettings settings,
    required Map<String, int> sessionsByDay,
    required int Function(WeekKey week) targetFor,
    required bool Function(WeekKey week) coveredByRestWeek,
    required DateTime today,
  }) => _walk(
    settings: settings,
    sessionsByDay: sessionsByDay,
    targetFor: targetFor,
    coveredByRestWeek: coveredByRestWeek,
    today: today,
  ).days;

  ({int run, int best, List<StreakDay> days}) _walk({
    required StreakSettings settings,
    required Map<String, int> sessionsByDay,
    required int Function(WeekKey week) targetFor,
    required bool Function(WeekKey week) coveredByRestWeek,
    required DateTime today,
  }) {
    final todayDate = DateTime(today.year, today.month, today.day);
    final todayKey = dayKey(todayDate);
    var first = DateTime.tryParse(settings.since) ?? todayDate;
    final earliest = _addDays(todayDate, -lookback);
    if (first.isBefore(earliest)) first = earliest;

    final days = <StreakDay>[];
    var running = false;
    var run = 0;
    var best = 0;
    WeekKey? endedWeek;

    for (var d = first; !d.isAfter(todayDate); d = _addDays(d, 1)) {
      final key = dayKey(d);
      final week = WeekKey.of(d);
      final trained = (sessionsByDay[key] ?? 0) > 0;

      if (trained) {
        if (!running) {
          running = true;
          run = 0;
        }
        run += 1;
        if (run > best) best = run;
        days.add((day: key, kind: StreakDayKind.trained));
        continue;
      }
      if (key == todayKey) {
        days.add((day: key, kind: StreakDayKind.pending));
        continue;
      }
      if (settings.pauses.any((p) => p.covers(key))) {
        days.add((day: key, kind: StreakDayKind.paused));
        continue;
      }
      if (!running || endedWeek == week) {
        days.add((day: key, kind: StreakDayKind.waiting));
        continue;
      }

      final target = targetFor(week);
      final soFar = _sessionsInWeekThrough(d, sessionsByDay);
      // Monday is 1 and Sunday 7, so this is the days of the week still to
      // come after [d].
      final left = DateTime.daysPerWeek - d.weekday;
      // A week that reached its target is a week she kept, however the
      // sessions fell: two on Saturday and one on Sunday count the week, so
      // Friday was a rest day in it, not the day it slipped. Judged on every
      // walk, so a week that catches up gives its days back.
      final weekReached = _sessionsInWeek(d, sessionsByDay) >= target;
      if (target <= 0 || weekReached || soFar + left >= target) {
        run += 1;
        if (run > best) best = run;
        days.add((day: key, kind: StreakDayKind.rest));
        continue;
      }
      if (_weekHasPause(d, settings)) {
        days.add((day: key, kind: StreakDayKind.paused));
        continue;
      }
      if (coveredByRestWeek(week)) {
        days.add((day: key, kind: StreakDayKind.covered));
        continue;
      }
      days.add((day: key, kind: StreakDayKind.ended));
      running = false;
      run = 0;
      endedWeek = week;
    }

    return (run: running ? run : 0, best: best, days: days);
  }

  /// Sessions logged in [d]'s ISO week, Monday through [d].
  static int _sessionsInWeekThrough(DateTime d, Map<String, int> byDay) {
    var total = 0;
    for (var back = d.weekday - 1; back >= 0; back--) {
      total += byDay[dayKey(_addDays(d, -back))] ?? 0;
    }
    return total;
  }

  /// Every session logged in [d]'s ISO week, Monday to Sunday.
  static int _sessionsInWeek(DateTime d, Map<String, int> byDay) {
    final monday = _addDays(d, 1 - d.weekday);
    var total = 0;
    for (var i = 0; i < DateTime.daysPerWeek; i++) {
      total += byDay[dayKey(_addDays(monday, i))] ?? 0;
    }
    return total;
  }

  /// Whether any day of [d]'s ISO week is paused.
  static bool _weekHasPause(DateTime d, StreakSettings settings) {
    final monday = _addDays(d, 1 - d.weekday);
    for (var i = 0; i < DateTime.daysPerWeek; i++) {
      final key = dayKey(_addDays(monday, i));
      if (settings.pauses.any((p) => p.covers(key))) return true;
    }
    return false;
  }
}

/// [days] calendar days after [from], by calendar field rather than by
/// `Duration`, so a daylight-saving change never lands two dates on one day.
DateTime _addDays(DateTime from, int days) =>
    DateTime(from.year, from.month, from.day + days);
