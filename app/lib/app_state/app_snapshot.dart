/// Everything she has done, as one JSON document, and back again.
///
/// The app holds her week in a dozen in-memory stores. This file is the only
/// place that knows how to turn all of them into a value that can be written to
/// the phone, and the only place that knows how to read one back.
/// `local_persistence.dart` does the reading and writing; this does the shape.
///
/// ## A bad snapshot must never take the app down with it
///
/// That is the requirement everything below is arranged around, because the
/// failure it prevents is the worst one there is: an app that cannot open. A
/// snapshot read off a phone can be missing, empty, truncated by a kill mid
/// write, written by an older build, or corrupt in ways nobody has thought of.
/// Every one of those has to end with the app starting, even if it starts with
/// nothing.
///
/// Three arrangements make that true rather than hoped for.
///
///  1. **A schema number.** [kSnapshotSchema] is written into the document and
///     checked on the way in. A document from a build that shaped things
///     differently is not decoded at all — it is ignored, and she starts fresh,
///     which is exactly what she would have had before this file existed.
///  2. **Decode is separate from apply.** [decode] builds every object and
///     touches no store; it returns a list of closures that do nothing but
///     assign what has already been built. So a section that throws halfway
///     through throws before anything was changed, and there is no such thing
///     as a half-restored store.
///  3. **One section at a time.** Each section decodes inside its own guard. A
///     corrupt `meals` section costs her meals and nothing else; her training,
///     her cycle and her settings still come back. An unrecognised section is
///     skipped without comment, which is what makes a newer document readable
///     by an older build as far as it goes.
///
/// ## What is not in here
///
/// Nothing that was never hers, and nothing that was still in flight.
///
///   * The workout and food libraries, the sample meal plan, the swap
///     candidates: content that ships with the app. It is already there when
///     the app opens, and writing a copy of it to her phone would only mean
///     reading a stale copy back.
///   * A meal or a set still inside its five-second window. It was never
///     written, and bringing it back would be logging something she can no
///     longer take back.
///   * Where she was standing: the month Y08 was scrolled to, the post she had
///     open, the session she was midway through. Those are places, not records.
///   * Community and coaching. Both are off for the first release, and both
///     are large nested graphs — see the note at the bottom of this file. The
///     exceptions are small and hers: which side of the app she holds
///     (`roles`), her own coach application (`coach`) and the code her coach
///     sent her (`invite`), so a coach is still a coach after a relaunch.
library;

import 'dart:convert';

import '../domain/clock/app_clock.dart';
import '../domain/identity/user_roles.dart';
import '../domain/rewards/daily_cap.dart';
import '../domain/rewards/personal_best_detector.dart';
import '../domain/rewards/training_streak.dart';
import '../domain/rewards/week_rollup.dart';
import '../domain/rewards/weekly_goal.dart';
import '../domain/training/prescribed_set.dart';
import '../domain/week/week_key.dart';
import '../features/account/domain/dietary_profile.dart';
import '../features/coach/domain/coach_capacity.dart';
import '../features/coach/domain/coach_credentials.dart';
import '../features/coach/domain/coach_invite.dart' show normaliseInviteCode;
import '../features/coach/domain/coach_profile.dart';
import '../features/account/domain/privacy_settings.dart';
import '../features/cycle/domain/cycle_document.dart';
import '../features/cycle/domain/period_entry.dart';
import '../features/cycle/domain/today_check_in.dart';
import '../features/eat/domain/custom_food.dart';
import '../features/eat/domain/meal_repository.dart';
import '../features/onboarding/domain/body_data.dart';
import '../features/onboarding/domain/intake.dart';
import '../features/onboarding/domain/starting_program.dart'
    show migratedProgrammeFamily, splitDaysOf;
import 'pledge.dart';
import 'guest_session.dart';
import 'onboarding_state.dart';
import '../features/progress/domain/progress_repository.dart';
import '../features/signup/domain/locale_preference.dart';
import '../features/today/domain/today_day.dart';
import '../features/today/domain/today_repository.dart';
import '../features/train/domain/custom_workout.dart';
import '../features/train/domain/getting_started_tips.dart';
import '../features/train/domain/my_plan.dart';
import '../features/train/domain/notification_plan.dart';
import '../features/train/domain/train_repository.dart';
import '../features/train/domain/notification_voice.dart';
import '../features/train/domain/training_reminders.dart';
import 'chosen_programme.dart';
import '../features/followup/domain/follow_up_plan.dart';
import 'first_gym_guide_state.dart';
import 'follow_up_state.dart';
import '../routing/app_router.dart';
import 'coach_invite_state.dart';
import 'coach_profile_state.dart';
import 'custom_workout_state.dart';
import 'my_plan_state.dart';
import 'bar_preference.dart';
import 'coach_application_draft.dart';
import 'coach_client_notes.dart';
import 'move_notes.dart';
import 'rest_timer_prefs.dart';
import 'cycle_state.dart';
import 'eat_state.dart';
import 'rewards_state.dart';
import 'workout_session_state.dart';
import 'role_state.dart';
import 'training_streak_state.dart';

/// The shape this build writes.
///
/// Bump it whenever a section changes in a way an older decoder would read
/// wrongly rather than not at all. A document carrying a number that is not in
/// [kReadableSchemas] is ignored whole, which is the cheapest correct migration
/// there is: she loses the snapshot, never the app.
///
/// 2 is the de-duplicated train section — a flush names the session's
/// prescription rather than repeating it, and null fields are left out. A build
/// that only knows 1 would read a flush's sets as empty rather than as
/// nonsense, which is quiet enough to be worse, so it refuses the document
/// instead.
const int kSnapshotSchema = 2;

/// Every shape this build can read.
///
/// Writing a new shape and reading only it would throw away the history of
/// every woman who updates the app, which is a worse failure than the one the
/// schema number exists to prevent. The 1 → 2 change is additive on the way in:
/// every flush set in a 1 document carries its own `prescribed`, which is the
/// same long form a 2 document still writes for a swapped move, read by the
/// same line. So the old number stays readable, and is written by nothing.
const Set<int> kReadableSchemas = <int>{1, 2};

/// Turns every store into a document, and a document back into every store.
abstract final class AppSnapshot {
  /// Everything she has done, as a JSON-encodable map.
  static Map<String, Object?> capture() => <String, Object?>{
    'schema': kSnapshotSchema,
    'savedAt': DateTime.now().toIso8601String(),
    'today': _captureToday(),
    'progress': _captureProgress(),
    'train': _captureTrain(),
    'liveSession': ?_captureLiveSession(),
    'meals': _captureMeals(),
    'eat': _captureEat(),
    'cycle': _captureCycle(),
    'privacy': _capturePrivacy(),
    'dietary': _captureDietary(),
    'intake': _captureIntake(),
    'language': _captureLanguage(),
    'pledge': _capturePledge(),
    'reminders': _captureReminders(),
    'firstGymGuide': <String, Object?>{
      'seen': FirstGymGuideState.instance.seen,
    },
    'roles': _captureRoles(),
    'coach': _captureCoach(),
    'invite': _captureInvite(),
    'awards': _captureAwards(),
    'trainingStreak': _captureTrainingStreak(),
    'chosenProgramme': ?_captureChosenProgramme(),
    'followUps': ?_captureFollowUps(),
    'notificationVoice': ?_captureNotificationVoice(),
    'customWorkouts': ?_captureCustomWorkouts(),
    'myPlan': ?_captureMyPlan(),
    'restTimer': ?_captureRestTimer(),
    'moveNotes': ?_captureMoveNotes(),
    'coachApplicationDraft': ?_captureCoachApplicationDraft(),
    'coachClientNotes': ?_captureCoachClientNotes(),
    'barKg': ?_captureBarKg(),
    'guest': ?_captureGuest(),
  };

  /// Reads [raw] and puts it back into the stores.
  ///
  /// Returns the number of sections restored — zero for a missing, empty,
  /// corrupt or foreign document, in which case nothing at all was touched and
  /// the app opens on the state it boots in. **This never throws.**
  static int restore(String? raw) {
    final apply = decode(raw);
    for (final section in apply) {
      section();
    }
    return apply.length;
  }

  /// Decodes [raw] into a list of assignments, without touching any store.
  ///
  /// Split out from [restore] so that "it decoded" and "it was applied" are two
  /// separate facts. Everything that can throw happens here, before anything is
  /// changed, which is what makes a half-restored store unreachable.
  static List<void Function()> decode(String? raw) {
    if (raw == null || raw.isEmpty) return const <void Function()>[];

    Object? parsed;
    try {
      parsed = jsonDecode(raw);
    } catch (_) {
      // Truncated by a kill mid-write, or not JSON at all.
      return const <void Function()>[];
    }
    if (parsed is! Map<String, Object?>) return const <void Function()>[];
    if (!kReadableSchemas.contains(_int(parsed['schema']))) {
      return const <void Function()>[];
    }

    final out = <void Function()>[];
    for (final reader in _readers.entries) {
      final section = parsed[reader.key];
      if (section == null) continue;
      try {
        final apply = reader.value(section);
        if (apply != null) out.add(apply);
      } catch (_) {
        // One section is one section. The rest of her week still comes back.
      }
    }
    return out;
  }

  /// Section name to its decoder. A name that is not in here is ignored, which
  /// is how a document from a newer build degrades instead of failing.
  static final Map<String, void Function()? Function(Object?)> _readers = {
    'today': _readToday,
    'progress': _readProgress,
    'train': _readTrain,
    'meals': _readMeals,
    'eat': _readEat,
    'cycle': _readCycle,
    'privacy': _readPrivacy,
    'dietary': _readDietary,
    'intake': _readIntake,
    'language': _readLanguage,
    'pledge': _readPledge,
    'reminders': _readReminders,
    'firstGymGuide': _readFirstGymGuide,
    'roles': _readRoles,
    'coach': _readCoach,
    'invite': _readInvite,
    'awards': _readAwards,
    'trainingStreak': _readTrainingStreak,
    'chosenProgramme': _readChosenProgramme,
    'followUps': _readFollowUps,
    'notificationVoice': _readNotificationVoice,
    'customWorkouts': _readCustomWorkouts,
    'myPlan': _readMyPlan,
    'restTimer': _readRestTimer,
    'moveNotes': _readMoveNotes,
    'coachApplicationDraft': _readCoachApplicationDraft,
    'coachClientNotes': _readCoachClientNotes,
    'barKg': _readBarKg,
    'guest': _readGuest,
    // After `train`: it points at a session that section restores.
    'liveSession': _readLiveSession,
  };
}

// ------------------------------------------------------------------ today ---

Map<String, Object?> _captureToday() {
  final repository = AppRouter.todayRepository;
  final day = repository.day;
  return <String, Object?>{
    'date': day.date.toIso8601String(),
    'state': day.state.name,
    'arc': <String, Object?>{
      'hasAnyLog': day.arc.hasAnyLog,
      'completed': [for (final step in day.arc.completed) step.name],
    },
    'week': <String, Object?>{
      'logged': day.week.sessionsLogged,
      'target': day.week.sessionsTarget,
      'repaired': day.week.repairedByRestWeek,
    },
    'walkToCount': day.walkToCount,
    'walkMinutes': day.walkMinutes,
    'mealLoggedAt': day.mealLoggedAt?.toIso8601String(),
    'showCycleCard': day.showCycleCard,
    'plates': [
      for (final plate in day.plates)
        <String, Object?>{'foodId': plate.foodId, 'kcal': plate.kcal},
    ],
    'programWeek': day.programWeek,
    'programTotalWeeks': day.programTotalWeeks,
    'seenNotices': repository.seenNotices.toList(),
    'creditedSessions': repository.creditedSessions.toList(),
  };
}

