/// HANDOFF 12, as a structural property — G14 §3.3.
///
/// > `materialise()` returns a **new value object**; the draft holds no pointer
/// > to the split. There is no function that takes a `splitId` and mutates a
/// > plan.
///
/// Read the signature below and note two absences. It takes a [Split] **by
/// value**, never a `splitId` — so there is nothing for a caller to pass that
/// would make this reach into storage and fetch a template. And it takes no
/// repository and no draft — so it cannot write anything, to anyone. It maps a
/// template and a list of dates onto a bag of days, and the caller decides what
/// to do with them.
///
/// `templateRef` travels with the result as **provenance only**. If the split
/// is deleted afterwards, the string dangles and nothing breaks, because
/// nothing ever reads it back.
///
/// ## Re-screened against *her* constraints
///
/// G14 §5.1 requires a split applied to a **different** client to be
/// re-screened against her constraints, "never the previous client's". So the
/// filter runs here, during materialisation, on the moves that are about to
/// become her days — not once, when the template was written. Every filled day
/// goes through it, and so does every approved alternative on one: a move that
/// is not screened is a move that arrives unscreened, and an "easier option"
/// she can tap mid-session is prescribed content like any other.
///
/// A move whose exercise is not in the catalogue is dropped for the reason
/// `ExerciseCandidateFilter` drops an untagged one: unknown content is not safe
/// content.
///
/// ## A template is authored for nobody
///
/// The filter answers one question: *does this move carry something her
/// assessment named?* That is the right question for W04, where a coach is
/// choosing one move with her file open, from a list the filter already built.
/// It is not the whole question here. A split is a template: it was written for
/// no one, or for somebody else, and applying it writes a **month** of days
/// nobody looked at one by one.
///
/// So once any restriction is in force for her — her assessment names a tag, a
/// referral suppresses one, her life stage derives one, or her constraints
/// could not be read at all — a template move crosses into her month only if
/// the catalogue says it restricts **nothing**. A move carrying a restriction
/// she was never asked about is an unanswered question about her body, and a
/// template is not an answer to it: the box jump was never hers to begin with,
/// and it must not become hers because a template mentioned it.
///
/// Two properties keep this from being a silent narrowing:
///
///  * every id it removes is named in [SplitApplication.suppressedExerciseIds],
///    which W03 states plainly — it is the screen telling the truth about what
///    it did, not an error;
///  * a woman whose constraints are **resolved and empty** — she was asked and
///    named nothing — is unaffected, because there is no restriction in force
///    to be cautious about. That is `ExerciseCandidateFilter`'s own
///    `blocked.isEmpty ⇒ clear`, and it is deliberately the same boundary.
///
/// The coach keeps every move she wants: W04 prescribes one at a time, with
/// this client's constraints in front of her. What she cannot do is fan a
/// tagged move out over thirty days of a woman she has recorded a restriction
/// for, without ever having chosen it for *her*.
library;

import 'package:meta/meta.dart';

import '../../../../domain/safety/client_constraints.dart';
import '../../../../domain/safety/exercise_candidate_filter.dart';
import '../plan/plan_draft.dart';
import '../prescription.dart';
import '../prescription_only_validator.dart';
import 'split.dart';
import 'split_assignment_guard.dart';

/// Looks an exercise up in G4's bundled pack. Null when the pack has no row
/// for it, which is treated as unknown and therefore unsafe.
typedef MoveCatalogue = ScreenableExercise? Function(String exerciseId);

/// What a split application produced. A value, holding no reference to the
/// template it came from beyond the provenance string.
@immutable
class SplitApplication {
  SplitApplication({
    required Map<String, PlanDay> days,
    required this.templateRef,
    Set<String> suppressedExerciseIds = const <String>{},
  }) : days = Map<String, PlanDay>.unmodifiable(days),
       suppressedExerciseIds = Set<String>.unmodifiable(suppressedExerciseIds);

  /// Keyed `yyyy-MM-dd`, ready to be merged into a draft.
  final Map<String, PlanDay> days;

  /// `coaches/{coachUid}/splits/{splitId}`. Provenance. Never dereferenced.
  final String templateRef;

  /// Moves the filter removed on the way in, so W03 can say plainly that her
  /// avoid list was applied — "deep knee bends and high impact never appear".
  /// Naming them is not an error state; it is the screen telling the truth
  /// about what it did.
  final Set<String> suppressedExerciseIds;

  bool get removedSomething => suppressedExerciseIds.isNotEmpty;

  @override
  String toString() => 'SplitApplication(${days.length} days)';
}

/// Copies a template onto dates, by value.
class SplitApplicator {
  const SplitApplicator();

