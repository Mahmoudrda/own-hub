/// D41 — her rewards, paid honestly, on her phone.
///
/// The reward engine in `domain/rewards/` was built and tested, and almost none
/// of it ran. Only session points were ever paid; a fresh [AwardLedger] was
/// built for every session, so the daily cap never carried from one to the
/// next; nothing ever closed a week, so counted weeks, runs, the rest-week bank
/// and every milestone stayed at their starting values for every woman. Three
/// screens meanwhile announced rewards nobody paid.
///
/// This is the one place that pays. It owns the two things the ledger needs to
/// be honest across sessions — the award ids already made and today's cap — and
/// it is the only caller of [AwardLedger.record] in the app:
///
/// - **A session** pays through the table, under the cap.
/// - **A counted week** pays once, the moment a session or a lowered target
///   takes the week to its goal. Weeks counted before this existed are not
///   back-paid: there is no record of them to pay from.
/// - **A real personal best** pays when it beats one she already had. A first
///   mark on a move she never logged is a record, not an improvement.
/// - **A food day** pays on the first meal of the day.
/// - **A milestone** pays once, when the count behind it is reached.
/// - **Weeks close** when the app opens or comes back, empty weeks included, so
///   a run that should have ended does, and the rest-week bank fills.
///
/// Everything stays on the phone (D41). `firestore.rules` refuses a client
/// write to `rewards` and `weeklyGoal`, and nothing here tries one.
library;

import '../domain/clock/app_clock.dart';
import '../domain/format/day_key.dart';
import '../domain/rewards/award_ledger.dart';
import '../domain/rewards/award_table.dart';
import '../domain/rewards/credit_outcome.dart';
import '../domain/rewards/daily_cap.dart';
import '../domain/rewards/level_curve.dart';
import '../domain/rewards/personal_best_detector.dart';
import '../domain/rewards/rest_week_repair.dart';
import '../domain/rewards/week_rollup.dart';
import '../domain/rewards/weekly_goal.dart';
// The award table speaks the training domain's SessionSource; the train
// feature has one of its own with the same three values.
import '../domain/training/session.dart' as training;
import '../domain/week/week_calendar.dart';
import '../domain/week/week_key.dart';
import '../features/progress/domain/milestone.dart';
import '../features/progress/domain/progress_repository.dart';
import '../features/progress/presentation/milestones_view.dart'
    show authoredMilestones;
import '../features/today/domain/today_repository.dart';
import '../features/train/domain/session_bests_bridge.dart';
import '../features/train/domain/train_repository.dart';
import 'app_changes.dart';
import 'training_streak_state.dart';

/// How many session, meal and best ids are kept. Week and milestone ids are
/// kept for ever: there are few of them, and forgetting one would pay it again.
const int kKeptAwardIds = 600;

class RewardsState {
  RewardsState._();

  static final RewardsState instance = RewardsState._();

  final Set<String> _awardIds = <String>{};
  DailyCapState _cap = const DailyCapState.fresh('');

  /// What each award under the daily cap actually paid, by award id. A session,
  /// a best and a food day can be taken back when she removes what earned it,
  /// and the cap may have paid less than the table says, so what comes off is
  /// what was paid, never the table's figure.
  final Map<String, int> _granted = <String, int>{};

  /// Milestone id to what earned it: `session:<id>` or `meal:<day>`. A
  /// milestone is taken back only when she removes the very thing that earned
  /// it and her count no longer reaches it.
  final Map<String, String> _earnedBy = <String, String>{};

  /// The awards already made, as the snapshot keeps them.
  Set<String> get awardIds => Set<String>.unmodifiable(_awardIds);

  /// What each capped award paid, as the snapshot keeps it.
  Map<String, int> get grantedPoints => Map<String, int>.unmodifiable(_granted);

  /// What earned each milestone, as the snapshot keeps it.
  Map<String, String> get milestoneSources =>
      Map<String, String>.unmodifiable(_earnedBy);

  /// Today's cap, as the snapshot keeps it.
  DailyCapState get capState => _cap;