void Function()? _readToday(Object? raw) {
  final section = _map(raw);
  if (section == null) return null;

  final date = _time(section['date']);
  if (date == null) return null;

  final arc = _map(section['arc']) ?? const <String, Object?>{};
  final week = _map(section['week']) ?? const <String, Object?>{};
  final fallback = InMemoryTodayRepository.defaultDay();

  final day = TodayDay(
    date: date,
    state: _pick(DayState.values, section['state']) ?? DayState.nothingDone,
    arc: FirstWeekArc(
      hasAnyLog: _bool(arc['hasAnyLog']) ?? false,
      completed: {
        for (final name in _list(arc['completed']) ?? const <Object?>[])
          ?_pick(FirstWeekStep.values, name),
      },
    ),
    week: WeekProgress(
      sessionsLogged: _int(week['logged']) ?? 0,
      sessionsTarget: _int(week['target']) ?? fallback.week.sessionsTarget,
      repairedByRestWeek: _bool(week['repaired']) ?? false,
    ),
    walkToCount: _bool(section['walkToCount']) ?? false,
    walkMinutes: _int(section['walkMinutes']),
    mealLoggedAt: _time(section['mealLoggedAt']),
    showCycleCard: _bool(section['showCycleCard']) ?? false,
    plates: [
      for (final entry in _list(section['plates']) ?? const <Object?>[])
        if (_map(entry) case final plate?)
          if (_str(plate['foodId']) case final foodId?)
            PlateSuggestion(foodId: foodId, kcal: _int(plate['kcal']) ?? 0),
    ],
    programWeek: _int(section['programWeek']),
    programTotalWeeks: _int(section['programTotalWeeks']),
  );

  final seen = _strings(section['seenNotices']);
  final credited = _strings(section['creditedSessions']);

  return () => AppRouter.todayRepository.restore(
    day: day,
    seenNotices: seen,
    creditedSessions: credited,
  );
}

// --------------------------------------------------------------- progress ---

Map<String, Object?> _captureProgress() {
  final store = AppRouter.progressStore;
  final ledger = AppRouter.personalBestLedger;
  return <String, Object?>{
    'weeks': <String, Object?>{
      for (final entry in store.weeks.entries) entry.key: _weekDoc(entry.value),
    },
    'goal': _weeklyGoal(store.goal),
    'bests': <String, Object?>{
      for (final entry in store.bests.entries) entry.key: _best(entry.value),
    },
    'rewards': _rewards(store.rewards),
    'measurements': <String, Object?>{
      for (final entry in store.measurements.entries)
        entry.key: _measurement(entry.value),
    },
    'ledger': <String, Object?>{
      'countedIds': ledger.countedIds.toList(),
      'bestsCount': ledger.bestsCount,
    },
  };
}

void Function()? _readProgress(Object? raw) {
  final section = _map(raw);
  if (section == null) return null;

  final weeks = <String, WeekDoc>{};
  for (final entry in (_map(section['weeks']) ?? const {}).entries) {
    final week = _readWeekDoc(entry.key, entry.value);
    if (week != null) weeks[entry.key] = week;
  }

  final bests = <String, PersonalBest>{};
  for (final entry in (_map(section['bests']) ?? const {}).entries) {
    final best = _readBest(entry.value);
    if (best != null) bests[entry.key] = best;
  }

  final measurements = <String, Measurement>{};
  for (final entry in (_map(section['measurements']) ?? const {}).entries) {
    // The store refuses anything that is not a date key, and so does the
    // backend. A snapshot carrying one is a snapshot to skip, not to throw on.
    if (!_isDayId(entry.key)) continue;
    final measurement = _readMeasurement(entry.key, entry.value);
    if (measurement != null) measurements[entry.key] = measurement;
  }

  final goal = _readWeeklyGoal(section['goal']);
  final rewards = _readRewards(section['rewards']);
  final ledger = _map(section['ledger']) ?? const <String, Object?>{};
  final countedIds = _strings(ledger['countedIds']);
  final bestsCount = _int(ledger['bestsCount']) ?? 0;

  return () {
    final store = AppRouter.progressStore;
    // Cleared in place, never replaced: `personalBestLedger.bests` is this very
    // map by reference, and handing either side a fresh one is how a screen and
    // the ledger end up holding two different ideas of her best.
    store.weeks
      ..clear()
      ..addAll(weeks);
    store.bests
      ..clear()
      ..addAll(bests);
    store.measurements
      ..clear()
      ..addAll(measurements);
    if (goal != null) store.goal = goal;
    if (rewards != null) store.rewards = rewards;
    AppRouter.personalBestLedger.restore(
      countedIds: countedIds,
      bestsCount: bestsCount,
    );
  };
}

Map<String, Object?> _weekDoc(WeekDoc week) => <String, Object?>{
  'target': week.sessionsTarget,
  'counted': week.counted,
  'repaired': week.repairedByRestWeek,
  'closedAt': week.closedAt?.toIso8601String(),
  'credited': week.creditedSessionIds,
  'foodDays': week.foodDaysLogged,
  'goalKind': week.goalKind.name,
};

WeekDoc? _readWeekDoc(String id, Object? raw) {
  final week = WeekKey.tryParse(id);
  final row = _map(raw);
  if (week == null || row == null) return null;
  return WeekDoc(
    week: week,
    sessionsTarget: _int(row['target']) ?? 3,
    counted: _bool(row['counted']) ?? false,
    repairedByRestWeek: _bool(row['repaired']) ?? false,
    closedAt: _time(row['closedAt']),
    creditedSessionIds: _strings(row['credited']),
    foodDaysLogged: _int(row['foodDays']) ?? 0,
    goalKind:
        _pick(WeekGoalKind.values, row['goalKind']) ?? WeekGoalKind.sessions,
  );
}

Map<String, Object?> _weekBar(WeekBar bar) => <String, Object?>{
  'week': bar.week.id,
  'logged': bar.sessionsLogged,
  'target': bar.sessionsTarget,
  'counted': bar.counted,
  'repaired': bar.repairedByRestWeek,
};

WeekBar? _readWeekBar(Object? raw) {
  final row = _map(raw);
  if (row == null) return null;
  final week = WeekKey.tryParse(_str(row['week']) ?? '');
  if (week == null) return null;
  return WeekBar(
    week: week,
    sessionsLogged: _int(row['logged']) ?? 0,
    sessionsTarget: _int(row['target']) ?? 0,
    counted: _bool(row['counted']) ?? false,
    repairedByRestWeek: _bool(row['repaired']) ?? false,
  );
}

Map<String, Object?> _weeklyGoal(WeeklyGoal goal) => <String, Object?>{
  'sessionsTarget': goal.sessionsTarget,
  'countedWeeks': goal.countedWeeks,
  'restWeeksBanked': goal.restWeeksBanked,
  'restWeekProgress': goal.restWeekProgress,
  'currentRun': goal.currentRun,
  'bestRun': goal.bestRun,
  'recent8': [for (final bar in goal.recent8) _weekBar(bar)],
  'lastClosedWeek': goal.lastClosedWeek?.id,
  'lastRepairedWeek': goal.lastRepairedWeek?.id,
  'tierSlippedWeek': goal.tierSlippedWeek?.id,
  'goalKind': goal.goalKind.name,
  'tz': goal.tz,
};

WeeklyGoal? _readWeeklyGoal(Object? raw) {
  final row = _map(raw);
  if (row == null) return null;
  // The constructor, deliberately, and never `copyWith`: copyWith takes the
  // larger of the two counts so that nothing earned is walked back, which is
  // right for a live update and wrong for reading a document off the phone.
  return WeeklyGoal(
    sessionsTarget: _int(row['sessionsTarget']) ?? 3,
    countedWeeks: _int(row['countedWeeks']) ?? 0,
    restWeeksBanked: (_int(row['restWeeksBanked']) ?? 0).clamp(
      0,
      kRestWeekBankCap,
    ),
    restWeekProgress: _int(row['restWeekProgress']) ?? 0,
    currentRun: _int(row['currentRun']) ?? 0,
    bestRun: _int(row['bestRun']) ?? 0,
    recent8: [
      for (final entry in _list(row['recent8']) ?? const <Object?>[])
        ?_readWeekBar(entry),
    ].take(kRecentWeekWindow).toList(),
    lastClosedWeek: WeekKey.tryParse(_str(row['lastClosedWeek']) ?? ''),
    lastRepairedWeek: WeekKey.tryParse(_str(row['lastRepairedWeek']) ?? ''),
    tierSlippedWeek: WeekKey.tryParse(_str(row['tierSlippedWeek']) ?? ''),
    goalKind:
        _pick(WeekGoalKind.values, row['goalKind']) ?? WeekGoalKind.sessions,
    tz: _str(row['tz']) ?? WeekKey.fallbackTimezone,
  );
}

Map<String, Object?> _rewards(Rewards rewards) => <String, Object?>{
  'points': rewards.points,
  'level': rewards.level,
  'pointsToNextLevel': rewards.pointsToNextLevel,
  'sessionsLogged': rewards.sessionsLogged,
  'bestsCount': rewards.bestsCount,
  'milestones': <String, Object?>{
    for (final entry in rewards.milestones.entries)
      entry.key: entry.value.toIso8601String(),
  },
};

Rewards? _readRewards(Object? raw) {
  final row = _map(raw);
  if (row == null) return null;
  return Rewards(
    points: _int(row['points']) ?? 0,
    level: _int(row['level']) ?? 1,
    pointsToNextLevel: _int(row['pointsToNextLevel']) ?? 0,
    sessionsLogged: _int(row['sessionsLogged']) ?? 0,
    bestsCount: _int(row['bestsCount']) ?? 0,
    milestones: <String, DateTime>{
      for (final entry in (_map(row['milestones']) ?? const {}).entries)
        entry.key: ?_time(entry.value),
    },
  );
}

Map<String, Object?> _best(PersonalBest best) => <String, Object?>{
  'exerciseId': best.exerciseId,
  'metric': best.metric.name,
  'dateKey': best.dateKey,
  'sessionId': best.sessionId,
  'loadKg': best.loadKg,
  'reps': best.reps,
  'holdSec': best.holdSec,
  'rank': best.rank,
  if (best.previous case final previous?)
    'previous': <String, Object?>{
      'loadKg': previous.loadKg,
      'reps': previous.reps,
      'holdSec': previous.holdSec,
      'rank': previous.rank,
      'dateKey': previous.dateKey,
    },
};

PersonalBest? _readBest(Object? raw) {
  final row = _map(raw);
  if (row == null) return null;
  final exerciseId = _str(row['exerciseId']);
  final metric = _pick(BestMetric.values, row['metric']);
  final dateKey = _str(row['dateKey']);
  final sessionId = _str(row['sessionId']);
  if (exerciseId == null ||
      metric == null ||
      dateKey == null ||
      sessionId == null) {
    return null;
  }
  final previous = _map(row['previous']);
  return PersonalBest(
    exerciseId: exerciseId,
    metric: metric,
    dateKey: dateKey,
    sessionId: sessionId,
    loadKg: _num(row['loadKg']),
    reps: _int(row['reps']),
    holdSec: _int(row['holdSec']),
    rank: _int(row['rank']),
    previous: previous == null
        ? null
        : PreviousBest(
            loadKg: _num(previous['loadKg']),
            reps: _int(previous['reps']),
            holdSec: _int(previous['holdSec']),
            rank: _int(previous['rank']),
            dateKey: _str(previous['dateKey']),
          ),
  );
}

Map<String, Object?> _measurement(Measurement m) => <String, Object?>{
  'takenAt': m.takenAt.toIso8601String(),
  'weightKg': m.weightKg,
  'waistCm': m.waistCm,
  'hipsCm': m.hipsCm,
  'armCm': m.armCm,
  'thighCm': m.thighCm,
  'note': m.note,
};

Measurement? _readMeasurement(String dayId, Object? raw) {
  final row = _map(raw);
  final takenAt = row == null ? null : _time(row['takenAt']);
  if (row == null || takenAt == null) return null;
  // The store's own bound: a figure that is not positive is a corrupt write,
  // and the one screen she is most sensitive about must not render one.
  num? positive(Object? value) {
    final figure = _num(value);
    return figure != null && figure > 0 ? figure : null;
  }

  return Measurement(
    dayId: dayId,
    takenAt: takenAt,
    weightKg: positive(row['weightKg']),
    waistCm: positive(row['waistCm']),
    hipsCm: positive(row['hipsCm']),
    armCm: positive(row['armCm']),
    thighCm: positive(row['thighCm']),
    note: _str(row['note']),
  );
}

