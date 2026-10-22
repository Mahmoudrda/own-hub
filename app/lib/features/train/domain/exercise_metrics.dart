/// What each move is measured on, from the bundled content pack.
///
/// `PersonalBestDetector` reads this locally and never from Firestore (G8 §3),
/// so detection costs no reads beyond the bests themselves. It also **fails
/// closed**: an exercise this map does not describe has no metric to be
/// compared on, so it can never set a best. That is the safe direction — the
/// alternative is guessing a metric and recording a best that is not one.
///
/// [bundledExerciseMetrics] is the six legacy ids the first screens name.
/// [allExerciseMetrics] adds every move of the starting programmes and the
/// catalogue, from `exercise_traits.dart`; a legacy id keeps its own entry.
///
/// **No progression family is authored here.** `BestMetric.variation` — "moved
/// to the harder version" — needs a family, a rank and sibling ids, and
/// inventing a ladder of exercises that do not exist would put a fabricated
/// progression behind a real celebration. The detector implements the branch
/// and P03 renders it; no move carries a family yet.
library;

import '../../../domain/rewards/personal_best_detector.dart';
import 'exercise_traits.dart';

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

/// The six legacy moves plus every bundled and synced move, for detection.
Map<String, ExerciseMeta> allExerciseMetrics() => <String, ExerciseMeta>{
  ...ExerciseTraits.traitsMetrics(),
  ...bundledExerciseMetrics,
};
