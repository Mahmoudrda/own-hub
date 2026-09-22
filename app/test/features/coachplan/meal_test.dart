// P0-MEAL-01 … 04 — W06 (the month's meals) and W07 (a meal she writes).
//
// Four properties, and they fail in four different directions:
//
//  * **Before selection.** A conflicting food is never *offered*. The picker is
//    built from the survivors, so there is no list entry to tap.
//  * **And on the way in.** A slot filled before the allergy was recorded is
//    caught by the write path, which names the allergen. A coach has no
//    override there, and there is no argument through which one could be added.
//  * **No invented nutrition.** One unresolved ingredient and there are no
//    numbers at all — not a partial total, not an estimate.
//  * **By value.** A coach meal is embedded in the published day, so the client
//    never reads another woman's document and a later edit changes nothing
//    already published.

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/safety/client_constraints.dart';
import 'package:own_hub/domain/safety/life_stage_safety_policy.dart';
import 'package:own_hub/domain/safety/safety_assessment.dart';
import 'package:own_hub/features/coachplan/domain/meal/coach_meal.dart';
import 'package:own_hub/features/coachplan/domain/meal/coach_meal_repository.dart';
import 'package:own_hub/features/coachplan/domain/meal/meal_slot_planner.dart';
import 'package:own_hub/features/coachplan/domain/plan/coach_plan_publisher.dart';
import 'package:own_hub/features/coachplan/domain/plan/plan_draft.dart';
import 'package:own_hub/features/coachplan/domain/plan/plan_draft_repository.dart';
import 'package:own_hub/features/eat/domain/allergy_guard.dart';
import 'package:own_hub/features/eat/domain/food_library.dart';

import 'source_scan.dart';

final DateTime _today = DateTime(2026, 9, 19);

// ------------------------------------------------------------------ the pack

const _ful = Food(
  foodId: 'ful_medames',
  names: <String>['Ful medames'],
  sizes: <FoodSize>[FoodSize(id: 'M', label: 'A plate', kcal: 410, proteinG: 22)],
  allergens: <String>{},
  dietTags: <String>{'vegetarian'},
);

const _nutBar = Food(
  foodId: 'nut_bar',
  names: <String>['Nut bar'],
  sizes: <FoodSize>[FoodSize(id: 'S', label: 'One', kcal: 200, proteinG: 6)],
  allergens: <String>{'nuts'},
  dietTags: <String>{'vegetarian'},
);

const _grilledChicken = Food(
  foodId: 'grilled_chicken',
  names: <String>['Grilled chicken'],
  sizes: <FoodSize>[FoodSize(id: 'M', label: 'A piece', kcal: 320, proteinG: 40)],
  allergens: <String>{},
  dietTags: <String>{'halal'},
);

/// Nobody has said what is in it. Unknown is not "none".
const _mysteryStew = Food(
  foodId: 'mystery_stew',
  names: <String>['Stew'],
  sizes: <FoodSize>[FoodSize(id: 'M', label: 'A bowl', kcal: 300, proteinG: 12)],
);

const _pack = <String, Food>{
  'ful_medames': _ful,
  'nut_bar': _nutBar,
  'grilled_chicken': _grilledChicken,
  'mystery_stew': _mysteryStew,
};

Food? _foods(String id) => _pack[id];

ClientConstraints _constraints({
  Set<String>? allergies = const <String>{'nuts'},
  Set<String>? dietary = const <String>{'vegetarian'},
}) => ClientConstraintResolver.resolve(
  assessment: SafetyAssessment(
    assessmentId: 'c1_u1__2026-09-01',
    clientUid: 'u1',
    coachUid: 'c1',
    takenAt: DateTime(2026, 9, 1),
    lifeStage: LifeStage.over1y,
  ),
  allergies: allergies,
  dietary: dietary,
);

MealSafety _safety({
  Set<String>? allergies = const <String>{'nuts'},
  Set<String>? dietary = const <String>{'vegetarian'},
  CoachMealResolver? meals,
}) => MealSafety(
  constraints: _constraints(allergies: allergies, dietary: dietary),
  foods: _foods,
  coachMeals: meals,
);

// ------------------------------------------------------------ coach's dishes

MealIngredient _line(String text, {String? foodId, int? grams}) =>
    MealIngredient(text: text, foodId: foodId, grams: grams);

