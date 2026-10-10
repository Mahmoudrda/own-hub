// P0-EAT-01 — "An allergy conflict fails closed."
//
// READ THIS BEFORE TRUSTING THE GREEN TICKS BELOW.
//
// **P0-EAT-01 is NOT COVERED by this file, and cannot be covered by any file
// today.** The case requires a precondition — "Intake records a nut allergy" —
// and an input: a dish known to contain nuts. Neither exists in the product:
//
//   * `foods.allergens[]` and `foods.dietTags[]` are unauthored.
//     `SCHEMA-SPINE.md` §1 calls them "mandatory, not enrichment";
//     `PHASE1-FINDINGS.md` F7 confirms they are still absent; `DECISIONS.md`
//     lists them under "Blocking Phase 2" and states outright that "Without
//     them `AllergyGuard` cannot function and **P0-EAT-01 cannot pass**".
//   * No screen anywhere captures `profile.allergies`, although `DECISIONS.md`
//     D3 says it is collected at sign-up and editable in My Profile. G5 §9 Q10b
//     and G7 Q18 agree and both defer the home to the owner.
//
// What this file DOES prove is that the guard's semantics are right, so that the
// day the content lands the behaviour is already correct and tested. Every food
// below is a fixture built inside this test file. **No allergen tag has been
// invented in `lib/`.** A guard that passed P0-EAT-01 by shipping a fabricated
// allergen list would be a fabricated safety guarantee shown to a woman with a
// food allergy, which is the worst outcome this feature can produce.
//
// The three fail-closed cases, and the one deliberate asymmetry, are below.

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/eat/domain/allergy_guard.dart';
import 'package:own_hub/features/eat/domain/food_library.dart';

const _sizes = [FoodSize(id: 'M', label: 'Medium', kcal: 400, proteinG: 20)];

/// A dish somebody has tagged. Does not exist in the shipped pack.
Food _tagged(String id, Set<String> allergens, {Set<String>? dietTags}) => Food(
  foodId: id,
  names: [id],
  allergens: allergens,
  dietTags: dietTags,
  sizes: _sizes,
);

/// A dish as the pack actually ships it today: **no allergen data at all.**
Food _untagged(String id) => Food(foodId: id, names: [id], sizes: _sizes);

