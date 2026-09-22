// HANDOFF 13 / P1-RULE-19 — the assessment is the only source of constraints,
// and `ClientConstraintResolver.resolve` is the only constructor of
// `ClientConstraints`.
//
// The read-only property is structural: the constructor is private to the
// resolver's library, every collection it exposes is unmodifiable, and there is
// no setter and no coach-writable field for a screen to bind to.

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/safety/client_constraints.dart';
import 'package:own_hub/domain/safety/contraindication_tag.dart';
import 'package:own_hub/domain/safety/life_stage_safety_policy.dart';
import 'package:own_hub/domain/safety/referral_registry.dart';
import 'package:own_hub/domain/safety/safety_assessment.dart';

SafetyAssessment _assessment({
  Set<ContraindicationTag> avoid = const {},
  LifeStage lifeStage = LifeStage.none,
  List<ScreeningItem> screening = const [],
  Clearance? clearance,
  String? painNotes,
}) => SafetyAssessment(
  assessmentId: 'fx_a4417',
  clientUid: 'fx_client_4417',
  coachUid: 'fx_coach_2031',
  takenAt: DateTime.utc(2031, 2, 17, 9, 30),
  lifeStage: lifeStage,
  avoid: avoid,
  screening: screening,
  clearance: clearance,
  painNotes: painNotes,
);

