// P1-RULE-10A and the id half of P0-ASK-01/02.
//
// "AssistantResponseValidator.validate() drops any id absent from the versioned
// library manifest; zero surviving picks → nothing found." G15 §5, rule 10(c).
//
// The case that matters most is the empty one. An empty answer looks like a bug,
// and the obvious "fix" is to fall back to whatever prose the model produced —
// which is precisely the defect rule 10 exists to prevent. So the empty case is
// given a name, a value and a test.

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/safety/contraindication_tag.dart';
import 'package:own_hub/features/assistant/domain/assistant_pack.dart';
import 'package:own_hub/features/assistant/domain/assistant_validator.dart';
import 'package:own_hub/features/assistant/domain/assistant_wire.dart';
import 'package:own_hub/features/eat/domain/food_library.dart';

/// Fixture ids, unlike any seeded content, so nothing passes by accident.
final AssistantPack _pack = AssistantPack(
  version: 'fx-pack-5520',
  exercises: const [
    AssistantExercise(
      exerciseId: 'fx_5520_bridge',
      name: 'fixture bridge',
      tags: {ContraindicationTag.supineLoad},
      quiet: true,
      floorOnly: true,
    ),
    AssistantExercise(
      exerciseId: 'fx_5520_row',
      name: 'fixture row',
      tags: {ContraindicationTag.none},
      quiet: true,
      floorOnly: false,
    ),
  ],
  foods: const FoodLibrary(<Food>[
    Food(
      foodId: 'fx_5520_soup',
      names: ['fixture soup'],
      sizes: [FoodSize(id: 'M', label: 'medium', kcal: 190, proteinG: 11)],
    ),
  ]),
);

final AssistantResponseValidator _validator = AssistantResponseValidator(_pack);

AssistantPick _move(String id) => AssistantPick(
  kind: PickKind.exercise,
  id: id,
  source: PickSource.moveLibrary,
);

AssistantPick _food(String id) =>
    AssistantPick(kind: PickKind.food, id: id, source: PickSource.foodLibrary);

void main() {
  group('a hallucinated id yields no row, therefore no gram', () {
    test('an unknown move is dropped', () {
      final answer = _validator.validate(
        AssistantAnswer(
          answerKey: AnswerKey.groundedAlternatives,
          picks: [_move('fx_5520_bridge'), _move('invented_move')],
        ),
      );

      expect(answer.picks.map((p) => p.id), ['fx_5520_bridge']);
      expect(answer.answerKey, AnswerKey.groundedAlternatives);
    });

    test('an unknown food is dropped', () {
      final answer = _validator.validate(
        AssistantAnswer(
          answerKey: AnswerKey.groundedAlternatives,
          picks: [_food('fx_5520_soup'), _food('invented_dish')],
        ),
      );
      expect(answer.picks.map((p) => p.id), ['fx_5520_soup']);
    });

    test('an id of the wrong KIND does not resolve', () {
      // A food id offered as a move is not a move. Without the kind check this
      // would pass validation and then render from the wrong table.
      final answer = _validator.validate(
        AssistantAnswer(
          answerKey: AnswerKey.groundedAlternatives,
          picks: [_move('fx_5520_soup')],
        ),
      );
      expect(answer.answerKey, AnswerKey.nothingFound);
    });
  });

  group('zero survivors is an answer, not an error', () {
    test('every id unknown becomes nothing found, with no picks', () {
      final answer = _validator.validate(
        const AssistantAnswer(
          answerKey: AnswerKey.groundedAlternatives,
          picks: [
            AssistantPick(
              kind: PickKind.exercise,
              id: 'ghost_one',
              source: PickSource.moveLibrary,
            ),
            AssistantPick(
              kind: PickKind.exercise,
              id: 'ghost_two',
              source: PickSource.herPlan,
            ),
          ],
        ),
      );

      expect(answer.answerKey, AnswerKey.nothingFound);
      expect(answer.picks, isEmpty);
      expect(answer.isEmpty, isTrue);
    });

    test('an answer that arrived empty stays empty', () {
      final answer = _validator.validate(
        const AssistantAnswer(answerKey: AnswerKey.groundedAlternatives),
      );
      expect(answer.answerKey, AnswerKey.nothingFound);
    });

    test('nothing found describes, names and approximates no move', () {
      // P0-ASK-02. There is no field on `AssistantAnswer` that could carry a
      // near miss, a description or the model's own words — so the screen has
      // nothing to render but the empty state.
      final answer = _validator.validate(
        const AssistantAnswer(
          answerKey: AnswerKey.groundedAlternatives,
          picks: [
            AssistantPick(
              kind: PickKind.exercise,
              id: 'something_like_a_glute_bridge',
              source: PickSource.moveLibrary,
            ),
          ],
        ),
      );
      expect(answer.picks, isEmpty);
      expect(answer, same(AssistantAnswer.nothingFound));
    });
  });

  group('drafts are validated the same way', () {
    test('unknown moves are removed, and the day survives as an empty day', () {
      final draft = _validator.validatePlan(
        const PlanDraft(
          days: [
            PlanDraftDay(
              kind: PlanDayKind.training,
              exerciseIds: ['fx_5520_bridge', 'ghost'],
            ),
            PlanDraftDay(kind: PlanDayKind.training, exerciseIds: ['ghost']),
            PlanDraftDay(kind: PlanDayKind.rest),
          ],
        ),
      );

      expect(draft.days[0].exerciseIds, ['fx_5520_bridge']);
      // Dropping the day would silently shorten a 30-day plan and nobody would
      // see it happen.
      expect(draft.days[1].exerciseIds, isEmpty);
      expect(draft.dayCount, 3);
      expect(draft.sessionCount, 2);
      expect(draft.restCount, 1);
    });

    test('unknown foods are removed from every slot', () {
      final draft = _validator.validateMeal(
        const MealDraft(
          days: [
            MealDraftDay(
              slots: {
                MealSlot.breakfast: ['fx_5520_soup', 'ghost_dish'],
                MealSlot.lunch: ['ghost_dish'],
              },
            ),
          ],
        ),
      );

      expect(draft.days.single.idsIn(MealSlot.breakfast), ['fx_5520_soup']);
      expect(draft.days.single.idsIn(MealSlot.lunch), isEmpty);
      // A slot that was never offered stays absent rather than becoming empty.
      expect(draft.days.single.slots.containsKey(MealSlot.dinner), isFalse);
    });
  });
}