// ------------------------------------------------------------------ train ---
//
// ## The sets were written twice, and now they are written once
//
// [InMemoryTrainRepository] keeps a session's sets twice on purpose, and that
// is right in memory: `sessions[].sets` are the PRESCRIPTIONS the session was
// born with, and `flushes[].sets` are what reached the server — the same
// prescriptions, each carrying the outcome she agreed to. `set_history.dart`
// depends on the separation.
//
// Persisting both verbatim meant every prescription went to the phone twice.
// Measured on the shape the app really writes (`test/qa/round6`), two years of
// training — 400 sessions of 5 moves and 3 sets — came to 1.76 MB, of which
// 1.10 MB was `flushes` and 0.66 MB was `sessions`, and `jsonEncode` of that
// document ran on the main isolate on every debounced write while she logged.
//
// So a flush set now names its prescription instead of repeating it: it writes
// the `order`, and the reader finds the prescription under the session it
// belongs to. Nothing of hers is dropped — the outcome, which is the half only
// the flush holds, is still written in full, and a prescription that is NOT in
// the session (a swapped move, a flush under a session id this phone no longer
// holds) still carries its own copy, so the short form can never lose one.
//
// Null fields are left out of both halves for the same reason: `"holdSeconds":
// null` is twenty bytes saying nothing, three times per set, and every reader
// below already answers null for a key that is absent.

/// Identifies a prescription within one session: an exercise and a set number.
///
/// Flat rather than nested so it can be a map key. `\u0000` cannot occur in an
/// exercise id, so no two different pairs can collide on it.
String _prescriptionKey(String exerciseId, int order) =>
    '$exerciseId\u0000$order';

/// The prescriptions a flush may name instead of repeating, per session id.
///
/// A key that appears twice in one session maps to null — "ambiguous, write it
/// out". That cannot happen with a session built by `startSession`, where the
/// order is the set's position in its move, but a document is read back from a
/// phone and this index decides what a later read trusts, so it is built to be
/// right rather than built on that.
Map<String, Map<String, PrescribedSet?>> _prescriptionIndex(
  Iterable<TrainSession> sessions,
) {
  final index = <String, Map<String, PrescribedSet?>>{};
  for (final session in sessions) {
    final byKey = <String, PrescribedSet?>{};
    for (final set in session.sets) {
      final key = _prescriptionKey(
        set.prescribed.exerciseId,
        set.prescribed.order,
      );
      byKey[key] = byKey.containsKey(key) ? null : set.prescribed;
    }
    index[session.id] = byKey;
  }
  return index;
}

/// True when [prescribed] is exactly the prescription the session already
/// carries for this exercise and set number, so writing the number is the same
/// as writing the prescription.
///
/// Every field is compared. Two sets can share an exercise and an order and
/// still differ — a plan republished between the session and the flush — and
/// restoring the session's copy over hers would quietly rewrite what she was
/// asked for.
bool _isSessionsOwn(
  Map<String, Map<String, PrescribedSet?>> index,
  String sessionId,
  String flushExerciseId,
  PrescribedSet prescribed,
) {
  if (prescribed.exerciseId != flushExerciseId) return false;
  final candidate =
      index[sessionId]?[_prescriptionKey(
        prescribed.exerciseId,
        prescribed.order,
      )];
  return candidate != null &&
      candidate.weightKg == prescribed.weightKg &&
      candidate.reps == prescribed.reps &&
      candidate.holdSeconds == prescribed.holdSeconds;
}

Map<String, Object?> _captureTrain() {
  final repository = AppRouter.trainRepository;
  final sessions = repository.sessions;
  final index = _prescriptionIndex(sessions);
  return <String, Object?>{
    'sessions': [for (final s in sessions) _session(s)],
    'flushes': [
      for (final flush in repository.flushes)
        <String, Object?>{
          'sessionId': flush.sessionId,
          'exerciseId': flush.exerciseId,
          'sets': [
            for (final set in flush.sets)
              if (_isSessionsOwn(
                index,
                flush.sessionId,
                flush.exerciseId,
                set.prescribed,
              ))
                <String, Object?>{
                  'order': set.prescribed.order,
                  if (set.outcome case final outcome?)
                    'outcome': _outcome(outcome),
                }
              else
                _loggedSet(set),
          ],
        },
    ],
    'swaps': [
      for (final swap in repository.swaps)
        <String, Object?>{'from': swap.from, 'to': swap.to},
    ],
    'counter': repository.sessionCounter,
    // The sessions she removed, so neither a restart nor a merge with the
    // cloud brings one back.
    if (repository.removedSessions.isNotEmpty)
      'removed': [
        for (final removed in repository.removedSessions)
          <String, Object?>{
            'id': removed.id,
            'source': removed.source.name,
            'dateKey': removed.dateKey,
          },
      ],
  };
}

void Function()? _readTrain(Object? raw) {
  final section = _map(raw);
  if (section == null) return null;

  final sessions = <TrainSession>[
    for (final entry in _list(section['sessions']) ?? const <Object?>[])
      ?_readSession(entry),
  ];

  // Built from the sessions this document carries, never from the repository:
  // decoding touches no store, and a flush must be resolved against the
  // session it was written beside rather than against whatever is in memory.
  final index = _prescriptionIndex(sessions);

  final flushes =
      <({String sessionId, String exerciseId, List<LoggedSet> sets})>[
        for (final entry in _list(section['flushes']) ?? const <Object?>[])
          if (_map(entry) case final row?)
            if (_str(row['sessionId']) case final sessionId?)
              if (_str(row['exerciseId']) case final exerciseId?)
                (
                  sessionId: sessionId,
                  exerciseId: exerciseId,
                  sets: _readFlushSets(
                    row['sets'],
                    index: index,
                    sessionId: sessionId,
                    exerciseId: exerciseId,
                  ),
                ),
      ];

  final swaps = <({String from, String to})>[
    for (final entry in _list(section['swaps']) ?? const <Object?>[])
      if (_map(entry) case final row?)
        if (_str(row['from']) case final from?)
          if (_str(row['to']) case final to?) (from: from, to: to),
  ];

  final counter = _int(section['counter']) ?? sessions.length;

  final removed = <RemovedSession>[
    for (final entry in _list(section['removed']) ?? const <Object?>[])
      if (_map(entry) case final row?)
        if (_str(row['id']) case final id?)
          if (_pick(SessionSource.values, row['source']) case final source?)
            RemovedSession(
              id: id,
              source: source,
              dateKey: _str(row['dateKey']) ?? '',
            ),
  ];

  return () {
    AppRouter.trainRepository.restore(
      sessions: sessions,
      flushes: flushes,
      swaps: swaps,
      // The live session is carried by its own section, `liveSession`. The
      // counter is carried here, so the next session gets an id no old one
      // holds.
      sessionCounter: counter,
    );
    AppRouter.trainRepository.restoreRemoved(removed);
  };
}

Map<String, Object?>? _captureLiveSession() {
  final state = WorkoutSessionState.instance;
  final day = state.day;
  final session = state.session;
  if (!state.isLive || day == null || session == null) return null;
  return <String, Object?>{
    'sessionId': session.id,
    'day': <String, Object?>{
      'id': day.id,
      'title': day.title,
      'summary': day.summary,
      'constraints': day.constraints,
      'planVersion': ?day.planVersion,
      'moves': [for (final move in day.moves) _plannedMove(move)],
    },
    'moveIndex': state.moveIndex,
    'setIndex': state.setIndex,
    'loggedSets': state.loggedSetCount,
    if (state.startedAt case final at?) 'startedAt': at.toIso8601String(),
    'swaps': [
      for (final entry in state.swappedMoves.entries)
        <String, Object?>{'for': entry.key, 'move': _plannedMove(entry.value)},
    ],
  };
}

Map<String, Object?> _plannedMove(PlannedMove move) => <String, Object?>{
  'exerciseId': move.exerciseId,
  'name': move.name,
  'prescriptionLabel': move.prescriptionLabel,
  'sets': [for (final set in move.sets) _prescription(set)],
  if (move.cues.isNotEmpty) 'cues': move.cues,
  if (move.quiet) 'quiet': true,
  if (move.needsEquipment) 'needsEquipment': true,
  if (move.floorOnly) 'floorOnly': true,
  'videoAssetId': ?move.videoAssetId,
  'restSeconds': ?move.restSeconds,
};

PlannedMove? _readPlannedMove(Object? raw) {
  final row = _map(raw);
  if (row == null) return null;
  final exerciseId = _str(row['exerciseId']);
  final name = _str(row['name']);
  if (exerciseId == null || name == null) return null;
  return PlannedMove(
    exerciseId: exerciseId,
    name: name,
    prescriptionLabel: _str(row['prescriptionLabel']) ?? '',
    sets: [
      for (final entry in _list(row['sets']) ?? const <Object?>[])
        ?_readPrescription(entry),
    ],
    cues: [
      for (final cue in _list(row['cues']) ?? const <Object?>[])
        if (cue is String) cue,
    ],
    quiet: _bool(row['quiet']) ?? false,
    needsEquipment: _bool(row['needsEquipment']) ?? false,
    floorOnly: _bool(row['floorOnly']) ?? false,
    videoAssetId: _str(row['videoAssetId']),
    restSeconds: _int(row['restSeconds']),
  );
}

void Function()? _readLiveSession(Object? raw) {
  final section = _map(raw);
  final dayRow = section == null ? null : _map(section['day']);
  final sessionId = section == null ? null : _str(section['sessionId']);
  if (section == null || dayRow == null || sessionId == null) return null;
  final id = _str(dayRow['id']);
  if (id == null) return null;
  final moves = <PlannedMove>[
    for (final entry in _list(dayRow['moves']) ?? const <Object?>[])
      ?_readPlannedMove(entry),
  ];
  if (moves.isEmpty) return null;
  final day = WorkoutDay(
    id: id,
    title: _str(dayRow['title']) ?? '',
    summary: _str(dayRow['summary']) ?? '',
    constraints: _str(dayRow['constraints']) ?? '',
    planVersion: _str(dayRow['planVersion']),
    moves: moves,
  );
  final swaps = <String, PlannedMove>{};
  for (final entry in _list(section['swaps']) ?? const <Object?>[]) {
    final row = _map(entry);
    final replaced = row == null ? null : _str(row['for']);
    final move = row == null ? null : _readPlannedMove(row['move']);
    if (replaced != null && move != null) swaps[replaced] = move;
  }
  final moveIndex = _int(section['moveIndex']) ?? 0;
  final setIndex = _int(section['setIndex']) ?? 0;
  final loggedSets = _int(section['loggedSets']) ?? 0;
  final startedAt = DateTime.tryParse(_str(section['startedAt']) ?? '');

  return () {
    // The session was restored by `train`, which runs first. Without it there
    // is nothing for her next log to belong to, so she starts fresh.
    final session = AppRouter.trainRepository.sessionById(sessionId);
    if (session == null) return;
    AppRouter.trainRepository.resumeLive(sessionId);
    WorkoutSessionState.instance.restoreLive(
      day: day,
      session: session,
      moveIndex: moveIndex,
      setIndex: setIndex,
      loggedSets: loggedSets,
      startedAt: startedAt,
      swaps: swaps,
    );
  };
}

Map<String, Object?> _session(TrainSession session) => <String, Object?>{
  'id': session.id,
  'source': session.source.name,
  'dateKey': session.dateKey,
  'sets': [for (final set in session.sets) _loggedSet(set)],
  // Absent rather than null. Every reader below answers null for a missing key,
  // and a recalled walk carries six of these empty.
  'assignmentId': ?session.assignmentId,
  'planVersion': ?session.planVersion,
  'workoutId': ?session.workoutId,
  'activity': ?session.activity,
  if (session.recallMethod case final value?) 'recallMethod': value.name,
  if (session.endedReason case final value?) 'endedReason': value.name,
  if (session.durationSec != 0) 'durationSec': session.durationSec,
  if (session.completed) 'completed': true,
};

