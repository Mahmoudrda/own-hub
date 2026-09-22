// The allergy capture surface — DECISIONS.md D3, and the interlock that closes
// the live safety hazard in allergy_interlock_test.dart.
//
// The distinction every test here turns on: `unknown` is an ABSENCE and `none`
// is a CLAIM. Collapsing them is how a safety guard silently switches itself off
// for exactly the women nobody has asked yet.

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/account/domain/dietary_profile.dart';
import 'package:own_hub/features/eat/domain/allergy_guard.dart';
import 'package:own_hub/features/eat/domain/food_library.dart';

/// A dish that genuinely contains a named allergen.
const _cashewRice = Food(
  foodId: 'cashew_rice',
  names: ['cashew rice'],
  sizes: [FoodSize(id: 'M', label: 'Medium', kcal: 430, proteinG: 11)],
  allergens: {'nuts'},
  dietTags: {'vegetarian'},
);

/// A dish nobody has tagged. Unknown allergens — which is every dish today.
const _untagged = Food(
  foodId: 'molokhia',
  names: ['molokhia'],
  sizes: [FoodSize(id: 'M', label: 'Medium', kcal: 280, proteinG: 19)],
);

/// A dish carrying **two** named allergens, for the partial-acknowledgement
/// case. A dish with only one cannot distinguish "she acknowledged the only
/// conflict" from "acknowledging one cleared the other".
const _creamyPasta = Food(
  foodId: 'creamy_pasta',
  names: ['creamy pasta'],
  sizes: [FoodSize(id: 'M', label: 'Medium', kcal: 520, proteinG: 17)],
  allergens: {'dairy', 'gluten'},
);

