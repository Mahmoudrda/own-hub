/// The session she is actually doing, while she is doing it.
///
/// The training screens are each correct on their own — R07 logs the set it is
/// given, R09 rests, R13 closes a move — but nothing held the thread between
/// them, so the router handed R07 the same move and the same set every time
/// and a finished session changed nothing anywhere. This holds that thread:
/// which day, which move, which set, what she swapped, and what happens when
/// she finishes.
///
/// It owns no numbers of its own. The week is credited through [WeekRollup]
/// (which dedupes by session id, so one session can never count twice), the
/// points through [AwardTable] and [AwardLedger] (which refuse to award the
/// same id twice), the level through [LevelCurve], and Today's own copy of the
/// week through the repository it already reads. One session, one increment,
/// everywhere.
library;

import '../domain/clock/app_clock.dart';
import '../domain/rewards/award_ledger.dart';
import '../domain/rewards/award_table.dart';
// The award table speaks the training domain's SessionSource; the train
// feature has one of its own with the same three values. One translation,
// here, rather than an alias that hides which is which.
import '../domain/training/session.dart' as training;
import '../domain/rewards/level_curve.dart';
import '../domain/rewards/week_rollup.dart';
import '../domain/training/prescribed_set.dart';
import '../domain/week/week_key.dart';
import '../features/progress/domain/progress_repository.dart';
import '../features/today/domain/today_repository.dart';
import '../features/train/domain/train_repository.dart';
import 'app_changes.dart';

class WorkoutSessionState {
  WorkoutSessionState._();

  static final WorkoutSessionState instance = WorkoutSessionState._();

  WorkoutDay? _day;
  TrainSession? _session;
  int _moveIndex = 0;
  int _setIndex = 0;
  int _loggedSets = 0;
  DateTime? _startedAt;

  /// Replacements she chose on R05, by the exercise they replace.
  final Map<String, PlannedMove> _swaps = <String, PlannedMove>{};

  /// The day being trained, as R03 lists it.
  WorkoutDay? get day => _day;

  /// The day's moves with her swaps applied, in order.
  List<PlannedMove> get moves => [
    for (final move in _day?.moves ?? const <PlannedMove>[])
      _swaps[move.exerciseId] ?? move,
  ];

  /// The move she is on, or null when there is no live session.
  PlannedMove? get currentMove {
    final all = moves;
    if (all.isEmpty || _moveIndex >= all.length) return null;
    return all[_moveIndex];
  }

  /// Zero-based, within [currentMove].
  int get setIndex => _setIndex;

  /// How many moves are behind her: zero-based, and also the count of moves
  /// struck off.
  ///
  /// R13 was handed [loggedSetCount] for this — a count of *sets* rendered as
  /// moves — so two moves of three sets each read "6 of 5".
  int get moveIndex => _moveIndex;

  /// How many moves today's session holds, her swaps included.
  int get moveCount => moves.length;

  /// The move she tapped on R03 to watch it.
  ///
  /// R03's `onOpenMove` threw its argument away and R04 was built with no move
  /// at all, so tapping "Dead bug" opened a demo of a goblet squat — a move
  /// that is not in the session. This carries the one she asked for.
  PlannedMove? get openedMove => _openedMove;
  PlannedMove? _openedMove;

  void openMove(PlannedMove move) => _openedMove = move;

  /// The set she is being asked for, or null when there is no live session.
  PrescribedSet? get currentSet {
    final move = currentMove;
    if (move == null || _setIndex >= move.sets.length) return null;
    return move.sets[_setIndex];
  }

  int get loggedSetCount => _loggedSets;

  /// True once every move has been logged or skipped past.
  bool get isComplete => _day != null && _moveIndex >= moves.length;

  bool get isLive => _session != null && !isComplete;

  /// The live session's id, or the fallback the screens use when opened on
  /// their own (from the testing index, say).
  String get sessionId => _session?.id ?? 'session';

  TrainSession? get session => _session;

  TrainSession? _lastFinished;

  /// The session [finish] last put away, still readable after it has cleared
  /// the live one.
  ///
  /// R10 reports on a session it must be *told* about: it decides whether a
  /// personal best is even possible from `session.source`, and with nothing
  /// passed it used to treat the absence as permission and draw the trophy for
  /// everybody. `finish` nulls [session] before the route builds, so the router
  /// reads this instead.
  TrainSession? get lastFinished => _lastFinished;

  /// Starts [day] if nothing is live. Safe to call from a tap on R01, R03 or
  /// Today: a session already under way is left alone.
  void start(WorkoutDay day, TrainRepository repository) {
    if (isLive) return;
    _day = day;
    _moveIndex = 0;
    _setIndex = 0;
    _loggedSets = 0;
    _startedAt = AppClock.now();
    _swaps.clear();
    repository.startSession(day).then((session) {
      _session = session;
      AppChanges.bump();
    });
    AppChanges.bump();
  }