TrainSession? _readSession(Object? raw) {
  final row = _map(raw);
  if (row == null) return null;
  final id = _str(row['id']);
  final source = _pick(SessionSource.values, row['source']);
  if (id == null || source == null) return null;
  return TrainSession(
    id: id,
    source: source,
    dateKey: _str(row['dateKey']) ?? '',
    sets: _readLoggedSets(row['sets']),
    assignmentId: _str(row['assignmentId']),
    planVersion: _str(row['planVersion']),
    workoutId: _str(row['workoutId']),
    activity: _str(row['activity']),
    recallMethod: _pick(RecallMethod.values, row['recallMethod']),
    endedReason: _pick(EndedReason.values, row['endedReason']),
    durationSec: _int(row['durationSec']) ?? 0,
    completed: _bool(row['completed']) ?? false,
  );
}

Map<String, Object?> _prescription(PrescribedSet prescribed) =>
    <String, Object?>{
      'exerciseId': prescribed.exerciseId,
      'order': prescribed.order,
      'weightKg': ?prescribed.weightKg,
      'reps': ?prescribed.reps,
      'holdSeconds': ?prescribed.holdSeconds,
    };

Map<String, Object?> _outcome(SetOutcome outcome) => <String, Object?>{
  'weightKg': ?outcome.weightKg,
  'reps': ?outcome.reps,
  'holdSeconds': ?outcome.holdSeconds,
  // Only ever written when it is true. A skipped set is a decision of hers and
  // has to survive; `skipped: false` is the default and says nothing.
  if (outcome.skipped) 'skipped': true,
};

Map<String, Object?> _loggedSet(LoggedSet set) => <String, Object?>{
  'prescribed': _prescription(set.prescribed),
  if (set.outcome case final outcome?) 'outcome': _outcome(outcome),
};

SetOutcome? _readOutcome(Object? raw) {
  final row = _map(raw);
  if (row == null) return null;
  return SetOutcome(
    weightKg: _double(row['weightKg']),
    reps: _int(row['reps']),
    holdSeconds: _int(row['holdSeconds']),
    skipped: _bool(row['skipped']) ?? false,
  );
}

PrescribedSet? _readPrescription(Object? raw) {
  final row = _map(raw);
  if (row == null) return null;
  final exerciseId = _str(row['exerciseId']);
  if (exerciseId == null) return null;
  return PrescribedSet(
    exerciseId: exerciseId,
    order: _int(row['order']) ?? 1,
    weightKg: _double(row['weightKg']),
    reps: _int(row['reps']),
    holdSeconds: _int(row['holdSeconds']),
  );
}

List<LoggedSet> _readLoggedSets(Object? raw) => <LoggedSet>[
  for (final entry in _list(raw) ?? const <Object?>[])
    if (_map(entry) case final row?)
      if (_readPrescription(row['prescribed']) case final prescribed?)
        LoggedSet(
          prescribed: prescribed,
          outcome: _readOutcome(row['outcome']),
        ),
];

/// The prescription one flush set is recorded against, in either of the two
/// forms a document can carry it.
///
/// `prescribed` present is the long form: a prescription this document holds
/// nowhere else, written out. Otherwise `order` names one of the session's own
/// prescriptions, which is the form every flush of a live session takes and
/// the reason the document halved. Null is a row that is neither, dropped the
/// way every other corrupt row in this file is.
PrescribedSet? _flushPrescription(
  Map<String, Object?> row, {
  required Map<String, Map<String, PrescribedSet?>> index,
  required String sessionId,
  required String exerciseId,
}) {
  final written = _readPrescription(row['prescribed']);
  if (written != null) return written;
  final order = _int(row['order']);
  if (order == null) return null;
  // The prescription the short form points at, when the session it belongs to
  // came back whole.
  final named = index[sessionId]?[_prescriptionKey(exerciseId, order)];
  if (named != null) return named;
  // It did not. The `sessions` row was truncated, corrupt, or written by a
  // build that shaped a session differently — and dropping this set would throw
  // away the OUTCOME, which is the half nothing else on the phone holds. So the
  // set is kept with the only prescription this row can honestly support: the
  // exercise and the set number, and no numbers she was asked for, because this
  // document no longer says what they were. A null weight reads as bodyweight
  // everywhere it is rendered, and nothing renders a flush's prescription:
  // `set_history.dart` reads the outcome, and `cloud_documents.dart` uploads
  // sessions rather than flushes.
  return PrescribedSet(exerciseId: exerciseId, order: order);
}

List<LoggedSet> _readFlushSets(
  Object? raw, {
  required Map<String, Map<String, PrescribedSet?>> index,
  required String sessionId,
  required String exerciseId,
}) => <LoggedSet>[
  for (final entry in _list(raw) ?? const <Object?>[])
    if (_map(entry) case final row?)
      if (_flushPrescription(
            row,
            index: index,
            sessionId: sessionId,
            exerciseId: exerciseId,
          )
          case final prescribed?)
        LoggedSet(
          prescribed: prescribed,
          outcome: _readOutcome(row['outcome']),
        ),
];

// ------------------------------------------------------------------ meals ---

Map<String, Object?> _captureMeals() {
  final store = AppRouter.mealRepository.store;
  return <String, Object?>{
    'days': <String, Object?>{
      for (final entry in store.days.entries) entry.key: _mealDay(entry.value),
    },
    'plans': <String, Object?>{
      for (final entry in store.plans.entries)
        entry.key: _mealPlan(entry.value),
    },
    'prefs': _eatPrefs(store.prefs),
  };
}

void Function()? _readMeals(Object? raw) {
  final section = _map(raw);
  if (section == null) return null;

  final days = <String, MealDay>{};
  for (final entry in (_map(section['days']) ?? const {}).entries) {
    if (!_isDayId(entry.key)) continue;
    final day = _readMealDay(entry.key, entry.value);
    if (day != null) days[entry.key] = day;
  }

  final plans = <String, MealPlan>{};
  for (final entry in (_map(section['plans']) ?? const {}).entries) {
    final plan = _readMealPlan(entry.key, entry.value);
    if (plan != null) plans[entry.key] = plan;
  }

  final prefs = _readEatPrefs(section['prefs']);

  return () {
    final store = AppRouter.mealRepository.store;
    store.days
      ..clear()
      ..addAll(days);
    // Plans are merged rather than replaced. The repository is seeded with a
    // sample plan for the current week, and a snapshot written last week does
    // not carry this one — clearing first would leave E07 and E08 with nothing
    // to draw the moment a week ticks over.
    store.plans.addAll(plans);
    if (prefs != null) {
      store.prefs = prefs;
      EatAppState.instance.syncCustomFoods();
    }
  };
}

Map<String, Object?> _mealDay(MealDay day) => <String, Object?>{
  'slots': <String, Object?>{
    for (final slot in MealSlot.values)
      if (day.slots[slot] case final items?)
        slot.name: [for (final item in items) _mealItem(item)],
  },
  'firstLogAt': day.firstLogAt?.toIso8601String(),
  'tz': day.tz,
  'libVersion': day.libVersion,
  'skipped': [for (final slot in day.skipped) slot.name],
};

MealDay? _readMealDay(String dayId, Object? raw) {
  final row = _map(raw);
  if (row == null) return null;
  final slots = <MealSlot, List<MealItem>>{};
  for (final entry in (_map(row['slots']) ?? const {}).entries) {
    final slot = _pick(MealSlot.values, entry.key);
    if (slot == null) continue;
    final items = <MealItem>[
      for (final raw in _list(entry.value) ?? const <Object?>[])
        ?_readMealItem(raw),
    ];
    // The cap the security rules assert. A document over it is a corrupt one.
    slots[slot] = items.length <= kSlotItemCap
        ? items
        : items.sublist(0, kSlotItemCap);
  }
  return MealDay(
    dayId: dayId,
    slots: slots,
    firstLogAt: _time(row['firstLogAt']),
    tz: _str(row['tz']) ?? '',
    libVersion: _int(row['libVersion']) ?? 0,
    skipped: {
      for (final name in _list(row['skipped']) ?? const <Object?>[])
        ?_pick(MealSlot.values, name),
    },
  );
}

Map<String, Object?> _mealItem(MealItem item) => <String, Object?>{
  'itemId': item.itemId,
  'foodId': item.foodId,
  'servings': item.servings,
  'size': item.size,
  'loggedAt': item.loggedAt.toIso8601String(),
  'source': item.source.name,
  'origin': item.origin.name,
  'kcal': item.kcal,
  'proteinG': item.proteinG,
  // Carbs, fat and fibre, her name for a food the pack does not hold, and
  // the weight she approved: each only when it is known, so a meal logged
  // before they existed reads back exactly as it was written.
  'carbsG': ?item.carbsG,
  'fatG': ?item.fatG,
  'fiberG': ?item.fiberG,
  'name': ?item.name,
  'grams': ?item.grams,
  if (item.planRef case final ref?)
    'planRef': <String, Object?>{
      'assignmentId': ref.assignmentId,
      'slot': ref.slot.name,
      'idx': ref.idx,
    },
  'helpingOf': item.helpingOf,
  'allergenOverride': item.allergenOverride,
};

MealItem? _readMealItem(Object? raw) {
  final row = _map(raw);
  if (row == null) return null;
  final itemId = _str(row['itemId']);
  final foodId = _str(row['foodId']);
  final loggedAt = _time(row['loggedAt']);
  if (itemId == null || foodId == null || loggedAt == null) return null;
  final ref = _map(row['planRef']);
  return MealItem(
    itemId: itemId,
    foodId: foodId,
    servings: _num(row['servings']) ?? 1,
    size: _str(row['size']) ?? '',
    loggedAt: loggedAt,
    source: _pick(MealSource.values, row['source']) ?? MealSource.search,
    origin: _pick(MealOrigin.values, row['origin']) ?? MealOrigin.search,
    kcal: _int(row['kcal']) ?? 0,
    proteinG: _int(row['proteinG']) ?? 0,
    carbsG: _macro(row['carbsG']),
    fatG: _macro(row['fatG']),
    fiberG: _macro(row['fiberG']),
    name: _mealName(row['name']),
    grams: _weight(row['grams']),
    planRef: switch (ref) {
      null => null,
      final ref => switch ((
        _str(ref['assignmentId']),
        _pick(MealSlot.values, ref['slot']),
      )) {
        (final String assignmentId, final MealSlot slot) => PlanRef(
          assignmentId: assignmentId,
          slot: slot,
          idx: _int(ref['idx']) ?? 0,
        ),
        _ => null,
      },
    },
    helpingOf: _str(row['helpingOf']),
    allergenOverride: _strings(row['allergenOverride']),
  );
}

Map<String, Object?> _mealPlan(MealPlan plan) => <String, Object?>{
  'dinners': <String, Object?>{
    for (final entry in plan.dinners.entries) entry.key.name: entry.value,
  },
  'groceries': <String, Object?>{
    for (final entry in plan.groceries.entries)
      entry.key: <String, Object?>{
        'ingredientId': entry.value.ingredientId,
        'group': entry.value.group.name,
        'ticked': entry.value.ticked,
        'tickedAt': entry.value.tickedAt?.toIso8601String(),
        'text': entry.value.text,
        'recipeId': entry.value.recipeId,
      },
  },
  'recipeVersion': plan.recipeVersion,
};

MealPlan? _readMealPlan(String weekId, Object? raw) {
  final row = _map(raw);
  if (row == null) return null;
  if (WeekKey.tryParse(weekId) == null) return null;
  final groceries = <String, GroceryLine>{};
  for (final entry in (_map(row['groceries']) ?? const {}).entries) {
    final line = _map(entry.value);
    final ingredientId = line == null ? null : _str(line['ingredientId']);
    if (line == null || ingredientId == null) continue;
    if (groceries.length >= kGroceryCap) break;
    groceries[entry.key] = GroceryLine(
      itemKey: entry.key,
      ingredientId: ingredientId,
      group: _pick(GroceryGroup.values, line['group']) ?? GroceryGroup.cupboard,
      ticked: _bool(line['ticked']) ?? false,
      tickedAt: _time(line['tickedAt']),
      text: _str(line['text']),
      recipeId: _str(line['recipeId']),
    );
  }
  return MealPlan(
    weekId: weekId,
    dinners: <PlanDay, String>{
      for (final entry in (_map(row['dinners']) ?? const {}).entries)
        ?_pick(PlanDay.values, entry.key): ?_str(entry.value),
    },
    groceries: groceries,
    recipeVersion: _int(row['recipeVersion']) ?? 0,
  );
}