void main() {
  group('unasked is not the same as "no allergies"', () {
    test(
      'a woman nobody has asked reads as UNKNOWN, and the guard fails closed',
      () {
        const profile = DietaryProfile.unasked;

        expect(profile.asked, isFalse);
        expect(profile.allergies, isNull);

        final constraints = profile.toConstraints();
        expect(
          constraints.allergies,
          isNull,
          reason: 'null is unreadable — an empty set is a statement about her',
        );
        expect(constraints.allergiesKnown, isFalse);

        // The guard's case 3: an unknown constraint is not an absent one.
        final assessment = AllergyGuard(constraints).assess(_cashewRice);
        expect(assessment.isBlocked, isTrue);
        expect(assessment.reason, AllergyBlockReason.constraintsUnavailable);
      },
    );

    test(
      'a woman who was asked and named nothing reads as NONE, and clears',
      () {
        const profile = DietaryProfile.noneNamed;

        expect(profile.asked, isTrue);
        expect(profile.allergies, isEmpty);

        final constraints = profile.toConstraints();
        expect(constraints.allergies, isEmpty);
        expect(constraints.allergiesKnown, isTrue);

        // Nothing to fail closed about, so an untagged dish is not a conflict
        // for her.
        expect(AllergyGuard(constraints).assess(_untagged).isBlocked, isFalse);
        expect(
          AllergyGuard(constraints).assess(_cashewRice).isBlocked,
          isFalse,
        );
      },
    );

    test('the two states are not equal, and neither is reachable by accident', () {
      expect(DietaryProfile.unasked == DietaryProfile.noneNamed, isFalse);

      // `noneNamed` is only ever produced by her answering — a repository that
      // has never been written returns `unasked`.
      final repository = InMemoryDietaryProfileRepository();
      expect(repository.read(), DietaryProfile.unasked);
      expect(repository.read().asked, isFalse);
    });
  });

  group('her real answer reaches the guard', () {
    test(
      'a named allergy blocks the dish that contains it, and names it',
      () async {
        final repository = InMemoryDietaryProfileRepository();
        final saved = await repository.save(allergies: {AllergenTag.nuts});

        final constraints = saved.toConstraints();
        expect(constraints.allergies, {'nuts'});

        final assessment = AllergyGuard(constraints).assess(_cashewRice);

        expect(assessment.isBlocked, isTrue);
        expect(assessment.reason, AllergyBlockReason.namedAllergen);
        expect(assessment.allergens, {
          'nuts',
        }, reason: 'the sheet names the allergen she told us about');
      },
    );

    test('an untagged dish is blocked for a woman WITH an allergy', () async {
      // Spine §1: a missing tag reads as "unknown, therefore unsafe" — never as
      // safe. This is the case that matters today, because no food in the
      // shipped pack carries allergen data at all.
      final repository = InMemoryDietaryProfileRepository();
      final saved = await repository.save(allergies: {AllergenTag.shellfish});

      final assessment = AllergyGuard(saved.toConstraints()).assess(_untagged);

      expect(assessment.isBlocked, isTrue);
      expect(assessment.reason, AllergyBlockReason.unknownAllergenData);
    });

    test(
      'screening removes a conflicting dish before it is ever offered',
      () async {
        final repository = InMemoryDietaryProfileRepository();
        final saved = await repository.save(
          allergies: {AllergenTag.nuts},
          dietary: {DietaryTag.everything},
        );

        final screened = AllergyGuard(saved.toConstraints())
            .screen([_cashewRice, _untagged]);

        // Both go: one for a named allergen, one for unknown allergen data.
        expect(screened, isEmpty);
      },
    );

    test('two allergens are carried across independently', () async {
      final repository = InMemoryDietaryProfileRepository();
      final saved = await repository.save(
        allergies: {AllergenTag.dairy, AllergenTag.gluten},
      );

      expect(saved.toConstraints().allergies, {'dairy', 'gluten'});

      // Acknowledging one does not clear the other. The dish carries both of
      // her allergens; she accepts the dairy and the gluten still blocks.
      final assessment = AllergyGuard(saved.toConstraints())
          .assess(_creamyPasta, acknowledged: {'dairy'});

      expect(assessment.isBlocked, isTrue);
      expect(
        assessment.allergens,
        {'gluten'},
        reason:
            'an explicit tap clears only the allergen it names — she is the '
            'authority on her own body, one allergen at a time',
      );

      // And acknowledging both clears it.
      expect(
        AllergyGuard(saved.toConstraints())
            .assess(_creamyPasta, acknowledged: {'dairy', 'gluten'})
            .isBlocked,
        isFalse,
      );
    });

    test('an allergen she does not have is not a conflict for her', () async {
      // The complement, and the reason the test above needed a two-allergen
      // dish: a dish containing nuts is simply fine for a woman allergic to
      // dairy. A guard that blocked here would interrupt women who have no
      // relevant allergy — G7 Q18's exact complaint about the status quo.
      final repository = InMemoryDietaryProfileRepository();
      final saved = await repository.save(allergies: {AllergenTag.dairy});

      expect(
        AllergyGuard(saved.toConstraints()).assess(_cashewRice).isBlocked,
        isFalse,
      );
    });
  });

  group('the write is a per-field merge, and G2 owns the field', () {
    test('saving allergies writes profile.allergies and nothing else', () async {
      final repository = InMemoryDietaryProfileRepository();

      await repository.save(allergies: {AllergenTag.nuts});

      expect(
        repository.writes,
        [
          {'profile.allergies'},
        ],
        reason:
            'G7 Q18: G7 hosts the row and G2 writes the field. The write names '
            'one field path, exactly as IntakeRepository.merge does.',
      );
    });

    test(
      'saving both writes both, and saving one later does not clear the other',
      () async {
        final repository = InMemoryDietaryProfileRepository();

        await repository.save(
          allergies: {AllergenTag.nuts},
          dietary: {DietaryTag.vegetarianWeekdays},
        );
        await repository.save(allergies: {AllergenTag.nuts, AllergenTag.dairy});

        expect(repository.writes, [
          {'profile.allergies', 'profile.dietary'},
          {'profile.allergies'},
        ]);

        // D3 — editable forever. The second save edited allergies and left her
        // dietary answer alone.
        final profile = repository.read();
        expect(profile.allergies, {AllergenTag.nuts, AllergenTag.dairy});
        expect(profile.dietary, {DietaryTag.vegetarianWeekdays});
      },
    );

    test('clearing her allergies is an answer, not an erasure', () async {
      final repository = InMemoryDietaryProfileRepository(
        const DietaryProfile(allergies: {AllergenTag.nuts}),
      );

      // She removes the last chip. That is "I have no allergies", which is a
      // claim she is entitled to make — and is NOT the same as never asked.
      final saved = await repository.save(allergies: const <AllergenTag>{});

      expect(saved.asked, isTrue);
      expect(saved.allergies, isEmpty);
      expect(saved.toConstraints().allergies, isEmpty);
      expect(saved.toConstraints().allergiesKnown, isTrue);
    });
  });

  group('the vocabulary is the one content authored', () {
    test('four allergens, matching G17', () {
      expect(AllergenTag.values.map((a) => a.wireName).toList(), [
        'nuts',
        'dairy',
        'gluten',
        'shellfish',
      ]);
    });

    test('wire names round-trip, case- and whitespace-insensitively', () {
      // AllergyGuard compares this way, so a tag stored as "Nuts" must still
      // match. A guard that missed on capitalisation would fail OPEN.
      expect(AllergenTag.fromWire('nuts'), AllergenTag.nuts);
      expect(AllergenTag.fromWire(' Gluten '), AllergenTag.gluten);
      expect(AllergenTag.fromWire('sesame'), isNull);
    });

    test('"everything" means nothing is filtered', () {
      expect(DietaryTag.everything.requiredDishTags, isEmpty);

      const profile = DietaryProfile(
        allergies: <AllergenTag>{},
        dietary: {DietaryTag.everything},
      );
      expect(profile.toConstraints().dietary, isEmpty);
    });

    test('a dietary preference never blocks a dish with unknown tags', () {
      // The asymmetry G5 §5.1 insists on: a preference gets no sheet, no
      // override and no warning, and an unknown tag is NOT a conflict for it.
      // Treating a preference like an allergy trains her to dismiss the sheet
      // that matters.
      const profile = DietaryProfile(
        allergies: <AllergenTag>{},
        dietary: {DietaryTag.vegetarianWeekdays},
      );

      final screened = AllergyGuard(profile.toConstraints())
          .screen([_untagged]);

      expect(screened, hasLength(1));
    });
  });
}
