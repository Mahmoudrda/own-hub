/// The last gate before anything is rendered: every id must exist.
///
/// G15 §5, rule 10(c): the validator "drops any `id` absent from the versioned
/// library manifest; zero surviving picks → `assistantNothingFound`". This is
/// the third of four independent defences, and each one alone would be enough
/// to be argued with — together they make the failure impossible rather than
/// unlikely:
///
///  1. the tool schemas are strict, so arguments are valid by construction;
///  2. `assistant_wire.dart` has no numeric field, so no quantity can travel;
///  3. **this file** removes any id the pack does not know;
///  4. the device reads every figure from the pack row, so an unknown id yields
///     no row and therefore no gram.
///
/// ## Zero survivors is an answer, not an error
///
/// When nothing survives, the result is [AssistantAnswer.nothingFound] — and
/// `X01` renders it as "nothing found" with the route to Sara. `P0-ASK-02` is
/// specific that **no move is described, named or approximated**: not a near
/// match, not "something like a glute bridge", not the model's own words about
/// what it would have suggested. There is no field for those, and this is where
/// the empty case is chosen rather than papered over.
///
/// The temptation this closes is real: an empty answer looks like a bug, and
/// the obvious "fix" is to fall back to the model's prose. That fallback is the
/// defect, so the empty case is given a name and a screen.
library;

import 'assistant_pack.dart';
import 'assistant_wire.dart';

/// Drops everything the pack does not know.
class AssistantResponseValidator {
  const AssistantResponseValidator(this.pack);

  final AssistantPack pack;

  /// Keeps the picks that resolve, and nothing else.
  ///
  /// A pick the pack does not know is removed silently — there is nothing
  /// useful to say about an id that does not exist, and naming it on screen
  /// would be describing a move that is not real.
  AssistantAnswer validate(AssistantAnswer raw) {
    final surviving = <AssistantPick>[
      for (final pick in raw.picks)
        if (pack.knows(pick)) pick,
    ];

    if (surviving.isEmpty) return AssistantAnswer.nothingFound;

    // The move being swapped out is an id like any other, and it gets the same
    // treatment: a swap away from a move the pack does not know is not a swap,
    // it is an instruction to touch something nobody can name. Dropping it
    // leaves a plain answer — two alternatives with no swap control — rather
    // than a control that would act on an unresolvable id.
    final from = raw.swapFromExerciseId;
    final knownFrom = from != null && pack.exerciseById(from) != null;

    return AssistantAnswer(
      answerKey: raw.answerKey,
      picks: List<AssistantPick>.unmodifiable(surviving),
      escalate: raw.escalate,
      swapFromExerciseId: knownFrom ? from : null,
    );
  }

  /// A plan draft with every unknown move removed.
  ///
  /// A day whose moves all vanish stays in the draft as a day with no moves
  /// rather than disappearing: dropping the day would silently shorten a
  /// 30-day plan to 27 and nobody would see it happen.
  PlanDraft validatePlan(PlanDraft raw) => PlanDraft(
    days: <PlanDraftDay>[
      for (final day in raw.days)
        PlanDraftDay(
          kind: day.kind,
          exerciseIds: <String>[
            for (final id in day.exerciseIds)
              if (pack.exerciseById(id) != null) id,
          ],
        ),
    ],
  );

  /// A meal draft with every unknown food removed.
  MealDraft validateMeal(MealDraft raw) => MealDraft(
    days: <MealDraftDay>[
      for (final day in raw.days)
        MealDraftDay(
          slots: <MealSlot, List<String>>{
            for (final slot in MealSlot.values)
              if (day.slots.containsKey(slot))
                slot: <String>[
                  for (final id in day.idsIn(slot))
                    if (pack.foodById(id) != null) id,
                ],
          },
        ),
    ],
  );
}