Map<String, Object?> _eatPrefs(EatPrefs prefs) => <String, Object?>{
  'plates': <String, Object?>{
    for (final entry in prefs.plates.entries) entry.key: _plate(entry.value),
  },
  'ramadanMode': prefs.ramadanMode.name,
  'proteinTargetGOverride': prefs.proteinTargetGOverride,
  'libVersion': prefs.libVersion,
  'favourites': prefs.favourites,
  'customFoods': [for (final food in prefs.customFoods) food.toJson()],
};

EatPrefs? _readEatPrefs(Object? raw) {
  final row = _map(raw);
  if (row == null) return null;
  final plates = <String, Plate>{};
  for (final entry in (_map(row['plates']) ?? const {}).entries) {
    if (plates.length >= kPlateCap) break;
    final plate = _readPlate(entry.key, entry.value);
    if (plate != null) plates[entry.key] = plate;
  }
  return EatPrefs(
    plates: plates,
    ramadanMode:
        _pick(RamadanMode.values, row['ramadanMode']) ?? RamadanMode.auto,
    proteinTargetGOverride: _int(row['proteinTargetGOverride']),
    libVersion: _int(row['libVersion']) ?? 0,
    favourites: [
      for (final id in _strings(row['favourites']))
        if (id.isNotEmpty) id,
    ].take(kFavouriteCap).toList(),
    customFoods: [
      for (final raw
          in (row['customFoods'] is List
              ? row['customFoods'] as List
              : const []))
        ?CustomFood.fromJson(raw),
    ].take(kCustomFoodCap).toList(),
  );
}

Map<String, Object?> _plate(Plate plate) => <String, Object?>{
  'items': [for (final item in plate.items) _plateItem(item)],
  'lastAt': plate.lastAt.toIso8601String(),
  'dayCounts': plate.dayCounts,
  'slotCounts': <String, Object?>{
    for (final entry in plate.slotCounts.entries) entry.key.name: entry.value,
  },
  'dowCounts': <String, Object?>{
    for (final entry in plate.dowCounts.entries) '${entry.key}': entry.value,
  },
};

Plate? _readPlate(String plateId, Object? raw) {
  final row = _map(raw);
  final lastAt = row == null ? null : _time(row['lastAt']);
  if (row == null || lastAt == null) return null;
  return Plate(
    plateId: plateId,
    items: _readPlateItems(row['items']),
    lastAt: lastAt,
    dayCounts: <String, int>{
      for (final entry in (_map(row['dayCounts']) ?? const {}).entries)
        entry.key: ?_int(entry.value),
    },
    slotCounts: <MealSlot, int>{
      for (final entry in (_map(row['slotCounts']) ?? const {}).entries)
        ?_pick(MealSlot.values, entry.key): ?_int(entry.value),
    },
    dowCounts: <int, int>{
      for (final entry in (_map(row['dowCounts']) ?? const {}).entries)
        ?int.tryParse(entry.key): ?_int(entry.value),
    },
  );
}

Map<String, Object?> _plateItem(PlateItem item) => <String, Object?>{
  'foodId': item.foodId,
  'size': item.size,
  'servings': item.servings,
};

List<PlateItem> _readPlateItems(Object? raw) => <PlateItem>[
  for (final entry in _list(raw) ?? const <Object?>[])
    if (_map(entry) case final row?)
      if (_str(row['foodId']) case final foodId?)
        PlateItem(
          foodId: foodId,
          size: _str(row['size']) ?? '',
          servings: _num(row['servings']) ?? 1,
        ),
];

// -------------------------------------------------------------------- eat ---

Map<String, Object?> _captureEat() {
  final state = EatAppState.instance;
  return <String, Object?>{
    'plates': <String, Object?>{
      for (final entry in state.platesByIdentity.entries)
        entry.key: <String, Object?>{
          'items': [for (final item in entry.value.items) _plateItem(item)],
          'kcal': entry.value.kcal,
          'timesEaten': entry.value.timesEaten,
          'lastAt': entry.value.lastAt.toIso8601String(),
        },
    },
    'saved': state.savedRecipes.toList(),
  };
}

void Function()? _readEat(Object? raw) {
  final section = _map(raw);
  if (section == null) return null;

  final plates = <String, UsualPlate>{};
  for (final entry in (_map(section['plates']) ?? const {}).entries) {
    final row = _map(entry.value);
    final lastAt = row == null ? null : _time(row['lastAt']);
    if (row == null || lastAt == null) continue;
    final items = _readPlateItems(row['items']);
    // A plate is named by the first food in it, so an empty one has no name
    // and `UsualPlate.foodId` would throw the moment Home drew it.
    if (items.isEmpty) continue;
    plates[entry.key] = UsualPlate(
      plateId: entry.key,
      items: items,
      kcal: _int(row['kcal']) ?? 0,
      timesEaten: _int(row['timesEaten']) ?? 1,
      lastAt: lastAt,
    );
  }
  final saved = _strings(section['saved']);

  return () =>
      EatAppState.instance.restore(plates: plates, savedRecipes: saved);
}

// ------------------------------------------------------------------ cycle ---

Map<String, Object?> _captureCycle() {
  final store = AppRouter.cycleRepository.store;
  final state = CycleAppState.instance;
  return <String, Object?>{
    'document': store.cycle == null ? null : _cycleDocument(store.cycle!),
    'periods': [
      for (final period in store.periods.values)
        <String, Object?>{
          'start': period.start.toIso8601String(),
          'end': period.end?.toIso8601String(),
        },
    ],
    // The merged view, so today's check-in is stored under today's key rather
    // than in a second place that could disagree with it.
    'checkIns': <String, Object?>{
      for (final entry in state.checkIns.entries)
        entry.key: _checkIn(entry.value),
    },
    'decidedOn': state.decidedOn,
    'homeCardChosen': state.homeCardChosen,
  };
}

void Function()? _readCycle(Object? raw) {
  final section = _map(raw);
  if (section == null) return null;

  final document = _readCycleDocument(section['document']);
  final today = AppClock.now();
  final periods = <String, PeriodEntry>{};
  for (final entry in _list(section['periods']) ?? const <Object?>[]) {
    final row = _map(entry);
    final start = row == null ? null : _time(row['start']);
    if (row == null || start == null) continue;
    // `PeriodEntry.validate` is the only way to build one, and that is the
    // point: a stored period that no longer validates is dropped rather than
    // forced back in through a side door.
    final result = PeriodEntry.validate(
      start: start,
      end: _time(row['end']),
      today: today,
    );
    if (result is PeriodValid) periods[result.entry.id] = result.entry;
  }

  final checkIns = <String, TodayCheckIn>{
    for (final entry in (_map(section['checkIns']) ?? const {}).entries)
      if (_isDayId(entry.key)) entry.key: ?_readCheckIn(entry.value),
  };
  final decidedOn = _str(section['decidedOn']);
  final homeCardChosen = _bool(section['homeCardChosen']) ?? false;

  return () {
    final store = AppRouter.cycleRepository.store;
    store.cycle = document;
    store.periods
      ..clear()
      ..addAll(periods);
    CycleAppState.instance.restore(
      checkIns: checkIns,
      decidedOn: decidedOn,
      homeCardChosen: homeCardChosen,
    );
    // Today's check-in is a fact about today and nothing else. A check-in from
    // a previous day stays in the map for Y10's chart and is never carried
    // forward as though she had logged it again this morning (G9 §3.3).
    final todayId = AppRouter.dayId(AppClock.now());
    AppRouter.todayCheckIn = checkIns[todayId] ?? TodayCheckIn.absent;
  };
}

Map<String, Object?> _cycleDocument(CycleDocument cycle) => <String, Object?>{
  'mode': cycle.mode.name,
  'contextFlags': [for (final flag in cycle.contextFlags) flag.name],
  'cycleLengthDays': cycle.cycleLengthDays,
  'adaptation': <String, Object?>{
    'workoutSuggestions': cycle.adaptation.workoutSuggestions,
    'mealSuggestions': cycle.adaptation.mealSuggestions,
    'homeCard': cycle.adaptation.homeCard,
    'easierWhenLowEnergy': cycle.adaptation.easierWhenLowEnergy,
  },
  'sharing': <String, Object?>{
    'energyAppetite': cycle.sharing.energyAppetite,
    'symptoms': cycle.sharing.symptoms,
    'datesAndPatterns': cycle.sharing.datesAndPatterns,
    'grantedForRelId': cycle.sharing.grantedForRelId,
  },
  if (cycle.lastPeriod case final last?)
    'lastPeriod': <String, Object?>{
      'startDate': last.startDate,
      'endDate': last.endDate,
    },
  'recentStarts': cycle.recentStarts,
};

CycleDocument? _readCycleDocument(Object? raw) {
  final row = _map(raw);
  final mode = row == null ? null : _pick(CycleMode.values, row['mode']);
  if (row == null || mode == null) return null;

  final adaptation = _map(row['adaptation']) ?? const <String, Object?>{};
  final sharing = _map(row['sharing']) ?? const <String, Object?>{};
  final lastPeriod = _map(row['lastPeriod']);
  final length = _int(row['cycleLengthDays']);

  return CycleDocument(
    mode: mode,
    // Capped at the document's own limits, which the security rules assert
    // too. A snapshot over them is corrupt, and truncating is what keeps the
    // constructor's asserts from taking the app down on launch.
    contextFlags: {
      for (final name in _list(row['contextFlags']) ?? const <Object?>[])
        ?_pick(CycleContextFlag.values, name),
    }.take(CycleDocument.maxContextFlags).toSet(),
    cycleLengthDays:
        length != null &&
            length >= CycleDocument.minCycleLengthDays &&
            length <= CycleDocument.maxCycleLengthDays
        ? length
        : null,
    adaptation: CycleAdaptation(
      workoutSuggestions: _bool(adaptation['workoutSuggestions']) ?? false,
      mealSuggestions: _bool(adaptation['mealSuggestions']) ?? false,
      homeCard: _bool(adaptation['homeCard']) ?? false,
      easierWhenLowEnergy: _bool(adaptation['easierWhenLowEnergy']) ?? false,
    ),
    sharing: CycleSharing(
      energyAppetite: _bool(sharing['energyAppetite']) ?? false,
      symptoms: _bool(sharing['symptoms']) ?? false,
      datesAndPatterns: _bool(sharing['datesAndPatterns']) ?? false,
      grantedForRelId: _str(sharing['grantedForRelId']),
    ),
    lastPeriod: switch (lastPeriod) {
      null => null,
      final last => switch (_str(last['startDate'])) {
        final String startDate => LastPeriod(
          startDate: startDate,
          endDate: _str(last['endDate']),
        ),
        _ => null,
      },
    },
    recentStarts: _strings(row['recentStarts'])
        .take(CycleDocument.maxRecentStarts)
        .toList(),
  );
}

Map<String, Object?> _checkIn(TodayCheckIn checkIn) => <String, Object?>{
  'energy': checkIn.energy?.name,
  'cramps': checkIn.cramps?.name,
  'appetite': checkIn.appetite?.name,
  'sleep': checkIn.sleep?.name,
  'bloating': checkIn.bloating?.name,
  'bleeding': checkIn.bleeding?.name,
};

TodayCheckIn? _readCheckIn(Object? raw) {
  final row = _map(raw);
  if (row == null) return null;
  return TodayCheckIn(
    energy: _pick(Energy.values, row['energy']),
    cramps: _pick(Cramps.values, row['cramps']),
    appetite: _pick(Appetite.values, row['appetite']),
    sleep: _pick(Sleep.values, row['sleep']),
    bloating: _pick(Bloating.values, row['bloating']),
    bleeding: _pick(Bleeding.values, row['bleeding']),
  );
}

// ---------------------------------------------------- privacy and profile ---

