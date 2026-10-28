/// A rough energy figure for a finished session: MET x body weight x hours.
///
/// It is an estimate and is always shown as one. A MET is how many times the
/// resting rate a kind of effort costs; two values are used, the ones the
/// published compendium gives for resistance training done at an ordinary
/// pace and for the same work done in circuit style. Nothing here knows her
/// heart rate or her build, so the figure is never a target, a budget or
/// advice.
///
/// Pure.
library;

/// The weight used when she has not told the app hers.
const double defaultBodyWeightKg = 65;

/// Strength work at an ordinary pace, with rests between sets.
const double steadyStrengthMet = 3.5;

/// Circuit-style or high-rep work with short rests.
const double hardCircuitMet = 5.0;

/// An ordinary, unhurried walk on a firm surface. The compendium gives about
/// 3.0 at 2.5 mph and 3.5 at 3 mph; this is the low end, so a walk's figure is
/// never flattering. The pace is not measured, so there is one value.
const double walkingMet = 3.0;

/// A session left open for hours is almost always a forgotten one; the
/// estimate stops counting at this length.
const int maxEstimatedSeconds = 3 * 3600;

/// Seconds per logged set (the set and its rest together) at or under which a
/// session reads as circuit style. The data holds no rest times, so density
/// stands in for them: a short rest is what makes the cycle short.
const int circuitSecondsPerSet = 75;

/// Average reps a set must reach, together with a still tight cycle, for
/// high-rep work to read as hard.
const int highRepAverage = 15;

/// The longest cycle at which high reps still read as hard.
const int highRepSecondsPerSet = 100;

enum EffortKind { steady, hard, walk }

/// Reads the pattern of a session: how long each logged set took, rest
/// included, and how many reps a rep set had on average.
///
/// [repSets] is the number of logged sets that had reps; [totalReps] is their
/// reps. Both are optional; hold-only sessions pass neither.
EffortKind classifyEffort({
  required int durationSec,
  required int sets,
  int repSets = 0,
  int totalReps = 0,
}) {
  if (sets <= 0 || durationSec <= 0) return EffortKind.steady;
  final perSet = durationSec / sets;
  if (perSet <= circuitSecondsPerSet) return EffortKind.hard;
  if (repSets > 0 &&
      totalReps / repSets >= highRepAverage &&
      perSet <= highRepSecondsPerSet) {
    return EffortKind.hard;
  }
  return EffortKind.steady;
}

double metFor(EffortKind kind) => switch (kind) {
  EffortKind.hard => hardCircuitMet,
  EffortKind.steady => steadyStrengthMet,
  EffortKind.walk => walkingMet,
};

/// The weight to calculate with: hers when it is a believable one, else the
/// default.
double bodyWeightOrDefault(double? kg) =>
    kg != null && kg >= 30 && kg <= 250 ? kg : defaultBodyWeightKg;

/// Kilocalories for [durationSec] of [kind] at [bodyWeightKg], rounded to a
/// whole number. Zero when there was no time.
int estimateKcal({
  required int durationSec,
  required EffortKind kind,
  double? bodyWeightKg,
}) {
  if (durationSec <= 0) return 0;
  final seconds = durationSec > maxEstimatedSeconds
      ? maxEstimatedSeconds
      : durationSec;
  return (metFor(kind) * bodyWeightOrDefault(bodyWeightKg) * seconds / 3600)
      .round();
}
