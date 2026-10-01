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
///     are large nested graphs — see the note at the bottom of this file.
library;

import 'dart:convert';

import '../domain/rewards/personal_best_detector.dart';
import '../domain/rewards/week_rollup.dart';
import '../domain/rewards/weekly_goal.dart';
import '../domain/training/prescribed_set.dart';
import '../domain/week/week_key.dart';
import '../features/account/domain/dietary_profile.dart';
import '../features/account/domain/privacy_settings.dart';
import '../features/cycle/domain/cycle_document.dart';
import '../features/cycle/domain/period_entry.dart';
import '../features/cycle/domain/today_check_in.dart';
import '../features/eat/domain/meal_repository.dart';
import '../features/onboarding/domain/intake.dart';
import '../features/progress/domain/progress_repository.dart';
import '../features/signup/domain/locale_preference.dart';
import '../features/today/domain/today_day.dart';
import '../features/today/domain/today_repository.dart';
import '../features/train/domain/train_repository.dart';
import '../routing/app_router.dart';
import 'cycle_state.dart';
import 'eat_state.dart';

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
    'meals': _captureMeals(),
    'eat': _captureEat(),
    'cycle': _captureCycle(),
    'privacy': _capturePrivacy(),
    'dietary': _captureDietary(),
    'intake': _captureIntake(),
    'language': _captureLanguage(),
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
      final key = _prescriptionKey(set.prescribed.exerciseId, set.prescribed.order);
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
      index[sessionId]?[_prescriptionKey(prescribed.exerciseId, prescribed.order)];
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
                  if (set.outcome case final outcome?) 'outcome': _outcome(outcome),
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

  return () => AppRouter.trainRepository.restore(
    sessions: sessions,
    flushes: flushes,
    swaps: swaps,
    // The live session id is deliberately not carried across. A session she
    // was midway through when the app was killed is over; `WorkoutSessionState`
    // is gone with it, and pointing the repository at that id would attribute
    // her next flush to a workout she is no longer doing. The counter IS
    // carried, so the next live session gets an id no old one holds.
    sessionCounter: counter,
  );
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

Map<String, Object?> _prescription(PrescribedSet prescribed) => <String, Object?>{
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
        LoggedSet(prescribed: prescribed, outcome: _readOutcome(row['outcome'])),
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
        LoggedSet(prescribed: prescribed, outcome: _readOutcome(row['outcome'])),
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
    if (prefs != null) store.prefs = prefs;
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
  final today = DateTime.now();
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
    final todayId = AppRouter.dayId(DateTime.now());
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
    // Whether she has been through the setup walk at all. Kept beside her
    // answers rather than in a section of its own, because it is a fact about
    // the same four questions and because account deletion clears both through
    // the same `reset()`.
    'setupDone': AppRouter.intakeRepository.setupDone,
  };
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

  final intake = Intake(
    goal: _wire(TrainingGoal.values, section['goal']) ?? defaults.goal,
    place: _wire(TrainingPlace.values, section['place']) ?? defaults.place,
    // At least one entry, always: `Equipment.none` is an answer rather than the
    // absence of one, and an empty set is not a state a screen can render.
    equipment: equipment.isEmpty ? defaults.equipment : equipment,
    // Both constructor asserts, applied to the document instead of trusting it.
    days: Intake.allowedDays.contains(days) ? days : defaults.days,
    minutes: Intake.allowedMinutes.contains(minutes)
        ? minutes
        : defaults.minutes,
    lifeStage:
        _wire(LifeStage.values, section['lifeStage']) ?? defaults.lifeStage,
  );

  // Absent means a document written before the walk existed, and the honest
  // reading of that is that she was never asked. She is asked once.
  final setupDone = _bool(section['setupDone']) ?? false;

  return () => AppRouter.intakeRepository.restore(intake, setupDone: setupDone);
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
