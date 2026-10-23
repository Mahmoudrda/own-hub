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
/// The event notes ride along too: each call works them out from the events
/// `EventsState` last read and the seats she holds. Until an events read has
/// succeeded in this run, the notes already on the phone are kept as they
/// are, so opening the app with no network does not cancel them. The events
/// state calls [reapplyLast] itself after every read and every seat change.
///
/// The getting started tips ride along: each call works them out again from
/// the moment and what she has done (`GettingStarted.facts`), and what the
/// phone accepted is remembered, so the next open can tell a tip that was
/// shown from one still to come.
library;

import 'dart:async' show unawaited;
import 'dart:convert' show jsonEncode;

import 'package:flutter/foundation.dart' show listEquals, visibleForTesting;
import 'package:flutter/services.dart' show rootBundle;

import '../domain/clock/app_clock.dart';
import '../domain/format/day_key.dart';
import '../features/cycle/domain/severe_symptom_gate.dart';
import '../features/eat/data/egyptian_food_pack.dart';
import '../features/eat/domain/allergy_guard.dart';
import '../features/events/domain/event_reminder_plan.dart';
import '../features/onboarding/domain/intake.dart' show LifeStage;
import '../features/train/domain/exercise_traits.dart';
import '../features/train/domain/getting_started_tips.dart';
import '../features/train/domain/my_plan.dart' show planDaysPerWeek;
import '../features/train/domain/notification_plan.dart';
import '../features/train/domain/notification_voice.dart';
import '../features/train/domain/programme_week.dart';
import '../features/train/domain/training_reminders.dart';
import '../l10n/app_l10n.dart';
import '../routing/app_router.dart';
import 'app_changes.dart';
import 'cycle_state.dart';
import 'events_state.dart';
import 'getting_started.dart';
import 'reminder_scheduler.dart';

abstract final class NotificationSync {
  static ReminderText? _text;

  /// Where the lines for the reminders' words are bundled.
  static const String bankAsset = 'assets/content/notification_lines.json';

  /// The bank in use. Empty until it has loaded, and when it cannot: every
  /// note then keeps its fixed text.
  static NotificationVoice get bank => _bank;
  static NotificationVoice _bank = NotificationVoice.empty;
  static Future<void>? _bankLoading;

  @visibleForTesting
  static set bank(NotificationVoice value) {
    _bank = value;
    _bankLoading = Future<void>.value();
  }