IngredientFigures? _lookup(MealIngredient ingredient) {
  final food = ingredient.foodId == null ? null : _pack[ingredient.foodId!];
  if (food == null) return null;
  final size = food.sizes.first;
  return (kcal: size.kcal, proteinG: size.proteinG);
}

CoachMeal _fulPlate({String mealId = 'm_ful', String? note}) =>
    CoachMeal.compose(
      mealId: mealId,
      name: 'Ful and salad',
      ingredients: <MealIngredient>[_line('Ful', foodId: 'ful_medames')],
      lookup: _lookup,
      note: note,
    );

CoachMeal _grandmothersMix() => CoachMeal.compose(
  mealId: 'm_mix',
  name: "Grandmother's mix",
  ingredients: <MealIngredient>[
    _line('Ful', foodId: 'ful_medames'),
    _line('Grilled chicken', foodId: 'grilled_chicken'),
    // The line nobody can resolve. It is the whole of P0-MEAL-03.
    _line("Grandmother's mix 200 g"),
  ],
  lookup: _lookup,
);

// -------------------------------------------------------------------- drafts

PlanDraft _draftWith(
  Map<PlanMealSlot, MealSlotAssignment?> slots, {
  String dayKey = '2026-09-20',
}) => PlanDraft(
  clientUid: 'u1',
  coachUid: 'c1',
  month: '2026-09',
  days: <String, PlanDay>{
    dayKey: PlanDay(
      kind: PlanDayKind.workout,
      workout: DraftWorkout(title: 'Full-body', minutes: 30),
      meal: DraftMealDay(slots: slots),
    ),
  },
);

class _RecordingGateway implements PlanPublishGateway {
  final List<PublishRequest> requests = <PublishRequest>[];

  @override
  Future<PublishReceipt> publishCoachPlan(PublishRequest request) async {
    requests.add(request);
    return PublishReceipt(
      version: 'v${requests.map((r) => r.idempotencyKey).toSet().length}',
      assignmentsWritten: request.payload.length,
      mealSlotsWritten: 0,
    );
  }
}

