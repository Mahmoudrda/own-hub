/// Everything this app ever shows as a local notification, worked out in one
/// place.
///
/// Pure: it takes the moment and what the phone knows, and returns what to
/// schedule. `lib/app_state/reminder_scheduler.dart` is the thin adapter that
/// hands the list to the platform, so every rule below is tested without a
/// phone.
///
/// The rules that hold for all of it:
/// - **Quiet hours.** Nothing shows between 22:00 and 08:00. Whatever falls
///   there moves to 08:00, so the privacy policy's promise is kept by the
///   plan and not by each caller. The rest-timer alert is the one exception:
///   it is a timer she started a minute ago in her hand, never a reminder.
/// - **No streak, no count, no guilt.** Nothing here reads a run of days. The
///   check-ins count days since she last opened the app or trained, and say
///   so to nobody.
/// - **Casual means one a day, four a week, three unanswered.** The
///   check-ins, the getting started tips, "Trained today?" and the friendly
///   nudges are casual; her chosen training days and the rest alert are not.
///   Together they land on at most one calendar day in each, at most
///   [kNudgesPerWeek] in a Saturday to Friday week, and at most
///   [kNudgesUnanswered] after she last opened the app or trained, the most
///   useful first: "Trained today?", then a check-in, then a tip, then a
///   nudge. None lands on a day she chose to train (a reminder that quiet
///   hours moved to the next day claims that day), except "Trained today?",
///   which is that day's own evening question.
/// - **Event reminders are not casual.** A note before an Own Hub event is
///   tied to a date the host set, has its own switch, and is bounded on its
///   own: at most [kEventNotesPerDay] a day and [kEventMaxPlanned] events at
///   a time. They are kept out of the casual budget on purpose, so an event
///   neither uses up the week's nudges nor is silenced by them. They still
///   honour quiet hours.
/// - **Local.** Nothing is sent to a server and no health data is in any
///   text.
library;

import 'package:flutter/foundation.dart';

import 'training_reminders.dart';

/// What a planned notification is.
enum PlanKind {
  /// Her chosen days and time, weekly.
  training,

  /// "Trained today? Add it in a tap." The evening of a reminder day.
  didYouTrain,

  /// Gentle, once at four days away and once at ten.
  checkIn,

  /// "Rest is over", while the phone is in her pocket.
  restOver,

  /// One of the getting started tips, in her first fortnight, only while she
  /// is not opening the app. [PlannedNotification.variant] is which one.
  tip,

  /// A friendly nudge. [PlannedNotification.variant] is
  /// [nudgeVariantCode]: which context and which of its texts.
  nudge,

  /// A note before an Own Hub event. [PlannedNotification.variant] is
  /// [eventVariantCode]: whether she has a seat and which of its texts.
  eventReminder,
}

/// Where in the run-up to an event a reminder falls.
enum EventReminderStep {
  /// Three days before, at 10:00. Only for an event she has not booked.
  threeDays,

  /// The day before, at 18:00. Only for an event she has not booked.
  oneDay,

  /// Three hours before the start, booked or not.
  threeHours,

  /// The morning of the event, at 09:00. Only for a booked seat.
  morningOf,
}

/// How many different texts an event reminder has for each of the two cases,
/// no seat and a booked seat.
const int kEventVariants = 2;

/// The code an event reminder carries in [PlannedNotification.variant]: the
/// block for a booked seat or not, then which text in it.
int eventVariantCode({required bool booked, required int variant}) =>
    (booked ? kEventVariants : 0) + variant.abs() % kEventVariants;

/// The case and text an [eventVariantCode] stands for.
({bool booked, int variant}) eventFromCode(int code) {
  final safe = code.abs() % (2 * kEventVariants);
  return (booked: safe >= kEventVariants, variant: safe % kEventVariants);
}

/// When in the day a friendly nudge is about, and so what it says.
enum NudgeContext {
  /// 09:30 to 11:00: a breakfast idea, or log breakfast in a tap.
  morning(9 * 60 + 30, 11 * 60),

  /// 13:30 to 16:00: a short movement at home.
  midday(13 * 60 + 30, 16 * 60),

