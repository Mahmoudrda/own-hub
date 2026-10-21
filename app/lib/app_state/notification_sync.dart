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
///
/// The getting started tips ride along: each call works them out again from
/// the moment and what she has done (`GettingStarted.facts`), and what the
/// phone accepted is remembered, so the next open can tell a tip that was
/// shown from one still to come.
library;

import 'package:flutter/foundation.dart' show visibleForTesting;

import '../features/train/domain/getting_started_tips.dart';
import '../features/train/domain/notification_plan.dart';
import '../features/train/domain/training_reminders.dart';
import 'getting_started.dart';
import 'reminder_scheduler.dart';

abstract final class NotificationSync {
  static ReminderText? _text;

  /// The words last used, so a session logged away from any screen's language
  /// still reschedules in hers.
  static ReminderText? get lastText => _text;

  static List<PlannedNotification> planFor(DateTime now) => _plan(now).plan;

  /// The whole plan, and the tip series as it stands once the plan is set.
  /// With the tips switched off nothing about the series moves.
  static ({List<PlannedNotification> plan, TipSeries tips}) _plan(
    DateTime now,
  ) {
    final state = ReminderState.instance;
    final tipsOn =
        state.permitted && state.prefs.tips && GettingStarted.allowed;
    final tips = tipsOn
        ? TipPlan.next(
            now: now,
            series: state.tips,
            facts: GettingStarted.facts(),
            lastActiveAt: state.lastActiveAt,
            hour: state.schedule?.hour ?? TrainingReminders.defaultHour,
            minute: state.schedule?.minute ?? 0,
          )
        : (plan: const <PlannedNotification>[], series: state.tips);
    final anchor = tips.series.anchorAt;
    final leftOut = <PlannedNotification>[];
    final plan = NotificationPlan.build(
      now: now,
      permitted: state.permitted,
      reminders: state.schedule,
      prefs: state.prefs,
      lastActiveAt: state.lastActiveAt,
      lastSessionAt: state.lastSessionAt,
      tips: tips.plan,
      tipsEnd: anchor == null ? null : tipSeriesEnd(anchor),
      shownTips: anchor == null
          ? const <DateTime>[]
          : [
              for (final tip in tips.series.done)
                DateTime(anchor.year, anchor.month, anchor.day + tip.day),
            ],
      tipsLeftOut: leftOut,
    );
    return (
      plan: plan,
      tips: tipsApplied(tips.series, plan, tipsOn: tipsOn, leftOut: leftOut),
    );
  }

  /// The series to remember once [plan] is on the phone: a tip is due where
  /// the plan really put it (a tip that gave way to another note moved to a
  /// later day), and only a tip in [leftOut], pushed past the end of the
  /// fortnight, is done. A tip merely dropped for a day or cut by the cap on
  /// unanswered notes stays due at its time, so it comes on a later open.
  @visibleForTesting
  static TipSeries tipsApplied(
    TipSeries series,
    List<PlannedNotification> plan, {
    bool tipsOn = true,
    List<PlannedNotification> leftOut = const <PlannedNotification>[],
  }) {
    if (!tipsOn || series.anchorAt == null) return series;
    final pastEnd = <GettingStartedTip>{
      for (final n in leftOut) ?GettingStartedTip.of(n),
    };
    final due = <GettingStartedTip, DateTime>{
      for (final entry in series.due.entries)
        if (!pastEnd.contains(entry.key)) entry.key: entry.value,
      for (final n in plan)
        if (GettingStartedTip.of(n) != null) GettingStartedTip.of(n)!: n.at,
    };
    final done = <GettingStartedTip>{...series.done, ...pastEnd};
    return TipSeries(
      anchorAt: series.anchorAt,
      due: due,
      done: done,
      ended: done.length == GettingStartedTip.values.length,
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
      final state = ReminderState.instance;
      final before = state.tips;
      final next = _plan(now ?? DateTime.now());
      await scheduler.apply(next.plan, text);
      // Remembered only once the phone has them, so a tip that was never set
      // does not later read as one that was shown; and not over a series a
      // sign-out cleared meanwhile.
      if (identical(state.tips, before)) state.tips = next.tips;
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
