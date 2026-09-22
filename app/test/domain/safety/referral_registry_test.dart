// HANDOFF 14 and P0-ASMT-04 — a referral cannot expire, decay, or be cleared
// by silence.
//
// G14 §3.2: "REFER → CLEARED is the only exit, it is an explicit coach action
// carrying a reason, and it is recorded on a new assessment document — never by
// editing the old one."
//
// The half that is easy to get wrong is *silence*: a re-assessment that simply
// does not mention the referral must not drop it.

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/safety/contraindication_tag.dart';
import 'package:own_hub/domain/safety/life_stage_safety_policy.dart';
import 'package:own_hub/domain/safety/referral_registry.dart';
import 'package:own_hub/domain/safety/safety_assessment.dart';

ScreeningItem _refer() => ScreeningItem(
  id: 'fx_scr_4417_pelvic',
  outcome: ScreeningOutcome.refer,
  suppresses: const {
    ContraindicationTag.pelvicFloorLoad,
    ContraindicationTag.jumping,
    ContraindicationTag.highImpact,
  },
);

SafetyAssessment _assessment({
  required String id,
  List<ScreeningItem> screening = const [],
  String? parentAssessmentId,
}) => SafetyAssessment(
  assessmentId: id,
  clientUid: 'fx_client_4417',
  coachUid: 'fx_coach_2031',
  takenAt: DateTime.utc(2031, 2, 17, 9, 30),
  lifeStage: LifeStage.none,
  screening: screening,
  parentAssessmentId: parentAssessmentId,
);

