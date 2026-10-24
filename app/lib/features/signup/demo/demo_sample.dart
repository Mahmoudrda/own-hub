/// The sample week the tour (`C04`) draws the real screens with.
///
/// Everything here is a **fresh object**, built when the tour opens and
/// dropped when it closes. None of it is an `AppRouter` singleton, so the
/// snapshot that writes her day to the phone (`local_persistence.dart`) and
/// the cloud store never see it, and a woman who leaves the tour has nothing
/// of it left behind.
///
/// The repositories are the in-memory ones the screens are built against,
/// with every write refused: the call reports to [DemoRefusals], which opens
/// the join sheet, and the state stays exactly as it was. See
/// `lib/app_state/demo_mode.dart` for why a refused write that must return a
/// session never completes rather than failing.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../domain/clock/app_clock.dart';
import '../../../domain/logging/log_command_bus.dart';
import '../../../domain/rewards/rewards.dart';
import '../../../domain/training/prescribed_set.dart';
import '../../../domain/rewards/week_rollup.dart';
import '../../../domain/rewards/weekly_goal.dart';
import '../../../domain/week/week_key.dart';
import '../../cycle/domain/cycle_document.dart';
import '../../cycle/domain/cycle_projection_reconciler.dart';
import '../../cycle/domain/period_entry.dart';
import '../../eat/data/seeded_recipe_library.dart';
import '../../eat/domain/meal_repository.dart';
import '../../eat/presentation/eat_sample_library.dart' show sampleMealPlan;
import '../../progress/presentation/milestones_view.dart'
    show authoredMilestones;
import '../../progress/presentation/progress_view_model.dart';
import '../../today/domain/today_day.dart';
import '../../today/domain/today_repository.dart';
import '../../train/domain/train_repository.dart';

/// Where the sample repositories report a write they refused.
class DemoRefusals {
  /// Opens the join sheet. Set by the tour once it is on screen.
  VoidCallback? listener;

  /// How many writes were refused. Read by tests.
  int count = 0;

  void refuse() {
    count++;
    listener?.call();
  }
}

/// A write that has to hand back a session, refused.
///
/// Never completes. See the library note: a failed future that nobody awaits
/// is an uncaught error, and in a release build that is a crash report.
Future<T> _neverCompletes<T>() => Completer<T>().future;

/// Home's sample day: one session of three done, a walk to count, breakfast
/// logged. The cycle row is off: before sign-in the cycle is not named.
///
/// The prototype's day ([InMemoryTodayRepository.defaultDay]) dated today,
/// without its "Week 3 of 8": that programme does not exist, and the badge
/// would name it.
TodayDay demoDay(DateTime now) {
  final prototype = InMemoryTodayRepository.defaultDay(date: now);
  return TodayDay(
    date: prototype.date,
    state: prototype.state,
    arc: prototype.arc,
    week: prototype.week,
    walkToCount: prototype.walkToCount,
    walkMinutes: prototype.walkMinutes,
    mealLoggedAt: prototype.mealLoggedAt,
    plates: prototype.plates,
    showCycleCard: false,
  );
}

/// Today, refusing every write.
class DemoTodayRepository extends InMemoryTodayRepository {
  DemoTodayRepository({required TodayDay day, required this.refusals})
    : super(day: day);

  final DemoRefusals refusals;

  @override
  Future<void> countWalk() async => refusals.refuse();

  @override
  Future<void> logRecalledSession(RecalledSession session) async =>
      refusals.refuse();

  @override
  Future<void> completeStep(FirstWeekStep step) async => refusals.refuse();

  /// A notice is not her data, and asking her to join to dismiss one would be
  /// absurd. Nothing is kept either way.
  @override
  Future<void> markNoticeSeen(NoticeKind kind, WeekKey week) async {}

  @override
  void recordMeal({required DateTime at, List<PlateSuggestion>? plates}) =>
      refusals.refuse();

  @override
  void recordSession(String sessionId) => refusals.refuse();

  @override
  void setShowCycleCard(bool show) {}
}

/// Train, refusing every write.
class DemoTrainRepository extends InMemoryTrainRepository {
  DemoTrainRepository({super.day, required this.refusals});

  final DemoRefusals refusals;

  @override
  Future<TrainSession> startSession(WorkoutDay day) {
    refusals.refuse();
    return _neverCompletes();
  }

  @override
  Future<void> swapMove({
    required String sessionId,
    required String fromExerciseId,
    required String toExerciseId,
  }) async => refusals.refuse();

  @override
  Future<void> flushMove({
    required String sessionId,
    required String exerciseId,
    required List<LoggedSet> sets,
  }) async => refusals.refuse();

  @override
  Future<TrainSession> finishSession({
    required String sessionId,
    required int durationSec,
    EndedReason reason = EndedReason.finished,
  }) {
    refusals.refuse();
    return _neverCompletes();
  }

  @override
  Future<TrainSession> logRecalled({
    required String dateKey,
    required RecallMethod method,
    String? assignmentId,
    List<LoggedSet> sets = const <LoggedSet>[],
    int durationSec = 0,
  }) {
    refusals.refuse();
    return _neverCompletes();
  }

  @override
  Future<TrainSession> logUnplanned({
    required String dateKey,
    required String activity,
    required int durationSec,
  }) {
    refusals.refuse();
    return _neverCompletes();
  }
}