  /// Puts back what the phone remembered.
  void restore({
    Iterable<String> awardIds = const <String>[],
    DailyCapState? cap,
    Map<String, int> granted = const <String, int>{},
    Map<String, String> earnedBy = const <String, String>{},
  }) {
    _awardIds
      ..clear()
      ..addAll(awardIds);
    _cap = cap ?? const DailyCapState.fresh('');
    _granted
      ..clear()
      ..addAll(granted);
    _earnedBy
      ..clear()
      ..addAll(earnedBy);
  }

  /// Account deletion, and tests.
  void reset() {
    _awardIds.clear();
    _cap = const DailyCapState.fresh('');
    _granted.clear();
    _earnedBy.clear();
  }

  /// Offers [award] to the ledger and keeps what it decided. Returns the points
  /// actually granted: zero for a replay, part or none when the cap is reached.
  int _record(
    Award award, {
    required ProgressStore progress,
    required DateTime on,
  }) {
    final ledger = AwardLedger(
      today: _cap,
      existingAwardIds: _awardIds,
      points: progress.rewards.points,
    );
    final entry = ledger.record(award, dayKey: dayKey(on));
    if (entry.refusal == LedgerRefusal.duplicate) return 0;
    _awardIds.add(award.awardId);
    if (award.underDailyCap) _granted[award.awardId] = entry.granted;
    _cap = ledger.capState;
    _setPoints(progress, ledger.points);
    _prune();
    return entry.granted;
  }

  /// Her points, and the level that follows from them. Never below zero.
  static void _setPoints(ProgressStore progress, int points) {
    final kept = points < 0 ? 0 : points;
    const curve = LevelCurve();
    progress.rewards = progress.rewards.copyWith(
      points: kept,
      level: curve.levelFor(kept),
      pointsToNextLevel: curve.pointsToNextLevel(kept),
    );
  }

  /// Credits one session everywhere it counts — the week, Today's copy of it,
  /// her points, the streak — exactly once per session id.
  CreditOutcome creditSession({
    required String sessionId,
    required SessionSource source,
    required InMemoryTodayRepository today,
    required ProgressStore progress,
    DateTime? now,
    bool creditToday = true,
  }) {
    final on = now ?? AppClock.now();
    final key = WeekKey.of(on);
    final week =
        progress.weeks[key.id] ??
        WeekDoc(week: key, sessionsTarget: progress.goal.sessionsTarget);
    final credit = const WeekRollup().creditSession(
      week: week,
      sessionId: sessionId,
    );
    if (credit.alreadyCredited) {
      return CreditOutcome(
        alreadyCredited: true,
        loggedBefore: week.sessionsLogged,
        loggedAfter: week.sessionsLogged,
        target: week.sessionsTarget,
        levelBefore: progress.rewards.level,
        levelAfter: progress.rewards.level,
      );
    }

    // A session that ran past midnight is credited to the day it finished.
    // Home moves to that day first, while the new week has nothing in it, so
    // the one recordSession below is the only count Home adds; rolled after
    // the week is written, Home would read this session and then add it again.
    if (creditToday) today.rollTo(on);

    // Read before anything moves: two closed weeks with nothing in them, after
    // she had trained before, is what "came back" means.
    final cameBack = _returningAfterBreak(progress);
    final levelBefore = progress.rewards.level;
    progress.weeks[key.id] = credit.week;
    progress.rewards = progress.rewards.copyWith(
      sessionsLogged: progress.rewards.sessionsLogged + 1,
    );

    final sessionPoints = _record(
      const AwardTable().award(
        SessionLogged(sessionId: sessionId, source: _asTraining(source)),
      ),
      progress: progress,
      on: on,
    );
    final weekPoints = credit.countedNow
        ? _record(
            const AwardTable().award(WeekCounted(week: key)),
            progress: progress,
            on: on,
          )
        : 0;
    final beforeMilestones = progress.rewards.points;
    final milestones = awardMilestones(
      progress: progress,
      now: on,
      cameBack: cameBack,
      earnedBy: 'session:$sessionId',
    );
    final milestonePoints = progress.rewards.points - beforeMilestones;

    if (creditToday) today.recordSession(sessionId);
    TrainingStreakState.instance.noteCredit(on, progress: progress);
    AppChanges.bump();

    return CreditOutcome(
      sessionPoints: sessionPoints,
      weekPoints: weekPoints,
      weekCountedNow: credit.countedNow,
      loggedBefore: week.sessionsLogged,
      loggedAfter: credit.week.sessionsLogged,
      target: credit.week.sessionsTarget,
      levelBefore: levelBefore,
      levelAfter: progress.rewards.level,
      milestonesEarned: milestones,
      milestonePoints: milestonePoints,
    );
  }

