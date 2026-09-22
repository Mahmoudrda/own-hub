// P0-ASK-09 and P0-ASK-10 — the constraint is applied to the candidate set
// BEFORE anything is ranked or chosen, not filtered out of a finished draft.
//
// The assistant does not re-implement either guard. `lib/domain/safety/` owns
// the move half and `lib/features/eat/domain/` owns the food half, both already
// tested; this file proves the assistant actually routes through them, because
// "two safety guards with different shapes is how one of them ends up weaker".
//
// The distinction these tests defend is *absence*: a blocked move is not in the
// returned list at all. There is no blocked-but-present representation for a
// widget to find and render, so no screen can accidentally offer one.

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/safety/client_constraints.dart';
import 'package:own_hub/domain/safety/contraindication_tag.dart';
import 'package:own_hub/domain/safety/life_stage_safety_policy.dart';
import 'package:own_hub/domain/safety/safety_assessment.dart';
import 'package:own_hub/features/assistant/domain/assistant_pack.dart';
import 'package:own_hub/features/assistant/domain/assistant_wire.dart';
import 'package:own_hub/features/eat/domain/allergy_guard.dart';
import 'package:own_hub/features/eat/domain/food_library.dart';

AssistantExercise _ex(
  String id,
  Set<ContraindicationTag>? tags, {
  bool quiet = true,
  bool floorOnly = false,
}) => AssistantExercise(
  exerciseId: id,
  name: 'fixture $id',
  tags: tags,
  quiet: quiet,
  floorOnly: floorOnly,
);

final AssistantPack _pack = AssistantPack(
  version: 'fx-pack-7714',
  exercises: [
    _ex('fx_7714_deep_lunge', const {ContraindicationTag.deepKneeFlexion}),
    _ex('fx_7714_box_jump', const {
      ContraindicationTag.highImpact,
      ContraindicationTag.jumping,
    }, quiet: false),
    _ex('fx_7714_bridge', const {
      ContraindicationTag.supineLoad,
    }, floorOnly: true),
    _ex('fx_7714_clam', const {ContraindicationTag.none}, floorOnly: true),
    _ex('fx_7714_untagged', null, floorOnly: true),
  ],
  foods: const FoodLibrary(<Food>[
    Food(
      foodId: 'fx_7714_nut_bowl',
      names: ['fixture nut bowl'],
      allergens: {'nuts'},
      sizes: [FoodSize(id: 'M', label: 'medium', kcal: 300, proteinG: 8)],
    ),
    Food(
      foodId: 'fx_7714_lentils',
      names: ['fixture lentils'],
      allergens: <String>{},
      sizes: [FoodSize(id: 'M', label: 'medium', kcal: 190, proteinG: 11)],
    ),
    Food(
      foodId: 'fx_7714_unauthored',
      names: ['fixture unauthored'],
      sizes: [FoodSize(id: 'M', label: 'medium', kcal: 210, proteinG: 9)],
    ),
    Food(
      foodId: 'fx_7714_unverified',
      names: ['fixture unverified'],
      allergens: <String>{},
      verified: false,
      sizes: [FoodSize(id: 'M', label: 'medium', kcal: 400, proteinG: 12)],
    ),
  ]),
);

ClientConstraints _constraints(Set<ContraindicationTag> avoid) =>
    ClientConstraintResolver.resolve(
      assessment: SafetyAssessment(
        assessmentId: 'fx_a7714',
        clientUid: 'fx_client_7714',
        takenAt: DateTime.utc(2026, 9, 19),
        lifeStage: LifeStage.none,
        avoid: avoid,
      ),
    );

List<String> _ids(List<AssistantExercise> moves) => [
  for (final m in moves) m.exerciseId,
];

