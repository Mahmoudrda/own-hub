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
  });

  /// "Remind me to add a session I did".
  final bool logNudge;

  /// "Gentle check-ins when I've been away".
  final bool checkIns;

  /// "Rest timer alert".
  final bool restAlert;

  /// "Getting started tips". Turning it off cancels the ones still to come.
  final bool tips;

  NotificationPrefs copyWith({
    bool? logNudge,
    bool? checkIns,
    bool? restAlert,
    bool? tips,
  }) => NotificationPrefs(
    logNudge: logNudge ?? this.logNudge,
    checkIns: checkIns ?? this.checkIns,
    restAlert: restAlert ?? this.restAlert,
    tips: tips ?? this.tips,
  );

  @override
  bool operator ==(Object other) =>
      other is NotificationPrefs &&
      other.logNudge == logNudge &&
      other.checkIns == checkIns &&
      other.restAlert == restAlert &&
      other.tips == tips;

  @override
  int get hashCode => Object.hash(logNudge, checkIns, restAlert, tips);
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
  });

  final int id;
  final PlanKind kind;

  /// Local wall-clock time. For a [weekly] one, its next occurrence; the
  /// platform repeats it on that weekday at that time.
  final DateTime at;

  final bool weekly;

  /// Which of the rotating texts a check-in carries, or which tip a tip is.
  final int variant;

  @override
  bool operator ==(Object other) =>
      other is PlannedNotification &&
      other.id == id &&
      other.kind == kind &&
      other.at == at &&
      other.weekly == weekly &&
      other.variant == variant;

  @override
  int get hashCode => Object.hash(id, kind, at, weekly, variant);

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

/// How many getting started tips there are.
const int kTipCount = 7;

/// The id of the getting started tip at [index], 7151 to 7157.
int tipNotificationId(int index) => 7151 + index;

/// Every id the plan may use, so replacing it removes what no longer applies.
/// The rest alert is not in it: it has its own lifetime.
final List<int> kPlannedIds = <int>[
  for (var weekday = DateTime.monday; weekday <= DateTime.sunday; weekday++)
    reminderNotificationId(weekday),
  kDidYouTrainId,
  kCheckInFirstId,
  kCheckInSecondId,
  for (var index = 0; index < kTipCount; index++) tipNotificationId(index),
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
  /// [NotificationPrefs.tips] is on, and a check-in that would land on the
  /// same day as one of them is dropped: one note that day is enough.
  static List<PlannedNotification> build({
    required DateTime now,
    required bool permitted,
    TrainingReminders? reminders,
    NotificationPrefs prefs = const NotificationPrefs(),
    DateTime? lastActiveAt,
    DateTime? lastSessionAt,
    List<PlannedNotification> tips = const <PlannedNotification>[],
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
      if (prefs.logNudge) {
        final at = _nextDidYouTrain(now, reminders, lastSessionAt);
        if (at != null) {
          plan.add(
            PlannedNotification(
              id: kDidYouTrainId,
              kind: PlanKind.didYouTrain,
              at: at,
            ),
          );
        }
      }
    }

    final kept = prefs.tips ? tips : const <PlannedNotification>[];
    if (prefs.checkIns) {
      plan.addAll(
        _checkIns(
          now,
          reminders,
          lastActiveAt,
          lastSessionAt,
        ).where((checkIn) => !kept.any((tip) => _sameDay(tip.at, checkIn.at))),
      );
    }
    plan.addAll(kept);
    return plan;
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
      final at = DateTime(day.year, day.month, day.day, kDidYouTrainHour);
      final reminderAt = DateTime(
        day.year,
        day.month,
        day.day,
        reminders.hour,
        reminders.minute,
      );
      if (at.isBefore(reminderAt.add(kDidYouTrainGap))) continue;
      if (at.hour >= kQuietFromHour) continue;
      if (at.isAfter(now)) return at;
    }
    return null;
  }

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
      // Behind her: delivered already, or she was away through it with the
      // phone off. Nothing is sent late.
      if (!at.isAfter(now)) continue;
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
