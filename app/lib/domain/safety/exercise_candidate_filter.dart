/// G14 §5.1 — the move half of "filter before selection".
///
/// > G5 established the principle for food: `AllergyGuard.screen()` removes
/// > conflicting foods **before** ranking, rather than validating after. Moves
/// > get the identical treatment, and the symmetry is deliberate — two safety
/// > guards with different shapes is how one of them ends up weaker.
///
/// So this has `AllergyGuard`'s shape: constructed with the constraints, with a
/// `screen` that takes the candidates and returns the survivors. Applied at
/// W04's move picker, K20's day-slot editor, `SplitApplicator.materialise()`
/// and G15's `search_exercise_library` tool — the list is built from the
/// result, so a removed move is never in the list to begin with.
///
/// ## Absent, not annotated
///
/// P0-ASMT-02: matching exercises "are ABSENT from the candidate list — removed
/// before it was built. They are not shown greyed out and not shown with a
/// warning. Nothing the coach can tap prescribes one."
///
/// [screen] therefore returns a plain list of survivors, and there is no
/// blocked-but-present representation for a widget to find and render. A
/// filter that returned annotated candidates would put the decision back in the
/// UI layer, which is where it gets lost.
///
/// ## Fail closed
///
/// When the constraints cannot be resolved, only the **quiet, low-impact,
/// floor-based** subset is returned. "An unknown constraint is not an absent
/// one" (G5 §5.1, item 3), so every restricting tag is treated as though it
/// might be the one she cannot do — a move carrying any of them is out, even a
/// quiet floor-based one. An **untagged** move is out too, for the reason a
/// dish with no allergen list is blocked: unknown content is not safe content.
///
/// The subset is narrower still when she has declared a life stage in her own
/// profile, because `ClientConstraints.derivedAvoid` is known even on a cold
/// start.
library;

import 'package:meta/meta.dart';

import 'client_constraints.dart';
import 'contraindication_tag.dart';

/// The only thing the filter needs to know about an exercise.
///
/// Deliberately not G4's full move type: the safety chain is pure domain and
/// must stay callable from a planner, an importer, a split applicator and the
/// assistant's tool schema without dragging a content pack behind it.
@immutable
class ScreenableExercise {
  const ScreenableExercise({
    required this.exerciseId,
    required this.tags,
    required this.quiet,
    required this.floorOnly,
  });

  final String exerciseId;

  /// `exercises[].contraindicationTags[]`.
  ///
  /// **Null means unauthored**, never "carries none" — the distinction
  /// `Food.allergens` draws, for the same reason. An unrestricted move is
  /// tagged `none`, which is a positive statement; null is the absence of one.
  final Set<ContraindicationTag>? tags;

  /// `exercises[].quiet`. False for anything a neighbour downstairs would hear.
  final bool quiet;

  /// `exercises[].floorOnly`.
  final bool floorOnly;

  /// False when nobody has said what this move loads.
  bool get tagsKnown => tags != null;

  /// The tags that actually restrict — `none` excluded.
  Set<ContraindicationTag> get restrictingTags => <ContraindicationTag>{
    for (final tag in tags ?? const <ContraindicationTag>{})
      if (tag.restricts) tag,
  };

  /// True when this move carries any tag in [against].
  bool blocks(Set<ContraindicationTag> against) =>
      restrictingTags.any(against.contains);

  @override
  String toString() => 'ScreenableExercise($exerciseId, ${tags ?? "unknown"})';
}

/// Removes what she must not be offered, **before** the candidate list exists.
class ExerciseCandidateFilter {
  const ExerciseCandidateFilter(this.constraints);

  final ClientConstraints constraints;

  /// The moves that may be offered, in the order they arrived.
  ///
  /// Order is preserved because screening is not a ranking — rule 11, and the
  /// reason `AllergyGuard.screen` is a `where` rather than a sort.
  List<ScreenableExercise> screen(Iterable<ScreenableExercise> candidates) {
    if (!constraints.isResolved) {
      return <ScreenableExercise>[
        for (final move in candidates)
          if (_safeWhileConstraintsAreUnknown(move)) move,
      ];
    }

    final blocked = constraints.blockedTags;

    // She was asked and named nothing, and her life stage derives nothing.
    // There is nothing to fail closed about, and removing every untagged move
    // here would empty the picker on content that is still being authored.
    // This is AllergyGuard's "allergies.isEmpty ⇒ clear", deliberately.
    if (blocked.isEmpty) return candidates.toList();

    return <ScreenableExercise>[
      for (final move in candidates)
        // Unknown tags are unsafe while any restriction is in force — the
        // move half of "a missing tag reads as unknown, therefore unsafe".
        if (move.tagsKnown && !move.blocks(blocked)) move,
    ];
  }

  /// The quiet, low-impact, floor-based subset. See the library note.
  bool _safeWhileConstraintsAreUnknown(ScreenableExercise move) =>
      move.tagsKnown &&
      move.quiet &&
      move.floorOnly &&
      move.restrictingTags.isEmpty;
}