  // Not waited for: the first plan after launch goes out with the fixed texts
  // and is set again, in the new words, as soon as the bank has loaded.
  static void _loadBank(ReminderScheduler scheduler) {
    _bankLoading ??= () async {
      try {
        _bank = NotificationVoice.parse(await rootBundle.loadString(bankAsset));
      } catch (_) {
        _bank = NotificationVoice.empty;
      }
      if (!_bank.isEmpty) unawaited(reapplyLast(scheduler));
    }();
  }

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
    final facts = _facts();
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
      events: state.permitted && state.prefs.events
          ? _eventNotes(now, state)
          : const <PlannedNotification>[],
      freshStart: true,
      lastBestAt: facts.lastBestAt,
      severeToday: facts.severeToday,
    );
    return (
      plan: plan,
      tips: tipsApplied(tips.series, plan, tipsOn: tipsOn, leftOut: leftOut),
    );
  }

  static NotificationFacts _facts() {
    try {
      return _text?.facts?.call() ?? const NotificationFacts();
    } catch (_) {
      return const NotificationFacts();
    }
  }

  /// The bank situation a note of this kind draws its words from, or null
  /// for the kinds that keep their own texts (tips, event notes, the rest
  /// alert).
  @visibleForTesting
  static String? situationOf(PlannedNotification note) => switch (note.kind) {
    PlanKind.training => 'trainingDay',
    PlanKind.didYouTrain => 'didYouTrain',
    PlanKind.checkIn =>
      note.id == kCheckInSecondId ? 'comeBackLong' : 'comeBack',
    PlanKind.nudge => switch (nudgeFromCode(note.variant).context) {
      NudgeContext.morning => 'morningMeal',
      NudgeContext.midday => 'middayMove',
      NudgeContext.evening => 'eveningMeal',
      NudgeContext.weekEnd => 'weekEnd',
      NudgeContext.freshStart => 'freshStart',
      NudgeContext.newBest => 'newBest',
    },
    _ => null,
  };

  /// [plan] with the words chosen from [voice] where a line fits, and what
  /// was chosen noted in [history].
  ///
  /// A note with no line keeps its fixed text, except the two that have none
  /// of their own (a fresh start and a new best), which are left out. A note
  /// that was in the last plan for the same day keeps its line, so a replan
  /// does not reword it, and one that is no longer planned is given back.
  @visibleForTesting
  static List<PlannedNotification> voiced(
    List<PlannedNotification> plan, {
    required NotificationVoice voice,
    required NotificationFacts facts,
    required VoiceHistory history,
    required DateTime now,
  }) {
    final out = <PlannedNotification>[];
    final planned = <int>{};
    for (final note in plan) {
      final situation = situationOf(note);
      if (situation == null) {
        out.add(note);
        continue;
      }
      final before = history.scheduled[note.id];
      final sameDay =
          before != null &&
          before.at.year == note.at.year &&
          before.at.month == note.at.month &&
          before.at.day == note.at.day;
      final line = voice.pick(
        situation,
        locale: facts.locale,
        // The weekly reminder repeats, so it names nothing that changes.
        slots: situation == 'trainingDay'
            ? const <String, String>{}
            : facts.slots,
        history: history,
        protectedStage: facts.protectedStage,
        seed: note.at.difference(DateTime.utc(1970)).inDays + note.id,
        now: note.at,
        keep: sameDay ? before.lineId : null,
      );
      if (line == null) {
        final own =
            note.kind != PlanKind.nudge ||
            nudgeFromCode(note.variant).context.index <
                NudgeContext.freshStart.index;
        if (own) out.add(note);
        continue;
      }
      history.schedule(
        id: note.id,
        lineId: line.lineId,
        tone: line.tone,
        at: note.at,
        now: now,
      );
      planned.add(note.id);
      out.add(note.withBody(line.text));
    }
    for (final id in history.scheduled.keys.toList()) {
      if (!planned.contains(id)) history.cancel(id, now);
    }
    return out;
  }

  /// What a reminder may name or hold back for, read on this phone.
  static NotificationFacts factsFor(AppL10n l10n) {
    final locale = l10n.localeName.startsWith('ar') ? 'ar' : 'en';
    try {
      final intake = AppRouter.intakeRepository.read();
      final now = AppClock.now();
      final slots = <String, String>{};

      final her = AppRouter.herProgramme;
      if (her != null) {
        final sessions = programmeSessionsFor(her.content, intake.lifeStage);
        if (sessions.isNotEmpty) {
          final days = planDaysPerWeek(her.content, sessions, intake.days);
          final next =
              nextSlot(
                days,
                sessionsDoneThisWeek(AppRouter.trainRepository.sessions),
              ) ??
              0;
          slots['workout'] = sessions[next % sessions.length].title(locale);
        }
      }

      final food = _usualFood(l10n, now);
      if (food != null) slots['food'] = food;

      // Only a best that beat an earlier one: a first lift is not "new".
      final beaten = [
        for (final best in AppRouter.personalBestLedger.bests.values)
          if (best.previous != null) best,
      ]..sort((a, b) => a.dateKey.compareTo(b.dateKey));
      DateTime? lastBestAt;
      if (beaten.isNotEmpty) {
        final latest = beaten.last;
        slots['move'] = ExerciseTraits.nameOf(latest.exerciseId);
        lastBestAt = DateTime.tryParse(latest.dateKey);
      }

      final checkIn =
          CycleAppState.instance.checkIns[dayKey(now)] ??
          AppRouter.todayCheckIn;
      return NotificationFacts(
        locale: locale,
        slots: slots,
        protectedStage:
            intake.lifeStage == LifeStage.pregnant ||
            intake.lifeStage == LifeStage.postpartum,
        severeToday: const SevereSymptomGate().evaluate(checkIn),
        lastBestAt: lastBestAt,
      );
    } catch (_) {
      return NotificationFacts(locale: locale);
    }
  }

  /// The food she logged most in the last 30 days that her allergies and
  /// diet allow, by the name she sees it under. Null when none.
  static String? _usualFood(AppL10n l10n, DateTime now) {
    final from = dayKey(DateTime(now.year, now.month, now.day - 30));
    final counts = <String, int>{};
    for (final day in AppRouter.mealRepository.store.days.values) {
      if (day.dayId.compareTo(from) < 0) continue;
      for (final item in day.allItems) {
        counts.update(item.foodId, (c) => c + 1, ifAbsent: () => 1);
      }
    }
    if (counts.isEmpty) return null;
    final foods = {
      for (final food in EgyptianFoodPack.foods(l10n)) food.foodId: food,
    };
    final guard = AllergyGuard(AppRouter.eatConstraints);
    final ranked = counts.keys.toList()
      ..sort((a, b) {
        final byCount = counts[b]!.compareTo(counts[a]!);
        return byCount != 0 ? byCount : a.compareTo(b);
      });
    for (final id in ranked) {
      final food = foods[id];
      if (food != null && guard.screen([food]).isNotEmpty) {
        return food.names.first;
      }
    }
    return null;
  }

  /// The event notes at [now]: worked out from the events read, or, before
  /// any read has succeeded, the ones already on the phone that are still to
  /// come.
  static List<PlannedNotification> _eventNotes(
    DateTime now,
    ReminderState state,
  ) {
    final known = EventsState.instance.reminderInput();
    if (known == null) {
      return [
        for (final note in state.eventPlan)
          if (note.at.isAfter(now)) note,
      ];
    }
    return EventReminderPlan.build(
      now: now,
      events: known.events,
      booked: known.booked,
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
      final at = now ?? DateTime.now();
      _loadBank(scheduler);
      final next = _plan(at);
      final history = VoiceHistory.instance.copy();
      final spoken = voiced(
        next.plan,
        voice: _bank,
        facts: _facts(),
        history: history,
        now: at,
      );
      await scheduler.apply(spoken, text);
      if (jsonEncode(history.toJson()) !=
          jsonEncode(VoiceHistory.instance.toJson())) {
        VoiceHistory.instance.adopt(history);
        AppChanges.bump();
      }
      // Remembered only once the phone has them, so a tip that was never set
      // does not later read as one that was shown; and not over a series a
      // sign-out cleared meanwhile.
      if (identical(state.tips, before)) state.tips = next.tips;
      final notes = [
        for (final n in next.plan)
          if (n.kind == PlanKind.eventReminder) n,
      ];
      if (!listEquals(notes, state.eventPlan)) {
        state.eventPlan = notes;
        AppChanges.bump();
      }
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