  /// What crediting [sessionId] would do, without doing it: the session and
  /// week points it would pay under today's cap (milestones are decided by the
  /// credit itself), and where her week would stand.
  ///
  /// For a screen that announces a session still inside its undo window. The
  /// credit itself waits for the window to close, so Undo never has a credit
  /// to take back.
  ({int points, int loggedAfter, int target}) previewSession({
    required String sessionId,
    required SessionSource source,
    required ProgressStore progress,
    DateTime? now,
  }) {
    final on = now ?? AppClock.now();
    final key = WeekKey.of(on);
    final week =
        progress.weeks[key.id] ??
        WeekDoc(week: key, sessionsTarget: progress.goal.sessionsTarget);
    final credit = const WeekRollup().creditSession(
      week: week,
      sessionId: sessionId,
    );
    if (credit.alreadyCredited) {
      return (
        points: 0,
        loggedAfter: week.sessionsLogged,
        target: week.sessionsTarget,
      );
    }
    var points = _available(
      const AwardTable().award(
        SessionLogged(sessionId: sessionId, source: _asTraining(source)),
      ),
      on,
    );
    if (credit.countedNow) {
      points += _available(
        const AwardTable().award(WeekCounted(week: key)),
        on,
      );
    }
    return (
      points: points,
      loggedAfter: credit.week.sessionsLogged,
      target: credit.week.sessionsTarget,
    );
  }

  int _available(Award award, DateTime on) {
    if (_awardIds.contains(award.awardId)) return 0;
    return const DailyCap()
        .apply(state: _cap, dayKey: dayKey(on), award: award)
        .granted;
  }

  /// Takes one session's own credit back, when she removes the session.
  ///
  /// What comes back: the session from its week's count, one from her
  /// sessions logged, the points the session itself paid, Today's copy of the
  /// week and the streak's count for [on]'s day. With [bests], every personal
  /// best the session set and the points they paid, and the running best on
  /// each move goes back to what she held without it. And any milestone this
  /// session earned that her counts no longer reach.
  ///
  /// What stays: a week that already counted stays counted, with its award.
  /// `WeekRollup` never un-counts a week (G6 §4.3), and a removal is not
  /// allowed to be the one way round that; a closed week loses the session
  /// from its count and its bar, and keeps its verdict. Today's cap is not
  /// given back either, so logging and removing cannot be used to farm points.
  ///
  /// The points come off as they were paid, from the record [_record] keeps.
  /// [sessionPoints] and [bestPoints] are what the caller saw paid, used only
  /// where the phone has no record (a document from an older build).
  ///
  /// Returns false when the session was never credited.
  bool uncreditSession({
    required String sessionId,
    required SessionSource source,
    required InMemoryTodayRepository today,
    required ProgressStore progress,
    int sessionPoints = 0,
    int bestPoints = 0,
    SessionBestsBridge? bests,
    InMemoryTrainRepository? train,
    DateTime? now,
  }) {
    final on = now ?? AppClock.now();
    String? weekId;
    for (final entry in progress.weeks.entries) {
      if (entry.value.creditedSessionIds.contains(sessionId)) {
        weekId = entry.key;
        break;
      }
    }
    if (weekId == null) return false;
    final week = progress.weeks[weekId]!;
    // `copyWith` cannot walk `counted` back, so a counted week stays counted.
    progress.weeks[weekId] = week.copyWith(
      creditedSessionIds: [
        for (final id in week.creditedSessionIds)
          if (id != sessionId) id,
      ],
    );
    if (week.isClosed) _lowerClosedBar(progress, week.week);

    final award = const AwardTable().award(
      SessionLogged(sessionId: sessionId, source: _asTraining(source)),
    );
    _awardIds.remove(award.awardId);
    final sessionPaid = _granted.remove(award.awardId) ?? sessionPoints;

    // Her bests from this session, and what they paid.
    final suffix = ':$sessionId';
    final bestIds = [
      for (final id in _awardIds)
        if (id.startsWith('best:') && id.endsWith(suffix)) id,
    ];
    var bestPaid = 0;
    var bestRecorded = false;
    for (final id in bestIds) {
      _awardIds.remove(id);
      final paid = _granted.remove(id);
      if (paid != null) {
        bestPaid += paid;
        bestRecorded = true;
      }
    }
    if (!bestRecorded) bestPaid = bestPoints;
    if (bests != null) {
      bests.forget(
        sessionId,
        flushes: train?.flushes ?? const [],
        sessionById: train?.sessionById,
      );
    }

    final logged = progress.rewards.sessionsLogged;
    progress.rewards = progress.rewards.copyWith(
      sessionsLogged: logged > 0 ? logged - 1 : 0,
      bestsCount: bests?.ledger.bestsCount,
    );
    _setPoints(progress, progress.rewards.points - sessionPaid - bestPaid);
    _revokeMilestones('session:$sessionId', progress: progress, on: on);

    today.unrecordSession(sessionId);
    TrainingStreakState.instance.noteUncredit(on);
    AppChanges.bump();
    return true;
  }