  /// 18:30 to 20:30: a dinner recipe idea, or log dinner in a tap.
  evening(18 * 60 + 30, 20 * 60 + 30),

  /// The last day of her week, Friday (her week runs Saturday to Friday, as
  /// on Home's strip): a calm, forward-looking note about the week to come. It
  /// rides the evening window.
  weekEnd(18 * 60 + 30, 20 * 60 + 30),

  /// 13:30 to 16:00, the day after a day she chose to train on went by with
  /// nothing logged: a kind nudge to start again. It has no fixed text of its
  /// own; it is sent only when a line from the voice bank fits.
  freshStart(13 * 60 + 30, 16 * 60),

  /// 09:30 to 11:00, the morning after a session that beat one of her bests.
  /// Like [freshStart], it is sent only with a line from the voice bank.
  newBest(9 * 60 + 30, 11 * 60);

  const NudgeContext(this.fromMinute, this.toMinute);

  /// The window, in minutes past midnight. A deterministic minute inside it
  /// is picked per day.
  final int fromMinute;
  final int toMinute;
}

/// How many different texts each [NudgeContext] has.
const int kNudgeVariants = 4;

/// The code a nudge carries in [PlannedNotification.variant]: the context's
/// block of [kNudgeVariants] texts, then which text in it.
int nudgeVariantCode(NudgeContext context, int variant) =>
    context.index * kNudgeVariants + variant % kNudgeVariants;

/// The context and text a [nudgeVariantCode] stands for.
({NudgeContext context, int variant}) nudgeFromCode(int code) {
  final safe = code.abs() % (NudgeContext.values.length * kNudgeVariants);
  return (
    context: NudgeContext.values[safe ~/ kNudgeVariants],
    variant: safe % kNudgeVariants,
  );
}

/// The screen a tap on the nudge carrying [code] opens: the recipes (E05) for
/// a breakfast or dinner idea, the food diary (E01) for a meal to log, Today
/// for a short movement, and her progress (where her week lives) for the end
/// of the week. In the morning and evening blocks texts 0 and 2 are the
/// recipe ideas and 1 and 3 the meal to log.
String nudgeScreen(int code) {
  final nudge = nudgeFromCode(code);
  return switch (nudge.context) {
    NudgeContext.morning ||
    NudgeContext.evening => nudge.variant.isOdd ? 'E01' : 'E05',
    NudgeContext.midday ||
    NudgeContext.freshStart ||
    NudgeContext.newBest => 'T01',
    NudgeContext.weekEnd => 'P01',
  };
}

/// The switches on A01 beyond the training days themselves. On by default
/// once the phone has agreed to show notifications.
@immutable
class NotificationPrefs {
  const NotificationPrefs({
    this.logNudge = true,
    this.checkIns = true,
    this.restAlert = true,
    this.tips = true,
    this.nudges = true,
    this.events = true,
  });

  /// "Remind me to add a session I did".
  final bool logNudge;

  /// "Gentle check-ins when I've been away".
  final bool checkIns;

  /// "Rest timer alert".
  final bool restAlert;

  /// "Getting started tips". Turning it off cancels the ones still to come.
  final bool tips;

  /// "Friendly nudges": at most one a day, never at night. Turning it off
  /// cancels the ones still to come.
  final bool nudges;

  /// "Event reminders": a few notes before an Own Hub event, and one or two
  /// for a seat she booked. Turning it off cancels the ones still to come.
  final bool events;

  NotificationPrefs copyWith({
    bool? logNudge,
    bool? checkIns,
    bool? restAlert,
    bool? tips,
    bool? nudges,
    bool? events,
  }) => NotificationPrefs(
    logNudge: logNudge ?? this.logNudge,
    checkIns: checkIns ?? this.checkIns,
    restAlert: restAlert ?? this.restAlert,
    tips: tips ?? this.tips,
    nudges: nudges ?? this.nudges,
    events: events ?? this.events,
  );

  @override
  bool operator ==(Object other) =>
      other is NotificationPrefs &&
      other.logNudge == logNudge &&
      other.checkIns == checkIns &&
      other.restAlert == restAlert &&
      other.tips == tips &&
      other.nudges == nudges &&
      other.events == events;

