/// The local library pack — where every quantity on screen actually comes from.
///
/// G15 D2: the model returns ids and a template key, and **every number is
/// looked up here, by id**. That is what makes an invented quantity
/// unrenderable rather than merely wrong: a hallucinated `exerciseId` finds no
/// row, so there is no row to read sets and reps from, so no figure reaches the
/// screen. `assistant_wire.dart` removes the other half of the problem by
/// having no numeric field for the model to put one in.
///
/// ## Safety runs before selection, and it is not re-implemented here
///
/// `lib/domain/safety/` already owns the move half and `lib/features/eat/domain/`
/// owns the food half, both with tests. This pack **consumes** them:
///
///  * [screenExercises] is `ExerciseCandidateFilter.screen` — the avoid list
///    applied to the candidate set *before* ranking, so a removed move is never
///    in the list to begin with. `P0-ASK-09` asks for exactly this, and it asks
///    for it to be visible in instrumentation rather than inferred: [screenExercises]
///    returns the survivors, and there is no blocked-but-present representation
///    for a widget to find and render.
///  * [screenFoods] is `AllergyGuard.screen` — unchanged, allergens removed
///    before ranking rather than validated after.
///
/// Two safety guards with different shapes is how one of them ends up weaker,
/// so neither is reshaped here.
///
/// ## Why a move may carry no prescription label
///
/// [AssistantExercise.prescriptionLabel] is nullable and **null means the
/// dictionary has no phrase for this move**, never "no prescription". The row
/// renders without a detail line rather than with an invented "3 × 10". Saying
/// nothing beats saying a number nobody authored — the position
/// `stated_figure.dart` already takes for the rest of the product.
///
/// ## Why the pack is an interface and not a constant
///
/// The real pack is a signed build artefact: 124 moves and ~4,100 foods,
/// bundled and versioned, read zero times from Firestore. It does not exist
/// yet. [AssistantPack] is therefore constructed by the caller, so the shipped
/// screens can pass the honest stand-in while tests pass fixtures — and so the
/// day the real pack lands, nothing in this file changes.
library;

import 'package:meta/meta.dart';

import '../../../domain/safety/client_constraints.dart';
import '../../../domain/safety/contraindication_tag.dart';
import '../../../domain/safety/exercise_candidate_filter.dart';
import '../../eat/domain/allergy_guard.dart';
import '../../eat/domain/food_library.dart';
import 'assistant_wire.dart';

/// One move in the pack.
@immutable
class AssistantExercise {
  const AssistantExercise({
    required this.exerciseId,
    required this.name,
    required this.tags,
    required this.quiet,
    required this.floorOnly,
    this.prescriptionLabel,
    this.equipment = const <String>{},
  });

  final String exerciseId;

  /// What she reads, resolved from the dictionary by the pack builder.
  final String name;

  /// **Null means unauthored**, never "carries none" — the distinction
  /// `ScreenableExercise.tags` draws, and for the same reason: an untagged move
  /// is unknown content, and unknown content is not safe content.
  final Set<ContraindicationTag>? tags;

  final bool quiet;
  final bool floorOnly;

  /// Null when the dictionary has no phrase for this move. See the file note.
  final String? prescriptionLabel;

  final Set<String> equipment;

  /// The view the safety filter screens on.
  ScreenableExercise get screenable => ScreenableExercise(
    exerciseId: exerciseId,
    tags: tags,
    quiet: quiet,
    floorOnly: floorOnly,
  );
}

/// The bundled content the assistant may select from, and nothing else.
@immutable
class AssistantPack {
  const AssistantPack({
    required this.exercises,
    required this.foods,
    this.version = 'unversioned',
  });

  /// An empty pack. Resolves nothing and invents nothing, which is the correct
  /// behaviour before the bundle has been built.
  static const AssistantPack empty = AssistantPack(
    exercises: <AssistantExercise>[],
    foods: FoodLibrary.empty,
  );

  final List<AssistantExercise> exercises;
  final FoodLibrary foods;

  /// Carried onto every answer, so a pick can never be rendered against a
  /// different pack than the one it was selected from.
  final String version;

  AssistantExercise? exerciseById(String id) {
    for (final move in exercises) {
      if (move.exerciseId == id) return move;
    }
    return null;
  }

  Food? foodById(String id) => foods.byId(id);

  /// Whether this pick resolves to a real row.
  ///
  /// The single question `AssistantResponseValidator` asks of every pick. A
  /// `false` here is how a hallucinated id becomes nothing at all.
  bool knows(AssistantPick pick) => switch (pick.kind) {
    PickKind.exercise => exerciseById(pick.id) != null,
    PickKind.food => foodById(pick.id) != null,
  };

  /// The moves that may be offered, **before** anything is ranked or chosen.
  ///
  /// Delegates to `ExerciseCandidateFilter`, which fails closed when her
  /// constraints cannot be resolved: only the quiet, low-impact, floor-based
  /// subset survives, because an unknown constraint is not an absent one.
  List<AssistantExercise> screenExercises(ClientConstraints constraints) {
    final survivors = ExerciseCandidateFilter(constraints)
        .screen([for (final move in exercises) move.screenable]);
    final allowed = <String>{for (final s in survivors) s.exerciseId};
    // Order preserved: screening is not a ranking (rule 11).
    return <AssistantExercise>[
      for (final move in exercises)
        if (allowed.contains(move.exerciseId)) move,
    ];
  }

  /// The foods that may be offered, **before** anything is ranked or chosen.
  ///
  /// Delegates to `AllergyGuard`, unchanged.
  List<Food> screenFoods(DietaryConstraints constraints) =>
      AllergyGuard(constraints).screen(foods.foods);
}