  /// The days [split] produces for [clientUid] over [dates].
  ///
  /// [dates] are the calendar days to fill, in order; the cycle repeats over
  /// them. Every day produced is built from **new** objects, so a later edit to
  /// the template cannot be seen from the draft, the version or an assignment.
  SplitApplication materialise({
    required Split split,
    required String clientUid,
    required List<DateTime> dates,
    required PlanningActor actor,
    required bool hasActiveRelationship,
    required ClientConstraints constraints,
    required MoveCatalogue catalogue,
    String? coachUid,
  }) {
    SplitAssignmentGuard.assertMayAssign(
      actor: actor,
      targetUid: clientUid,
      hasActiveRelationship: hasActiveRelationship,
    );

    final screen = _TemplateScreen(
      filter: ExerciseCandidateFilter(constraints),
      catalogue: catalogue,
      // See the library note. Unresolved counts as "in force": an unknown
      // constraint is not an absent one, here as everywhere else.
      restrictionsInForce:
          !constraints.isResolved || constraints.blockedTags.isNotEmpty,
    );
    final suppressed = <String>{};
    final days = <String, PlanDay>{};

    for (var i = 0; i < dates.length; i++) {
      final date = dates[i];
      final slot = split.daySlots[i % split.daySlots.length];
      final provenance = SplitProvenance(
        splitId: split.splitId,
        dayIndex: slot.dayIndex,
      );

      if (slot.isRest) {
        days[_dayKey(date)] = PlanDay.rest(fromSplit: provenance);
        continue;
      }

      final kept = screen.keep(slot.moves, suppressed);
      days[_dayKey(date)] = PlanDay(
        kind: PlanDayKind.workout,
        fromSplit: provenance,
        workout: DraftWorkout(
          title: slot.title ?? '',
          minutes: slot.minutes ?? kSessionMinuteOptions.first,
          restBetweenSetsSec: slot.restBetweenSetsSec,
          // Copied one by one: no list here is the template's list, and no
          // move here is the template's move.
          moves: kept,
          approvedAlternatives: split.carryApproved
              ? <ApprovedAlternative>[
                  for (final alternative in slot.approvedAlternatives)
                    // The substitute is screened on its own account. It is a
                    // move she can tap mid-session, so an unscreened one is an
                    // unscreened prescription with an extra step in front of
                    // it — and an alternative for a move she no longer has is
                    // not an option either.
                    if (screen.allows(alternative.exerciseId, suppressed) &&
                        kept.any(
                          (m) => m.exerciseId == alternative.forExerciseId,
                        ))
                      alternative.copy(),
                ]
              : const <ApprovedAlternative>[],
        ),
      );
    }

    final application = SplitApplication(
      days: days,
      templateRef: 'coaches/${coachUid ?? actor.uid}/splits/${split.splitId}',
      suppressedExerciseIds: suppressed,
    );

    // Rule 1 at the boundary the spec names: a template that somehow carried a
    // result must not become a month that carries one.
    for (final day in application.days.values) {
      PrescriptionOnlyValidator.assertPrescriptionOnly(day.toWire());
    }
    return application;
  }

  static String _dayKey(DateTime moment) =>
      '${moment.year.toString().padLeft(4, '0')}-'
      '${moment.month.toString().padLeft(2, '0')}-'
      '${moment.day.toString().padLeft(2, '0')}';
}

/// The screen a template's content passes on its way into one woman's month.
///
/// One object, so the moves and the approved alternatives on a day cannot be
/// screened by two slightly different rules — the failure `ExerciseCandidateFilter`
/// names for food and moves ("two safety guards with different shapes is how
/// one of them ends up weaker"), one level down.
class _TemplateScreen {
  _TemplateScreen({
    required this.filter,
    required this.catalogue,
    required this.restrictionsInForce,
  });

  final ExerciseCandidateFilter filter;
  final MoveCatalogue catalogue;

  /// True when anything at all restricts her — including the case where her
  /// constraints could not be read.
  final bool restrictionsInForce;

  final Map<String, bool> _decided = <String, bool>{};

  /// Whether [exerciseId] may cross from a template into her month.
  ///
  /// Every `false` is recorded in [suppressed], so nothing is removed without
  /// being named.
  bool allows(String exerciseId, Set<String> suppressed) {
    final decided = _decided[exerciseId];
    if (decided != null) {
      if (!decided) suppressed.add(exerciseId);
      return decided;
    }

    final entry = catalogue(exerciseId);
    // Unknown content is not safe content. It is named, not silently lost.
    final verdict = entry != null && _survives(entry);
    _decided[exerciseId] = verdict;
    if (!verdict) suppressed.add(exerciseId);
    return verdict;
  }

  /// [moves], screened and renumbered.
  List<PrescribedMove> keep(
    List<PrescribedMove> moves,
    Set<String> suppressed,
  ) {
    final kept = <PrescribedMove>[];
    var order = 1;
    for (final move in moves) {
      if (!allows(move.exerciseId, suppressed)) continue;
      // Renumbered, so removing move 2 does not leave her session numbered
      // 1, 3, 4 — the order is hers to read, not a foreign key.
      kept.add(
        PrescribedMove(
          exerciseId: move.exerciseId,
          order: order++,
          sets: move.sets,
          load: move.load,
          reps: move.reps,
          holdSeconds: move.holdSeconds,
          note: move.note,
        ),
      );
    }
    return kept;
  }

  /// The filter first, then the template rule. See the library note.
  bool _survives(ScreenableExercise move) {
    // `screen` is given one candidate at a time on purpose: the answer is
    // per-move, and a filter that returned a *list* would let a caller read
    // "empty" as "nothing to do" and write the day unscreened.
    if (filter.screen(<ScreenableExercise>[move]).isEmpty) return false;
    if (!restrictionsInForce) return true;
    return move.restrictingTags.isEmpty;
  }
}