  @override
  int get hashCode =>
      Object.hash(logNudge, checkIns, restAlert, tips, nudges, events);
}

/// One notification to schedule.
@immutable
class PlannedNotification {
  const PlannedNotification({
    required this.id,
    required this.kind,
    required this.at,
    this.weekly = false,
    this.variant = 0,
    this.body,
  });

  final int id;
  final PlanKind kind;

  /// Local wall-clock time. For a [weekly] one, its next occurrence; the
  /// platform repeats it on that weekday at that time.
  final DateTime at;

  final bool weekly;

  /// Which of the rotating texts a check-in carries, or which tip a tip is.
  final int variant;

  /// The words, when they were chosen from the voice bank. Null means the
  /// scheduler uses the fixed text of the kind. The plan itself never sets it.
  final String? body;

  PlannedNotification withBody(String text) => PlannedNotification(
    id: id,
    kind: kind,
    at: at,
    weekly: weekly,
    variant: variant,
    body: text,
  );

  @override
  bool operator ==(Object other) =>
      other is PlannedNotification &&
      other.id == id &&
      other.kind == kind &&
      other.at == at &&
      other.weekly == weekly &&
      other.variant == variant &&
      other.body == body;

  @override
  int get hashCode => Object.hash(id, kind, at, weekly, variant, body);

  @override
  String toString() => 'PlannedNotification($kind #$id at $at)';
}

/// The id of a weekday's reminder. A fixed block, so changing days replaces
/// rather than adds, and cancelling touches nothing else this app shows.
int reminderNotificationId(int weekday) => 7100 + weekday;

const int kDidYouTrainId = 7121;
const int kCheckInFirstId = 7131;
const int kCheckInSecondId = 7132;
const int kRestOverId = 7141;

/// How many days ahead the friendly nudges are planned.
const int kNudgeHorizonDays = 7;

/// The most friendly nudges in one of her weeks, Saturday to Friday.
const int kNudgesPerWeek = 4;

/// The most friendly nudges planned after she last opened the app.
const int kNudgesUnanswered = 3;

/// The id of the nudge on [weekday], 7161 to 7167. A fixed block: the horizon
/// is seven days, so no two nudges share a weekday.
int nudgeNotificationId(int weekday) => 7160 + weekday;

/// How many getting started tips there are.
const int kTipCount = 7;

/// The id of the getting started tip at [index], 7151 to 7157.
int tipNotificationId(int index) => 7151 + index;

/// The most events whose reminders are planned at once, the soonest ones.
const int kEventMaxPlanned = 6;

/// Ids per event: one for each [EventReminderStep].
const int kEventStepsPerEvent = 4;

/// The first of the event reminder ids, 7171. The block runs to 7194.
const int kEventFirstId = 7171;

/// The most event notes on one calendar day, across all events.
const int kEventNotesPerDay = 2;

/// The id of [step] for the event in [slot] (0 to [kEventMaxPlanned] - 1).
///
/// The slot is the event's place among the soonest events at the moment the
/// plan is built, by start time and then id, so the id is fixed by "which
/// event, which step" and a rebuild gives the same event the same ids while
/// the list stands. Nothing else uses 7171 to 7194.
int eventNotificationId(int slot, EventReminderStep step) =>
    kEventFirstId + slot * kEventStepsPerEvent + step.index;

/// Every id the plan may use, so replacing it removes what no longer applies.
/// The rest alert is not in it: it has its own lifetime.
final List<int> kPlannedIds = <int>[
  for (var weekday = DateTime.monday; weekday <= DateTime.sunday; weekday++)
    reminderNotificationId(weekday),
  kDidYouTrainId,
  kCheckInFirstId,
  kCheckInSecondId,
  for (var index = 0; index < kTipCount; index++) tipNotificationId(index),
  for (var weekday = DateTime.monday; weekday <= DateTime.sunday; weekday++)
    nudgeNotificationId(weekday),
  for (
    var id = kEventFirstId;
    id < kEventFirstId + kEventMaxPlanned * kEventStepsPerEvent;
    id++
  )
    id,
];