  /// Takes back the personal bests a discarded workout set before she put it
  /// away: the bests and their count, the points they paid, and any milestone
  /// they earned that her counts no longer reach. Today's cap is not given
  /// back, as in [uncreditSession]. The session itself was never credited.
  void uncreditPersonalBests({
    required String sessionId,
    required ProgressStore progress,
    required SessionBestsBridge bests,
    InMemoryTrainRepository? train,
    DateTime? now,
  }) {
    final on = now ?? AppClock.now();
    final suffix = ':$sessionId';
    var paid = 0;
    for (final id in [
      for (final id in _awardIds)
        if (id.startsWith('best:') && id.endsWith(suffix)) id,
    ]) {
      _awardIds.remove(id);
      paid += _granted.remove(id) ?? 0;
    }
    bests.forget(
      sessionId,
      flushes: train?.flushes ?? const [],
      sessionById: train?.sessionById,
    );
    progress.rewards = progress.rewards.copyWith(
      bestsCount: bests.ledger.bestsCount,
    );
    _setPoints(progress, progress.rewards.points - paid);
    _revokeMilestones('session:$sessionId', progress: progress, on: on);
    AppChanges.bump();
  }

  /// A closed week's bar on Progress, one session lower. Its verdict stays.
  static void _lowerClosedBar(ProgressStore progress, WeekKey week) {
    final bars = progress.goal.recent8;
    final at = bars.indexWhere((bar) => bar.week == week);
    if (at < 0) return;
    final bar = bars[at];
    progress.goal = progress.goal.copyWith(
      recent8: [
        for (var i = 0; i < bars.length; i++)
          if (i == at)
            WeekBar(
              week: bar.week,
              sessionsLogged: bar.sessionsLogged > 0
                  ? bar.sessionsLogged - 1
                  : 0,
              sessionsTarget: bar.sessionsTarget,
              counted: bar.counted,
              repairedByRestWeek: bar.repairedByRestWeek,
            )
          else
            bars[i],
      ],
    );
  }

  /// Takes back each milestone [source] earned that her counts no longer
  /// reach, and the points it paid. "Came back" was earned by the session
  /// itself, so it goes with it.
  void _revokeMilestones(
    String source, {
    required ProgressStore progress,
    required DateTime on,
    MilestoneCatalogue catalogue = authoredMilestones,
  }) {
    final counts = milestoneCounts(progress, now: on);
    final kept = <String, DateTime>{...progress.rewards.milestones};
    var points = 0;
    for (final milestone in catalogue.milestones) {
      if (_earnedBy[milestone.id] != source) continue;
      if (!kept.containsKey(milestone.id)) continue;
      final stillMet =
          milestone.measure != MilestoneMeasure.cameBack &&
          counts.of(milestone.measure) >= milestone.target;
      if (stillMet) continue;
      kept.remove(milestone.id);
      _earnedBy.remove(milestone.id);
      final award = const AwardTable().award(
        MilestoneReached(milestoneId: milestone.id),
      );
      if (_awardIds.remove(award.awardId)) points += award.points;
    }
    if (kept.length == progress.rewards.milestones.length) return;
    progress.rewards = progress.rewards.copyWith(milestones: kept);
    _setPoints(progress, progress.rewards.points - points);
  }

