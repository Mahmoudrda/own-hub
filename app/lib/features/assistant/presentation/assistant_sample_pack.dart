/// The pack the shipped screens read, standing in for content that has not
/// been built — and an honest account of how small it is.
///
/// G15 assumes a bundled, signed, versioned pack: 124 moves and ~4,100 verified
/// Egyptian foods. That pipeline does not exist. What *does* exist is the
/// seeded content library in `lib/features/admin/domain/seed_library.dart`,
/// where `contraindicationTags` is a **required** column and every exercise row
/// carries a real, authored value.
///
/// So the moves below are the intersection of two things that are both true:
///
///  1. the move's contraindication tags are **authored** in the seeded library,
///     and
///  2. the move's name exists in the dictionary.
///
/// That intersection is three moves. It is a small pack, and saying so is the
/// point — the alternative is to author safety tags here, in a presentation
/// file, for moves nobody has screened. `foods.allergens[]` was left null
/// throughout `eat_sample_library.dart` for exactly that reason: "a fabricated
/// allergen list would make the guard *look* like it works. That is the worst
/// available outcome here." The same applies to a fabricated contraindication
/// tag, which is why there is not one in this file.
///
/// ## The move the design draws, and why it is absent
///
/// `X01` shows "Box squat to a chair · 3 × 10 · less depth" as the second pick.
/// `boxSquatToAChair` and `n310LessDepth` are both in the dictionary — but the
/// seeded library has no `box_squat_to_a_chair` row, so **nothing has said what
/// that move loads.** Offering it would mean inventing its safety tags, and an
/// untagged move is exactly what `ExerciseCandidateFilter` removes. It is
/// recorded here rather than quietly substituted.
///
/// ## No move carries a prescription, and that is the honest state
///
/// `X01`'s design pairs each move with a line like "3 × 12 · nothing on the
/// knee". Those strings are in the dictionary, and every one of them is a
/// **fixed sentence with the mockup's figure inside it** — the defect class
/// `test/baked_in_samples_test.dart` was written to stop, and the one
/// `stated_figure.dart` exists to withhold. The load in her session is
/// prescribed by her coach and read from her plan; nobody has prescribed
/// "12 kg" to the woman reading this screen, and rendering it would tell her
/// the prototype's number as though it were hers.
///
/// So `prescriptionLabel` is left null on all three rows.
/// `AssistantPack`'s own note already says what null means here: the row
/// renders **without a detail line** rather than with an invented one. Saying
/// nothing beats saying a number nobody authored. When the prescription
/// pipeline exists, these come from her plan; until then the pack has no value
/// to give and says so by having none.
///
/// ## The foods are `eat_sample_library.dart`'s, unchanged
///
/// Reused rather than rebuilt, so there is one food pack in the product and one
/// allergen posture. Every row there carries `allergens: null` — **unknown, not
/// none** — which means `AllergyGuard` fails closed for any woman who has named
/// an allergy, and `K27` shows her nothing rather than something unverified.
/// That is the honest state of the content, and it is what ships.
library;

import '../../../domain/safety/contraindication_tag.dart';
import '../../../l10n/app_l10n.dart';
import '../../eat/presentation/eat_sample_library.dart';
import '../domain/assistant_pack.dart';

/// The moves the assistant may select from, in her language.
///
/// Tags, `quiet` and `floorOnly` are copied from the seeded library rows, which
/// are the authored values the content console imports and the safety filter
/// screens on. Nothing here is invented.
List<AssistantExercise> assistantSampleExercises(
  AppL10n l10n,
) => <AssistantExercise>[
  // seed_library: contraindicationTags 'supine_load', quiet, floorOnly.
  AssistantExercise(
    exerciseId: 'glute_bridge',
    name: l10n.gluteBridge,
    tags: const {ContraindicationTag.supineLoad},
    quiet: true,
    floorOnly: true,
    equipment: const {'mat'},
    // No prescriptionLabel: see the file note. The design's line for this
    // row states the mockup's sets and reps.
  ),
  // seed_library: contraindicationTags 'supine_load', quiet, floorOnly.
  AssistantExercise(
    exerciseId: 'dead_bug',
    name: l10n.deadBug,
    tags: const {ContraindicationTag.supineLoad},
    quiet: true,
    floorOnly: true,
    equipment: const {'mat'},
  ),
  // seed_library: contraindicationTags 'deep_knee_flexion', quiet, not floor.
  AssistantExercise(
    exerciseId: 'goblet_squat',
    name: l10n.gobletSquat,
    tags: const {ContraindicationTag.deepKneeFlexion},
    quiet: true,
    floorOnly: false,
    equipment: const {'dumbbells'},
  ),
];

/// The pack the shipped assistant screens read.
///
/// `version` names the stand-in explicitly, so a pick rendered against it can
/// never be mistaken for one selected from the real bundle.
AssistantPack assistantSamplePack(AppL10n l10n) => AssistantPack(
  version: 'sample-pack-unbuilt',
  exercises: assistantSampleExercises(l10n),
  foods: eatSampleLibrary(l10n),
);
