/// Getting started: seven short tips over her first fortnight, each about one
/// thing the app does, for a woman who is not opening it.
///
/// Pure, like the rest of the plan (`notification_plan.dart`): it takes the
/// moment, what the phone remembers of the series and what she has already
/// done, and returns what to schedule and what to remember next.
///
/// The rules:
/// - **Anchored once.** Day one is the calendar day after the moment she
///   first lands verified in the app ([TipSeries.anchorAt]), kept on the
///   phone. Each tip has its day ([GettingStartedTip.day]) at her reminder
///   time, else 18:00, and never in quiet hours.
/// - **Only when she is away.** A tip comes only if she has not opened the app
///   in the [kTipQuietAfterOpen] before it. Every open reapplies the plan, so
///   a tip that would come sooner moves to a day after the open, and the ones
///   after it keep their order, a day apart at least.
/// - **Never late.** A tip whose moment has passed was shown, or passed while
///   nothing could be shown. Either way it is done and is never sent late.
/// - **Not about what she already did.** A tip whose thing she has done is
///   skipped ([TipFacts]).
/// - **Over for good.** After day fourteen, or once every tip is done, the
///   series has ended and nothing here schedules again.
library;

import 'package:flutter/foundation.dart';

import 'notification_plan.dart';
import 'training_reminders.dart';

/// The tips, in the order they come. [screen] is the payload a tap carries:
/// a screen id, or `GYM` for the first-gym guide, which has no route of its
/// own.
enum GettingStartedTip {
  firstWorkout(day: 1, screen: 'R03'),
  videos(day: 2, screen: 'R14'),
  mealScan(day: 3, screen: 'E12'),
  recipes(day: 5, screen: 'E05'),
  firstGym(day: 7, screen: kFirstGymTipPayload),
  muscles(day: 10, screen: 'P06'),
  program(day: 14, screen: 'R02');

  const GettingStartedTip({required this.day, required this.screen});

  /// Days after the day she landed.
  final int day;

  /// What a tap on it opens.
  final String screen;

  /// Its notification id, 7151 to 7157.
  int get id => tipNotificationId(index);

  /// The tip a planned notification carries, or null for anything else.
  static GettingStartedTip? of(PlannedNotification item) {
    if (item.kind != PlanKind.tip) return null;
    if (item.variant < 0 || item.variant >= values.length) return null;
    return values[item.variant];
  }
}

/// The payload of the first-gym tip.
const String kFirstGymTipPayload = 'GYM';

/// The series lasts this many days after the day she landed.
const int kTipSeriesDays = 14;

/// A tip waits at least this long after she last opened the app.
const Duration kTipQuietAfterOpen = Duration(hours: 24);

/// Where the series ends: midnight after its last day.
DateTime tipSeriesEnd(DateTime anchorAt) =>
    DateTime(anchorAt.year, anchorAt.month, anchorAt.day + kTipSeriesDays + 1);

/// What she has already done, read from what the phone holds. Never the
/// network.
@immutable
class TipFacts {
  const TipFacts({
    this.loggedASession = false,
    this.openedVideos = false,
    this.loggedAPhotoMeal = false,
    this.cannotScanMeals = false,
    this.openedRecipes = false,
    this.trainsAtHomeOnly = false,
    this.sawGymGuide = false,
    this.openedMuscles = false,
    this.openedProgram = false,
  });

  /// Any session she logged, trained or recalled.
  final bool loggedASession;

  /// She opened the exercise library (R14) or a demo (R15).
  final bool openedVideos;

  /// A meal she photographed was saved.
  final bool loggedAPhotoMeal;

  /// The meal scan is not open to her (allergies, or switched off), so the
  /// tip about it is not for her.
  final bool cannotScanMeals;

  /// She opened the recipes (E05).
  final bool openedRecipes;

  /// She said she trains at home only. Unanswered is not home.
  final bool trainsAtHomeOnly;

  /// The first-gym guide has been offered to her already.
  final bool sawGymGuide;

  /// She opened her muscles (P06).
  final bool openedMuscles;

  /// She opened her program (R02).
  final bool openedProgram;

  /// Whether [tip] is about something she has already done, or that is not
  /// for her.
  bool settles(GettingStartedTip tip) => switch (tip) {
    GettingStartedTip.firstWorkout => loggedASession,
    GettingStartedTip.videos => openedVideos,
    GettingStartedTip.mealScan => loggedAPhotoMeal || cannotScanMeals,
    GettingStartedTip.recipes => openedRecipes,
    GettingStartedTip.firstGym => trainsAtHomeOnly || sawGymGuide,
    GettingStartedTip.muscles => openedMuscles,
    GettingStartedTip.program => openedProgram,
  };
}

/// What the phone remembers of the series.
@immutable
class TipSeries {
  const TipSeries({
    this.anchorAt,
    this.due = const <GettingStartedTip, DateTime>{},
    this.done = const <GettingStartedTip>{},
    this.ended = false,
  });

  /// When she first landed verified in the app. Null until then: no series.
  final DateTime? anchorAt;

