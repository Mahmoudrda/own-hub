/// Which muscles each move works, for P06 "Your muscles".
///
/// The exercise library (D42) records muscles for every move it holds, and
/// when the phone has the library its row is the answer. But the library
/// arrives from the server after she is verified, and before that it is
/// empty, while her programme's moves and the seed day are on the phone from
/// the first launch. So every move a session can hold has its muscles here
/// too, in the library's own [Muscle] words, so her map is right from her
/// first set.
///
/// The moves the catalogue also lists carry the catalogue's muscles exactly,
/// so the two sources never disagree. The others follow standard anatomy for
/// the move: the muscle that does the work is primary, the ones that steady or
/// help it are secondary.
library;

import 'package:meta/meta.dart';

import '../../train/domain/exercise_library.dart';

/// The muscles one move works.
@immutable
class ExerciseMuscles {
  const ExerciseMuscles({
    required this.primary,
    this.secondary = const <Muscle>[],
    this.stretch = false,
  });

  /// The library's row, in the same shape.
  factory ExerciseMuscles.of(LibraryExercise exercise) => ExerciseMuscles(
    primary: exercise.primaryMuscles,
    secondary: exercise.secondaryMuscles,
    stretch: exercise.kind == ExerciseKind.stretch,
  );

  /// The muscles that do the work.
  final List<Muscle> primary;

  /// The muscles that help or steady it.
  final List<Muscle> secondary;

  /// A stretch or a warm-up drill. Its muscles are named, but holding a
  /// stretch is not training a muscle, so it adds no sets to her map.
  final bool stretch;

  /// How much one set counts toward each section: 1 where a primary muscle
  /// lies, 0.5 where only a helping one does.
  ///
  /// Once per section, at the most it earns there. A row works the lats and
  /// the upper back, which are both "upper back": one set of it is one set
  /// there, not two.
  Map<MuscleSection, double> get sectionWeights => _weigh(sectionOf);

  /// How much one set counts toward each [BodyRegion], the same way.
  Map<BodyRegion, double> get regionWeights {
    final out = <BodyRegion, double>{};
    void add(Muscle muscle, double weight) {
      for (final region in regionsOf(muscle)) {
        final had = out[region] ?? 0;
        if (weight > had) out[region] = weight;
      }
    }

    for (final m in secondary) {
      add(m, 0.5);
    }
    for (final m in primary) {
      add(m, 1);
    }
    return out;
  }

  Map<K, double> _weigh<K>(K Function(Muscle) key) {
    final out = <K, double>{};
    for (final m in secondary) {
      final k = key(m);
      if ((out[k] ?? 0) < 0.5) out[k] = 0.5;
    }
    for (final m in primary) {
      out[key(m)] = 1;
    }
    return out;
  }
}

/// The halves of the body P06 compares.
///
/// Read from the [Muscle], not the section: a shoulder press is the front of
/// the shoulder and a reverse fly is the back of it, and both are filed under
/// "Shoulders".
enum BodyRegion { upper, lower, front, back }

/// The halves [muscle] belongs to. The trunk (abs, sides and lower back) is
/// neither upper nor lower body; the sides of the shoulders and hips, the
/// inner thighs and the forearms are neither front nor back.
Set<BodyRegion> regionsOf(Muscle muscle) => switch (muscle) {
  Muscle.chest ||
  Muscle.frontDelts ||
  Muscle.biceps => {BodyRegion.upper, BodyRegion.front},
  Muscle.lats ||
  Muscle.upperBack ||
  Muscle.rearDelts ||
  Muscle.triceps => {BodyRegion.upper, BodyRegion.back},
  Muscle.sideDelts || Muscle.forearms => {BodyRegion.upper},
  Muscle.quads => {BodyRegion.lower, BodyRegion.front},
  Muscle.glutes ||
  Muscle.hamstrings ||
  Muscle.calves => {BodyRegion.lower, BodyRegion.back},
  Muscle.adductors || Muscle.abductors => {BodyRegion.lower},
  Muscle.core || Muscle.obliques => {BodyRegion.front},
  Muscle.lowerBack => {BodyRegion.back},
};

/// The muscles for [exerciseId]: the library's row when the phone holds one,
/// otherwise the bundled table, otherwise null.
ExerciseMuscles? musclesFor(String exerciseId, ExerciseLibrary library) {
  final row = library.byId(exerciseId);
  if (row != null) return ExerciseMuscles.of(row);
  return bundledExerciseMuscles[exerciseId];
}