void main() {
  group('the type distinguishes "none" from "unknown"', () {
    test('an untagged food reports its allergens as unknown, not as empty', () {
      final food = _untagged('koshari');
      expect(food.allergens, isNull);
      expect(food.allergensUnknown, isTrue);
      // This is the distinction the whole guard turns on. An empty set is a
      // CLAIM — "this contains none of what you named" — and nobody is in a
      // position to make it.
      expect(food.allergens, isNot(const <String>{}));
    });

    test('unknown constraints are not the same as no constraints', () {
      expect(DietaryConstraints.unknown.allergies, isNull);
      expect(DietaryConstraints.unknown.allergiesKnown, isFalse);

      expect(DietaryConstraints.none.allergies, const <String>{});
      expect(DietaryConstraints.none.allergiesKnown, isTrue);
      expect(DietaryConstraints.none.hasAllergies, isFalse);
    });
  });

  group('fail closed, case 1 — a named allergen', () {
    const guard = AllergyGuard(DietaryConstraints(allergies: {'nuts'}));

    test('the log is refused and the allergen is named', () {
      final verdict = guard.assess(_tagged('yoghurt_dates_nuts', {'nuts'}));

      expect(verdict.isBlocked, isTrue);
      expect(verdict.reason, AllergyBlockReason.namedAllergen);
      expect(
        verdict.allergens,
        {'nuts'},
        reason:
            'the sheet has to name what she reacts to, not say "an '
            'ingredient"',
      );
    });

    test('capitalisation and stray whitespace cannot make it fail open', () {
      const messy = AllergyGuard(DietaryConstraints(allergies: {' Nuts '}));
      expect(messy.assess(_tagged('cake', {'NUTS'})).isBlocked, isTrue);
    });

    test('a dish without that allergen is clear', () {
      expect(guard.assess(_tagged('ful', {'sesame'})).isBlocked, isFalse);
    });
  });

  group('fail closed, case 2 — unknown allergen data', () {
    const guard = AllergyGuard(DietaryConstraints(allergies: {'nuts'}));

    test('a dish with no allergen list is refused, not allowed', () {
      final verdict = guard.assess(_untagged('koshari'));

      expect(
        verdict.isBlocked,
        isTrue,
        reason:
            'SCHEMA-SPINE §1: a missing tag reads as "unknown, therefore '
            'unsafe" — never as safe',
      );
      expect(verdict.reason, AllergyBlockReason.unknownAllergenData);
      expect(
        verdict.allergens,
        isEmpty,
        reason:
            'naming a specific allergen here would state something nobody '
            'knows',
      );
    });

    test('this is the state EVERY dish is in today', () {
      // The shipped pack carries no allergens[]. Recorded as an executable fact
      // rather than as a comment: if the content lands and this test starts
      // failing, that is the signal to re-run P0-EAT-01 for real.
      final shippedShape = _untagged('anything_at_all');
      expect(shippedShape.allergensUnknown, isTrue);
      expect(guard.assess(shippedShape).isBlocked, isTrue);
    });
  });

  group('fail closed, case 3 — her constraints cannot be read', () {
    const guard = AllergyGuard(DietaryConstraints.unknown);

    test('a log is refused even for a dish with a clean allergen list', () {
      final verdict = guard.assess(_tagged('plain_rice', const <String>{}));

      expect(
        verdict.isBlocked,
        isTrue,
        reason: 'G5 §5.1: "An unknown constraint is not an absent one."',
      );
      expect(verdict.reason, AllergyBlockReason.constraintsUnavailable);
    });

    test('but suggestions still render — the list is not emptied', () {
      final candidates = [
        _tagged('a', {'nuts'}),
        _untagged('b'),
        _tagged('c', const <String>{}),
      ];

      expect(
        guard.screen(candidates),
        hasLength(3),
        reason:
            'G5 §5.1 item 3 is explicit that suggestions render while the '
            'profile is unavailable; the block happens at the moment of the '
            'log, not by leaving her with a blank screen',
      );
    });
  });

  group('a woman who was asked and named nothing', () {
    const guard = AllergyGuard(DietaryConstraints.none);

    test('is never blocked, even on a dish with no allergen data', () {
      expect(guard.assess(_untagged('koshari')).isBlocked, isFalse);
      expect(guard.assess(_tagged('cake', {'nuts'})).isBlocked, isFalse);
    });

    test('and nothing is filtered out of her suggestions', () {
      final candidates = [
        _tagged('a', {'nuts'}),
        _untagged('b'),
      ];
      expect(guard.screen(candidates), hasLength(2));
    });
  });

  group('screen() removes candidates BEFORE ranking', () {
    const guard = AllergyGuard(DietaryConstraints(allergies: {'sesame'}));

    test('a dish containing her allergen never reaches the ranker', () {
      final kept = guard.screen([
        _tagged('tahini_salad', {'sesame'}),
        _tagged('grilled_chicken', const <String>{}),
      ]);

      expect(kept.map((f) => f.foodId), ['grilled_chicken']);
    });

    test('a dish with unknown allergens is removed too', () {
      final kept = guard.screen([_untagged('koshari')]);
      expect(
        kept,
        isEmpty,
        reason:
            'filtering at the source, not validating after (§5.1). A ranker '
            'that saw it first and had it removed afterwards is how the filter '
            'gets "fixed" by moving it later',
      );
    });
  });

  group('a dietary preference is deliberately NOT treated like an allergy', () {
    const guard = AllergyGuard(
      DietaryConstraints(allergies: <String>{}, dietary: {'vegetarian'}),
    );

    test('it is excluded from suggestions', () {
      final kept = guard.screen([
        _tagged(
          'grilled_chicken',
          const <String>{},
          dietTags: const <String>{},
        ),
        _tagged('koshari', const <String>{}, dietTags: {'vegetarian'}),
      ]);

      expect(kept.map((f) => f.foodId), ['koshari']);
    });

    test('but logging one raises NO block at all', () {
      final chicken = _tagged(
        'grilled_chicken',
        const <String>{},
        dietTags: const <String>{},
      );

      expect(
        guard.assess(chicken).isBlocked,
        isFalse,
        reason:
            'G5 §5.1: "No sheet, no override, no warning." Treating a '
            'preference like an allergy trains her to dismiss the sheet that '
            'matters',
      );
    });

    test('and an untagged dish is not excluded on a preference', () {
      // Unknown diet tags must not empty the recipe list for every woman with a
      // preference, on content that does not exist yet.
      expect(guard.screen([_untagged('koshari')]), hasLength(1));
    });
  });

  group('she is the authority on her own body', () {
    const guard = AllergyGuard(
      DietaryConstraints(allergies: {'sesame', 'nuts'}),
    );

    test('an explicit acknowledgement clears the block', () {
      final dish = _tagged('tahini', {'sesame'});

      expect(guard.assess(dish).isBlocked, isTrue);
      expect(
        guard.assess(dish, acknowledged: {'sesame'}).isBlocked,
        isFalse,
        reason: '"Add it anyway" is an explicit tap, and it is hers to make',
      );
    });

    test('acknowledging one allergen does not clear a different one', () {
      final dish = _tagged('baklava', {'sesame', 'nuts'});
      final verdict = guard.assess(dish, acknowledged: {'sesame'});

      expect(verdict.isBlocked, isTrue);
      expect(
        verdict.allergens,
        {'nuts'},
        reason:
            'accepting sesame is not accepting nuts, and a guard that '
            'treated one tap as blanket consent would be worse than none',
      );
    });
  });

  test('P0-EAT-01 is NOT COVERED — recorded, not rounded up', () {
    // Deliberately a passing test that states a failure. The case needs a dish
    // KNOWN to contain nuts and a profile that RECORDS a nut allergy. The guard
    // handles both correctly once they exist; neither exists.
    //
    // Both halves are content obligations tracked in DECISIONS.md, and neither
    // may be invented here. This assertion exists so that the reason travels
    // with the code rather than living only in a report.
    const asShipped = AllergyGuard(DietaryConstraints.unknown);
    final asShippedFood = _untagged('koshari_bowl');

    expect(asShippedFood.allergensUnknown, isTrue);
    expect(asShipped.constraints.allergiesKnown, isFalse);
    expect(
      asShipped.assess(asShippedFood).reason,
      AllergyBlockReason.constraintsUnavailable,
      reason:
          'In the shipped product EVERY assessment lands here, which is fail-'
          'closed and correct — and it means the guard currently interrupts '
          'women who have no allergy at all (G7 Q18). That is a content gap, '
          'not a code defect.',
    );
  });
}