/// Quiet from 22:00 up to, not including, 08:00.
const int kQuietFromHour = 22;
const int kQuietToHour = 8;

/// The hour "Trained today?" is asked.
const int kDidYouTrainHour = 21;

/// "Trained today?" comes at least this long after that day's reminder, or
/// it is skipped that day.
const Duration kDidYouTrainGap = Duration(minutes: 60);

/// Days away before each check-in.
const int kFirstCheckInDays = 4;
const int kSecondCheckInDays = 10;

/// How many different check-in texts there are. The text set must hold this
/// many.
const int kCheckInVariants = 4;

bool _isQuiet(int hour) => hour >= kQuietFromHour || hour < kQuietToHour;

/// [at], or the 08:00 after it when it falls in quiet hours.
DateTime afterQuietHours(DateTime at) {
  if (!_isQuiet(at.hour)) return at;
  final day = at.hour >= kQuietFromHour ? at.day + 1 : at.day;
  return DateTime(at.year, at.month, day, kQuietToHour);
}

/// A weekly reminder's weekday and time once quiet hours are applied: 22:30
/// on Thursday becomes 08:00 on Friday, so the weekday moves with it.
({int weekday, int hour, int minute}) quietWeeklySlot(
  int weekday,
  int hour,
  int minute,
) {
  if (!_isQuiet(hour)) return (weekday: weekday, hour: hour, minute: minute);
  final nextDay = hour >= kQuietFromHour;
  return (
    weekday: nextDay ? weekday % 7 + 1 : weekday,
    hour: kQuietToHour,
    minute: 0,
  );
}

DateTime _dayOf(DateTime at) => DateTime(at.year, at.month, at.day);

/// The Saturday that starts the week [day] is in.
DateTime _weekStart(DateTime day) => DateTime(
  day.year,
  day.month,
  day.day - (day.weekday - DateTime.saturday) % DateTime.daysPerWeek,
);

DateTime? _latest(DateTime? a, DateTime? b) {
  if (a == null) return b;
  if (b == null) return a;
  return a.isAfter(b) ? a : b;
}

/// A fixed shuffle of a day, the same on every phone and every rebuild.
int _scatter(DateTime day) => (_dayNumber(day) * 2654435761) % 65521;

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Whole days since 1970 for the calendar day of [at], zone-free so it does
/// not wobble across a clock change.
int _dayNumber(DateTime at) =>
    DateTime.utc(at.year, at.month, at.day).millisecondsSinceEpoch ~/
    Duration.millisecondsPerDay;