  /// One set logged: the next set of this move, or the next move.
  void setLogged() {
    final move = currentMove;
    if (move == null) return;
    _loggedSets++;
    if (_setIndex + 1 < move.sets.length) {
      _setIndex++;
    } else {
      _advanceMove();
    }
    AppChanges.bump();
  }

  /// Every remaining set of this move at once — R13's "I did all 3 sets".
  void moveLogged() {
    final move = currentMove;
    if (move == null) return;
    _loggedSets += move.sets.length - _setIndex;
    _advanceMove();
    AppChanges.bump();
  }

  void _advanceMove() {
    _moveIndex++;
    _setIndex = 0;
  }

  /// R05: she is doing something else instead of the current move. The
  /// prescription travels with it — the alternative is a different exercise,
  /// not a different amount of work.
  void swapCurrent(MoveAlternative alternative, TrainRepository repository) {
    final move = currentMove;
    if (move == null) return;
    repository.swapMove(
      sessionId: sessionId,
      fromExerciseId: move.exerciseId,
      toExerciseId: alternative.exerciseId,
    );
    _swaps[move.exerciseId] = PlannedMove(
      exerciseId: alternative.exerciseId,
      name: alternative.name,
      prescriptionLabel: move.prescriptionLabel,
      quiet: move.quiet,
      floorOnly: move.floorOnly,
      sets: [
        for (final set in move.sets)
          PrescribedSet(
            exerciseId: alternative.exerciseId,
            order: set.order,
            weightKg: set.weightKg,
            reps: set.reps,
            holdSeconds: set.holdSeconds,
          ),
      ],
    );
    AppChanges.bump();
  }

  /// Ends the session and credits it once — to the week, to Today's own copy
  /// of the week, and to her points.
  ///
  /// Idempotent by session id at every step, so a second tap on "finish"
  /// credits nothing twice.
  Future<void> finish({
    required TrainRepository repository,
    required InMemoryTodayRepository today,
    required ProgressStore progress,
    EndedReason reason = EndedReason.finished,
  }) async {
    final session = _session;
    if (session == null) return;
    // Synchronously, before the first await: the caller does not await this and
    // pushes R10 in the next statement.
    _lastFinished = session;
    final seconds = _startedAt == null
        ? 0
        : AppClock.now().difference(_startedAt!).inSeconds;
    await repository.finishSession(
      sessionId: session.id,
      durationSec: seconds,
      reason: reason,
    );
    creditSession(
      sessionId: session.id,
      source: session.source,
      today: today,
      progress: progress,
    );
    _session = null;
    _day = null;
    _moveIndex = 0;
    _setIndex = 0;
    _startedAt = null;
    AppChanges.bump();
  }

  /// Credits one session everywhere it counts. Used by the live session and by
  /// T02's "I already did it", so a recalled session and a trained one take
  /// exactly the same path — and the same protections against counting twice.
  static void creditSession({
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
    if (credit.alreadyCredited) return;
    progress.weeks[key.id] = credit.week;

    // Points: one award id per session, refused on replay by the ledger.
    final ledger = AwardLedger(points: progress.rewards.points);
    final award = const AwardTable().award(
      SessionLogged(sessionId: sessionId, source: _asTraining(source)),
    );
    ledger.record(award, dayKey: _dayKey(on));
    const curve = LevelCurve();
    progress.rewards = progress.rewards.copyWith(
      points: ledger.points,
      level: curve.levelFor(ledger.points),
      pointsToNextLevel: curve.pointsToNextLevel(ledger.points),
      sessionsLogged: progress.rewards.sessionsLogged + 1,
    );

    // Today keeps its own copy of the week so Home can render offline; it is
    // deduped by the same session id.
    if (creditToday) today.recordSession(sessionId);
    AppChanges.bump();
  }

  static training.SessionSource _asTraining(SessionSource source) =>
      switch (source) {
        SessionSource.live => training.SessionSource.live,
        SessionSource.recalled => training.SessionSource.recalled,
        SessionSource.unplanned => training.SessionSource.unplanned,
      };

  /// `yyyy-MM-dd`, the id the daily cap and every day document are keyed by.
  static String _dayKey(DateTime on) =>
      '${on.year.toString().padLeft(4, '0')}-'
      '${on.month.toString().padLeft(2, '0')}-'
      '${on.day.toString().padLeft(2, '0')}';

  /// For tests: back to no session.
  void reset() {
    _day = null;
    _session = null;
    _lastFinished = null;
    _moveIndex = 0;
    _setIndex = 0;
    _loggedSets = 0;
    _startedAt = null;
    _openedMove = null;
    _swaps.clear();
  }
}