void main() {
  group('P0-ASK-09 — the avoid list is applied before selection', () {
    test('an excluded move is ABSENT, not flagged', () {
      final survivors = _pack.screenExercises(
        _constraints(const {ContraindicationTag.deepKneeFlexion}),
      );

      expect(_ids(survivors), isNot(contains('fx_7714_deep_lunge')));
      // And it is not present in any other form either: the returned type has
      // no "blocked" field for a widget to render.
      expect(
        survivors.any((m) => m.exerciseId == 'fx_7714_deep_lunge'),
        isFalse,
      );
    });

    test('everything not excluded survives, in its original order', () {
      // Screening is not a ranking — rule 11 — so the survivors arrive in the
      // order they were given, not in a ranked one.
      //
      // `fx_7714_untagged` is ABSENT, and its absence is the specified
      // behaviour rather than a hole in the fixture. Its `tags` are null, and
      // null means **unauthored**, never "carries none": an unrestricted move
      // is tagged `none`, which is a positive statement somebody made.
      // `ExerciseCandidateFilter.screen` therefore drops every move whose tags
      // are unknown as soon as any restriction is in force — the move half of
      // `AllergyGuard`'s posture on a dish with no allergen list, and the same
      // sentence: *an unknown constraint is not an absent one.* Nobody has said
      // what this move loads, so it cannot be proven safe, so it is not
      // offered. It goes out not because it is known to conflict, but because
      // nothing about it is known at all.
      //
      // Do NOT "fix" this by putting the id back. A test that expected an
      // untagged move to survive a live restriction would be asserting that the
      // filter fails open, and the next person to read it would make the code
      // match. The complementary case below is what keeps this honest: it
      // proves the filter is not simply deleting every untagged row.
      final survivors = _pack.screenExercises(
        _constraints(const {ContraindicationTag.highImpact}),
      );
      expect(_ids(survivors), [
        'fx_7714_deep_lunge',
        'fx_7714_bridge',
        'fx_7714_clam',
      ]);
    });

    test('asked and named nothing: an untagged move IS offered', () {
      // The other half of the rule above, and the reason it is fail-*closed*
      // rather than a blanket ban on unauthored content.
      //
      // Her constraints resolved, and the avoid set came back empty: she was
      // asked and named nothing, and her life stage derives nothing. There is
      // no restriction for an unknown tag to be unknown *about*, so there is
      // nothing to fail closed about — `AllergyGuard`'s "allergies known and
      // empty ⇒ clear", deliberately mirrored. Removing untagged moves here
      // would empty the picker over content that is still being authored, and
      // teach whoever met it that the safety filter is broken.
      final survivors = _pack.screenExercises(
        _constraints(const <ContraindicationTag>{}),
      );
      expect(_ids(survivors), contains('fx_7714_untagged'));
      expect(
        _ids(survivors),
        hasLength(5),
        reason: 'with nothing to avoid, nothing is screened out',
      );
    });

    test('an untagged move is removed while any restriction is in force', () {
      // A missing tag reads as unknown, therefore unsafe.
      final survivors = _pack.screenExercises(
        _constraints(const {ContraindicationTag.supineLoad}),
      );
      expect(_ids(survivors), isNot(contains('fx_7714_untagged')));
    });

    test('unresolved constraints fail closed to the quiet floor subset', () {
      // An unknown constraint is not an absent one.
      final survivors = _pack.screenExercises(
        ClientConstraintResolver.unresolved(),
      );
      expect(_ids(survivors), ['fx_7714_clam']);
    });

    test('`none` never suppresses the moves that carry it', () {
      final survivors = _pack.screenExercises(
        _constraints(const {ContraindicationTag.deepKneeFlexion}),
      );
      expect(_ids(survivors), contains('fx_7714_clam'));
    });
  });

  group('P0-ASK-10 — allergens go through AllergyGuard, unchanged', () {
    test('a dish containing a named allergen is never offered', () {
      final offered = _pack.screenFoods(
        const DietaryConstraints(allergies: {'nuts'}, dietary: <String>{}),
      );
      expect(offered.map((f) => f.foodId), isNot(contains('fx_7714_nut_bowl')));
    });

    test(
      'a dish with unauthored allergens is blocked when she has any allergy',
      () {
        // Unknown is unsafe, never "safe by default".
        final offered = _pack.screenFoods(
          const DietaryConstraints(allergies: {'nuts'}, dietary: <String>{}),
        );
        expect(
          offered.map((f) => f.foodId),
          isNot(contains('fx_7714_unauthored')),
        );
        expect(offered.map((f) => f.foodId), contains('fx_7714_lentils'));
      },
    );

    test('unreadable constraints do not empty the list, per G5 §5.1', () {
      final offered = _pack.screenFoods(DietaryConstraints.unknown);
      expect(offered, hasLength(4));
    });

    test('an unverified food carries no totals rather than invented ones', () {
      // The pack marks it; the screen renders it without figures. Nothing here
      // computes a total, and nothing may.
      final unverified = _pack.foodById('fx_7714_unverified');
      expect(unverified, isNotNull);
      expect(unverified!.verified, isFalse);
    });
  });

  group('the pack is the only source of a quantity', () {
    test('a known id resolves to a row', () {
      expect(
        _pack.knows(
          const AssistantPick(
            kind: PickKind.exercise,
            id: 'fx_7714_bridge',
            source: PickSource.moveLibrary,
          ),
        ),
        isTrue,
      );
    });

    test('an invented id resolves to nothing at all', () {
      expect(
        _pack.knows(
          const AssistantPick(
            kind: PickKind.exercise,
            id: 'invented',
            source: PickSource.moveLibrary,
          ),
        ),
        isFalse,
      );
      expect(_pack.exerciseById('invented'), isNull);
      expect(_pack.foodById('invented'), isNull);
    });

    test('an empty pack resolves nothing and invents nothing', () {
      expect(AssistantPack.empty.exerciseById('anything'), isNull);
      expect(
        AssistantPack.empty.screenExercises(_constraints(const {})),
        isEmpty,
      );
    });

    test('a move with no authored prescription renders no figure', () {
      // Null means the dictionary has no phrase for this move — never "3 × 10".
      // Saying nothing beats saying a number nobody authored.
      final move = _pack.exerciseById('fx_7714_bridge');
      expect(move!.prescriptionLabel, isNull);
    });
  });
}