  /// When each tip still to come is scheduled, as last handed to the phone.
  final Map<GettingStartedTip, DateTime> due;

  /// Tips shown, skipped or out of time. Never scheduled again.
  final Set<GettingStartedTip> done;

  /// The series is over for good.
  final bool ended;

  /// Landed now, unless she has landed before.
  TipSeries anchoredAt(DateTime now) =>
      anchorAt != null ? this : TipSeries(anchorAt: now);

  Map<String, Object?> toJson() => <String, Object?>{
    'anchorAt': anchorAt?.toIso8601String(),
    'due': <String, String>{
      for (final entry in due.entries)
        entry.key.name: entry.value.toIso8601String(),
    },
    'done': [for (final tip in done) tip.name],
    'ended': ended,
  };

  /// Whatever is unreadable is left out: a missing anchor is no series.
  static TipSeries fromJson(Object? raw) {
    if (raw is! Map) return const TipSeries();
    GettingStartedTip? tipNamed(Object? name) {
      for (final tip in GettingStartedTip.values) {
        if (tip.name == name) return tip;
      }
      return null;
    }

    final anchor = raw['anchorAt'];
    final dueRaw = raw['due'];
    final doneRaw = raw['done'];
    final due = <GettingStartedTip, DateTime>{};
    if (dueRaw is Map) {
      for (final entry in dueRaw.entries) {
        final tip = tipNamed(entry.key);
        final at = entry.value is String
            ? DateTime.tryParse(entry.value as String)
            : null;
        if (tip != null && at != null) due[tip] = at;
      }
    }
    return TipSeries(
      anchorAt: anchor is String ? DateTime.tryParse(anchor) : null,
      due: due,
      done: {
        if (doneRaw is List)
          for (final name in doneRaw) ?tipNamed(name),
      },
      ended: raw['ended'] == true,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is TipSeries &&
      other.anchorAt == anchorAt &&
      other.ended == ended &&
      mapEquals(other.due, due) &&
      setEquals(other.done, done);

  @override
  int get hashCode => Object.hash(
    anchorAt,
    ended,
    Object.hashAllUnordered(
      due.entries.map((e) => Object.hash(e.key, e.value)),
    ),
    Object.hashAllUnordered(done),
  );

  @override
  String toString() =>
      'TipSeries(anchor $anchorAt, due $due, done $done'
      '${ended ? ', ended' : ''})';
}

abstract final class TipPlan {
  /// The tips to have scheduled at [now], and the series to remember once
  /// they are.
  ///
  /// [lastActiveAt] is when she last opened the app; every open sets it
  /// before the plan is applied again. [hour] and [minute] are her reminder
  /// time, or 18:00.
  static ({List<PlannedNotification> plan, TipSeries series}) next({
    required DateTime now,
    required TipSeries series,
    TipFacts facts = const TipFacts(),
    DateTime? lastActiveAt,
    int hour = TrainingReminders.defaultHour,
    int minute = 0,
  }) {
    final anchor = series.anchorAt;
    if (anchor == null || series.ended) {
      return (plan: const <PlannedNotification>[], series: series);
    }
    final end = tipSeriesEnd(anchor);
    final done = <GettingStartedTip>{...series.done};
    final due = <GettingStartedTip, DateTime>{};
    final plan = <PlannedNotification>[];
    final quietUntil = lastActiveAt?.add(kTipQuietAfterOpen);
    DateTime? previous;

    DateTime later(DateTime a, DateTime? b) =>
        b != null && b.isAfter(a) ? b : a;

    for (final tip in GettingStartedTip.values) {
      if (done.contains(tip)) continue;
      final slot = afterQuietHours(
        DateTime(anchor.year, anchor.month, anchor.day + tip.day, hour, minute),
      );
      final stored = series.due[tip];
      // Its moment has passed: shown while she was away, or passed before
      // anything could be shown. Nothing is sent late.
      if (!(stored ?? slot).isAfter(now)) {
        done.add(tip);
        continue;
      }
      if (facts.settles(tip)) {
        done.add(tip);
        continue;
      }
      // A slot already behind her stands at the time it was moved to.
      var at = slot.isAfter(now) ? slot : stored!;
      at = later(at, quietUntil);
      if (previous != null) {
        at = later(
          at,
          DateTime(
            previous.year,
            previous.month,
            previous.day + 1,
            previous.hour,
            previous.minute,
          ),
        );
      }
      at = afterQuietHours(at);
      // Pushed past the fortnight: that one is over.
      if (!at.isBefore(end)) {
        done.add(tip);
        continue;
      }
      due[tip] = at;
      previous = at;
      plan.add(
        PlannedNotification(
          id: tip.id,
          kind: PlanKind.tip,
          at: at,
          variant: tip.index,
        ),
      );
    }

    return (
      plan: plan,
      series: TipSeries(
        anchorAt: anchor,
        due: due,
        done: done,
        ended: done.length == GettingStartedTip.values.length,
      ),
    );
  }
}
