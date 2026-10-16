/// Keeps the phone's scheduled notifications equal to what
/// [NotificationPlan] says they should be.
///
/// Called whenever the answer could have changed: at launch and on resume
/// (which also covers a new time zone), when she changes a switch or her days,
/// when she opens the app or logs a session (which pushes the check-ins out and
/// ends today's "Trained today?"), and when the language changes.
///
/// Every call is safe to repeat and asks for nothing. A failure is swallowed:
/// a notification that could not be set must never stop a feature (U09).
library;

import '../features/train/domain/notification_plan.dart';
import '../features/train/domain/training_reminders.dart';
import 'reminder_scheduler.dart';

abstract final class NotificationSync {
  static ReminderText? _text;

  /// The words last used, so a session logged away from any screen's language
  /// still reschedules in hers.
  static ReminderText? get lastText => _text;

  static List<PlannedNotification> planFor(DateTime now) {
    final state = ReminderState.instance;
    return NotificationPlan.build(
      now: now,
      permitted: state.permitted,
      reminders: state.schedule,
      prefs: state.prefs,
      lastActiveAt: state.lastActiveAt,
      lastSessionAt: state.lastSessionAt,
    );
  }

  /// Replaces what is scheduled. Does nothing until the phone has agreed to
  /// show notifications, so nothing is initialised for a woman who never
  /// turned them on.
  static Future<void> reapply(
    ReminderScheduler scheduler,
    ReminderText text, {
    DateTime? now,
    bool quiet = true,
  }) async {
    _text = text;
    if (!ReminderState.instance.permitted) return;
    try {
      await scheduler.apply(planFor(now ?? DateTime.now()), text);
    } catch (_) {
      // Only the sheet that just asked wants to hear that it failed.
      if (!quiet) rethrow;
    }
  }

  /// [reapply] with the words last used. A no-op before there are any.
  static Future<void> reapplyLast(
    ReminderScheduler scheduler, {
    DateTime? now,
  }) async {
    final text = _text;
    if (text == null) return;
    await reapply(scheduler, text, now: now);
  }

  /// The app went to the background with a rest running out at [deadline].
  static Future<void> restBackgrounded(
    ReminderScheduler scheduler,
    DateTime deadline, {
    DateTime? now,
  }) async {
    final text = _text;
    if (text == null) return;
    final state = ReminderState.instance;
    final rest = NotificationPlan.rest(
      now: now ?? DateTime.now(),
      deadline: deadline,
      permitted: state.permitted,
      prefs: state.prefs,
    );
    try {
      if (rest == null) {
        await scheduler.cancelRest();
      } else {
        await scheduler.scheduleRest(rest, text);
      }
    } catch (_) {}
  }

  /// She is back, skipped, asked for longer, finished or left.
  static Future<void> restCancelled(ReminderScheduler scheduler) async {
    if (!ReminderState.instance.permitted) return;
    try {
      await scheduler.cancelRest();
    } catch (_) {}
  }
}
