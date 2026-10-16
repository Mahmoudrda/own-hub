/// Training reminders: a note on the days she chose, at the time she chose.
///
/// Opt-in only. Offered once on `R10`, after the first session she finishes,
/// and changed or turned off from `A01`. Nothing asks at launch, and nothing
/// is sent from a server: the phone schedules them itself
/// (`lib/app_state/reminder_scheduler.dart`), so no token and no schedule
/// leaves the phone.
///
/// **§2 rule 3: weeks, not days.** The weekdays here are when to remind her,
/// never a record of what she did. Nothing counts a run of days, nothing is
/// sent after a missed one, and the text is the same every time ("Your session
/// is ready when you are"): no streak, no count, no guilt.
library;

import 'package:meta/meta.dart';

import 'notification_plan.dart';

/// When she asked to be reminded. [weekdays] use [DateTime.monday] (1) to
/// [DateTime.sunday] (7).
@immutable
class TrainingReminders {
  TrainingReminders({
    required Set<int> weekdays,
    this.hour = defaultHour,
    this.minute = 0,
  }) : weekdays = Set.unmodifiable(weekdays),
       assert(weekdays.isNotEmpty, 'a reminder needs at least one day'),
       assert(
         weekdays.every((d) => d >= DateTime.monday && d <= DateTime.sunday),
         'weekdays run 1 to 7',
       ),
       assert(hour >= 0 && hour < 24 && minute >= 0 && minute < 60);

  /// Six in the evening: after work and school, before dinner.
  static const int defaultHour = 18;

  final Set<int> weekdays;
  final int hour;
  final int minute;

  /// The days, Saturday first, the way the week runs in Egypt.
  List<int> get orderedWeekdays => [
    for (final day in egyptianWeekOrder)
      if (weekdays.contains(day)) day,
  ];

  TrainingReminders copyWith({Set<int>? weekdays, int? hour, int? minute}) =>
      TrainingReminders(
        weekdays: weekdays ?? this.weekdays,
        hour: hour ?? this.hour,
        minute: minute ?? this.minute,
      );

  Map<String, Object> toJson() => <String, Object>{
    'weekdays': orderedWeekdays,
    'hour': hour,
    'minute': minute,
  };

  /// Null for anything that is not a whole, valid schedule.
  static TrainingReminders? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final days = raw['weekdays'];
    final hour = raw['hour'];
    final minute = raw['minute'];
    if (days is! List || hour is! int || minute is! int) return null;
    final weekdays = <int>{
      for (final d in days)
        if (d is int && d >= DateTime.monday && d <= DateTime.sunday) d,
    };
    if (weekdays.isEmpty) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return TrainingReminders(weekdays: weekdays, hour: hour, minute: minute);
  }

  @override
  bool operator ==(Object other) =>
      other is TrainingReminders &&
      other.hour == hour &&
      other.minute == minute &&
      other.weekdays.length == weekdays.length &&
      other.weekdays.containsAll(weekdays);

  @override
  int get hashCode =>
      Object.hash(hour, minute, Object.hashAllUnordered(weekdays));
}

/// Saturday to Friday.
const List<int> egyptianWeekOrder = <int>[
  DateTime.saturday,
  DateTime.sunday,
  DateTime.monday,
  DateTime.tuesday,
  DateTime.wednesday,
  DateTime.thursday,
  DateTime.friday,
];

/// The days first offered for [sessionsAWeek], spread so no two sit side by
/// side where that can be helped. She changes them before anything is set.
Set<int> suggestedReminderDays(int sessionsAWeek) {
  return switch (sessionsAWeek) {
    <= 1 => {DateTime.sunday},
    2 => {DateTime.sunday, DateTime.wednesday},
    3 => {DateTime.sunday, DateTime.tuesday, DateTime.thursday},
    4 => {
      DateTime.saturday,
      DateTime.monday,
      DateTime.wednesday,
      DateTime.friday,
    },
    _ => {
      for (final day in egyptianWeekOrder.take(sessionsAWeek.clamp(1, 7))) day,
    },
  };
}

/// The next moment on or after [from] that falls on [weekday] at
/// [hour]:[minute]. A time already passed today goes to next week.
DateTime nextReminderAt(
  DateTime from, {
  required int weekday,
  required int hour,
  required int minute,
}) {
  var at = DateTime(from.year, from.month, from.day, hour, minute);
  while (at.weekday != weekday || !at.isAfter(from)) {
    at = DateTime(at.year, at.month, at.day + 1, hour, minute);
  }
  return at;
}

/// What this phone knows of her reminders.
class ReminderState {
  ReminderState._();

  static final ReminderState instance = ReminderState._();

  /// Whether `R10` has offered them. Once offered, it never asks again: she
  /// changes them from Notifications.
  bool offered = false;

  /// Her reminders, or null when they are off.
  TrainingReminders? schedule;

  /// The phone agreed to show notifications, when she saved her reminders.
  /// Kept so the other switches on `A01` can be on by default from then.
  bool permissionGranted = false;

  /// The extra switches on `A01`.
  NotificationPrefs prefs = const NotificationPrefs();

  /// When she last opened the app and when she last logged a session. They
  /// only start the away count for the gentle check-ins and are never sent
  /// anywhere.
  DateTime? lastActiveAt;
  DateTime? lastSessionAt;

  /// `R10` shows the offer once, and not to a woman who already set them.
  bool get offerDue => !offered && schedule == null;

  /// Whether the phone has agreed to show them. A woman who saved reminders
  /// before this was kept has `schedule` and no flag: saving needed it.
  bool get permitted => permissionGranted || schedule != null;

  /// She opened the app. Returns true when that is news worth keeping: the
  /// away count runs in days, so a second open the same day changes nothing.
  bool noteActive(DateTime now) {
    final before = lastActiveAt;
    lastActiveAt = now;
    return before == null ||
        before.year != now.year ||
        before.month != now.month ||
        before.day != now.day;
  }

  /// Account deletion and sign-out.
  void reset() {
    offered = false;
    schedule = null;
    permissionGranted = false;
    prefs = const NotificationPrefs();
    lastActiveAt = null;
    lastSessionAt = null;
  }
}