void main() {
  group('P0-MEAL-01 — allergies filter before selection', () {
    final planner = MealSlotPlanner(_safety());

    test('a nut food is absent from the picker, not warned about', () {
      final offered = planner.offerable(_pack.values);
      expect(offered.map((f) => f.foodId), isNot(contains('nut_bar')));
      expect(offered.map((f) => f.foodId), contains('ful_medames'));
    });

    test('a dish with no allergen list is absent too — unknown is not none', () {
      expect(
        planner.offerable(_pack.values).map((f) => f.foodId),
        isNot(contains('mystery_stew')),
        reason: 'she has an allergy and nobody has said what is in this dish',
      );
    });

    test('a preference is filtered with no warning and no override', () {
      final offered = planner.offerable(_pack.values).map((f) => f.foodId);
      expect(offered, isNot(contains('grilled_chicken')));
      // And it is a *filter*, not a guard: a preference never blocks a write,
      // because treating a preference like an allergy trains her to tap
      // through the sheet that matters.
      expect(
        AllergyGuard(_safety().dietary).assess(_grilledChicken).isBlocked,
        isFalse,
      );
    });

    test('order is preserved — screening is not a ranking', () {
      final candidates = <Food>[_ful, _nutBar, _grilledChicken];
      expect(
        planner.offerable(candidates).map((f) => f.foodId),
        <String>['ful_medames'],
      );
      expect(
        MealSlotPlanner(
          _safety(allergies: const <String>{}, dietary: const <String>{}),
        ).offerable(candidates).map((f) => f.foodId),
        <String>['ful_medames', 'nut_bar', 'grilled_chicken'],
        reason: 'she was asked and named nothing: nothing is removed, and '
            'nothing is reordered either',
      );
    });

    test('one conflicting ingredient makes the whole dish unofferable', () {
      final nutty = CoachMeal.compose(
        mealId: 'm_nutty',
        name: 'Salad with a nut bar',
        ingredients: <MealIngredient>[
          _line('Ful', foodId: 'ful_medames'),
          _line('Nut bar', foodId: 'nut_bar'),
        ],
        lookup: _lookup,
      );
      expect(
        MealSlotPlanner(_safety()).offerableMeals(<CoachMeal>[
          _fulPlate(),
          nutty,
          _grandmothersMix(),
        ]).map((m) => m.mealId),
        <String>['m_ful'],
        reason: 'a coach cannot un-cook the nuts out of it, and a dish with an '
            'unresolved line has not been declared clear by anybody',
      );
    });

    test('no coach surface can say "assign it anyway"', () {
      // The override in G5 exists because *she* is the authority on her own
      // body. A coach is not. So there is no acknowledgement argument anywhere
      // in this feature to pass one through.
      for (final entry in coachPlanSources().entries) {
        for (final needle in kForbiddenOverrideTokens) {
          expect(
            entry.value.contains(needle),
            isFalse,
            reason: '${entry.key} names "$needle"',
          );
        }
      }
    });
  });

  group('P0-MEAL-02 — a conflicting item arriving by another route', () {
    test('the write is refused, and the allergen is named', () async {
      final repo = InMemoryPlanDraftRepository(safety: _safety());
      final draft = _draftWith(<PlanMealSlot, MealSlotAssignment?>{
        PlanMealSlot.breakfast: const MealSlotAssignment.fromLibrary(
          foodIds: <String>['nut_bar'],
        ),
      });

      await expectLater(
        repo.save(draft),
        throwsA(
          isA<AllergenInPlan>()
              .having((e) => e.first.allergens, 'allergens', <String>{'nuts'})
              .having((e) => e.first.dayKey, 'dayKey', '2026-09-20')
              .having((e) => e.first.slot, 'slot', PlanMealSlot.breakfast),
        ),
      );
      expect(repo.writes, 0, reason: 'nothing was stored');
    });

    test('every blocked slot is named at once, not one per round trip', () {
      final draft = PlanDraft(
        clientUid: 'u1',
        coachUid: 'c1',
        month: '2026-09',
        days: <String, PlanDay>{
          '2026-09-20': PlanDay(
            kind: PlanDayKind.rest,
            meal: DraftMealDay(
              slots: <PlanMealSlot, MealSlotAssignment?>{
                PlanMealSlot.breakfast: const MealSlotAssignment.fromLibrary(
                  foodIds: <String>['nut_bar'],
                ),
                PlanMealSlot.lunch: const MealSlotAssignment.fromLibrary(
                  foodIds: <String>['ful_medames'],
                ),
              },
            ),
          ),
          '2026-09-21': PlanDay(
            kind: PlanDayKind.rest,
            meal: DraftMealDay(
              slots: <PlanMealSlot, MealSlotAssignment?>{
                PlanMealSlot.dinner: const MealSlotAssignment.fromLibrary(
                  foodIds: <String>['mystery_stew'],
                ),
              },
            ),
          ),
        },
      );

      final blocked = MealSlotPlanner(_safety()).blockedSlots(draft);
      expect(blocked, hasLength(2));
      expect(
        blocked.map((b) => b.reason),
        containsAll(<AllergyBlockReason>[
          AllergyBlockReason.namedAllergen,
          AllergyBlockReason.unknownAllergenData,
        ]),
      );
      expect(
        blocked
            .firstWhere(
              (b) => b.reason == AllergyBlockReason.unknownAllergenData,
            )
            .allergens,
        isEmpty,
        reason: 'naming an allergen here would state something nobody knows',
      );
    });

    test('one of her own dishes is screened the same way', () {
      final nutty = CoachMeal.compose(
        mealId: 'm_nutty',
        name: 'Nutty',
        ingredients: <MealIngredient>[_line('Nut bar', foodId: 'nut_bar')],
        lookup: _lookup,
      );
      final draft = _draftWith(<PlanMealSlot, MealSlotAssignment?>{
        PlanMealSlot.lunch: const MealSlotAssignment.coachMeal(
          coachMealId: 'm_nutty',
        ),
      });

      expect(
        MealSlotPlanner(
          _safety(meals: (id) => id == 'm_nutty' ? nutty : null),
        ).blockedSlots(draft).single.allergens,
        <String>{'nuts'},
      );
    });

    test('unreadable constraints block the write, they do not wave it through', () {
      final draft = _draftWith(<PlanMealSlot, MealSlotAssignment?>{
        PlanMealSlot.breakfast: const MealSlotAssignment.fromLibrary(
          foodIds: <String>['ful_medames'],
        ),
      });

      expect(
        MealSlotPlanner(
          _safety(allergies: null, dietary: null),
        ).blockedSlots(draft).single.reason,
        AllergyBlockReason.constraintsUnavailable,
        reason: 'an unknown constraint is not an absent one',
      );
    });

    test('a meal cannot be planned at all without her constraints', () {
      final repo = InMemoryPlanDraftRepository();
      expect(
        () => repo.save(
          _draftWith(<PlanMealSlot, MealSlotAssignment?>{
            PlanMealSlot.breakfast: const MealSlotAssignment.fromLibrary(
              foodIds: <String>['ful_medames'],
            ),
          }),
        ),
        throwsA(isA<MealPlannedWithoutConstraints>()),
      );
    });

    test('a stated free choice is not a food, and is never blocked', () {
      expect(
        MealSlotPlanner(_safety()).blockedSlots(
          _draftWith(<PlanMealSlot, MealSlotAssignment?>{
            PlanMealSlot.snack: const MealSlotAssignment.freeChoice(),
          }),
        ),
        isEmpty,
      );
    });
  });

  group('P0-MEAL-03 — no invented nutrition', () {
    test('one unresolved line and there are no numbers at all', () async {
      final meal = _grandmothersMix();

      expect(meal.nutrition.resolved, isFalse);
      expect(meal.nutrition.kcal, isNull);
      expect(meal.nutrition.proteinG, isNull);
      expect(meal.unresolvedIngredients.single.text, contains('mix'));

      final wire = meal.toWire()['nutrition']! as Map<String, Object?>;
      expect(wire.containsKey('kcal'), isFalse);
      expect(wire.containsKey('proteinG'), isFalse);
      expect(
        wire['resolved'],
        false,
        reason: 'not a partial total of the two lines that did resolve',
      );

      final repo = InMemoryCoachMealRepository();
      await repo.save(meal);
      expect(repo.contents['m_mix']!.nutrition.resolved, isFalse);
    });

    test('an empty dish is unavailable, never zero', () {
      expect(
        CoachMeal.nutritionFor(const <MealIngredient>[], _lookup).resolved,
        isFalse,
        reason: '0 kcal is a number somebody could believe',
      );
    });

    test('an id the pack no longer carries makes the whole dish unavailable', () {
      expect(
        CoachMeal.nutritionFor(<MealIngredient>[
          _line('Ful', foodId: 'ful_medames'),
          _line('Something', foodId: 'withdrawn_from_the_pack'),
        ], _lookup).resolved,
        isFalse,
      );
    });

    test('a meal claiming to be resolved with an unresolved line is refused', () {
      final lying = CoachMeal(
        mealId: 'm_lie',
        name: 'Ful and something',
        ingredients: <MealIngredient>[
          _line('Ful', foodId: 'ful_medames'),
          _line('Something of my own'),
        ],
        nutrition: const MealNutrition.resolved(kcal: 410, proteinG: 22),
      );
      expect(
        () => InMemoryCoachMealRepository().save(lying),
        throwsA(isA<UnverifiedNutritionStored>()),
      );
    });

    test('the figures that do exist came from the pack, not from the coach', () {
      final resolved = _fulPlate();
      expect(resolved.nutrition.resolved, isTrue);
      expect(resolved.nutrition.kcal, _ful.sizes.first.kcal);
      expect(resolved.nutrition.proteinG, _ful.sizes.first.proteinG);
    });

    test('her dish never enters the verified pack', () {
      final sources = coachPlanSources();
      for (final entry in sources.entries) {
        expect(
          RegExp(r"""collection\(\s*['"]foods['"]""").hasMatch(entry.value),
          isFalse,
          reason: '${entry.key} writes to G5\'s public library',
        );
      }
      // And the repository has nowhere else to put one: its only store is the
      // coach's own collection.
      expect(
        sources['domain/meal/coach_meal_repository.dart']!.contains('_store'),
        isTrue,
      );
    });
  });

  group('P0-MEAL-04 — every quantity comes from the library', () {
    test('a slot carries ids and servings, and no typed-in quantity', () {
      const assignment = MealSlotAssignment.fromLibrary(
        foodIds: <String>['ful_medames'],
        servings: 2,
      );
      expect(assignment.toWire().keys, <String>{
        'source',
        'foodIds',
        'servings',
      });
      for (final banned in kForbiddenQuantityKeys) {
        expect(assignment.toWire().containsKey(banned), isFalse, reason: banned);
      }
    });

    test('a coach meal publishes by value, and its id does not travel', () async {
      final gateway = _RecordingGateway();
      final publisher = CoachPlanPublisher(
        gateway: gateway,
        queue: InMemoryPublishIntentQueue(),
        coachMeals: (id) => id == 'm_ful' ? _fulPlate() : null,
      );

      final outcome = await publisher.publish(
        draft: _draftWith(<PlanMealSlot, MealSlotAssignment?>{
          PlanMealSlot.lunch: const MealSlotAssignment.coachMeal(
            coachMealId: 'm_ful',
            servings: 2,
            note: 'Skip the bread today',
          ),
        }),
        context: PublishContext(lifeStage: LifeStage.over1y, today: _today),
      );
      expect(outcome.isPublished, isTrue);

      final days = gateway.requests.single.payload['days']!
          as Map<String, Object?>;
      final day = days['2026-09-20']! as Map<String, Object?>;
      final slots =
          (day['meal']! as Map<String, Object?>)['slots']!
              as Map<String, Object?>;
      final lunch = slots['lunch']! as Map<String, Object?>;

      expect(lunch['name'], 'Ful and salad');
      expect(lunch['servings'], 2);
      expect(lunch['note'], 'Skip the bread today');
      expect((lunch['ingredients']! as List<Object?>), hasLength(1));
      expect(
        lunch.containsKey('coachMealId'),
        isFalse,
        reason: 'a reference left in the payload is a reference somebody will '
            'eventually dereference — and she may not read the coach\'s '
            'document',
      );
    });

    test('a later edit to her dish does not reach the published day', () async {
      final gateway = _RecordingGateway();
      var dish = _fulPlate();
      final publisher = CoachPlanPublisher(
        gateway: gateway,
        queue: InMemoryPublishIntentQueue(),
        coachMeals: (id) => id == 'm_ful' ? dish : null,
      );
      final draft = _draftWith(<PlanMealSlot, MealSlotAssignment?>{
        PlanMealSlot.lunch: const MealSlotAssignment.coachMeal(
          coachMealId: 'm_ful',
        ),
      });

      await publisher.publish(
        draft: draft,
        context: PublishContext(lifeStage: LifeStage.over1y, today: _today),
      );
      final published = gateway.requests.single.payload.toString();

      dish = CoachMeal.compose(
        mealId: 'm_ful',
        name: 'Renamed entirely',
        ingredients: <MealIngredient>[
          _line('Chicken', foodId: 'grilled_chicken'),
        ],
        lookup: _lookup,
      );

      expect(
        gateway.requests.single.payload.toString(),
        published,
        reason: 'embedded by value, exactly as a split is',
      );
    });

    test('a dish that cannot be read refuses the publish', () async {
      final gateway = _RecordingGateway();
      final outcome = await CoachPlanPublisher(
        gateway: gateway,
        queue: InMemoryPublishIntentQueue(),
        // Her meals are not readable on this device right now.
      ).publish(
        draft: _draftWith(<PlanMealSlot, MealSlotAssignment?>{
          PlanMealSlot.lunch: const MealSlotAssignment.coachMeal(
            coachMealId: 'm_ful',
          ),
        }),
        context: PublishContext(lifeStage: LifeStage.over1y, today: _today),
      );

      expect(outcome.refusal, PublishRefusal.coachMealUnreadable);
      expect(gateway.requests, isEmpty);
      expect(
        outcome.resultingStatus,
        PlanDraftStatus.draft,
        reason: 'a refused publish leaves her month exactly as she wrote it',
      );
    });

    test('a workout-only month needs no meal resolver at all', () async {
      final gateway = _RecordingGateway();
      final outcome = await CoachPlanPublisher(
        gateway: gateway,
        queue: InMemoryPublishIntentQueue(),
      ).publish(
        draft: PlanDraft(
          clientUid: 'u1',
          coachUid: 'c1',
          month: '2026-09',
          days: <String, PlanDay>{'2026-09-20': const PlanDay.rest()},
        ),
        context: PublishContext(lifeStage: LifeStage.over1y, today: _today),
      );
      expect(outcome.isPublished, isTrue);
    });
  });
}