abstract final class NotificationPlan {
  /// What to have scheduled at [now].
  ///
  /// Empty until the phone has agreed to show notifications ([permitted]).
  /// [lastActiveAt] and [lastSessionAt] are when she last opened the app and
  /// when she last logged a session; the later of them starts the away
  /// count.
  ///
  /// [tips] are the getting started tips already worked out by `TipPlan`
  /// (`getting_started_tips.dart`). They are kept only while
  /// [NotificationPrefs.tips] is on. One casual note a day is enough, so a
  /// tip that would land on a day already taken by "Trained today?", a
  /// check-in, a day she opened the app or trained moves to the next free
  /// day at the same time. Moved past [tipsEnd] (the end of the series) it
  /// is left out and added to [tipsLeftOut] when given. A tip missing from the
  /// result but not in [tipsLeftOut] was cut by the cap below and is still to
  /// come.
  ///
  /// [shownTips] are the days tips already came due, so they count towards
  /// the caps with the check-ins and nudges that came and went meanwhile.
  ///
  /// [events] are the event reminders already worked out by
  /// `EventReminderPlan`. They are added as they are while
  /// [NotificationPrefs.events] is on and take no part in the casual caps.
  ///
  /// [freshStart] plans a [NudgeContext.freshStart] for the day after one of
  /// her chosen days (yesterday or today) that has no session logged since,
  /// when that next day is not a chosen day itself. [lastBestAt] is the day of
  /// her last session that beat a best: the morning after it gets a
  /// [NudgeContext.newBest]. [severeToday] drops today's midday and fresh
  /// start notes. All three come from the caller and are off by default.
  ///
  /// All casual notes share the caps in the library comment, counting those
  /// that came and went since she last opened the app or trained, so a long
  /// absence plans none.
  static List<PlannedNotification> build({
    required DateTime now,
    required bool permitted,
    TrainingReminders? reminders,
    NotificationPrefs prefs = const NotificationPrefs(),
    DateTime? lastActiveAt,
    DateTime? lastSessionAt,
    List<PlannedNotification> tips = const <PlannedNotification>[],
    DateTime? tipsEnd,
    List<DateTime> shownTips = const <DateTime>[],
    List<PlannedNotification>? tipsLeftOut,
    List<PlannedNotification> events = const <PlannedNotification>[],
    bool freshStart = false,
    DateTime? lastBestAt,
    bool severeToday = false,
  }) {
    if (!permitted) return const <PlannedNotification>[];
    final plan = <PlannedNotification>[];

    if (reminders != null) {
      for (final weekday in reminders.orderedWeekdays) {
        final slot = quietWeeklySlot(weekday, reminders.hour, reminders.minute);
        plan.add(
          PlannedNotification(
            id: reminderNotificationId(weekday),
            kind: PlanKind.training,
            at: nextReminderAt(
              now,
              weekday: slot.weekday,
              hour: slot.hour,
              minute: slot.minute,
            ),
            weekly: true,
          ),
        );
      }
    }

    // Casual notes share one budget: a day each, [kNudgesPerWeek] a week,
    // [kNudgesUnanswered] since she last opened the app or trained. Highest
    // first: "Trained today?", then a check-in, then a tip, then a nudge.
    // Whatever does not fit is dropped or moved on.
    final keptTips = prefs.tips ? tips : const <PlannedNotification>[];
    final lastSeen = _latest(lastActiveAt, lastSessionAt);
    final seenDay = lastSeen == null ? null : _dayOf(lastSeen);
    final training = _trainingWeekdays(reminders);

    // A day she has already opened the app or trained on gets no casual note
    // beyond "Trained today?", which has its own rule: it only skips a day she
    // already logged. Opening the app, logging a meal and finishing a session
    // all set the times below and rebuild the plan, so today's note goes
    // away on its own.
    bool activeOn(DateTime at) =>
        (lastActiveAt != null && _sameDay(at, lastActiveAt)) ||
        (lastSessionAt != null && _sameDay(at, lastSessionAt));

    // Casual notes that have already come due, so the caps hold however often
    // the plan is rebuilt. Days only: no count is stored anywhere.
    final past = <DateTime>{};
    final allCheckIns = prefs.checkIns
        ? _checkIns(now, reminders, lastActiveAt, lastSessionAt)
        : const <PlannedNotification>[];
    for (final checkIn in allCheckIns) {
      if (!checkIn.at.isAfter(now)) past.add(_dayOf(checkIn.at));
    }
    final nudges = prefs.nudges
        ? _nudges(
            now,
            training,
            lastSeen,
            specials: _specialNudgeDays(
              now,
              reminders,
              training,
              lastSessionAt,
              freshStart,
              lastBestAt,
            ),
            severeToday: severeToday,
          )
        : (items: const <PlannedNotification>[], past: const <DateTime>[]);
    past.addAll(nudges.past);
    if (prefs.tips) {
      for (final day in shownTips) {
        if (!day.isAfter(now)) past.add(_dayOf(day));
      }
    }
    if (prefs.logNudge && reminders != null && seenDay != null) {
      // "Trained today?" asked on her reminder days since she was last seen.
      for (
        var day = DateTime(seenDay.year, seenDay.month, seenDay.day + 1);
        !day.isAfter(_dayOf(now));
        day = DateTime(day.year, day.month, day.day + 1)
      ) {
        if (!reminders.weekdays.contains(day.weekday)) continue;
        final asked = _didYouTrainAt(day, reminders);
        if (asked != null && !asked.isAfter(now)) past.add(day);
      }
    }
    final allowance =
        kNudgesUnanswered -
        (seenDay == null ? 0 : past.where((d) => d.isAfter(seenDay)).length);

    final accepted = <PlannedNotification>[];
    final claimed = <DateTime>{};
    final weekCount = <DateTime, int>{};
    for (final day in past) {
      weekCount.update(_weekStart(day), (c) => c + 1, ifAbsent: () => 1);
    }
    bool canTake(DateTime at, {bool onTrainingDay = false}) {
      final day = _dayOf(at);
      return !claimed.contains(day) &&
          (onTrainingDay || !training.contains(day.weekday)) &&
          (weekCount[_weekStart(day)] ?? 0) < kNudgesPerWeek;
    }

    void take(DateTime at) {
      final day = _dayOf(at);
      claimed.add(day);
      weekCount.update(_weekStart(day), (c) => c + 1, ifAbsent: () => 1);
    }

    // The first free day from [at] on, moving a day at a time, or null.
    DateTime? place(DateTime at, int maxMoves, {DateTime? end}) {
      var candidate = at;
      for (var moved = 0; moved <= maxMoves; moved++) {
        if (end != null && !candidate.isBefore(end)) return null;
        if (!activeOn(candidate) && canTake(candidate)) return candidate;
        candidate = DateTime(
          candidate.year,
          candidate.month,
          candidate.day + 1,
          candidate.hour,
          candidate.minute,
        );
      }
      return null;
    }

    if (prefs.logNudge && reminders != null) {
      final at = _nextDidYouTrain(now, reminders, lastSessionAt);
      if (at != null && canTake(at, onTrainingDay: true)) {
        take(at);
        accepted.add(
          PlannedNotification(
            id: kDidYouTrainId,
            kind: PlanKind.didYouTrain,
            at: at,
          ),
        );
      }
    }
    for (final checkIn in allCheckIns) {
      if (!checkIn.at.isAfter(now)) continue;
      final at = place(checkIn.at, DateTime.daysPerWeek - 1);
      if (at == null) continue;
      take(at);
      accepted.add(
        at == checkIn.at
            ? checkIn
            : PlannedNotification(
                id: checkIn.id,
                kind: checkIn.kind,
                at: at,
                variant: checkIn.variant,
              ),
      );
    }
    for (final tip in keptTips) {
      // A year of days is far past any series; the loop cannot run away.
      final at = place(tip.at, 400, end: tipsEnd);
      if (at == null) {
        tipsLeftOut?.add(tip);
        continue;
      }
      take(at);
      accepted.add(
        at == tip.at
            ? tip
            : PlannedNotification(
                id: tip.id,
                kind: tip.kind,
                at: at,
                variant: tip.variant,
              ),
      );
    }
    for (final nudge in nudges.items) {
      if (activeOn(nudge.at) || !canTake(nudge.at)) continue;
      take(nudge.at);
      accepted.add(nudge);
    }
    // Days and weeks are settled by priority; the unanswered cap is spent in
    // time order, so the soonest notes come and the ones after them wait for
    // her next open.
    accepted.sort((a, b) => a.at.compareTo(b.at));
    plan.addAll(accepted.take(allowance < 0 ? 0 : allowance));
    if (prefs.events) {
      plan.addAll(events.where((e) => e.kind == PlanKind.eventReminder));
    }
    return plan;
  }

