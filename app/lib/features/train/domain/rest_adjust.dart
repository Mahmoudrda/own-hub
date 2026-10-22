/// The rest timer's steps and limits.
///
/// R09 offers fifteen seconds less or more. The total never goes under
/// [kRestFloor] and never over [kRestCeiling], which is the longest rest a
/// workout may author.
library;

import 'workout_library.dart' show WorkoutLimits;

const Duration kRestStep = Duration(seconds: 15);
const Duration kRestFloor = Duration(seconds: 15);
const Duration kRestCeiling = Duration(seconds: WorkoutLimits.maxRestSeconds);

/// [total] held between the floor and the ceiling.
Duration clampRest(Duration total) {
  if (total < kRestFloor) return kRestFloor;
  if (total > kRestCeiling) return kRestCeiling;
  return total;
}

/// Whether a rest of [total] with [remaining] left can be shortened by a step
/// without ending it or going under the floor.
bool canShortenRest(Duration total, Duration remaining) =>
    total - kRestStep >= kRestFloor && remaining > kRestStep;

/// Whether a rest of [total] can be lengthened by a step.
bool canLengthenRest(Duration total) => total + kRestStep <= kRestCeiling;
