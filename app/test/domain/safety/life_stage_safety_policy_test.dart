// Pregnancy and postpartum — PHASE3-PLAN §1.4.
//
// "Today nothing in the specs makes a recorded pregnancy restrict anything."
// This is the hole being closed, and the owner approved a policy STRICTER than
// the spec: a recorded life stage derives avoid-tags on its own, and publishing
// is blocked while clearance is withheld during the first six weeks.
//
// The self-declaration half (item 7) is the other approved addition: she can
// state her life stage in her own profile, and a coach's assessment does not
// silently override what she said about her own body.

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/safety/contraindication_tag.dart';
import 'package:own_hub/domain/safety/life_stage_safety_policy.dart';

/// The five the owner approved. "At least" these — never fewer.
const Set<ContraindicationTag> _ownerApprovedMinimum = {
  ContraindicationTag.pelvicFloorLoad,
  ContraindicationTag.highImpact,
  ContraindicationTag.jumping,
  ContraindicationTag.supineLoad,
  ContraindicationTag.breathHoldValsalva,
};

void main() {
  group('the vocabulary of life stages is G14 §1.4', () {
    test('five stages, with the spec wire names', () {
      expect(LifeStage.values.map((s) => s.wireName).toSet(), {
        'pregnant',
        'p0_6w',
        'p6w_1y',
        'over_1y',
        'none',
      });
    });

    test('an unknown stage has no representation', () {
      expect(LifeStage.fromWire('postpartum'), isNull);
      expect(LifeStage.fromWire('pain_injury'), isNull);
      expect(LifeStage.fromWire('p0_6w'), LifeStage.postpartum0to6w);
    });
  });

  group('a recorded life stage derives avoid-tags automatically', () {
    test('pregnant derives at least the five the owner approved', () {
      final derived = LifeStageSafetyPolicy.derivedAvoid(LifeStage.pregnant);
      for (final tag in _ownerApprovedMinimum) {
        expect(
          derived,
          contains(tag),
          reason: '${tag.wireName} must be derived for a pregnant client',
        );
      }
    });

    test('p0_6w derives at least the same five', () {
      final derived = LifeStageSafetyPolicy.derivedAvoid(
        LifeStage.postpartum0to6w,
      );
      for (final tag in _ownerApprovedMinimum) {
        expect(derived, contains(tag), reason: tag.wireName);
      }
    });

    test('negative control — none derives nothing', () {
      // If every stage derived the same tags the policy would be a constant,
      // and the test above would pass while the feature did nothing.
      expect(LifeStageSafetyPolicy.derivedAvoid(LifeStage.none), isEmpty);
      expect(LifeStageSafetyPolicy.derivedAvoid(LifeStage.over1y), isEmpty);
    });

    test('a derived set never contains the none token', () {
      for (final stage in LifeStage.values) {
        expect(
          LifeStageSafetyPolicy.derivedAvoid(stage),
          isNot(contains(ContraindicationTag.none)),
        );
      }
    });
  });

  group('publishing is blocked when clearance is withheld during p0_6w', () {
    test('granted:false blocks — it is a recorded answer, not a gap', () {
      final decision = LifeStageSafetyPolicy.publishGate(
        stage: LifeStage.postpartum0to6w,
        clearance: Clearance(
          granted: false,
          recordedAt: DateTime.utc(2031, 2, 17),
        ),
      );
      expect(decision.allowed, isFalse);
      expect(decision.reason, PublishBlockReason.clearanceWithheld);
    });

    test(
      'no clearance recorded at all also blocks — unknown is not absent',
      () {
        final decision = LifeStageSafetyPolicy.publishGate(
          stage: LifeStage.postpartum0to6w,
          clearance: null,
        );
        expect(decision.allowed, isFalse);
        expect(decision.reason, PublishBlockReason.clearanceUnrecorded);
      },
    );

    test('granted:true during p0_6w publishes', () {
      final decision = LifeStageSafetyPolicy.publishGate(
        stage: LifeStage.postpartum0to6w,
        clearance: Clearance(
          granted: true,
          recordedAt: DateTime.utc(2031, 2, 17),
        ),
      );
      expect(decision.allowed, isTrue);
      expect(decision.reason, isNull);
    });

    test('negative control — the gate is p0_6w only, not every stage', () {
      // A gate that blocked everything would pass the blocking tests above and
      // make the product unusable for the women it is not about.
      for (final stage in [
        LifeStage.none,
        LifeStage.over1y,
        LifeStage.postpartum6wTo1y,
        LifeStage.pregnant,
      ]) {
        expect(
          LifeStageSafetyPolicy.publishGate(
            stage: stage,
            clearance: null,
          ).allowed,
          isTrue,
          reason: '${stage.wireName} must not be gated on clearance',
        );
      }
    });
  });

  group('she can state her life stage in her own profile', () {
    test('a self-declaration alone drives the policy', () {
      final effective = LifeStageSafetyPolicy.effective(
        recorded: LifeStage.none,
        selfDeclared: SelfDeclaredLifeStage(
          stage: LifeStage.pregnant,
          declaredAt: DateTime.utc(2031, 2, 17),
        ),
      );
      expect(effective.stage, LifeStage.pregnant);
      expect(effective.derivedAvoid, containsAll(_ownerApprovedMinimum));
    });

    test('a coach assessment does not silently override what she said', () {
      // The coach recorded the least restrictive answer; she said she is in the
      // first six weeks. The union takes hers, and both sources stay readable
      // so a screen can show the disagreement rather than resolve it quietly.
      final effective = LifeStageSafetyPolicy.effective(
        recorded: LifeStage.none,
        selfDeclared: SelfDeclaredLifeStage(
          stage: LifeStage.postpartum0to6w,
          declaredAt: DateTime.utc(2031, 2, 17),
        ),
      );
      expect(effective.stage, LifeStage.postpartum0to6w);
      expect(effective.sourcesDisagree, isTrue);
      expect(effective.recorded, LifeStage.none);
      expect(effective.selfDeclared, LifeStage.postpartum0to6w);
    });

    test('where they disagree the more protective one wins, either way', () {
      // The coach is the more protective source here. Hers is still recorded.
      final effective = LifeStageSafetyPolicy.effective(
        recorded: LifeStage.pregnant,
        selfDeclared: SelfDeclaredLifeStage(
          stage: LifeStage.over1y,
          declaredAt: DateTime.utc(2031, 2, 17),
        ),
      );
      expect(effective.stage, LifeStage.pregnant);
      expect(effective.sourcesDisagree, isTrue);
      expect(effective.selfDeclared, LifeStage.over1y);
    });

    test('the derived set is the union of both sources, never one alone', () {
      final effective = LifeStageSafetyPolicy.effective(
        recorded: LifeStage.pregnant,
        selfDeclared: SelfDeclaredLifeStage(
          stage: LifeStage.postpartum0to6w,
          declaredAt: DateTime.utc(2031, 2, 17),
        ),
      );
      expect(
        effective.derivedAvoid,
        containsAll(
          LifeStageSafetyPolicy.derivedAvoid(LifeStage.pregnant).union(
            LifeStageSafetyPolicy.derivedAvoid(LifeStage.postpartum0to6w),
          ),
        ),
      );
    });

    test('the publish gate reads the effective stage, not the coach field', () {
      // She says first six weeks; the coach recorded nothing. Withholding the
      // gate here would be the silent override the owner asked to prevent.
      final effective = LifeStageSafetyPolicy.effective(
        recorded: LifeStage.none,
        selfDeclared: SelfDeclaredLifeStage(
          stage: LifeStage.postpartum0to6w,
          declaredAt: DateTime.utc(2031, 2, 17),
        ),
      );
      expect(
        LifeStageSafetyPolicy.publishGate(
          stage: effective.stage,
          clearance: null,
        ).allowed,
        isFalse,
      );
    });

    test('no self-declaration leaves the recorded answer untouched', () {
      final effective = LifeStageSafetyPolicy.effective(
        recorded: LifeStage.postpartum6wTo1y,
        selfDeclared: null,
      );
      expect(effective.stage, LifeStage.postpartum6wTo1y);
      expect(effective.selfDeclared, isNull);
      expect(effective.sourcesDisagree, isFalse);
    });
  });
}