  /// The weekdays she chose to train on, and the ones quiet hours moved a
  /// reminder to.
  static Set<int> _trainingWeekdays(TrainingReminders? reminders) {
    final training = <int>{};
    if (reminders != null) {
      for (final weekday in reminders.weekdays) {
        training
          ..add(weekday)
          ..add(
            quietWeeklySlot(weekday, reminders.hour, reminders.minute).weekday,
          );
      }
    }
    return training;
  }

  /// The friendly nudges worth having from [now] on, before the shared caps
  /// sort them against the other casual notes, and the days of those that
  /// have already come due.
  ///
  /// Her week runs Saturday to Friday, as on Home's strip. Which days of a
  /// week carry a nudge is decided by the week alone, not by when the plan is
  /// rebuilt, so an open on Wednesday does not hand Thursday's week a fifth.
  /// A week holds at most [kNudgesPerWeek], never on a day she chose to train
  /// ([training], which holds a reminder that quiet hours moved to the next
  /// day as that next day, and her chosen day stays free too), and the last
  /// day of the week, Friday, is the forward-looking note when it is free.
  static ({List<PlannedNotification> items, List<DateTime> past}) _nudges(
    DateTime now,
    Set<int> training,
    DateTime? lastSeen, {
    Map<DateTime, NudgeContext> specials = const <DateTime, NudgeContext>{},
    bool severeToday = false,
  }) {
    final today = _dayOf(now);
    final horizonEnd = DateTime(
      today.year,
      today.month,
      today.day + kNudgeHorizonDays - 1,
    );
    // Far enough back to see three come and go, never further than a month.
    var scanFrom = today;
    if (lastSeen != null && lastSeen.isBefore(now)) {
      scanFrom = _dayOf(lastSeen);
      final limit = DateTime(today.year, today.month, today.day - 28);
      if (scanFrom.isBefore(limit)) scanFrom = limit;
    }

    final slots = <PlannedNotification>[];
    final past = <DateTime>[];
    var weekStart = _weekStart(scanFrom);
    while (!weekStart.isAfter(horizonEnd)) {
      final friday = DateTime(
        weekStart.year,
        weekStart.month,
        weekStart.day + 6,
      );
      final eligible = <DateTime>[
        for (var i = 0; i < DateTime.daysPerWeek; i++)
          if (!training.contains(
            DateTime(
              weekStart.year,
              weekStart.month,
              weekStart.day + i,
            ).weekday,
          ))
            DateTime(weekStart.year, weekStart.month, weekStart.day + i),
      ];
      // Days with a reason of their own come first, then the Friday note.
      final chosen = <DateTime>[
        for (final day in eligible)
          if (specials.containsKey(day)) day,
      ];
      if (eligible.contains(friday) && !chosen.contains(friday)) {
        chosen.add(friday);
      }
      final rest = eligible.where((day) => !chosen.contains(day)).toList()
        ..sort((a, b) => _scatter(a).compareTo(_scatter(b)));
      chosen.addAll(rest.take(kNudgesPerWeek - chosen.length));
      chosen.sort();
      for (final day in chosen) {
        if (day.isAfter(horizonEnd)) continue;
        final seed = _dayNumber(day);
        final context =
            specials[day] ??
            (day == friday
                ? NudgeContext.weekEnd
                : NudgeContext.values[seed % 3]);
        final span = context.toMinute - context.fromMinute;
        final minute = context.fromMinute + _scatter(day) % span;
        final at = afterQuietHours(
          DateTime(day.year, day.month, day.day, minute ~/ 60, minute % 60),
        );
        if (!at.isAfter(now)) {
          past.add(day);
          continue;
        }
        if (day.isBefore(scanFrom)) continue;
        if (severeToday &&
            day == today &&
            (context == NudgeContext.midday ||
                context == NudgeContext.freshStart)) {
          continue;
        }
        slots.add(
          PlannedNotification(
            id: nudgeNotificationId(day.weekday),
            kind: PlanKind.nudge,
            at: at,
            variant: nudgeVariantCode(context, (seed ~/ 3) % kNudgeVariants),
          ),
        );
      }
      weekStart = DateTime(
        weekStart.year,
        weekStart.month,
        weekStart.day + DateTime.daysPerWeek,
      );
    }
    slots.sort((a, b) => a.at.compareTo(b.at));
    return (items: slots, past: past);
  }

