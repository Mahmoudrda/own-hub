/// How long she rests after each move, as she last set it.
///
/// When she shortens or lengthens the rest on R09, the new total becomes that
/// move's rest the next time she trains it. Phone only: it is kept in the
/// local snapshot and is in no cloud document, and Delete everything clears it.
library;

import '../features/train/domain/rest_adjust.dart';
import '../features/train/domain/rest_policy.dart';
import 'app_changes.dart';

class RestTimerPrefs {
  RestTimerPrefs._();

  static final RestTimerPrefs instance = RestTimerPrefs._();

  final Map<String, int> _seconds = <String, int>{};

  /// True once she has set a rest for any move.
  bool get touched => _seconds.isNotEmpty;

  /// The rest she set for [exerciseId], or null when she never changed it.
  Duration? forMove(String? exerciseId) {
    if (exerciseId == null) return null;
    final seconds = _seconds[exerciseId];
    return seconds == null ? null : clampRest(Duration(seconds: seconds));
  }

  /// [forMove], or the standard rest.
  Duration restFor(String? exerciseId) => forMove(exerciseId) ?? kRestDuration;

  /// Keeps [total] as [exerciseId]'s rest. Held between the floor and the
  /// ceiling, so a value that should not exist is never stored.
  void setFor(String exerciseId, Duration total) {
    if (exerciseId.isEmpty) return;
    final seconds = clampRest(total).inSeconds;
    if (_seconds[exerciseId] == seconds) return;
    _seconds[exerciseId] = seconds;
    AppChanges.bump();
  }

  /// For the snapshot.
  Map<String, int> toJson() => Map<String, int>.of(_seconds);

  /// Puts back what the snapshot held. Anything that is not a move id with a
  /// whole number of seconds is dropped.
  void restore(Map<String, int> saved) {
    _seconds
      ..clear()
      ..addEntries([
        for (final entry in saved.entries)
          if (entry.key.isNotEmpty)
            MapEntry(
              entry.key,
              clampRest(Duration(seconds: entry.value)).inSeconds,
            ),
      ]);
  }

  /// Back to no rests of her own. Delete everything, and tests.
  void reset() => _seconds.clear();
}
