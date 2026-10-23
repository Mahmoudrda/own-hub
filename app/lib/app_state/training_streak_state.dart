/// D37 — what the phone remembers for her training streak, and nothing more.
///
/// Two things are stored: her choices ([StreakSettings]) and how many sessions
/// she logged on each day. The length is never stored; [TrainingStreak] derives
/// it from those two every time it is asked, so there is no counter to drift.
///
/// The per-day count is kept here rather than read from the train repository
/// because a session she recalls on T02 never reaches that repository — it is
/// credited, and it counts toward her week, and so it counts here too.
///
/// Device only (D37). Never synced, never sent anywhere, never shown in a
/// notification, a reminder or a widget — `test/gamification_rules_test.dart`
/// holds the files that may import this to a list.
library;

import '../domain/clock/app_clock.dart';
import '../domain/format/day_key.dart';
import '../domain/rewards/training_streak.dart';
import '../features/progress/domain/progress_repository.dart';
import 'app_changes.dart';

/// How many days of session counts are kept. Longer than the walk looks back.
const int kStreakDaysKept = 400;

class TrainingStreakState {
  TrainingStreakState._();

  static final TrainingStreakState instance = TrainingStreakState._();

  StreakSettings? _settings;
  final Map<String, int> _byDay = <String, int>{};

  /// Her choices. Born on, from the first day she logs or changes anything, so
  /// nobody is judged on days she was never told were being counted.
  ///
  /// Reading never stores anything: Home asking how her streak stands must not
  /// leave state behind on a phone she has just wiped.
  StreakSettings settings([DateTime? now]) =>
      _settings ?? StreakSettings.startingOn(now ?? AppClock.now());

  /// [settings], kept, for the calls that change something.
  StreakSettings _held(DateTime now) =>
      _settings ??= StreakSettings.startingOn(now);

  /// Whether anything has been chosen or logged yet, for the snapshot.
  bool get touched => _settings != null || _byDay.isNotEmpty;

  Map<String, int> get sessionsByDay => Map<String, int>.unmodifiable(_byDay);

  /// One credited session on [on]'s day. Called by `RewardsState` on a first
  /// credit only, so a replayed session never counts twice.
  void noteCredit(DateTime on, {required ProgressStore progress}) {
    _held(on);
    final key = dayKey(on);
    _byDay[key] = (_byDay[key] ?? 0) + 1;
    _prune(on);
    _keepBest(progress, on);
  }

  /// A credited session on [on]'s day was removed. The count for that day
  /// comes down by one; nothing else changes, and her best stays hers.
  void noteUncredit(DateTime on) {
    final key = dayKey(on);
    final count = _byDay[key];
    if (count == null) return;
    if (count <= 1) {
      _byDay.remove(key);
    } else {
      _byDay[key] = count - 1;
    }
  }

  /// Her run as of [now]. [StreakStatus.off] when she switched it off.
  StreakStatus status({required ProgressStore progress, DateTime? now}) {
    final today = now ?? AppClock.now();
    return const TrainingStreak().evaluate(
      settings: settings(today),
      sessionsByDay: _byDay,
      targetFor: (week) =>
          progress.weeks[week.id]?.sessionsTarget ??
          progress.goal.sessionsTarget,
      coveredByRestWeek: (week) {
        final doc = progress.weeks[week.id];
        if (doc != null && doc.isClosed) return doc.repairedByRestWeek;
        // The week is still open: the same test the repair will apply when it
        // closes — a rest week in the bank, and a counted week behind it.
        return progress.goal.restWeeksBanked > 0 &&
            progress.goal.countedWeeks > 0;
      },
      today: today,
    );
  }

  /// Her switch. Turning it on starts fresh from today; turning it off keeps
  /// her best and judges nothing until she turns it on again.
  void setEnabled(bool on, {required ProgressStore progress, DateTime? now}) {
    final today = now ?? AppClock.now();
    _keepBest(progress, today);
    final current = _held(today);
    if (current.enabled == on) return;
    _settings = on ? current.switchedOn(today) : current.switchedOff();
    AppChanges.bump();
  }

  void pause(StreakPauseLength length, {DateTime? now}) {
    final today = now ?? AppClock.now();
    _settings = _held(today).pausedFrom(today, length);
    AppChanges.bump();
  }

  void resume({DateTime? now}) {
    final today = now ?? AppClock.now();
    _settings = _held(today).resumedOn(today);
    AppChanges.bump();
  }

  /// Puts back what the phone remembered.
  void restore({StreakSettings? settings, Map<String, int>? sessionsByDay}) {
    _settings = settings;
    _byDay
      ..clear()
      ..addAll(sessionsByDay ?? const <String, int>{});
  }

  /// Account deletion, and tests.
  void reset() {
    _settings = null;
    _byDay.clear();
  }

  void _keepBest(ProgressStore progress, DateTime on) {
    final current = _held(on);
    if (!current.enabled) return;
    final best = status(progress: progress, now: on).best;
    _settings = current.withBest(best);
  }

  void _prune(DateTime on) {
    final oldest = dayKey(
      DateTime(on.year, on.month, on.day - kStreakDaysKept),
    );
    _byDay.removeWhere((day, _) => day.compareTo(oldest) < 0);
  }
}