  /// The days that carry a [NudgeContext.freshStart] or a
  /// [NudgeContext.newBest], whatever the week's usual pick: the day after a
  /// chosen day that went by without a session (today and yesterday are the
  /// ones that can still be waiting), and the day after her last best.
  /// Neither lands on a chosen training day.
  static Map<DateTime, NudgeContext> _specialNudgeDays(
    DateTime now,
    TrainingReminders? reminders,
    Set<int> training,
    DateTime? lastSessionAt,
    bool freshStart,
    DateTime? lastBestAt,
  ) {
    final today = _dayOf(now);
    final days = <DateTime, NudgeContext>{};
    if (freshStart && reminders != null) {
      final trained = lastSessionAt == null ? null : _dayOf(lastSessionAt);
      for (var back = 1; back >= 0; back--) {
        final chosen = DateTime(today.year, today.month, today.day - back);
        if (!reminders.weekdays.contains(chosen.weekday)) continue;
        if (trained != null && !trained.isBefore(chosen)) continue;
        final next = DateTime(chosen.year, chosen.month, chosen.day + 1);
        if (!training.contains(next.weekday)) {
          days[next] = NudgeContext.freshStart;
        }
      }
    }
    if (lastBestAt != null) {
      final best = _dayOf(lastBestAt);
      final next = DateTime(best.year, best.month, best.day + 1);
      if (!next.isBefore(today) && !training.contains(next.weekday)) {
        days[next] = NudgeContext.newBest;
      }
    }
    return days;
  }

