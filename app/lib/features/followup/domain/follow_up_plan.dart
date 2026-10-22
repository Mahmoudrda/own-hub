/// What Own Hub asks or tells her next, chosen from facts about her week.
///
/// Pure Dart: the screens read [FollowUpPlan.next] and draw what it returns.
/// One follow-up at a time, in the order of [FollowUpKind]. Nothing here
/// changes her plan: [FollowUpPlan.suggest] only says what a change would be,
/// and she taps to accept it.
library;

import 'package:flutter/foundation.dart';

import '../../../domain/clock/app_clock.dart';
import '../../../domain/format/day_key.dart';
import '../../onboarding/domain/intake.dart';

/// The kinds of follow-up, in priority order: the first that applies wins.
enum FollowUpKind { weekReview, afterSession, comeBack, food }

/// How she feels the day after a session.
enum Feel { fresh, aBitSore, verySore }

/// How her week felt.
enum WeekFelt { good, okay, hard }

/// Whether her plan fitted the week.
enum PlanFit { tooMuch, aboutRight, tooLittle }

/// What she wants the coming week to be about.
enum WeekFocus { strength, feelGood, steadyLoss }

/// Her three answers on the Friday week review.
@immutable
class WeekReviewAnswer {
  const WeekReviewAnswer({
    required this.felt,
    required this.fit,
    required this.focus,
  });

  final WeekFelt felt;
  final PlanFit fit;
  final WeekFocus focus;

  @override
  bool operator ==(Object other) =>
      other is WeekReviewAnswer &&
      other.felt == felt &&
      other.fit == fit &&
      other.focus == focus;

  @override
  int get hashCode => Object.hash(felt, fit, focus);
}

/// Her latest finished session, in numbers.
@immutable
class SessionRecap {
  const SessionRecap({
    required this.dateKey,
    required this.moves,
    required this.sets,
    this.topMoveName,
    this.topKg,
  });

  /// The day of the session, `yyyy-MM-dd`.
  final String dateKey;
  final int moves;
  final int sets;

  /// The move with her heaviest weight, when she logged one.
  final String? topMoveName;
  final double? topKg;
}

/// Everything [FollowUpPlan.next] looks at.
@immutable
class FollowUpFacts {
  const FollowUpFacts({
    required this.now,
    this.enabled = true,
    this.muted = const <FollowUpKind>{},
    this.notBefore = const <FollowUpKind, String>{},
    this.lastSession,
    this.feels = const <String, Feel>{},
    required this.weekStartKey,
    this.sessionsThisWeek = 0,
    this.weekTarget = 0,
    this.setsThisWeek = 0,
    this.bestsThisWeek = 0,
    this.avgProteinThisWeek,
    this.weekReviews = const <String, WeekReviewAnswer>{},
    this.lastLoggedDays = const <({int protein, int target})>[],
    this.proteinPick,
    this.protectedStage = false,
    this.severeToday = false,
    this.gentleToday = false,
  });

  final DateTime now;

  /// Her master switch.
  final bool enabled;

  /// Kinds she asked not to see again.
  final Set<FollowUpKind> muted;

  /// Per kind, the first day (`yyyy-MM-dd`) it may show again.
  final Map<FollowUpKind, String> notBefore;
  final SessionRecap? lastSession;

  /// How she felt, by the `dateKey` of the session.
  final Map<String, Feel> feels;

  /// The Saturday her week started on, `yyyy-MM-dd`.
  final String weekStartKey;
  final int sessionsThisWeek;
  final int weekTarget;
  final int setsThisWeek;
  final int bestsThisWeek;
  final int? avgProteinThisWeek;

  /// Her week reviews, by `weekStartKey`.
  final Map<String, WeekReviewAnswer> weekReviews;

  /// Days she logged food, newest first, at most five.
  final List<({int protein, int target})> lastLoggedDays;
  final ({String name, int proteinG})? proteinPick;

  /// Pregnant, postpartum, or training around pain or an injury: wording
  /// leads with safety.
  final bool protectedStage;

  /// A severe symptom today: nothing is shown.
  final bool severeToday;

  /// A hard day today: wording is gentler.
  final bool gentleToday;
}

/// The follow-up to show, with the numbers its words use.
@immutable
class FollowUp {
  const FollowUp({
    required this.kind,
    this.session,
    this.weekStartKey,
    this.sessions = 0,
    this.sets = 0,
    this.bests = 0,
    this.avgProtein,
    this.daysAway,
    this.lowDays,
    this.pick,
    this.safetyFirst = false,
    this.gentle = false,
  });

  final FollowUpKind kind;
  final SessionRecap? session;
  final String? weekStartKey;
  final int sessions;
  final int sets;
  final int bests;
  final int? avgProtein;
  final int? daysAway;
  final int? lowDays;
  final ({String name, int proteinG})? pick;
  final bool safetyFirst;
  final bool gentle;
}

/// A change to her plan that the week review offers. Null fields stay as they
/// are.
@immutable
class WeekSuggestion {
  const WeekSuggestion({this.days, this.minutes, this.goal});

  final int? days;
  final int? minutes;
  final TrainingGoal? goal;

  bool get isEmpty => days == null && minutes == null && goal == null;
}