void main() {
  group('a refer outcome suppresses tags', () {
    test('its suppresses[] become active tags', () {
      final assessment = _assessment(id: 'fx_a1', screening: [_refer()]);
      expect(ReferralRegistry.activeTags(assessment), {
        ContraindicationTag.pelvicFloorLoad,
        ContraindicationTag.jumping,
        ContraindicationTag.highImpact,
      });
    });

    test('negative control — pass and modify suppress nothing', () {
      // G14 §3.2's table: only REFER suppresses. A registry that returned every
      // item's tags would pass the test above and empty the library.
      final assessment = _assessment(
        id: 'fx_a2',
        screening: [
          ScreeningItem(
            id: 'fx_scr_knee',
            outcome: ScreeningOutcome.pass,
            suppresses: const {ContraindicationTag.deepKneeFlexion},
          ),
          ScreeningItem(
            id: 'fx_scr_wrist',
            outcome: ScreeningOutcome.modify,
            suppresses: const {ContraindicationTag.wristLoad},
          ),
          ScreeningItem(id: 'fx_scr_unset', outcome: ScreeningOutcome.unset),
        ],
      );
      expect(ReferralRegistry.activeTags(assessment), isEmpty);
    });

    test('an assessment with no screening suppresses nothing', () {
      expect(ReferralRegistry.activeTags(_assessment(id: 'fx_a3')), isEmpty);
    });

    test('refer is not an error state', () {
      // P1-RULE-20: no screen may render refer as a failure. The domain gives
      // it no error-shaped representation to render.
      final names = ScreeningOutcome.values.map((o) => o.name.toLowerCase());
      for (final name in names) {
        expect(name, isNot(contains('error')));
        expect(name, isNot(contains('fail')));
        expect(name, isNot(contains('invalid')));
      }
      // And reading an active referral is a value, not a thrown exception.
      final assessment = _assessment(id: 'fx_a4', screening: [_refer()]);
      expect(ReferralRegistry.activeReferrals(assessment), hasLength(1));
    });
  });

  group('it cannot be cleared by silence', () {
    test('a re-assessment that omits it carries it forward', () {
      final previous = _assessment(id: 'fx_a5', screening: [_refer()]);
      final carried = ReferralRegistry.carryForward(
        previous: previous,
        next: const [],
      );
      expect(
        carried.map((i) => i.id),
        contains('fx_scr_4417_pelvic'),
        reason: 'silence is not a clearing action',
      );
      expect(carried.single.outcome, ScreeningOutcome.refer);
    });

    test('carrying forward does not duplicate one that is restated', () {
      final previous = _assessment(id: 'fx_a6', screening: [_refer()]);
      final carried = ReferralRegistry.carryForward(
        previous: previous,
        next: [_refer()],
      );
      expect(carried, hasLength(1));
    });

    test('negative control — a cleared one is not resurrected', () {
      // Carry-forward that ignored the outcome would make CLEARED unreachable
      // and the referral genuinely permanent, which is not the rule either.
      final previous = _assessment(
        id: 'fx_a7',
        screening: [
          ScreeningItem(
            id: 'fx_scr_4417_pelvic',
            outcome: ScreeningOutcome.cleared,
            clearedReason: 'Physio discharged her on 17 February 2031.',
            clearedAt: DateTime.utc(2031, 2, 17),
            suppresses: const {ContraindicationTag.pelvicFloorLoad},
          ),
        ],
      );
      expect(
        ReferralRegistry.carryForward(previous: previous, next: const []),
        isEmpty,
      );
    });

    test('a newer assessment cannot silently drop it', () {
      final previous = _assessment(id: 'fx_a8', screening: [_refer()]);
      final next = _assessment(
        id: 'fx_a9',
        parentAssessmentId: 'fx_a8',
        screening: const [],
      );
      final merged = ReferralRegistry.mergeIntoSuccessor(
        previous: previous,
        successor: next,
      );
      expect(ReferralRegistry.activeTags(merged), isNotEmpty);
      expect(ReferralRegistry.activeTags(merged), {
        ContraindicationTag.pelvicFloorLoad,
        ContraindicationTag.jumping,
        ContraindicationTag.highImpact,
      });
    });

    test('there is no clock to expire against', () {
      // "Cannot expire or decay" is enforced by the signature: activeTags takes
      // an assessment and nothing else, so there is no date it could compare
      // to. The same referral read at any time reads the same.
      final previous = _assessment(id: 'fx_a10', screening: [_refer()]);
      expect(
        ReferralRegistry.activeTags(previous),
        ReferralRegistry.activeTags(previous),
      );
      expect(ReferralRegistry.activeTags(previous), hasLength(3));
    });
  });

  group('only an explicit clearing action with a reason clears it', () {
    test('clearing writes a NEW assessment and leaves the old one intact', () {
      final previous = _assessment(id: 'fx_a11', screening: [_refer()]);
      final cleared = ReferralRegistry.clearReferral(
        previous: previous,
        screeningId: 'fx_scr_4417_pelvic',
        reason: 'Pelvic health physio signed her off on 17 February 2031.',
        takenAt: DateTime.utc(2031, 4, 2, 11, 15),
      );

      expect(ReferralRegistry.activeTags(cleared), isEmpty);
      expect(cleared.parentAssessmentId, 'fx_a11');
      expect(cleared.assessmentId, isNot('fx_a11'));

      // The old document is untouched — clearing is never an edit.
      expect(ReferralRegistry.activeTags(previous), hasLength(3));
      expect(previous.screening.single.outcome, ScreeningOutcome.refer);
      expect(previous.screening.single.clearedReason, isNull);
    });

    test('the new assessment carries the reason, readable as history', () {
      final previous = _assessment(id: 'fx_a12', screening: [_refer()]);
      final cleared = ReferralRegistry.clearReferral(
        previous: previous,
        screeningId: 'fx_scr_4417_pelvic',
        reason: 'Pelvic health physio signed her off.',
        takenAt: DateTime.utc(2031, 4, 2),
      );
      final item = cleared.screening.single;
      expect(item.outcome, ScreeningOutcome.cleared);
      expect(item.clearedReason, 'Pelvic health physio signed her off.');
      expect(item.clearedAt, DateTime.utc(2031, 4, 2));
    });

    test('an empty or blank reason is refused', () {
      final previous = _assessment(id: 'fx_a13', screening: [_refer()]);
      expect(
        () => ReferralRegistry.clearReferral(
          previous: previous,
          screeningId: 'fx_scr_4417_pelvic',
          reason: '   ',
          takenAt: DateTime.utc(2031, 4, 2),
        ),
        throwsArgumentError,
      );
      expect(
        () => ReferralRegistry.clearReferral(
          previous: previous,
          screeningId: 'fx_scr_4417_pelvic',
          reason: '',
          takenAt: DateTime.utc(2031, 4, 2),
        ),
        throwsArgumentError,
      );
    });

    test('clearing something that is not referred is refused', () {
      final previous = _assessment(id: 'fx_a14', screening: [_refer()]);
      expect(
        () => ReferralRegistry.clearReferral(
          previous: previous,
          screeningId: 'fx_scr_does_not_exist',
          reason: 'A reason.',
          takenAt: DateTime.utc(2031, 4, 2),
        ),
        throwsArgumentError,
      );
    });

    test('the type itself refuses a cleared item with no reason', () {
      expect(
        () => ScreeningItem(
          id: 'fx_scr_4417_pelvic',
          outcome: ScreeningOutcome.cleared,
        ),
        throwsArgumentError,
      );
      expect(
        () => ScreeningItem(
          id: 'fx_scr_4417_pelvic',
          outcome: ScreeningOutcome.cleared,
          clearedReason: '  ',
        ),
        throwsArgumentError,
      );
    });

    test('a reason on a non-cleared outcome is refused', () {
      // Otherwise a refer could be stamped with a reason and read as cleared by
      // the next component along.
      expect(
        () => ScreeningItem(
          id: 'fx_scr_4417_pelvic',
          outcome: ScreeningOutcome.refer,
          clearedReason: 'looks fine',
        ),
        throwsArgumentError,
      );
    });
  });
}
