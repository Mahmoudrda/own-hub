/// §2.5 — the single definition of "severe".
///
/// Plan §5: "The single definition of severe: **`cramps == 'severe'` or
/// `bleeding == 'heavy'`**. Evaluated before any suggestion is built; the
/// resolver calls it first and returns immediately."
///
/// It is published to G4 and G5 as well as used here, because "a severe day
/// suppresses the Train row and the meal-suggestion card too, not only Y03's.
/// Y11's note — 'never a meal-based answer' — is this call" (§7.2).
///
/// One definition, one call site per consumer. Two implementations of "severe"
/// would drift, and the one that drifted would be the one that let a workout
/// through.
library;

import 'today_check_in.dart';

class SevereSymptomGate {
  const SevereSymptomGate();

  /// Whether today's check-in is a severe day.
  ///
  /// Takes the check-in and nothing else, for the same reason
  /// `SymptomSuggestionResolver.resolve` does: a date must not be able to make a
  /// day severe, and it cannot be passed here.
  bool evaluate(TodayCheckIn checkIn) =>
      checkIn.cramps == Cramps.severe || checkIn.bleeding == Bleeding.heavy;
}