abstract final class FollowUpPlan {
  /// Fewest minutes a session may be suggested down to.
  static const int minMinutes = 10;

  /// Most minutes a session may be suggested up to.
  static const int maxMinutes = 180;

  /// The Saturday that starts the week [day] is in, as `yyyy-MM-dd`.
  static String weekStartKeyOf(DateTime day) => dayKey(
    DateTime(
      day.year,
      day.month,
      day.day - (day.weekday - DateTime.saturday) % DateTime.daysPerWeek,
    ),
  );

  /// The follow-up to show now, or null when there is none.
  static FollowUp? next(FollowUpFacts f) {
    if (!f.enabled || f.severeToday) return null;
    final today = dayKey(f.now);
    for (final kind in FollowUpKind.values) {
      if (f.muted.contains(kind)) continue;
      final notBefore = f.notBefore[kind];
      if (notBefore != null && today.compareTo(notBefore) < 0) continue;
      final found = _match(kind, f, today);
      if (found != null) return found;
    }
    return null;
  }

  static FollowUp? _match(FollowUpKind kind, FollowUpFacts f, String today) {
    switch (kind) {
      case FollowUpKind.weekReview:
        // Friday is the last day of her Saturday-to-Friday week.
        if (f.now.weekday != DateTime.friday) return null;
        if (f.weekReviews[f.weekStartKey] != null) return null;
        return FollowUp(
          kind: kind,
          weekStartKey: f.weekStartKey,
          sessions: f.sessionsThisWeek,
          sets: f.setsThisWeek,
          bests: f.bestsThisWeek,
          avgProtein: f.avgProteinThisWeek,
          safetyFirst: f.protectedStage,
        );
      case FollowUpKind.afterSession:
        final last = f.lastSession;
        if (last == null || f.feels[last.dateKey] != null) return null;
        final ago = _daysBetween(last.dateKey, today);
        if (ago == null || ago < 1 || ago > 2) return null;
        return FollowUp(
          kind: kind,
          session: last,
          safetyFirst: f.protectedStage,
          gentle: f.gentleToday,
        );
      case FollowUpKind.comeBack:
        final last = f.lastSession;
        if (last == null) return null;
        final ago = _daysBetween(last.dateKey, today);
        if (ago == null || ago < 7) return null;
        return FollowUp(
          kind: kind,
          session: last,
          daysAway: ago,
          safetyFirst: f.protectedStage,
        );
      case FollowUpKind.food:
        final pick = f.proteinPick;
        if (pick == null || f.lastLoggedDays.length < 5) return null;
        final low = f.lastLoggedDays.where((d) => d.protein < d.target).length;
        if (low < 3) return null;
        return FollowUp(
          kind: kind,
          lowDays: low,
          pick: pick,
          safetyFirst: f.protectedStage,
        );
    }
  }

  /// Whole days from [from] to [to], both `yyyy-MM-dd`; null if either is not
  /// a day.
  static int? _daysBetween(String from, String to) {
    final a = DateTime.tryParse(from);
    final b = DateTime.tryParse(to);
    if (a == null || b == null) return null;
    return DateTime.utc(
      b.year,
      b.month,
      b.day,
    ).difference(DateTime.utc(a.year, a.month, a.day)).inDays;
  }

  /// What her week review answer would change in her plan.
  static WeekSuggestion suggest(
    WeekReviewAnswer a, {
    required int days,
    required int minutes,
    required TrainingGoal goal,
  }) {
    int? newDays;
    int? newMinutes;
    switch (a.fit) {
      case PlanFit.tooMuch:
        if (days > 1) {
          newDays = days - 1;
        } else {
          final lower = minutes - 10 < minMinutes ? minMinutes : minutes - 10;
          if (lower != minutes) newMinutes = lower;
        }
      case PlanFit.tooLittle:
        if (days < 7) {
          newDays = days + 1;
        } else {
          final higher = minutes + 10 > maxMinutes ? maxMinutes : minutes + 10;
          if (higher != minutes) newMinutes = higher;
        }
      case PlanFit.aboutRight:
        break;
    }
    final wanted = switch (a.focus) {
      WeekFocus.strength => TrainingGoal.stronger,
      WeekFocus.feelGood => TrainingGoal.feelBetter,
      WeekFocus.steadyLoss => TrainingGoal.loseSteadily,
    };
    return WeekSuggestion(
      days: newDays,
      minutes: newMinutes,
      // Building muscle is a way of getting stronger, so "strength" is not a
      // change of goal for her.
      goal:
          wanted == goal ||
              (goal == TrainingGoal.buildMuscle &&
                  wanted == TrainingGoal.stronger)
          ? null
          : wanted,
    );
  }

  /// Whether the load stays where it is: of her answers in the last 14 days,
  /// the two latest, by day, are both "very sore". An older answer is not how
  /// she feels now.
  static bool holdsLoad(Map<String, Feel> feels, {DateTime? now}) {
    final today = now ?? AppClock.now();
    final since = dayKey(DateTime(today.year, today.month, today.day - 14));
    final recent = feels.keys.where((key) => key.compareTo(since) >= 0).toList()
      ..sort();
    if (recent.length < 2) return false;
    return feels[recent[recent.length - 1]] == Feel.verySore &&
        feels[recent[recent.length - 2]] == Feel.verySore;
  }
}
