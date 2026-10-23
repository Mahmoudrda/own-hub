// P0-INTAKE-01 and P0-INTAKE-02 — her allergies are stated once, reach the
// coach, and stay editable.
//
// The assertion that carries the rule is about **who wrote what**: G17 writes
// her allergies to the profile and writes nothing allergy-shaped into the
// intake document, so there is exactly one source for the fact that matters.

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/account/domain/dietary_profile.dart';
import 'package:own_hub/features/coached/domain/coach_projection.dart';
import 'package:own_hub/features/coached/domain/intake.dart';

const _relId = 'c7k9farida__u3m2rania';

void main() {
  group('P0-INTAKE-01 — allergies stated once reach the coach', () {
    test(
      'G17 writes the profile, and nothing allergy-shaped into the intake',
      () async {
        final profile = InMemoryDietaryProfileRepository();
        final intake = InMemoryCoachingIntakeRepository(profile: profile);

        await intake.mergeFood(
          relId: _relId,
          cookMinutes: 45,
          familyPot: true,
          allergies: {AllergenTag.crustaceans, AllergenTag.gluten},
          dietary: {DietaryTag.vegetarianWeekdays},
        );

        // The profile has them…
        expect(profile.read().allergies, {
          AllergenTag.crustaceans,
          AllergenTag.gluten,
        });
        expect(profile.writes.last, contains('profile.allergies'));

        // …and the intake document holds no copy that could drift from it.
        final written = intake.writes.expand((w) => w).toSet();
        for (final field in written) {
          expect(
            RegExp('(allerg|dietary)', caseSensitive: false).hasMatch(field),
            isFalse,
            reason: 'the intake wrote $field — a second source for one fact',
          );
        }
      },
    );

    test('the constraints projection carries what she stated', () {
      final writer = CoachProjectionWriter(store: CoachProjectionStore());
      final profile = DietaryProfile(
        allergies: const {AllergenTag.crustaceans},
        dietary: const {DietaryTag.vegetarianWeekdays},
      );

      final constraints = writer.buildConstraints(
        ProjectionInputs(
          allergies: profile.allergies!.map((a) => a.wireName).toList(),
          dietary: profile.dietary!.expand((d) => d.requiredDishTags).toList(),
          avoid: const ['left shoulder'],
        ),
      );

      // `shellfish` until the vocabulary widened to the EU/UK declarables,
      // which split it into crustaceans and molluscs.
      expect(constraints.allergies, ['crustaceans']);
      expect(constraints.dietary, ['vegetarian']);
      // The avoid list is about movement, never about food.
      expect(constraints.avoid, ['left shoulder']);
    });

    test('no coach screen has anything to type into', () {
      // The projection is read-only: no setter, no copyWith, no mutable list.
      const constraints = SharedConstraints(allergies: ['crustaceans']);
      expect(constraints.allergies, hasLength(1));
      // Mutating the list it exposes throws, because `buildConstraints` wraps
      // it unmodifiable.
      final built = const CoachProjectionWriter().buildConstraints(
        const ProjectionInputs(allergies: ['crustaceans']),
      );
      expect(
        () => built.allergies.add('sesame'),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });

  group('P0-INTAKE-02 — nothing collected at intake is frozen', () {
    test('editing the allergy list later is the same merge', () async {
      final profile = InMemoryDietaryProfileRepository();
      final intake = InMemoryCoachingIntakeRepository(profile: profile);

      await intake.mergeFood(relId: _relId, allergies: {AllergenTag.treeNuts});
      // A month later, from My Profile — the identical call.
      await profile.save(allergies: {AllergenTag.treeNuts, AllergenTag.milk});

      expect(profile.read().allergies, {
        AllergenTag.treeNuts,
        AllergenTag.milk,
      });
    });

    test('a merge touches only the fields it names', () async {
      final profile = InMemoryDietaryProfileRepository();
      final intake = InMemoryCoachingIntakeRepository(profile: profile);

      await intake.mergeTraining(relId: _relId, goalNote: 'Carry my son.');
      expect(intake.writes.last, contains('goalNote'));
      expect(intake.writes.last, isNot(contains('cookMinutes')));

      await intake.mergeSupport(relId: _relId, dailyCheckin: true);
      expect(intake.writes.last, contains('dailyCheckin'));
      expect(intake.writes.last, isNot(contains('goalNote')));
    });

    test('abandoning after two steps leaves two real answers', () async {
      final profile = InMemoryDietaryProfileRepository();
      final intake = InMemoryCoachingIntakeRepository(profile: profile);

      await intake.mergeTraining(relId: _relId, avoid: const ['left shoulder']);
      await intake.mergeFood(relId: _relId, cookMinutes: 45);

      final held = intake.read(_relId);
      expect(held.avoid, ['left shoulder']);
      expect(held.cookMinutes, 45);
      expect(held.isSubmitted, isFalse);
      expect(held.step, IntakeStep.support);
    });
  });

  group('submitting', () {
    test('the three steps complete, then submit stamps the time', () async {
      final profile = InMemoryDietaryProfileRepository();
      final intake = InMemoryCoachingIntakeRepository(profile: profile);

      await intake.mergeTraining(relId: _relId, goalNote: 'Carry my son.');
      await intake.mergeFood(
        relId: _relId,
        cookMinutes: 45,
        allergies: {AllergenTag.crustaceans},
      );
      await intake.mergeSupport(
        relId: _relId,
        reminderLocalTime: '06:15',
        dailyCheckin: true,
      );

      final submitted = await intake.submit(
        relId: _relId,
        at: DateTime(2026, 9, 19, 20, 12),
      );

      expect(submitted.step, IntakeStep.done);
      expect(submitted.submittedAt, DateTime(2026, 9, 19, 20, 12));
      // The echo carries what the profile says, not a second answer.
      expect(submitted.profileEcho.allergies, ['crustaceans']);
    });

    test('submitting a half-answered intake throws', () {
      final intake = InMemoryCoachingIntakeRepository(
        profile: InMemoryDietaryProfileRepository(),
      );
      expect(
        () => intake.submit(relId: _relId, at: DateTime(2026, 9, 19)),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('negative controls', () {
    test('an unasked profile stays unasked — the intake invents nothing', () async {
      final profile = InMemoryDietaryProfileRepository();
      final intake = InMemoryCoachingIntakeRepository(profile: profile);

      await intake.mergeFood(relId: _relId, cookMinutes: 20);

      expect(profile.read().asked, isFalse);
      expect(
        profile.read().toConstraints().allergiesKnown,
        isFalse,
        reason:
            'unknown is not "she has no allergies". The guard must still fail '
            'closed.',
      );
    });

    test('the echo is a copy, and the profile is the authority', () async {
      final profile = InMemoryDietaryProfileRepository();
      final intake = InMemoryCoachingIntakeRepository(profile: profile);

      await intake.mergeFood(relId: _relId, allergies: {AllergenTag.treeNuts});
      final echoed = intake.read(_relId).profileEcho.allergies;
      expect(echoed, ['tree_nuts']);

      // She changes her mind in My Profile. The authority moves; the echo is
      // stale until the next intake write, which is why readers prefer the
      // profile.
      await profile.save(allergies: {AllergenTag.treeNuts, AllergenTag.milk});
      expect(intake.read(_relId).profileEcho.allergies, ['tree_nuts']);
      expect(profile.read().allergies, hasLength(2));
    });

    test(
      'the avoid list is capped in spirit: it is movement, not food',
      () async {
        final intake = InMemoryCoachingIntakeRepository(
          profile: InMemoryDietaryProfileRepository(),
        );
        await intake.mergeTraining(
          relId: _relId,
          avoid: const ['left shoulder', 'lower back'],
        );
        expect(intake.read(_relId).avoid, ['left shoulder', 'lower back']);
      },
    );
  });
}