  /// The first reminder day's 21:00 still ahead, skipping a day she has
  /// already logged a session on.
  static DateTime? _nextDidYouTrain(
    DateTime now,
    TrainingReminders reminders,
    DateTime? lastSessionAt,
  ) {
    for (var ahead = 0; ahead <= 7; ahead++) {
      final day = DateTime(now.year, now.month, now.day + ahead);
      if (!reminders.weekdays.contains(day.weekday)) continue;
      if (lastSessionAt != null && _sameDay(day, lastSessionAt)) continue;
      final at = _didYouTrainAt(day, reminders);
      if (at != null && at.isAfter(now)) return at;
    }
    return null;
  }

  /// When "Trained today?" is asked on the reminder day [day], or null when
  /// the day's reminder is too late in the evening for it.
  static DateTime? _didYouTrainAt(DateTime day, TrainingReminders reminders) {
    final at = DateTime(day.year, day.month, day.day, kDidYouTrainHour);
    final reminderAt = DateTime(
      day.year,
      day.month,
      day.day,
      reminders.hour,
      reminders.minute,
    );
    if (at.isBefore(reminderAt.add(kDidYouTrainGap))) return null;
    if (at.hour >= kQuietFromHour) return null;
    return at;
  }

  /// Both check-ins, those already due included: the caller counts those and
  /// schedules only the ones still ahead, so nothing is sent late.
  static List<PlannedNotification> _checkIns(
    DateTime now,
    TrainingReminders? reminders,
    DateTime? lastActiveAt,
    DateTime? lastSessionAt,
  ) {
    var base = now;
    DateTime? latest;
    for (final seen in [lastActiveAt, lastSessionAt]) {
      if (seen == null) continue;
      if (latest == null || seen.isAfter(latest)) latest = seen;
    }
    if (latest != null && !latest.isAfter(now)) base = latest;

    final hour = reminders?.hour ?? TrainingReminders.defaultHour;
    final minute = reminders?.minute ?? 0;
    final seed = _dayNumber(base);
    final out = <PlannedNotification>[];
    final steps = <(int, int, int)>[
      (kFirstCheckInDays, kCheckInFirstId, 0),
      (kSecondCheckInDays, kCheckInSecondId, kCheckInVariants ~/ 2),
    ];
    for (final (days, id, shift) in steps) {
      final at = afterQuietHours(
        DateTime(base.year, base.month, base.day + days, hour, minute),
      );
      out.add(
        PlannedNotification(
          id: id,
          kind: PlanKind.checkIn,
          at: at,
          variant: (seed + shift) % kCheckInVariants,
        ),
      );
    }
    return out;
  }

  /// The one-shot for the end of a rest that ends at [deadline], or null when
  /// there is nothing to announce.
  static PlannedNotification? rest({
    required DateTime now,
    required DateTime deadline,
    required bool permitted,
    NotificationPrefs prefs = const NotificationPrefs(),
  }) {
    if (!permitted || !prefs.restAlert || !deadline.isAfter(now)) return null;
    return PlannedNotification(
      id: kRestOverId,
      kind: PlanKind.restOver,
      at: deadline,
    );
  }
}