  /// Pays for bests that beat one she already had, at most three a day (the
  /// cap's own rule). A first mark — no previous value — pays nothing.
  int creditPersonalBests(
    Iterable<PersonalBest> counted, {
    required String sessionId,
    required ProgressStore progress,
    DateTime? now,
  }) {
    final on = now ?? AppClock.now();
    var granted = 0;
    for (final best in counted) {
      if (best.previous == null) continue;
      granted += _record(
        const AwardTable().award(
          PersonalBestSet(exerciseId: best.exerciseId, sessionId: sessionId),
        ),
        progress: progress,
        on: on,
      );
    }
    awardMilestones(
      progress: progress,
      now: on,
      earnedBy: 'session:$sessionId',
    );
    return granted;
  }

  /// The first meal she logs on [day] (`yyyy-MM-dd`) pays once.
  int creditFoodDay({
    required String day,
    required ProgressStore progress,
    DateTime? now,
  }) {
    final on = now ?? AppClock.now();
    final granted = _record(
      const AwardTable().award(FoodDayLogged(dayId: day)),
      progress: progress,
      on: on,
    );
    awardMilestones(progress: progress, now: on, earnedBy: 'meal:$day');
    if (granted > 0) AppChanges.bump();
    return granted;
  }

  /// Takes [day]'s food-day credit back, when she removes the last meal of
  /// the day: the points it paid, and a milestone it earned that her count no
  /// longer reaches. Today's cap is not given back. Returns false when the day
  /// had not paid.
  bool uncreditFoodDay({
    required String day,
    required ProgressStore progress,
    DateTime? now,
  }) {
    final on = now ?? AppClock.now();
    final award = const AwardTable().award(FoodDayLogged(dayId: day));
    if (!_awardIds.remove(award.awardId)) return false;
    final paid = _granted.remove(award.awardId) ?? 0;
    _setPoints(progress, progress.rewards.points - paid);
    _revokeMilestones('meal:$day', progress: progress, on: on);
    AppChanges.bump();
    return true;
  }

  /// What a meal logged on [day] would pay, without paying it. Zero once the
  /// day has paid, while another meal of the same day is still waiting in its
  /// undo window, or when the cap has nothing left.
  int foodDayPointsAvailable(String day, {bool anotherPendingToday = false}) {
    final award = const AwardTable().award(FoodDayLogged(dayId: day));
    if (anotherPendingToday || _awardIds.contains(award.awardId)) return 0;
    return const DailyCap()
        .apply(state: _cap, dayKey: day, award: award)
        .granted;
  }

  /// Her new weekly target, applied to the goal and to the week she is in.
  ///
  /// Raising it changes this week only through the goal she reads next week —
  /// a week's document keeps the target it started with. Lowering it can count
  /// the week, and that pays the week once, like any other way of reaching it.
  void retargetCurrentWeek(
    int target, {
    required ProgressStore progress,
    DateTime? now,
  }) {
    final on = now ?? AppClock.now();
    final key = WeekKey.of(on);
    final existing = progress.weeks[key.id];
    if (existing == null) {
      progress.weeks[key.id] = WeekDoc(week: key, sessionsTarget: target);
      return;
    }
    final next = const WeekRollup().retarget(existing, target);
    progress.weeks[key.id] = next;
    if (!existing.counted && next.counted) {
      _record(
        const AwardTable().award(WeekCounted(week: key)),
        progress: progress,
        on: on,
      );
      awardMilestones(progress: progress, now: on);
    }
  }

