/// The walk she is on, kept as times and not as a running count.
///
/// A walk is minutes, so the clock is arithmetic on two stored times: when she
/// started, and how long she held it paused. A phone put in a pocket, an app
/// sent to the background or killed mid-walk, loses nothing: the next draw
/// reads the same two times. The snapshot keeps them (`walk`), so a walk
/// survives a restart, and a walk she finished but has not yet logged or
/// dropped survives too.
///
/// It owns no calories and no points. The estimate is `energy_estimate.dart`'s,
/// and logging is the router's, through the same unplanned-session path as a
/// session she did without the phone. Nothing here touches what she eats.
library;

import '../domain/clock/app_clock.dart';
import 'app_changes.dart';

class WalkSessionState {
  WalkSessionState._();

  static final WalkSessionState instance = WalkSessionState._();

  DateTime? _startedAt;
  DateTime? _pausedAt;
  int _pausedMs = 0;
  int? _finishedSec;

  /// She has started and not finished.
  bool get isWalking => _startedAt != null;

  bool get isPaused => _pausedAt != null;

  /// A finished walk waiting for her to log it or drop it, in seconds.
  int? get finishedSeconds => _finishedSec;

  /// Whether there is anything to keep on the phone.
  bool get touched => isWalking || _finishedSec != null;

  /// Starts a walk. Nothing happens while one is under way or waiting.
  void start([DateTime? now]) {
    if (isWalking || _finishedSec != null) return;
    _startedAt = now ?? AppClock.now();
    _pausedAt = null;
    _pausedMs = 0;
    AppChanges.bump();
  }

  void pause([DateTime? now]) {
    if (!isWalking || isPaused) return;
    _pausedAt = now ?? AppClock.now();
    AppChanges.bump();
  }

  void resume([DateTime? now]) {
    final at = _pausedAt;
    if (at == null) return;
    _pausedMs += (now ?? AppClock.now()).difference(at).inMilliseconds;
    _pausedAt = null;
    AppChanges.bump();
  }

  /// Time walked so far, not counting the pauses.
  Duration elapsed([DateTime? now]) {
    final started = _startedAt;
    if (started == null) return Duration.zero;
    final on = now ?? AppClock.now();
    final heldNow = _pausedAt == null
        ? 0
        : on.difference(_pausedAt!).inMilliseconds;
    final ms = on.difference(started).inMilliseconds - _pausedMs - heldNow;
    return Duration(milliseconds: ms < 0 ? 0 : ms);
  }

  /// Ends the walk and keeps its length until she logs or drops it. Returns
  /// the seconds, or null when no walk was under way.
  int? finish([DateTime? now]) {
    if (!isWalking) return null;
    final seconds = elapsed(now).inSeconds;
    _startedAt = null;
    _pausedAt = null;
    _pausedMs = 0;
    _finishedSec = seconds;
    AppChanges.bump();
    return seconds;
  }

  /// Drops the walk, under way or finished, with nothing recorded.
  void discard() {
    if (!touched) return;
    reset();
    AppChanges.bump();
  }

  /// A walk that was logged: the waiting length is no longer waiting.
  void logged() => discard();

  Map<String, Object?> toJson() => <String, Object?>{
    'startedAt': ?_startedAt?.toIso8601String(),
    'pausedAt': ?_pausedAt?.toIso8601String(),
    'pausedMs': _pausedMs,
    'finishedSec': ?_finishedSec,
  };

  void restore({
    DateTime? startedAt,
    DateTime? pausedAt,
    int pausedMs = 0,
    int? finishedSec,
  }) {
    _startedAt = startedAt;
    _pausedAt = startedAt == null ? null : pausedAt;
    _pausedMs = startedAt == null || pausedMs < 0 ? 0 : pausedMs;
    _finishedSec = startedAt == null ? finishedSec : null;
  }

  /// Account deletion, sign-out and tests.
  void reset() {
    _startedAt = null;
    _pausedAt = null;
    _pausedMs = 0;
    _finishedSec = null;
  }
}
