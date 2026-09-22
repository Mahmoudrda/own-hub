/// What each move is measured on, from the bundled content pack.
///
/// `PersonalBestDetector` reads this locally and never from Firestore (G8 §3),
/// so detection costs no reads beyond the bests themselves. It also **fails
/// closed**: an exercise this map does not describe has no metric to be
/// compared on, so it can never set a best. That is the safe direction — the
/// alternative is guessing a metric and recording a best that is not one — but
/// it means an untagged move costs a woman a best she earned, which is why this
/// map has to cover everything the product actually prescribes.
///
/// ## Seed data, and only for the moves that exist
///
/// `DECISIONS.md` D20: library content is authored now as working seed data so
/// the guards have something to read, and the owner replaces it later. These are
/// the six ids the product names today — the five R03 prescribes and the plank
/// P03 renders. The 124-title library will supply the rest, at which point this
/// map is replaced wholesale rather than extended by hand.
///
/// **No progression family is authored here.** `BestMetric.variation` — "moved
/// to the harder version" — needs a family, a rank and sibling ids, and
/// inventing a ladder of exercises that do not exist would put a fabricated
/// progression behind a real celebration. The detector implements the branch and
/// P03 renders it; it stays unpopulated until the library lands, and that is
/// reported as a content gap rather than papered over.
library;

import '../../../domain/rewards/personal_best_detector.dart';

/// Metric by exercise id. Fails closed for anything absent.
const Map<String, ExerciseMeta> bundledExerciseMetrics = <String, ExerciseMeta>{
  // Bodyweight, so there is no load to beat — more reps at no less weight.
  'glute_bridge': ExerciseMeta(
    exerciseId: 'glute_bridge',
    metric: BestMetric.reps,
  ),
  // Held at the chest: the load is the thing.
  'goblet_squat': ExerciseMeta(
    exerciseId: 'goblet_squat',
    metric: BestMetric.load,
  ),
  'step_back_lunge': ExerciseMeta(
    exerciseId: 'step_back_lunge',
    metric: BestMetric.reps,
  ),
  // Timed, not counted. R03 prescribes it in seconds and nothing else in the
  // product could detect it until `actualHoldSec` was carried across (D19).
  'hip_thrust_hold': ExerciseMeta(
    exerciseId: 'hip_thrust_hold',
    metric: BestMetric.hold,
  ),
  'plank_hold': ExerciseMeta(exerciseId: 'plank_hold', metric: BestMetric.hold),
  'dead_bug': ExerciseMeta(exerciseId: 'dead_bug', metric: BestMetric.reps),
};
