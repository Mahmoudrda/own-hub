/// The words R14 and R15 put on the exercise library's vocabulary.
///
/// Every switch is exhaustive, so a muscle or a piece of kit added to the
/// catalogue without a word for it fails to compile rather than showing a
/// wire name to her.
library;

import '../../../l10n/app_l10n.dart';
import '../domain/exercise_library.dart';

String muscleLabel(AppL10n l10n, Muscle muscle) => switch (muscle) {
  Muscle.glutes => l10n.glutes,
  Muscle.quads => l10n.frontOfThighs,
  Muscle.hamstrings => l10n.backOfThighs,
  Muscle.adductors => l10n.innerThighs,
  Muscle.abductors => l10n.outerThighs,
  Muscle.calves => l10n.calves,
  Muscle.core => l10n.core,
  Muscle.obliques => l10n.sidesOfTheWaist,
  Muscle.lowerBack => l10n.lowerBack,
  Muscle.chest => l10n.chest,
  Muscle.lats => l10n.sidesOfTheBack,
  Muscle.upperBack => l10n.upperBack,
  Muscle.frontDelts => l10n.frontOfTheShoulders,
  Muscle.sideDelts => l10n.sidesOfTheShoulders,
  Muscle.rearDelts => l10n.backOfTheShoulders,
  Muscle.biceps => l10n.biceps,
  Muscle.triceps => l10n.triceps,
  Muscle.forearms => l10n.forearms,
};

String sectionLabel(AppL10n l10n, MuscleSection section) => switch (section) {
  MuscleSection.glutes => l10n.glutes,
  MuscleSection.frontOfThighs => l10n.frontOfThighs,
  MuscleSection.backOfThighs => l10n.backOfThighs,
  MuscleSection.innerAndOuterThighs => l10n.innerAndOuterThighs,
  MuscleSection.calves => l10n.calves,
  MuscleSection.absAndSides => l10n.absAndSides,
  MuscleSection.lowerBack => l10n.lowerBack,
  MuscleSection.chest => l10n.chest,
  MuscleSection.upperBack => l10n.upperBack,
  MuscleSection.shoulders => l10n.shoulders,
  MuscleSection.arms => l10n.arms,
};

String equipmentLabel(AppL10n l10n, LibraryEquipment equipment) =>
    switch (equipment) {
      LibraryEquipment.none => l10n.noEquipment,
      LibraryEquipment.mat => l10n.mat,
      LibraryEquipment.dumbbells => l10n.dumbbells,
      LibraryEquipment.bands => l10n.bands,
      LibraryEquipment.kettlebell => l10n.kettlebell,
      LibraryEquipment.bench => l10n.bench,
      LibraryEquipment.step => l10n.step,
      LibraryEquipment.barbell => l10n.barbell,
      LibraryEquipment.cable => l10n.cableMachine,
      LibraryEquipment.machine => l10n.machine,
      LibraryEquipment.smithMachine => l10n.smithMachine,
    };

String placeLabel(AppL10n l10n, ExercisePlace place) => switch (place) {
  ExercisePlace.both => l10n.homeOrGym,
  ExercisePlace.gym => l10n.gymOnly,
};

String levelLabel(AppL10n l10n, ExerciseLevel level) => switch (level) {
  ExerciseLevel.beginner => l10n.beginner,
  ExerciseLevel.intermediate => l10n.intermediate,
};

String angleLabel(AppL10n l10n, ClipAngle angle) => switch (angle) {
  ClipAngle.front => l10n.front,
  ClipAngle.side => l10n.side,
  ClipAngle.rear => l10n.fromBehind,
  ClipAngle.otherSide => l10n.otherSide,
};

/// "Glutes · Back of thighs" for the moves listed under a heading.
String musclesLine(AppL10n l10n, List<Muscle> muscles) =>
    [for (final m in muscles) muscleLabel(l10n, m)].join(' · ');

/// "Dumbbells · Bench".
String equipmentLine(AppL10n l10n, List<LibraryEquipment> equipment) =>
    [for (final e in equipment) equipmentLabel(l10n, e)].join(' · ');