Map<String, Object?> _capturePrivacy() {
  final repository = AppRouter.privacyRepository;
  final privacy = repository.settings();
  final notify = repository.notify();
  return <String, Object?>{
    'privacy': <String, Object?>{
      'profileVisible': privacy.profileVisible,
      'showBests': privacy.showBests,
      'blurFacesDefault': privacy.blurFacesDefault,
      'shareLogsWithCoach': privacy.shareLogsWithCoach,
      'policyVersion': privacy.policyVersion,
    },
    'notify': <String, Object?>{
      'push': notify.push,
      'mealNudge': notify.mealNudge,
      'quietStart': notify.quietStart,
      'quietEnd': notify.quietEnd,
      'usualMealHour': notify.usualMealHour,
    },
  };
}

void Function()? _readPrivacy(Object? raw) {
  final section = _map(raw);
  if (section == null) return null;

  final privacyRow = _map(section['privacy']);
  final notifyRow = _map(section['notify']);

  // Every default here is the one a new account opens with, and the blur is the
  // only one that is true. A snapshot missing a key must not quietly turn a
  // protection off (G7 rule 6).
  final privacy = privacyRow == null
      ? null
      : PrivacySettings(
          profileVisible: _bool(privacyRow['profileVisible']) ?? false,
          showBests: _bool(privacyRow['showBests']) ?? false,
          blurFacesDefault: _bool(privacyRow['blurFacesDefault']) ?? true,
          shareLogsWithCoach: _bool(privacyRow['shareLogsWithCoach']) ?? false,
          policyVersion: _int(privacyRow['policyVersion']) ?? 1,
        );

  final quietStart = (_int(notifyRow?['quietStart']) ?? 1320).clamp(0, 1439);
  final quietEnd = (_int(notifyRow?['quietEnd']) ?? 480).clamp(0, 1439);
  final notify = notifyRow == null
      ? null
      : NotifySettings(
          push: _bool(notifyRow['push']) ?? false,
          mealNudge: _bool(notifyRow['mealNudge']) ?? true,
          quietStart: quietStart,
          quietEnd: quietEnd,
          usualMealHour: _int(notifyRow['usualMealHour']),
        );

  return () =>
      AppRouter.privacyRepository.restore(privacy: privacy, notify: notify);
}

Map<String, Object?> _captureDietary() {
  final profile = AppRouter.dietaryRepository.read();
  return <String, Object?>{
    // Null is her never having been asked, and it is a different fact from an
    // empty list, which is her answering "nothing". Collapsing the two is how
    // a safety guard silently turns itself off.
    'allergies': profile.allergies?.map((a) => a.wireName).toList(),
    'dietary': profile.dietary?.map((d) => d.wireName).toList(),
  };
}

void Function()? _readDietary(Object? raw) {
  final section = _map(raw);
  if (section == null) return null;

  Set<AllergenTag>? allergies;
  if (_list(section['allergies']) case final stored?) {
    allergies = {
      for (final wire in stored)
        if (_str(wire) case final name?) ?AllergenTag.fromWire(name),
    };
  }
  Set<DietaryTag>? dietary;
  if (_list(section['dietary']) case final stored?) {
    dietary = {
      for (final wire in stored)
        if (_str(wire) case final name?) ?DietaryTag.fromWire(name),
    };
  }
  if (allergies == null && dietary == null) return null;

  return () => AppRouter.dietaryRepository.restore(
    DietaryProfile(allergies: allergies, dietary: dietary),
  );
}

Map<String, Object?> _captureIntake() {
  final intake = AppRouter.intakeRepository.read();
  return <String, Object?>{
    'goal': intake.goal.wireName,
    'place': intake.place.wireName,
    'equipment': [for (final item in intake.equipment) item.wireName],
    'days': intake.days,
    'minutes': intake.minutes,
    'lifeStage': intake.lifeStage.wireName,
    'level': intake.level.wireName,
    'weekdays': [...intake.weekdays]..sort(),
    'minutesCustom': intake.minutesCustom,
    // O04 "About you". Health data (D31): it is saved here on the phone and
    // is not in the profile mapping, so it is never uploaded.
    'body': _captureBody(),
    // Whether she has been through the setup walk at all. Kept beside her
    // answers rather than in a section of its own, because it is a fact about
    // the same four questions and because account deletion clears both through
    // the same `reset()`.
    'setupDone': AppRouter.intakeRepository.setupDone,
    // Whether she was asked where she trains. The short "Your week" never
    // asks, and her week must not be read back to her as "at home" then.
    'placeAnswered': AppRouter.intakeRepository.placeAnswered,
    // "Not now" on day-one Home's "Track my cycle". A Home preference, kept
    // here because it is cleared by the same reset as the answers above.
    'cycleRowDismissed': OnboardingState.instance.cycleRowDismissed,
    // She built this week before she had an account, and no account has
    // claimed it yet. Read by a change of account on this phone.
    if (OnboardingState.instance.weekBuiltSignedOut) 'builtSignedOut': true,
  };
}

Map<String, Object?> _captureBody() {
  final body = BodyDataStore.instance.read();
  return <String, Object?>{
    'weightKg': body.weightKg,
    'heightCm': body.heightCm,
    'ageYears': body.ageYears,
  };
}

BodyData _readBody(Object? raw) {
  final section = _map(raw);
  if (section == null) return BodyData.empty;
  final weight = section['weightKg'];
  return BodyData(
    weightKg: weight is num ? weight.toDouble() : null,
    heightCm: _int(section['heightCm']),
    ageYears: _int(section['ageYears']),
  ).sanitised();
}

void Function()? _readIntake(Object? raw) {
  final section = _map(raw);
  if (section == null) return null;
  final defaults = Intake.defaults;

  final equipment = <Equipment>{
    for (final wire in _list(section['equipment']) ?? const <Object?>[])
      ?_wire(Equipment.values, wire),
  };
  final days = _int(section['days']) ?? defaults.days;
  final minutes = _int(section['minutes']) ?? defaults.minutes;
  final weekdays = Intake.cleanWeekdays([
    for (final d in _list(section['weekdays']) ?? const <Object?>[])
      if (d is int) d,
  ]);
  final body = _readBody(section['body']);

  final intake = Intake(
    goal: _wire(TrainingGoal.values, section['goal']) ?? defaults.goal,
    place: _wire(TrainingPlace.values, section['place']) ?? defaults.place,
    // At least one entry, always: `Equipment.none` is an answer rather than the
    // absence of one, and an empty set is not a state a screen can render.
    equipment: equipment.isEmpty ? defaults.equipment : equipment,
    // Both constructor asserts, applied to the document instead of trusting it.
    days: Intake.daysOk(days) ? days : defaults.days,
    minutes: Intake.minutesOk(minutes) ? minutes : defaults.minutes,
    lifeStage:
        _wire(LifeStage.values, section['lifeStage']) ?? defaults.lifeStage,
    // A document from before the tiers read as the level her answers suggest.
    level:
        TrainingLevel.fromWire(section['level']) ?? TrainingLevel.defaultLevel,
    weekdays: weekdays,
    minutesCustom: _bool(section['minutesCustom']) ?? false,
  );

  // Absent means a document written before the walk existed, and the honest
  // reading of that is that she was never asked. She is asked once.
  final setupDone = _bool(section['setupDone']) ?? false;
  // Absent reads as not asked: a place-less line is never untrue.
  final placeAnswered = _bool(section['placeAnswered']) ?? false;
  final cycleRowDismissed = _bool(section['cycleRowDismissed']) ?? false;
  final builtSignedOut = _bool(section['builtSignedOut']) ?? false;

  return () {
    AppRouter.intakeRepository.restore(
      intake,
      setupDone: setupDone,
      placeAnswered: placeAnswered,
    );
    BodyDataStore.instance.restore(body);
    OnboardingState.instance
      ..cycleRowDismissed = cycleRowDismissed
      ..weekBuiltSignedOut = builtSignedOut;
  };
}

Map<String, Object?> _captureLanguage() => <String, Object?>{
  'code': AppRouter.localePreference.read()?.code,
};

void Function()? _readLanguage(Object? raw) {
  final section = _map(raw);
  final code = section == null ? null : _str(section['code']);
  // `AppLanguage.fromCode` answers Arabic for anything it does not recognise,
  // which is right for a chooser and wrong here: nothing stored means she never
  // chose, and the app's own default should stand.
  if (code != 'ar' && code != 'en') return null;
  final language = AppLanguage.fromCode(code);
  return () => AppRouter.localePreference.write(language);
}

// Her agreement to the community's rules (C16): the version and when. The
// server keeps its own record (record_pledge); this one is what lets the
// community open without asking again on her next visit.
Map<String, Object?> _capturePledge() => <String, Object?>{
  'version': PledgeState.instance.agreedVersion,
  'at': PledgeState.instance.agreedAt?.toUtc().toIso8601String(),
  'pending': PledgeState.instance.recordPending,
};

void Function()? _readPledge(Object? raw) {
  final section = _map(raw);
  if (section == null) return null;
  final version = _int(section['version']);
  final at = DateTime.tryParse(_str(section['at']) ?? '');
  final pending = section['pending'] == true;
  return () {
    PledgeState.instance
      ..agreedVersion = version
      ..agreedAt = at
      ..recordPending = pending;
  };
}

// The day, not the minute: the away count runs in days, and an open that
// changes the minute alone must not make the snapshot look changed.
String? _dayOf(DateTime? at) =>
    at == null ? null : DateTime(at.year, at.month, at.day).toIso8601String();

// Her training reminders: whether R10 has offered them, and the days and time
// she chose. When to remind her, never a record of what she did.
Map<String, Object?> _captureReminders() => <String, Object?>{
  'offered': ReminderState.instance.offered,
  'schedule': ReminderState.instance.schedule?.toJson(),
  'permission': ReminderState.instance.permissionGranted,
  'logNudge': ReminderState.instance.prefs.logNudge,
  'checkIns': ReminderState.instance.prefs.checkIns,
  'restAlert': ReminderState.instance.prefs.restAlert,
  'tipsOn': ReminderState.instance.prefs.tips,
  'nudgesOn': ReminderState.instance.prefs.nudges,
  'eventsOn': ReminderState.instance.prefs.events,
  // The event notes on the phone: id, time and which text, nothing about the
  // event itself. Only written while there are some.
  if (ReminderState.instance.eventPlan.isNotEmpty)
    'eventPlan': [
      for (final note in ReminderState.instance.eventPlan)
        <String, Object?>{
          'id': note.id,
          'at': note.at.toIso8601String(),
          'variant': note.variant,
        },
    ],
  'lastActiveAt': _dayOf(ReminderState.instance.lastActiveAt),
  'lastSessionAt': _dayOf(ReminderState.instance.lastSessionAt),
  // The getting started tips. To the minute, unlike the two above: a tip's
  // time is what tells the next open whether it was shown. It changes only
  // in her first fortnight, and only when she opens the app.
  'tips': ReminderState.instance.tips.toJson(),
  'tipMarks': (ReminderState.instance.tipMarks.toList()..sort()),
  'tipsOfferDue': ReminderState.instance.tipsOfferDue,
  'tipsOffered': ReminderState.instance.tipsOffered,
};

void Function()? _readReminders(Object? raw) {
  final section = _map(raw);
  if (section == null) return null;
  final offered = _bool(section['offered']) ?? false;
  final schedule = TrainingReminders.fromJson(section['schedule']);
  final permission =
      (_bool(section['permission']) ?? false) || schedule != null;
  final prefs = NotificationPrefs(
    logNudge: _bool(section['logNudge']) ?? true,
    checkIns: _bool(section['checkIns']) ?? true,
    restAlert: _bool(section['restAlert']) ?? true,
    tips: _bool(section['tipsOn']) ?? true,
    nudges: _bool(section['nudgesOn']) ?? true,
    events: _bool(section['eventsOn']) ?? true,
  );
  final eventPlan = _readEventPlan(section['eventPlan']);
  final active = DateTime.tryParse(_str(section['lastActiveAt']) ?? '');
  final session = DateTime.tryParse(_str(section['lastSessionAt']) ?? '');
  final tips = TipSeries.fromJson(section['tips']);
  final marks = section['tipMarks'];
  final tipMarks = <String>{
    if (marks is List)
      for (final mark in marks)
        if (mark is String) mark,
  };
  final tipsOfferDue = _bool(section['tipsOfferDue']) ?? false;
  final tipsOffered = _bool(section['tipsOffered']) ?? false;
  return () {
    ReminderState.instance
      ..offered = offered
      ..schedule = schedule
      ..permissionGranted = permission
      ..prefs = prefs
      ..eventPlan = eventPlan
      ..lastActiveAt = active
      ..lastSessionAt = session
      ..tips = tips
      ..tipMarks = tipMarks
      ..tipsOfferDue = tipsOfferDue
      ..tipsOffered = tipsOffered;
  };
}

