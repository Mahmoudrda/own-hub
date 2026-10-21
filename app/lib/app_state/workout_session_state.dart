/// The session she is actually doing, while she is doing it.
///
/// The training screens are each correct on their own — R07 logs the set it is
/// given, R09 rests, R13 closes a move — but nothing held the thread between
/// them, so the router handed R07 the same move and the same set every time
/// and a finished session changed nothing anywhere. This holds that thread:
/// which day, which move, which set, what she swapped, and what happens when
/// she finishes.
///
/// It owns no numbers of its own. Crediting is [RewardsState]'s: the week
/// (deduped by session id, so one session can never count twice), the points
/// (the ledger refuses the same id twice, and its cap now carries from one
/// session to the next), the level, Today's copy of the week and the streak.
/// One session, one increment, everywhere.
///
/// It does own the session's log bus. Each training screen used to build its
/// own, and a screen's bus died with the screen — cancelling, not committing,
/// whatever was still inside its five seconds. Finishing straight after the
/// last set lost that set, and with it any best it carried. One bus for the
/// whole session, flushed before anything is credited, is what makes the last
/// set as real as the first.
library;

import 'dart:async';

import '../domain/clock/app_clock.dart';
import '../domain/logging/log_command_bus.dart';
import '../domain/rewards/credit_outcome.dart';
import '../domain/rewards/personal_best_detector.dart';
import '../domain/training/prescribed_set.dart';
import '../features/progress/domain/progress_repository.dart';
import '../features/today/domain/today_repository.dart';
import '../features/train/domain/own_best_challenge.dart';
import '../features/train/domain/session_summary.dart';
import '../features/train/domain/train_repository.dart';
import 'app_changes.dart';
import 'rewards_state.dart';
import 'training_streak_state.dart';

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

  /// Where she was before each log, newest last, so Undo on R09 or R13 can put
  /// her back on the set she took back. The bus took the write back; this
  /// takes the position back, which nothing did — she undid a set and was
  /// asked for the next one anyway.
  final List<({int move, int set, int logged})> _history = [];

  LogCommandBus _bus = LogCommandBus();
  int _screens = 0;

  /// Bests the ledger counted for each session, as they were flushed, and the
  /// points it paid for them.
  final Map<String, List<PersonalBest>> _bests = <String, List<PersonalBest>>{};
  final Map<String, int> _bestPoints = <String, int>{};

  /// The weekly challenge as it stood when this session began.
  ChallengeProgress? _challengeAtStart;

  /// The session's one log bus. Every training screen logs through this.
  LogCommandBus get bus => _bus;

  /// A training screen holding [bus] has opened. Counted, so the bus is
  /// committed when the last of them closes rather than when the first does.
  void attachScreen() => _screens++;

  /// A training screen holding [bus] has closed. When it was the last one —
  /// she left the workout — everything still inside its five seconds is
  /// committed, never dropped.
  void detachScreen() {
    if (_screens > 0) _screens--;
    if (_screens == 0) unawaited(_bus.flushAll());
  }

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

  /// Sets of today's session behind her: every set of the moves she has
  /// finished, plus this move's sets before the current one.
  int get setsDone {
    final all = moves;
    var done = 0;
    for (var i = 0; i < _moveIndex && i < all.length; i++) {
      done += all[i].sets.length;
    }
    return done + (_moveIndex < all.length ? _setIndex : 0);
  }

  /// Every set in today's session, her swaps included.
  int get setsTotal {
    var total = 0;
    for (final move in moves) {
      total += move.sets.length;
    }
    return total;
  }

  /// True once every move has been logged or skipped past.
  bool get isComplete => _day != null && _moveIndex >= moves.length;

  bool get isLive => _session != null && !isComplete;

  /// The live session's id, or the fallback the screens use when opened on
  /// their own (from the testing index, say).
  String get sessionId => _session?.id ?? 'session';

  TrainSession? get session => _session;

  TrainSession? _lastFinished;
  SessionSummary? _lastSummary;

  /// What the session [finish] last put away really was, for R10. Null until
  /// its credit has landed — R10 redraws when it does.
  SessionSummary? get lastSummary => _lastSummary;

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
  ///
  /// [challenge] is the weekly challenge as it stands now, so R10 can tell
  /// whether it was this session that met it.
  void start(
    WorkoutDay day,
    TrainRepository repository, {
    ChallengeProgress? challenge,
  }) {
    if (isLive) return;
    _day = day;
    _moveIndex = 0;
    _setIndex = 0;
    _loggedSets = 0;
    _startedAt = AppClock.now();
    _swaps.clear();
    _lastSwap = null;
    _history.clear();
    _challengeAtStart = challenge;
    repository.startSession(day).then((session) {
      _session = session;
      AppChanges.bump();
    });
    AppChanges.bump();
  }

  /// Puts [fresh], the same day read in the language on screen now, in place of
  /// the one the session began with, so a woman who switches language
  /// mid-session sees the title and every set line in her language.
  ///
  /// Only when it is the same day with the same moves in the same order, which
  /// is what a language change produces; her position and swaps stay as they
  /// are. Does not notify: the caller bumps [AppChanges] when this returns
  /// true, which it does only when the wording actually changed.
  bool relabel(WorkoutDay fresh) {
    final day = _day;
    if (day == null || !isLive) return false;
    if (day.id != fresh.id ||
        day.planVersion != fresh.planVersion ||
        day.moves.length != fresh.moves.length) {
      return false;
    }
    for (var i = 0; i < day.moves.length; i++) {
      if (day.moves[i].exerciseId != fresh.moves[i].exerciseId ||
          day.moves[i].sets.length != fresh.moves[i].sets.length) {
        return false;
      }
    }
    final reworded =
        day.title != fresh.title ||
        day.summary != fresh.summary ||
        day.constraints != fresh.constraints;
    _day = fresh;
    return reworded;
  }

  /// One set logged: the next set of this move, or the next move.
  void setLogged() {
    final move = currentMove;
    if (move == null) return;
    _remember();
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
    _remember();
    _loggedSets += move.sets.length - _setIndex;
    _advanceMove();
    AppChanges.bump();
  }

  void _advanceMove() {
    _moveIndex++;
    _setIndex = 0;
  }

  void _remember() =>
      _history.add((move: _moveIndex, set: _setIndex, logged: _loggedSets));

  /// Puts her back where she was before the last log. Called only after the
  /// bus has actually taken that log back, so the position and the write move
  /// together. False when there is nothing to step back to.
  bool undoLast() {
    if (_history.isEmpty) return false;
    final last = _history.removeLast();
    _moveIndex = last.move;
    _setIndex = last.set;
    _loggedSets = last.logged;
    AppChanges.bump();
    return true;
  }

  /// The bests the ledger counted while flushing [sessionId]'s moves.
  void noteBests(
    String sessionId,
    Iterable<PersonalBest> bests, {
    int points = 0,
  }) {
    if (bests.isEmpty) return;
    (_bests[sessionId] ??= <PersonalBest>[]).addAll(bests);
    _bestPoints[sessionId] = (_bestPoints[sessionId] ?? 0) + points;
  }

  /// R05: she is doing something else instead of the current move. The
  /// prescription travels with it — the alternative is a different exercise,
  /// not a different amount of work.
  ///
  /// [record] false leaves the repository write to the caller, which holds it
  /// for the swap's undo window.
  void swapCurrent(
    MoveAlternative alternative,
    TrainRepository repository, {
    bool record = true,
  }) {
    final move = currentMove;
    if (move == null) return;
    if (record) {
      repository.swapMove(
        sessionId: sessionId,
        fromExerciseId: move.exerciseId,
        toExerciseId: alternative.exerciseId,
      );
    }
    _lastSwap = (key: move.exerciseId, previous: _swaps[move.exerciseId]);
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

  /// The swap [swapCurrent] last made, so Undo on R05 can take it back.
  ({String key, PlannedMove? previous})? _lastSwap;

  /// Puts back the move the last swap replaced. False when there is none.
  bool undoSwap() {
    final last = _lastSwap;
    if (last == null) return false;
    _lastSwap = null;
    final previous = last.previous;
    if (previous == null) {
      _swaps.remove(last.key);
    } else {
      _swaps[last.key] = previous;
    }
    AppChanges.bump();
    return true;
  }

  /// R06's "Skip this move": on to the next move with nothing logged for this
  /// one. Remembered like a log, so Undo puts her back on it.
  void skipMove() {
    if (currentMove == null) return;
    _remember();
    _advanceMove();
    AppChanges.bump();
  }

  /// Ends the session and credits it once — to the week, to Today's own copy
  /// of the week, to her points and to the streak — and keeps a summary of it
  /// for R10.
  ///
  /// In this order: the session is captured synchronously (the caller does not
  /// await this and pushes R10 in its next statement); every log still inside
  /// its undo window is committed; the session is closed; then it is credited.
  /// Crediting before the last flush credited a session without its last move,
  /// and any best on that move never reached R10.
  ///
  /// Idempotent by session id at every step, so a second tap on "finish"
  /// credits nothing twice.
  Future<SessionSummary?> finish({
    required TrainRepository repository,
    required InMemoryTodayRepository today,
    required ProgressStore progress,
    EndedReason reason = EndedReason.finished,
    ChallengeProgress? Function()? challengeNow,
  }) async {
    final session = _session;
    if (session == null) return null;
    // A second finish for the same session — R09's clock and a tap landing
    // together — waits for the first rather than crediting again and
    // replacing its summary with an empty one.
    final running = _finishing;
    if (running != null && _finishingId == session.id) return running;
    final done = _finish(
      session,
      repository: repository,
      today: today,
      progress: progress,
      reason: reason,
      challengeNow: challengeNow,
    );
    _finishing = done;
    _finishingId = session.id;
    try {
      return await done;
    } finally {
      if (_finishingId == session.id) {
        _finishing = null;
        _finishingId = null;
      }
    }
  }

  Future<SessionSummary?>? _finishing;
  String? _finishingId;

  Future<SessionSummary?> _finish(
    TrainSession session, {
    required TrainRepository repository,
    required InMemoryTodayRepository today,
    required ProgressStore progress,
    required EndedReason reason,
    ChallengeProgress? Function()? challengeNow,
  }) async {
    _lastFinished = session;
    _lastSummary = null;
    final seconds = _startedAt == null
        ? 0
        : AppClock.now().difference(_startedAt!).inSeconds;
    final challengeAtStart = _challengeAtStart;
    final moveNames = <String, String>{
      for (final move in moves) move.exerciseId: move.name,
      // The move a swap replaced keeps its name too: a best found while
      // flushing is filed under the exercise she actually did.
      for (final swapped in _swaps.values) swapped.exerciseId: swapped.name,
    };

    await _bus.flushAll();
    await repository.finishSession(
      sessionId: session.id,
      durationSec: seconds,
      reason: reason,
    );
    final credit = RewardsState.instance.creditSession(
      sessionId: session.id,
      source: session.source,
      today: today,
      progress: progress,
    );

    final trainingStreakState = TrainingStreakState.instance;
    final summary = summarise(
      sessionId: session.id,
      source: session.source,
      flushes: repository is InMemoryTrainRepository
          ? repository.flushes
          : const <FlushRecord>[],
      durationSec: seconds,
      credit: credit,
      bests: _bests.remove(session.id) ?? const <PersonalBest>[],
      challengeBefore: challengeAtStart,
      challengeAfter: challengeNow?.call(),
      trainingStreak: trainingStreakState.settings().enabled
          ? trainingStreakState.status(progress: progress)
          : null,
      moveNames: moveNames,
      bestPoints: _bestPoints.remove(session.id) ?? 0,
    );

    _session = null;
    _day = null;
    _moveIndex = 0;
    _setIndex = 0;
    _startedAt = null;
    _history.clear();
    _challengeAtStart = null;
    _lastSummary = summary;
    AppChanges.bump();
    return summary;
  }

  /// Credits one session everywhere it counts. Used by the live session and by
  /// T02's "I already did it", so a recalled session and a trained one take
  /// exactly the same path — and the same protections against counting twice.
  static CreditOutcome creditSession({
    required String sessionId,
    required SessionSource source,
    required InMemoryTodayRepository today,
    required ProgressStore progress,
    DateTime? now,
    bool creditToday = true,
  }) => RewardsState.instance.creditSession(
    sessionId: sessionId,
    source: source,
    today: today,
    progress: progress,
    now: now,
    creditToday: creditToday,
  );

  /// When the live session began, for a snapshot.
  DateTime? get startedAt => _startedAt;

  /// Her swaps by the move they replace, for a snapshot.
  Map<String, PlannedMove> get swappedMoves =>
      Map<String, PlannedMove>.unmodifiable(_swaps);

  /// Puts back a session that was under way when the app was closed, on the
  /// same move and set. The session itself is the repository's, restored
  /// beside it. Her undo history and the weekly challenge's starting point do
  /// not come back: nothing in them is worth a stale guess.
  void restoreLive({
    required WorkoutDay day,
    required TrainSession session,
    required int moveIndex,
    required int setIndex,
    required int loggedSets,
    DateTime? startedAt,
    Map<String, PlannedMove> swaps = const <String, PlannedMove>{},
  }) {
    _day = day;
    _session = session;
    _moveIndex = moveIndex;
    _setIndex = setIndex;
    _loggedSets = loggedSets;
    _startedAt = startedAt;
    _swaps
      ..clear()
      ..addAll(swaps);
    _history.clear();
    AppChanges.bump();
  }

  /// For tests: back to no session.
  void reset() {
    _day = null;
    _session = null;
    _lastFinished = null;
    _lastSummary = null;
    _history.clear();
    _bests.clear();
    _bestPoints.clear();
    _challengeAtStart = null;
    _bus.dispose();
    _bus = LogCommandBus();
    _screens = 0;
    _moveIndex = 0;
    _setIndex = 0;
    _loggedSets = 0;
    _startedAt = null;
    _openedMove = null;
    _swaps.clear();
    _lastSwap = null;
  }
}