void main() {
  group('the resolver is the only constructor', () {
    test('it resolves the avoid list from the assessment', () {
      final constraints = ClientConstraintResolver.resolve(
        assessment: _assessment(
          avoid: const {
            ContraindicationTag.highImpact,
            ContraindicationTag.deepKneeFlexion,
          },
        ),
      );
      expect(constraints.isResolved, isTrue);
      expect(constraints.avoid, {
        ContraindicationTag.highImpact,
        ContraindicationTag.deepKneeFlexion,
      });
    });

    test('it folds active referral tags into the avoid set', () {
      // G14 §5.1: the filter's input is avoid ∪ activeTags. Folding them here
      // means every consumer gets the union without having to remember.
      final constraints = ClientConstraintResolver.resolve(
        assessment: _assessment(
          avoid: const {ContraindicationTag.deepKneeFlexion},
          screening: [
            ScreeningItem(
              id: 'fx_scr_4417_pelvic',
              outcome: ScreeningOutcome.refer,
              suppresses: const {
                ContraindicationTag.pelvicFloorLoad,
                ContraindicationTag.jumping,
              },
            ),
          ],
        ),
      );
      expect(constraints.blockedTags, {
        ContraindicationTag.deepKneeFlexion,
        ContraindicationTag.pelvicFloorLoad,
        ContraindicationTag.jumping,
      });
      expect(constraints.referrals, hasLength(1));
    });

    test('it folds derived life-stage tags in too', () {
      final constraints = ClientConstraintResolver.resolve(
        assessment: _assessment(lifeStage: LifeStage.pregnant),
      );
      expect(
        constraints.blockedTags,
        containsAll(LifeStageSafetyPolicy.derivedAvoid(LifeStage.pregnant)),
      );
    });

    test('a prior assessment\'s referral cannot be dropped by silence', () {
      final previous = _assessment(
        screening: [
          ScreeningItem(
            id: 'fx_scr_4417_pelvic',
            outcome: ScreeningOutcome.refer,
            suppresses: const {ContraindicationTag.pelvicFloorLoad},
          ),
        ],
      );
      final constraints = ClientConstraintResolver.resolve(
        assessment: _assessment(),
        priorAssessment: previous,
      );
      expect(
        constraints.blockedTags,
        contains(ContraindicationTag.pelvicFloorLoad),
      );
    });

    test('the none token never becomes a blocking tag', () {
      final constraints = ClientConstraintResolver.resolve(
        assessment: _assessment(avoid: const {ContraindicationTag.none}),
      );
      expect(constraints.blockedTags, isEmpty);
    });
  });

  group('read-only — no public setter, no coach-writable field', () {
    test('the avoid set cannot be added to', () {
      final constraints = ClientConstraintResolver.resolve(
        assessment: _assessment(avoid: const {ContraindicationTag.wristLoad}),
      );
      expect(
        () => constraints.avoid!.add(ContraindicationTag.jumping),
        throwsUnsupportedError,
      );
      expect(
        () => constraints.blockedTags.remove(ContraindicationTag.wristLoad),
        throwsUnsupportedError,
      );
    });

    test('the referral list cannot be added to or cleared', () {
      final constraints = ClientConstraintResolver.resolve(
        assessment: _assessment(
          screening: [
            ScreeningItem(
              id: 'fx_scr_4417_pelvic',
              outcome: ScreeningOutcome.refer,
              suppresses: const {ContraindicationTag.pelvicFloorLoad},
            ),
          ],
        ),
      );
      expect(() => constraints.referrals.clear(), throwsUnsupportedError);
    });

    test('the allergy and dietary sets cannot be written either', () {
      final constraints = ClientConstraintResolver.resolve(
        assessment: _assessment(),
        allergies: const {'nuts'},
        dietary: const {'vegetarian'},
      );
      expect(() => constraints.allergies!.add('sesame'), throwsUnsupportedError);
      expect(() => constraints.dietary!.add('halal'), throwsUnsupportedError);
    });
  });

  group('fail closed — an unknown constraint is not an absent one', () {
    test('no assessment at all resolves to unresolved, not to empty', () {
      final constraints = ClientConstraintResolver.resolve(assessment: null);
      expect(constraints.isResolved, isFalse);
      expect(
        constraints.avoid,
        isNull,
        reason: 'an empty set is a claim — "she has nothing to avoid"',
      );
    });

    test('unresolved is distinguishable from resolved-and-empty', () {
      // The distinction the whole chain turns on, exactly as DietaryConstraints
      // draws it for food.
      final known = ClientConstraintResolver.resolve(assessment: _assessment());
      expect(known.isResolved, isTrue);
      expect(known.avoid, const <ContraindicationTag>{});

      final unknown = ClientConstraintResolver.resolve(assessment: null);
      expect(unknown.isResolved, isFalse);
      expect(unknown.avoid, isNot(const <ContraindicationTag>{}));
    });

    test('allergies stay unknown rather than defaulting to empty', () {
      final constraints = ClientConstraintResolver.resolve(
        assessment: _assessment(),
      );
      expect(constraints.allergies, isNull);
      expect(constraints.dietary, isNull);
    });

    test('a self-declaration still bites while the assessment is unreadable', () {
      // She said she is pregnant in her own profile. The coach's document could
      // not be read. Her statement about her own body is not lost — it narrows
      // the cold-start list further rather than waiting for the projection.
      final constraints = ClientConstraintResolver.resolve(
        assessment: null,
        selfDeclared: SelfDeclaredLifeStage(
          stage: LifeStage.pregnant,
          declaredAt: DateTime.utc(2031, 2, 17),
        ),
      );
      expect(constraints.isResolved, isFalse);
      expect(
        constraints.derivedAvoid,
        containsAll(LifeStageSafetyPolicy.derivedAvoid(LifeStage.pregnant)),
      );
    });

    test('a self-declaration alone never counts as a resolved avoid list', () {
      // Resolving from her life stage alone would be a claim that she has
      // nothing else to avoid, on a document nobody could read.
      final constraints = ClientConstraintResolver.resolve(
        assessment: null,
        selfDeclared: SelfDeclaredLifeStage(
          stage: LifeStage.none,
          declaredAt: DateTime.utc(2031, 2, 17),
        ),
      );
      expect(constraints.isResolved, isFalse);
    });

    test('an avoid token outside the vocabulary fails the whole resolution', () {
      // Dropping the unknown token would leave a constraint set that looks
      // authored and is short by one tag.
      expect(
        () => SafetyAssessment.fromWire(
          assessmentId: 'fx_a4417',
          clientUid: 'fx_client_4417',
          coachUid: 'fx_coach_2031',
          takenAt: DateTime.utc(2031, 2, 17),
          lifeStage: 'none',
          avoid: const ['deep_knee_flexion', 'knee'],
        ),
        throwsA(isA<UnknownContraindicationTag>()),
      );
    });

    test('a wholly known wire assessment resolves', () {
      final assessment = SafetyAssessment.fromWire(
        assessmentId: 'fx_a4417',
        clientUid: 'fx_client_4417',
        coachUid: 'fx_coach_2031',
        takenAt: DateTime.utc(2031, 2, 17),
        lifeStage: 'p0_6w',
        avoid: const ['deep_knee_flexion'],
      );
      expect(assessment.lifeStage, LifeStage.postpartum0to6w);
      expect(assessment.avoid, {ContraindicationTag.deepKneeFlexion});
    });

    test('an unknown life stage on the wire is refused', () {
      expect(
        () => SafetyAssessment.fromWire(
          assessmentId: 'fx_a4417',
          clientUid: 'fx_client_4417',
          takenAt: DateTime.utc(2031, 2, 17),
          lifeStage: 'postpartum',
        ),
        throwsArgumentError,
      );
    });
  });

  group('free prose is never a safety input', () {
    test('painNotes is carried for display and changes no tag', () {
      // G14 §1.4: "Displayed to the coach; never parsed, never used to filter".
      final withNotes = ClientConstraintResolver.resolve(
        assessment: _assessment(
          painNotes: 'Diastasis, 4-finger gap. Jumping hurts. Avoid burpees.',
        ),
      );
      final withoutNotes = ClientConstraintResolver.resolve(
        assessment: _assessment(),
      );
      expect(withNotes.blockedTags, withoutNotes.blockedTags);
      expect(withNotes.blockedTags, isEmpty);
    });
  });

  group('the document id is deterministic — G14 §1.4', () {
    test('a coach-authored assessment scopes to coach and client', () {
      expect(_assessment().scopeKey, 'fx_coach_2031_fx_client_4417');
    });

    test('a self-authored assessment scopes to self', () {
      final self = SafetyAssessment(
        assessmentId: 'fx_a_self',
        clientUid: 'fx_client_4417',
        takenAt: DateTime.utc(2031, 2, 17),
        lifeStage: LifeStage.none,
      );
      expect(self.scopeKey, 'self_fx_client_4417');
      expect(self.coachUid, isNull);
    });
  });
}