// The event notes last scheduled. Anything that is not a whole note inside the
// event id block is dropped, so a damaged entry can never schedule a stray id.
List<PlannedNotification> _readEventPlan(Object? raw) {
  if (raw is! List) return const <PlannedNotification>[];
  final last = kEventFirstId + kEventMaxPlanned * kEventStepsPerEvent;
  return [
    for (final entry in raw)
      if (entry is Map)
        if (_int(entry['id']) case final id?
            when id >= kEventFirstId && id < last)
          if (DateTime.tryParse(_str(entry['at']) ?? '') case final at?)
            PlannedNotification(
              id: id,
              kind: PlanKind.eventReminder,
              at: at,
              variant: _int(entry['variant']) ?? 0,
            ),
  ];
}

void Function()? _readFirstGymGuide(Object? raw) {
  final section = _map(raw);
  if (section == null) return null;
  final seen = _bool(section['seen']) ?? false;
  return () => FirstGymGuideState.instance.seen = seen;
}

// Her awards (D41): the ids already paid and today's cap. Without these every
// launch began a fresh ledger, so the daily cap reset with the app and a week
// could be paid twice.
Map<String, Object?> _captureAwards() {
  final rewards = RewardsState.instance;
  final cap = rewards.capState;
  return <String, Object?>{
    'ids': rewards.awardIds.toList(),
    'cap': <String, Object?>{
      'day': cap.dayKey,
      'points': cap.pointsToday,
      'bests': cap.bestsToday,
    },
    // What each capped award paid and what earned each milestone, so a
    // session or a meal she removes takes back exactly what it was given.
    if (rewards.grantedPoints.isNotEmpty) 'granted': rewards.grantedPoints,
    if (rewards.milestoneSources.isNotEmpty)
      'earnedBy': rewards.milestoneSources,
  };
}

void Function()? _readAwards(Object? raw) {
  final section = _map(raw);
  if (section == null) return null;
  final ids = _strings(section['ids']);
  final cap = _map(section['cap']);
  final state = cap == null
      ? null
      : DailyCapState(
          dayKey: _str(cap['day']) ?? '',
          pointsToday: _int(cap['points']) ?? 0,
          bestsToday: _int(cap['bests']) ?? 0,
        );
  final granted = <String, int>{
    for (final entry in (_map(section['granted']) ?? const {}).entries)
      entry.key: ?_int(entry.value),
  };
  final earnedBy = <String, String>{
    for (final entry in (_map(section['earnedBy']) ?? const {}).entries)
      entry.key: ?_str(entry.value),
  };
  return () => RewardsState.instance.restore(
    awardIds: ids,
    cap: state,
    granted: granted,
    earnedBy: earnedBy,
  );
}

// Her training streak (D37): her choices and her sessions per day. The length
// is derived from these, never stored. Null until this phone has either.
Map<String, Object?>? _captureTrainingStreak() {
  final state = TrainingStreakState.instance;
  if (!state.touched) return null;
  final settings = state.settings();
  return <String, Object?>{
    'on': settings.enabled,
    'since': settings.since,
    'best': settings.best,
    'pauses': [
      for (final pause in settings.pauses)
        <String, Object?>{'from': pause.start, 'to': pause.end},
    ],
    'days': state.sessionsByDay,
  };
}

void Function()? _readTrainingStreak(Object? raw) {
  final section = _map(raw);
  if (section == null) return null;
  final since = _str(section['since']);
  if (since == null || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(since)) {
    return null;
  }
  // Day ids only: a pause end that is not one would throw when the streak
  // reads it, on Home.
  bool isDay(String? value) =>
      value != null && RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value);
  final pauses = <StreakPause>[
    for (final row in _list(section['pauses']) ?? const <Object?>[])
      if (_map(row) case final pause?
          when isDay(_str(pause['from'])) &&
              (pause['to'] == null || isDay(_str(pause['to']))))
        StreakPause(start: _str(pause['from'])!, end: _str(pause['to'])),
  ];
  final days = <String, int>{
    for (final entry
        in (_map(section['days']) ?? const <String, Object?>{}).entries)
      if (_int(entry.value) case final count? when count > 0) entry.key: count,
  };
  final settings = StreakSettings(
    enabled: _bool(section['on']) ?? true,
    since: since,
    pauses: pauses,
    best: _int(section['best']) ?? 0,
  );
  return () => TrainingStreakState.instance.restore(
    settings: settings,
    sessionsByDay: days,
  );
}

// Her roles (R1-P17): which apps she holds and which one she was looking at.
// Null when this phone has none, and then the launch default stands.
Map<String, Object?>? _captureRoles() {
  final roles = RoleState.instance.roles;
  if (roles == null) return null;
  return <String, Object?>{
    'held': [
      for (final role in AppRole.values)
        if (roles.held.contains(role)) role.name,
    ],
    'active': roles.active.name,
  };
}

void Function()? _readRoles(Object? raw) {
  final section = _map(raw);
  if (section == null) return null;
  final held = rolesFromNames(section['held']);
  if (held == null) return null;
  final active = AppRole.values
      .where((r) => r.name == _str(section['active']))
      .firstOrNull;
  final roles = UserRoles(held: held, active: active ?? held.first);
  return () => RoleState.instance.roles = roles;
}

// Her coach application (R1-P17): what she answered on K01 to K05, her
// certificates and whether it went in. Never a check result: "verified" is the
// server's word (see `CoachProfileState.restore`). Written only once she has
// started, so a trainee's snapshot carries nothing here.
Map<String, Object?>? _captureCoach() {
  final state = CoachProfileState.instance;
  final setup = state.setup;
  final started =
      state.profile.displayName.isNotEmpty ||
      state.profile.city.isNotEmpty ||
      setup.certificates.isNotEmpty ||
      state.isSetupComplete;
  if (!started) return null;
  final profile = state.profile;
  return <String, Object?>{
    'displayName': profile.displayName,
    'city': profile.city,
    'tagline': profile.tagline,
    'photoBlurred': profile.photoBlurred,
    'specialties': [for (final s in profile.specialties) s.name],
    'languages': [for (final l in profile.languages) l.name],
    'places': [for (final p in profile.clientPlaces) p.name],
    if (profile.capacity.isSet) 'capacityMax': profile.capacity.max,
    'certificates': [
      for (final c in setup.certificates)
        <String, Object?>{
          'credentialId': c.credentialId,
          'mediaRef': c.mediaRef,
          'issuedAt': c.issuedAt.toIso8601String(),
          if (c.expiresAt case final ends?) 'expiresAt': ends.toIso8601String(),
          'sent': c.state.hasLeftTheDevice,
        },
    ],
    'payoutLater': setup.payoutLater,
    'submitted': state.isSetupComplete,
    'testCoach': state.isTestCoach,
  };
}

Set<T> _named<T extends Enum>(Object? raw, List<T> values) => {
  for (final name in _list(raw) ?? const <Object?>[])
    ...values.where((v) => v.name == name),
};

void Function()? _readCoach(Object? raw) {
  final section = _map(raw);
  if (section == null) return null;
  final max = _int(section['capacityMax']);
  CoachCapacity capacity = CoachCapacity.unset;
  if (max != null) {
    try {
      capacity = CoachCapacity(max: max, taken: 0);
    } on ArgumentError {
      capacity = CoachCapacity.unset;
    }
  }
  final profile = CoachProfile(
    displayName: _str(section['displayName']) ?? '',
    city: _str(section['city']) ?? '',
    tagline: _str(section['tagline']) ?? '',
    photoBlurred: _bool(section['photoBlurred']) ?? true,
    specialties: _named(section['specialties'], Specialty.values),
    languages: _named(section['languages'], CoachLanguage.values),
    clientPlaces: _named(section['places'], ClientPlace.values),
    capacity: capacity,
  );
  final certificates = <Certificate>[];
  for (final item in _list(section['certificates']) ?? const <Object?>[]) {
    final c = _map(item);
    final credentialId = _str(c?['credentialId']);
    final mediaRef = _str(c?['mediaRef']);
    final issuedAt = DateTime.tryParse(_str(c?['issuedAt']) ?? '');
    if (credentialId == null || mediaRef == null || issuedAt == null) continue;
    final sent = _bool(c?['sent']) ?? false;
    certificates.add(
      Certificate(
        id: '${credentialId}_${issuedAt.toIso8601String()}',
        credentialId: credentialId,
        mediaRef: mediaRef,
        issuedAt: issuedAt,
        expiresAt: DateTime.tryParse(_str(c?['expiresAt']) ?? ''),
        // Where it got to on this phone, never further: only a reviewer
        // moves a certificate past "uploaded".
        state: sent ? CertificateState.uploaded : CertificateState.localPending,
      ),
    );
  }
  final payoutLater = _bool(section['payoutLater']) ?? false;
  final submitted = _bool(section['submitted']) ?? false;
  final testCoach = _bool(section['testCoach']) ?? false;
  return () => CoachProfileState.instance.restore(
    profile: profile,
    certificates: certificates,
    payoutLater: payoutLater,
    submitted: submitted,
    testCoach: testCoach,
  );
}

// The code her coach sent (R1-P18), waiting for her check to finish.
Map<String, Object?>? _captureInvite() {
  final code = CoachInviteState.instance.pendingCode;
  return code == null ? null : <String, Object?>{'code': code};
}

void Function()? _readInvite(Object? raw) {
  final code = normaliseInviteCode(_str(_map(raw)?['code']) ?? '');
  if (code == null) return null;
  return () => CoachInviteState.instance.pendingCode = code;
}

// ---------------------------------------------------------------- readers ---
//
// Every one of these answers null rather than throwing, so a field of the wrong
// type costs that field and not the document.

Map<String, Object?>? _map(Object? value) =>
    value is Map<String, Object?> ? value : null;

List<Object?>? _list(Object? value) => value is List<Object?> ? value : null;

String? _str(Object? value) => value is String ? value : null;

bool? _bool(Object? value) => value is bool ? value : null;

num? _num(Object? value) => value is num ? value : null;

int? _int(Object? value) => value is num ? value.toInt() : null;

/// A macro in grams on a logged meal: a whole, non-negative number, or null
/// when it is absent or not a number. A day can never read back a negative.
int? _macro(Object? value) =>
    value is num && value.isFinite && value >= 0 ? value.round() : null;

/// Her name for a food the pack does not hold, bounded the way a typed name
/// is on E13.
String? _mealName(Object? value) {
  if (value is! String) return null;
  final name = value.trim();
  if (name.isEmpty) return null;
  return name.length <= 80 ? name : name.substring(0, 80);
}

/// The weight she approved on E13, in grams, when it is a sane one.
num? _weight(Object? value) =>
    value is num && value.isFinite && value >= 0 && value <= 3000
    ? value
    : null;

double? _double(Object? value) => value is num ? value.toDouble() : null;

DateTime? _time(Object? value) {
  final text = _str(value);
  return text == null ? null : DateTime.tryParse(text);
}

List<String> _strings(Object? value) => <String>[
  for (final entry in _list(value) ?? const <Object?>[]) ?_str(entry),
];

/// One enum value by its Dart name, or null for a name this build does not
/// have. That is what lets an older build read a document written by a newer
/// one: a value it has never heard of is dropped, not guessed at.
T? _pick<T extends Enum>(List<T> values, Object? value) {
  final name = _str(value);
  if (name == null) return null;
  for (final candidate in values) {
    if (candidate.name == name) return candidate;
  }
  return null;
}