  /// Closes every week before this one that is still open, empty weeks
  /// included, through [RestWeekRepair] — the same rules, the same order.
  ///
  /// Returns null when there was nothing to close. Safe to call on every
  /// start and every resume: a closed week is never closed again.
  WeekCloseRun? closeStaleWeeks({
    required ProgressStore progress,
    DateTime? now,
  }) {
    final on = now ?? AppClock.now();
    final current = WeekKey.of(on);
    final known = [for (final doc in progress.weeks.values) doc.week]..sort();
    final from =
        progress.goal.lastClosedWeek ?? (known.isEmpty ? null : known.first);
    if (from == null) return null;

    // A week she logged nothing in has no document, and a week with no
    // document can never close — so her run never ended and the bank never
    // learned it was missed. Give each one an empty document first.
    for (final week in weeksBetween(from, current, max: kRecentWeekWindow)) {
      progress.weeks.putIfAbsent(
        week.id,
        () => WeekDoc(week: week, sessionsTarget: progress.goal.sessionsTarget),
      );
    }

    final unclosed = [
      for (final doc in progress.weeks.values)
        if (!doc.isClosed && doc.week.compareTo(current) < 0) doc,
    ];
    if (unclosed.isEmpty) return null;

    final run = const RestWeekRepair().closeStaleWeeks(
      unclosed: unclosed,
      goal: progress.goal,
      closedAt: on,
    );
    for (final decision in run.decisions) {
      progress.weeks[decision.week.week.id] = decision.week;
    }
    // Older than the window the repair looks at: stamped closed so they are
    // not offered to it again on every start, for ever.
    for (final week in run.skippedWeeks) {
      final doc = progress.weeks[week.id];
      if (doc != null && !doc.isClosed) {
        progress.weeks[week.id] = doc.copyWith(closedAt: on);
      }
    }
    progress.goal = run.goal;
    awardMilestones(progress: progress, now: on);
    return run;
  }

  /// Pays every authored milestone her counts have reached and nobody has paid
  /// yet. Returns their ids, in catalogue order.
  ///
  /// [earnedBy] names what was just credited (`session:<id>`, `meal:<day>`),
  /// so removing it later can take back what it alone earned.
  List<String> awardMilestones({
    required ProgressStore progress,
    DateTime? now,
    bool cameBack = false,
    String? earnedBy,
    MilestoneCatalogue catalogue = authoredMilestones,
  }) {
    final on = now ?? AppClock.now();
    final counts = milestoneCounts(progress, now: on);
    final reached = <String>[];
    for (final milestone in catalogue.milestones) {
      if (progress.rewards.milestones.containsKey(milestone.id)) continue;
      final met = milestone.measure == MilestoneMeasure.cameBack
          ? cameBack
          : counts.of(milestone.measure) >= milestone.target;
      if (!met) continue;
      _record(
        const AwardTable().award(MilestoneReached(milestoneId: milestone.id)),
        progress: progress,
        on: on,
      );
      progress.rewards = progress.rewards.copyWith(
        milestones: {...progress.rewards.milestones, milestone.id: on},
      );
      if (earnedBy != null) _earnedBy[milestone.id] = earnedBy;
      reached.add(milestone.id);
    }
    return reached;
  }

  /// The counts the milestones are measured against, from what she has done.
  ///
  /// A week that has already counted but is not over yet is included: making
  /// her wait for Monday to see "first counted week" would be the app knowing
  /// and not saying.
  MilestoneCounts milestoneCounts(ProgressStore progress, {DateTime? now}) {
    final current = progress.weeks[WeekKey.of(now ?? AppClock.now()).id];
    final openAndCounted =
        current != null && !current.isClosed && current.counted;
    return MilestoneCounts(
      sessions: progress.rewards.sessionsLogged,
      countedWeeks: progress.goal.countedWeeks + (openAndCounted ? 1 : 0),
      personalBests: progress.rewards.bestsCount,
      foodDays: _awardIds.where((id) => id.startsWith('meal:')).length,
    );
  }

  /// Two closed weeks with no session, after she had trained before.
  static bool _returningAfterBreak(ProgressStore progress) {
    if (progress.rewards.sessionsLogged == 0) return false;
    final bars = progress.goal.recent8;
    if (bars.length < 2) return false;
    final lastTwo = bars.sublist(bars.length - 2);
    return lastTwo.every((bar) => bar.sessionsLogged == 0);
  }

  void _prune() {
    final perishable = [
      for (final id in _awardIds)
        if (!id.startsWith('week:') && !id.startsWith('milestone:')) id,
    ];
    if (perishable.length <= kKeptAwardIds) return;
    // Ids carry a date or a session number, not an order, so the oldest are
    // the first ones added: a Set keeps insertion order.
    for (final id in perishable.take(perishable.length - kKeptAwardIds)) {
      _awardIds.remove(id);
      _granted.remove(id);
    }
  }

  static training.SessionSource _asTraining(SessionSource source) =>
      switch (source) {
        SessionSource.live => training.SessionSource.live,
        SessionSource.recalled => training.SessionSource.recalled,
        SessionSource.unplanned => training.SessionSource.unplanned,
      };
}