/// Eat, refusing every write. Holds this week's sample dinners.
class DemoMealRepository extends InMemoryMealRepository {
  DemoMealRepository({required String weekId, required this.refusals})
    : super(plans: {weekId: sampleMealPlan(weekId)});

  final DemoRefusals refusals;

  @override
  Future<void> applyLog(MealWrite write) async => refusals.refuse();

  @override
  Future<void> recordPlate(PlateObservation observation) async =>
      refusals.refuse();

  @override
  Future<void> savePrefs(EatPrefs prefs) async => refusals.refuse();

  @override
  Future<void> swapDinner({
    required String weekId,
    required PlanDay day,
    required String recipeId,
  }) async => refusals.refuse();

  @override
  Future<void> tickGrocery({
    required String weekId,
    required String itemKey,
    required bool ticked,
  }) async => refusals.refuse();
}

/// The undo bus, refusing every log.
///
/// A screen submits a log and offers five seconds to take it back before the
/// write. In the tour there is nothing to take back: the log is withdrawn the
/// moment it is made and the join sheet opens, rather than five seconds later
/// when the write would have been refused.
class DemoLogCommandBus extends LogCommandBus {
  DemoLogCommandBus({required this.refusals});

  final DemoRefusals refusals;

  @override
  LogHandle submit(UndoableLog log) {
    final handle = super.submit(log);
    handle.undo();
    refusals.refuse();
    return handle;
  }
}

/// The whole sample, built once when the tour opens.
class DemoSample {
  /// The minutes in each of the sample's finished sessions.
  static const int sessionMinutes = 25;

  /// Days back from today of the sample sessions the tour lists, newest first:
  /// today's is the one this week's figure counts. The others are a week or
  /// more back, so they are in an earlier week whatever day the tour opens.
  static const List<int> sessionDaysAgo = [0, 8, 10];

  DemoSample._({
    required this.now,
    required this.refusals,
    required this.today,
    required this.train,
    required this.meal,
    required this.bus,
    required this.cycle,
    required this.periods,
    required this.progress,
    this.book,
  });

  /// [book] is Rahma's, when it has already been read. Null and the tour
  /// reads the bundled seed itself; the tour asks the network for no data.
  factory DemoSample.build({DateTime? now, RecipeBook? book}) {
    final at = now ?? AppClock.now();
    final today = DateTime(at.year, at.month, at.day);
    final refusals = DemoRefusals();

    // Three periods, twenty-nine days apart, the last one nine days ago.
    final periods = <PeriodEntry>[
      for (final daysAgo in const [9, 38, 67])
        switch (PeriodEntry.validate(
          start: today.subtract(Duration(days: daysAgo)),
          end: today.subtract(Duration(days: daysAgo - 4)),
          today: today,
        )) {
          PeriodValid(:final entry) => entry,
          PeriodInvalid() => throw StateError('the sample period is invalid'),
        },
    ];
    final cycle = const CycleProjectionReconciler().apply(
      CycleDocument(mode: CycleMode.datesAndSymptoms, cycleLengthDays: 29),
      periods,
    );

    final thisWeek = WeekKey.of(at);
    final progress = ProgressSummary.from(
      goal: WeeklyGoal(
        sessionsTarget: 3,
        countedWeeks: 2,
        currentRun: 2,
        recent8: [
          for (final weeksAgo in const [2, 1])
            WeekBar(
              week: WeekKey.of(at.subtract(Duration(days: 7 * weeksAgo))),
              sessionsLogged: 3,
              sessionsTarget: 3,
              counted: true,
            ),
        ],
      ),
      // Seven sessions over three weeks, two of them counted: the first
      // session and the first counted week are the milestones that earns.
      rewards: Rewards(
        points: 120,
        sessionsLogged: 7,
        milestones: {
          'first_session': today.subtract(const Duration(days: 16)),
          'first_counted_week': today.subtract(const Duration(days: 8)),
        },
      ),
      currentWeek: WeekDoc(
        week: thisWeek,
        sessionsTarget: 3,
        creditedSessionIds: const ['sample-session'],
      ),
      milestoneCount: authoredMilestones.count,
    );

    return DemoSample._(
      now: at,
      refusals: refusals,
      today: DemoTodayRepository(day: demoDay(at), refusals: refusals),
      train: DemoTrainRepository(refusals: refusals),
      meal: DemoMealRepository(weekId: thisWeek.id, refusals: refusals),
      bus: DemoLogCommandBus(refusals: refusals),
      cycle: cycle,
      periods: periods,
      progress: progress,
      book: book,
    );
  }

  final DateTime now;
  final DemoRefusals refusals;
  final DemoTodayRepository today;
  final DemoTrainRepository train;
  final DemoMealRepository meal;
  final DemoLogCommandBus bus;
  final CycleDocument cycle;
  final List<PeriodEntry> periods;
  final ProgressSummary progress;

  /// Rahma's book. Filled in by the tour once the bundled seed is read.
  RecipeBook? book;

  /// Drops anything still pending. Called when the tour closes.
  void dispose() {
    refusals.listener = null;
    bus.dispose();
    unawaited(today.dispose());
    unawaited(meal.dispose());
  }
}