/// Every move her programmes, the seed day and the content seed prescribe.
const Map<String, ExerciseMuscles> bundledExerciseMuscles = {
  // The seed day and the demo, which the catalogue does not list.
  'goblet_squat': ExerciseMuscles(
    primary: [Muscle.quads, Muscle.glutes],
    secondary: [Muscle.adductors, Muscle.core],
  ),
  'box_squat': ExerciseMuscles(
    primary: [Muscle.quads, Muscle.glutes],
    secondary: [Muscle.hamstrings, Muscle.adductors],
  ),
  'step_back_lunge': ExerciseMuscles(
    primary: [Muscle.glutes, Muscle.quads],
    secondary: [Muscle.hamstrings, Muscle.adductors],
  ),
  'hip_thrust_hold': ExerciseMuscles(
    primary: [Muscle.glutes],
    secondary: [Muscle.hamstrings, Muscle.core],
  ),
  'plank_hold': ExerciseMuscles(
    primary: [Muscle.core],
    secondary: [Muscle.frontDelts, Muscle.glutes],
  ),

  // Programme moves the catalogue does not list.
  'bird_dog': ExerciseMuscles(
    primary: [Muscle.lowerBack, Muscle.core],
    secondary: [Muscle.glutes, Muscle.frontDelts],
  ),
  'bodyweight_squat': ExerciseMuscles(
    primary: [Muscle.quads, Muscle.glutes],
    secondary: [Muscle.hamstrings, Muscle.adductors],
  ),
  'dead_bug': ExerciseMuscles(
    primary: [Muscle.core],
    secondary: [Muscle.obliques],
  ),
  'glute_bridge': ExerciseMuscles(
    primary: [Muscle.glutes],
    secondary: [Muscle.hamstrings, Muscle.core],
  ),
  'reverse_lunge': ExerciseMuscles(
    primary: [Muscle.glutes, Muscle.quads],
    secondary: [Muscle.hamstrings, Muscle.adductors],
  ),
  'side_plank': ExerciseMuscles(
    primary: [Muscle.obliques],
    secondary: [Muscle.core, Muscle.abductors],
  ),
  'wall_press_up': ExerciseMuscles(
    primary: [Muscle.chest],
    secondary: [Muscle.triceps, Muscle.frontDelts],
  ),

  // The content seed's moves the catalogue does not list. An admin can
  // import them, so a session could hold them.
  'forward_lunge': ExerciseMuscles(
    primary: [Muscle.glutes, Muscle.quads],
    secondary: [Muscle.hamstrings, Muscle.adductors],
  ),
  'hip_thrust': ExerciseMuscles(
    primary: [Muscle.glutes],
    secondary: [Muscle.hamstrings, Muscle.quads],
  ),
  'jumping_jack': ExerciseMuscles(
    primary: [Muscle.calves],
    secondary: [Muscle.abductors, Muscle.adductors, Muscle.sideDelts],
  ),
  'seated_band_row': ExerciseMuscles(
    primary: [Muscle.upperBack, Muscle.lats],
    secondary: [Muscle.rearDelts, Muscle.biceps],
  ),
  'squat_jump': ExerciseMuscles(
    primary: [Muscle.quads, Muscle.glutes],
    secondary: [Muscle.calves, Muscle.hamstrings],
  ),
  // The catalogue lists this one; its muscles are the catalogue's.
  'shoulder_press': ExerciseMuscles(
    primary: [Muscle.frontDelts, Muscle.sideDelts],
    secondary: [Muscle.triceps],
  ),
  'step_up': ExerciseMuscles(
    primary: [Muscle.quads, Muscle.glutes],
    secondary: [Muscle.hamstrings, Muscle.adductors],
  ),
  'suitcase_carry': ExerciseMuscles(
    primary: [Muscle.obliques, Muscle.forearms],
    secondary: [Muscle.core, Muscle.upperBack, Muscle.abductors],
  ),

  // Programme moves the catalogue lists, with the catalogue's muscles.
  'bent_over_row': ExerciseMuscles(
    primary: [Muscle.upperBack, Muscle.lats],
    secondary: [Muscle.rearDelts, Muscle.biceps],
  ),
  'bicycle_crunch': ExerciseMuscles(primary: [Muscle.obliques, Muscle.core]),
  'bodyweight_squat_arm_swing': ExerciseMuscles(
    primary: [Muscle.quads, Muscle.glutes],
  ),
  'calf_raise': ExerciseMuscles(primary: [Muscle.calves]),
  'childs_pose': ExerciseMuscles(
    primary: [Muscle.lowerBack, Muscle.lats],
    secondary: [Muscle.glutes],
    stretch: true,
  ),
  'cross_body_shoulder_stretch': ExerciseMuscles(
    primary: [Muscle.rearDelts],
    secondary: [Muscle.upperBack],
    stretch: true,
  ),
  'donkey_kick': ExerciseMuscles(
    primary: [Muscle.glutes],
    secondary: [Muscle.core],
  ),
  'dumbbell_lateral_raise': ExerciseMuscles(
    primary: [Muscle.sideDelts],
    secondary: [Muscle.upperBack],
  ),
  'dumbbell_reverse_lunge': ExerciseMuscles(
    primary: [Muscle.glutes, Muscle.quads],
    secondary: [Muscle.hamstrings, Muscle.adductors],
  ),
  'dumbbell_stiff_leg_deadlift': ExerciseMuscles(
    primary: [Muscle.hamstrings, Muscle.glutes],
    secondary: [Muscle.lowerBack, Muscle.forearms],
  ),
  'dumbbell_sumo_squat': ExerciseMuscles(
    primary: [Muscle.quads, Muscle.glutes, Muscle.adductors],
    secondary: [Muscle.core],
  ),
  'forearm_plank': ExerciseMuscles(
    primary: [Muscle.core],
    secondary: [Muscle.frontDelts, Muscle.glutes],
  ),
  'half_kneeling_hip_flexor_stretch': ExerciseMuscles(
    primary: [Muscle.quads],
    secondary: [Muscle.glutes],
    stretch: true,
  ),
  'heel_touches': ExerciseMuscles(
    primary: [Muscle.obliques],
    secondary: [Muscle.core],
  ),
  'knee_press_up': ExerciseMuscles(
    primary: [Muscle.chest],
    secondary: [Muscle.triceps, Muscle.frontDelts, Muscle.core],
  ),
  'lat_pulldown_wide': ExerciseMuscles(
    primary: [Muscle.lats],
    secondary: [Muscle.upperBack, Muscle.biceps],
  ),
  'machine_chest_press': ExerciseMuscles(
    primary: [Muscle.chest],
    secondary: [Muscle.frontDelts, Muscle.triceps],
  ),
  'machine_shoulder_press': ExerciseMuscles(
    primary: [Muscle.frontDelts, Muscle.sideDelts],
    secondary: [Muscle.triceps],
  ),
  'pendulum_squat': ExerciseMuscles(
    primary: [Muscle.quads],
    secondary: [Muscle.glutes],
  ),
  'plank': ExerciseMuscles(
    primary: [Muscle.core],
    secondary: [Muscle.frontDelts, Muscle.glutes],
  ),
  'push_up': ExerciseMuscles(
    primary: [Muscle.chest],
    secondary: [Muscle.triceps, Muscle.frontDelts, Muscle.core],
  ),
  'romanian_deadlift': ExerciseMuscles(
    primary: [Muscle.hamstrings, Muscle.glutes],
    secondary: [Muscle.lowerBack, Muscle.forearms],
  ),
  'seated_cable_row': ExerciseMuscles(
    primary: [Muscle.upperBack, Muscle.lats],
    secondary: [Muscle.biceps, Muscle.rearDelts],
  ),
  'seated_leg_curl': ExerciseMuscles(
    primary: [Muscle.hamstrings],
    secondary: [Muscle.calves],
  ),
  'seated_leg_press': ExerciseMuscles(
    primary: [Muscle.quads, Muscle.glutes],
    secondary: [Muscle.hamstrings, Muscle.adductors],
  ),
  'single_arm_machine_row': ExerciseMuscles(
    primary: [Muscle.lats, Muscle.upperBack],
    secondary: [Muscle.rearDelts, Muscle.biceps],
  ),
  'smith_machine_hip_thrust': ExerciseMuscles(
    primary: [Muscle.glutes],
    secondary: [Muscle.hamstrings, Muscle.quads],
  ),
  'standing_forward_fold': ExerciseMuscles(
    primary: [Muscle.hamstrings],
    secondary: [Muscle.lowerBack, Muscle.calves],
    stretch: true,
  ),
  'straight_leg_glute_kickback': ExerciseMuscles(
    primary: [Muscle.glutes],
    secondary: [Muscle.hamstrings],
  ),
  'wall_chest_stretch': ExerciseMuscles(
    primary: [Muscle.chest],
    secondary: [Muscle.frontDelts, Muscle.biceps],
    stretch: true,
  ),
};