/// The same, for the enums that carry a stored `wireName` distinct from the
/// Dart name — the ones a rename must not silently rewrite.
T? _wire<T extends Enum>(List<T> values, Object? value) {
  final name = _str(value);
  if (name == null) return null;
  for (final candidate in values) {
    final wire = switch (candidate) {
      TrainingGoal(:final wireName) => wireName,
      TrainingPlace(:final wireName) => wireName,
      Equipment(:final wireName) => wireName,
      LifeStage(:final wireName) => wireName,
      _ => candidate.name,
    };
    if (wire == name) return candidate;
  }
  return null;
}

/// `yyyy-MM-dd`, the id every day-keyed document must carry.
bool _isDayId(String id) => RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(id);

// ------------------------------------------------------- deliberately out ---
//
// **Community and coaching are not in the snapshot**, and this is the note that
// says so rather than leaving it to be discovered.
//
// Both are off for the first release (`FeatureFlags.shipped`), and neither
// serialises cheaply: `CommunityPost` alone carries a nested author card, a
// media list, an audience key set, a cost, a blur opt-out, six counters and a
// schema version, and the coaching desk holds clients, plans, splits,
// assessment forms and threads on top of that. Writing codecs for that graph
// now would be a large surface with no woman behind it, and a large surface
// that nothing exercises is a large surface that rots.
//
// What keeps it from rotting instead is where the seam is: everything above
// reads and writes through `restore`/`reset` pairs on the stores themselves. A
// `community` section is a reader in `_readers`, a writer in `capture`, and
// `CommunityState.restore` beside the `reset` it already has — no change to the
// storage layer, the lifecycle or the schema number, beyond bumping it.

// Guest mode: the one action she tried before signing in, kept until she is
// verified. Null when there is nothing to keep.
Map<String, Object?>? _captureGuest() {
  final guest = GuestSession.instance;
  final action = guest.pending;
  final at = guest.pendingAt;
  if (action == null || at == null) return null;
  return <String, Object?>{
    'action': action.toJson(),
    'at': at.toIso8601String(),
  };
}

void Function()? _readGuest(Object? raw) {
  final section = _map(raw);
  if (section == null) return null;
  final action = PendingAction.fromJson(section['action']);
  final at = _time(section['at']);
  if (action == null || at == null) return null;
  return () {
    GuestSession.instance
      ..pending = action
      ..pendingAt = at;
  };
}

Map<String, Object?>? _captureChosenProgramme() {
  final family = ChosenProgramme.family;
  return family == null ? null : <String, Object?>{'family': family};
}

void Function()? _readChosenProgramme(Object? raw) {
  final section = _map(raw);
  final family = section == null ? null : _str(section['family']);
  if (family == null || family.isEmpty) return null;
  // A family from before the three splits becomes the split nearest her days,
  // and her days a week become that split's so every day of it is reached.
  return () {
    final intake = AppRouter.intakeRepository;
    final migrated = migratedProgrammeFamily(family, days: intake.read().days);
    ChosenProgramme.family = migrated;
    final days = splitDaysOf(migrated);
    if (migrated != family && days != null) {
      ChosenProgramme.alignDays(intake, days);
    }
  };
}

// ------------------------------------------------------------- followUps ---

// What she answered on the follow-ups and how she set them. Phone only: this
// section is in the snapshot and in no cloud document.
Map<String, Object?>? _captureFollowUps() {
  final state = FollowUpState.instance;
  if (!state.touched) return null;
  return <String, Object?>{
    'on': state.enabled,
    'muted': [for (final kind in state.muted) kind.name],
    'notBefore': {
      for (final entry in state.notBefore.entries) entry.key.name: entry.value,
    },
    'feels': {
      for (final entry in state.feels.entries) entry.key: entry.value.name,
    },
    'reviews': {
      for (final entry in state.weekReviews.entries)
        entry.key: <String, Object?>{
          'felt': entry.value.felt.name,
          'fit': entry.value.fit.name,
          'focus': entry.value.focus.name,
        },
    },
  };
}

void Function()? _readFollowUps(Object? raw) {
  final section = _map(raw);
  if (section == null) return null;
  bool isDay(String? value) =>
      value != null && RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value);
  final muted = <FollowUpKind>{
    for (final name in _list(section['muted']) ?? const <Object?>[])
      ?_pick(FollowUpKind.values, name),
  };
  final notBefore = <FollowUpKind, String>{
    for (final entry
        in (_map(section['notBefore']) ?? const <String, Object?>{}).entries)
      if (_pick(FollowUpKind.values, entry.key) case final kind?
          when isDay(_str(entry.value)))
        kind: entry.value as String,
  };
  final feels = <String, Feel>{};
  for (final entry
      in (_map(section['feels']) ?? const <String, Object?>{}).entries) {
    final feel = _pick(Feel.values, entry.value);
    if (isDay(entry.key) && feel != null) feels[entry.key] = feel;
  }
  final reviews = <String, WeekReviewAnswer>{
    for (final entry
        in (_map(section['reviews']) ?? const <String, Object?>{}).entries)
      if (isDay(entry.key) && _map(entry.value) != null)
        if (_pick(WeekFelt.values, _map(entry.value)!['felt']) case final felt?)
          if (_pick(PlanFit.values, _map(entry.value)!['fit']) case final fit?)
            if (_pick(WeekFocus.values, _map(entry.value)!['focus'])
                case final focus?)
              entry.key: WeekReviewAnswer(felt: felt, fit: fit, focus: focus),
  };
  final enabled = _bool(section['on']) ?? true;
  return () => FollowUpState.instance.restore(
    enabled: enabled,
    muted: muted,
    notBefore: notBefore,
    feels: feels,
    weekReviews: reviews,
  );
}

// ------------------------------------------------------ notificationVoice ---

// Which words each reminder carries, so a line is not repeated and her tone is
// learned. Phone only: this section is in the snapshot and in no cloud
// document.
Map<String, Object?>? _captureNotificationVoice() {
  final history = VoiceHistory.instance;
  return history.touched ? history.toJson() : null;
}

void Function()? _readNotificationVoice(Object? raw) {
  final section = _map(raw);
  if (section == null) return null;
  final sent = <String, String>{
    for (final entry
        in (_map(section['sent']) ?? const <String, Object?>{}).entries)
      entry.key: ?_str(entry.value),
  };
  final tones = <String, ToneStat>{};
  for (final tone in const [kToneCalm, kTonePlayful]) {
    final stat = _map((_map(section['toneStats']) ?? const {})[tone]);
    if (stat == null) continue;
    final sentCount = _int(stat['sent']) ?? 0;
    final taps = _int(stat['taps']) ?? 0;
    if (sentCount < 0 || taps < 0) continue;
    tones[tone] = ToneStat(sent: sentCount, taps: taps);
  }
  final scheduled = <int, ScheduledLine>{};
  for (final entry
      in (_map(section['scheduled']) ?? const <String, Object?>{}).entries) {
    final id = int.tryParse(entry.key);
    final line = _map(entry.value);
    final lineId = line == null ? null : _str(line['lineId']);
    final tone = line == null ? null : _str(line['tone']);
    final at = line == null ? null : _time(line['at']);
    if (id == null || lineId == null || at == null) continue;
    if (tone != kToneCalm && tone != kTonePlayful) continue;
    scheduled[id] = ScheduledLine(lineId: lineId, tone: tone!, at: at);
  }
  return () => VoiceHistory.instance.restore(
    sent: sent,
    toneStats: tones,
    scheduled: scheduled,
  );
}

// --------------------------------------------------------- customWorkouts ---

Map<String, Object?>? _captureCustomWorkouts() {
  final state = CustomWorkoutState.instance;
  if (state.workouts.isEmpty && state.deletedIds.isEmpty) return null;
  return <String, Object?>{
    'saved': [for (final workout in state.workouts) workout.toJson()],
    'deleted': state.deletedIds,
  };
}

void Function()? _readCustomWorkouts(Object? raw) {
  final section = _map(raw);
  if (section == null) return null;
  final saved = <CustomWorkout>[
    for (final entry in _list(section['saved']) ?? const <Object?>[])
      ?CustomWorkout.tryParse(entry),
  ];
  final deleted = <String>[
    for (final id in _strings(section['deleted']))
      if (isCustomWorkoutId(id)) id,
  ];
  return () =>
      CustomWorkoutState.instance.restoreSaved(saved: saved, deleted: deleted);
}

// ----------------------------------------------------------------- myPlan ---

// Her own plan. Phone only: this section is in the snapshot and in no cloud
// document. A snapshot from before it existed has no such section and reads as
// no plan.
Map<String, Object?>? _captureMyPlan() => MyPlanState.instance.plan?.toJson();

void Function()? _readMyPlan(Object? raw) {
  final plan = MyPlan.tryParse(raw);
  if (plan == null) return null;
  return () => MyPlanState.instance.restore(plan);
}

// -------------------------------------------------------------- restTimer ---

// The rest she set for each move on R09, in seconds. Phone only: this section
// is in the snapshot and in no cloud document. Written only once she has set
// one, so an old snapshot has none and reads as none.
Map<String, Object?>? _captureRestTimer() {
  final saved = RestTimerPrefs.instance.toJson();
  if (saved.isEmpty) return null;
  return <String, Object?>{'moves': saved};
}

void Function()? _readRestTimer(Object? raw) {
  final section = _map(raw);
  if (section == null) return null;
  final moves = _map(section['moves']);
  if (moves == null) return null;
  final saved = <String, int>{
    for (final entry in moves.entries)
      if (entry.key.isNotEmpty)
        if (_int(entry.value) case final seconds? when seconds > 0)
          entry.key: seconds,
  };
  if (saved.isEmpty) return null;
  return () => RestTimerPrefs.instance.restore(saved);
}

// ------------------------------------------------------------- moveNotes ---

// The note she keeps for each move. Phone only: this section is in the
// snapshot and in no cloud document. Written only once she has a note.
Map<String, Object?>? _captureMoveNotes() {
  final saved = MoveNotes.instance.toJson();
  if (saved.isEmpty) return null;
  return <String, Object?>{'moves': saved};
}

void Function()? _readMoveNotes(Object? raw) {
  final section = _map(raw);
  if (section == null) return null;
  final moves = _map(section['moves']);
  if (moves == null) return null;
  final saved = <String, String>{
    for (final entry in moves.entries)
      if (entry.key.isNotEmpty && entry.value is String && entry.value != '')
        entry.key: entry.value as String,
  };
  if (saved.isEmpty) return null;
  return () => MoveNotes.instance.restore(saved);
}

// ------------------------------------------------- coachApplicationDraft ---

// The coach application she is writing. Phone only: this section is in the
// snapshot and in no cloud document. Written only once she has started.
Map<String, Object?>? _captureCoachApplicationDraft() =>
    CoachApplicationDraft.instance.touched
    ? CoachApplicationDraft.instance.toJson()
    : null;

void Function()? _readCoachApplicationDraft(Object? raw) {
  final section = _map(raw);
  if (section == null || _map(section['application']) == null) return null;
  final saved = Map<String, Object?>.of(section);
  return () => CoachApplicationDraft.instance.restore(saved);
}

// ------------------------------------------------------ coachClientNotes ---

// The private note a coach keeps about each client. Phone only: this section is
// in the snapshot and in no cloud document. Written only once she has a note.
Map<String, Object?>? _captureCoachClientNotes() {
  final saved = CoachClientNotes.instance.toJson();
  if (saved.isEmpty) return null;
  return <String, Object?>{'clients': saved};
}

void Function()? _readCoachClientNotes(Object? raw) {
  final section = _map(raw);
  if (section == null) return null;
  final clients = _map(section['clients']);
  if (clients == null) return null;
  final saved = <String, String>{
    for (final entry in clients.entries)
      if (entry.key.isNotEmpty && entry.value is String && entry.value != '')
        entry.key: entry.value as String,
  };
  if (saved.isEmpty) return null;
  return () => CoachClientNotes.instance.restore(saved);
}

// ----------------------------------------------------------------- barKg ---

// The bar she loads, chosen once on R07. Phone only.
Object? _captureBarKg() =>
    BarPreference.instance.touched ? BarPreference.instance.kg : null;

void Function()? _readBarKg(Object? raw) {
  if (raw is! num) return null;
  final kg = raw.toDouble();
  return () => BarPreference.instance.restore(kg);
}
