// P0-ASMT-02, P0-ASMT-03 and the move half of P1-RULE-20.
//
// G14 §5.1: the filter runs BEFORE the candidate list is built, the way
// `AllergyGuard.screen()` runs before ranking. A matching move is ABSENT — not
// greyed out, not shown with a warning. `screen` returns the list the picker is
// built from, so there is nothing for a widget to render in a disabled state:
// the removed moves are not in the returned value at all.
//
// Fixture ids and figures are deliberately unlike the seeded library's
// (`goblet_squat`, `hip_thrust`, …) so a test cannot pass by accidentally
// reading real content.

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/safety/client_constraints.dart';
import 'package:own_hub/domain/safety/contraindication_tag.dart';
import 'package:own_hub/domain/safety/exercise_candidate_filter.dart';
import 'package:own_hub/domain/safety/life_stage_safety_policy.dart';
import 'package:own_hub/domain/safety/referral_registry.dart';
import 'package:own_hub/domain/safety/safety_assessment.dart';

ScreenableExercise _ex(
  String id,
  Set<ContraindicationTag>? tags, {
  bool quiet = true,
  bool floorOnly = false,
}) => ScreenableExercise(
  exerciseId: id,
  tags: tags,
  quiet: quiet,
  floorOnly: floorOnly,
);

/// A fixture library. Nothing here is a real seeded move.
final _library = <ScreenableExercise>[
  _ex('fx_4417_box_jump', const {
    ContraindicationTag.highImpact,
    ContraindicationTag.jumping,
  }, quiet: false),
  _ex('fx_4417_deep_lunge', const {ContraindicationTag.deepKneeFlexion}),
  _ex('fx_4417_bridge_hold', const {
    ContraindicationTag.supineLoad,
  }, floorOnly: true),
  _ex('fx_4417_side_lying_clam', const {
    ContraindicationTag.none,
  }, floorOnly: true),
  _ex('fx_4417_seated_press', const {ContraindicationTag.overheadLoad}),
  _ex('fx_4417_untagged_row', null, floorOnly: true),
  _ex('fx_4417_floor_breathing', const {
    ContraindicationTag.none,
  }, floorOnly: true),
  _ex(
    'fx_4417_loud_shuttle',
    const {ContraindicationTag.none},
    quiet: false,
    floorOnly: true,
  ),
];

List<String> _ids(List<ScreenableExercise> moves) => [
  for (final m in moves) m.exerciseId,
];

SafetyAssessment _assessment({
  Set<ContraindicationTag> avoid = const {},
  LifeStage lifeStage = LifeStage.none,
  List<ScreeningItem> screening = const [],
}) => SafetyAssessment(
  assessmentId: 'fx_a4417',
  clientUid: 'fx_client_4417',
  coachUid: 'fx_coach_2031',
  takenAt: DateTime.utc(2031, 2, 17, 9, 30),
  lifeStage: lifeStage,
  avoid: avoid,
  screening: screening,
);

void main() {
  group('P0-ASMT-02 — the avoid list suppresses moves before selection', () {
    // "Assessment records avoid=[high_impact,deep_knee_flexion]"
    final constraints = ClientConstraintResolver.resolve(
      assessment: _assessment(
        avoid: const {
          ContraindicationTag.highImpact,
          ContraindicationTag.deepKneeFlexion,
        },
      ),
    );
    final filter = ExerciseCandidateFilter(constraints);

    test('matching exercises are ABSENT from the candidate list', () {
      final candidates = filter.screen(_library);
      expect(_ids(candidates), isNot(contains('fx_4417_box_jump')));
      expect(_ids(candidates), isNot(contains('fx_4417_deep_lunge')));
    });

    test('searching explicitly for a jumping move still finds nothing', () {
      // The picker's search runs over the screened list, so there is no query
      // that reaches a removed move.
      final candidates = filter.screen(_library);
      final jumping = candidates.where(
        (m) => (m.tags ?? const {}).contains(ContraindicationTag.jumping),
      );
      expect(jumping, isEmpty);
    });

    test('nothing is returned greyed out or flagged — it is removed', () {
      // The returned list is the picker. A removed move has no representation
      // in it at all, so no widget can render one disabled or with a warning.
      final candidates = filter.screen(_library);
      expect(candidates.length, lessThan(_library.length));
      for (final move in candidates) {
        expect(
          move.blocks(constraints.blockedTags),
          isFalse,
          reason: '${move.exerciseId} survived screening but conflicts',
        );
      }
    });

    test('negative control — unaffected moves are still offered', () {
      // A filter that returned an empty list would pass every assertion above.
      final candidates = filter.screen(_library);
      expect(_ids(candidates), contains('fx_4417_side_lying_clam'));
      expect(_ids(candidates), contains('fx_4417_seated_press'));
      expect(_ids(candidates), contains('fx_4417_bridge_hold'));
      expect(candidates, isNotEmpty);
    });

    test('the none token does not suppress the moves that carry it', () {
      // An unrestricted move is tagged 'none' in the seeded content. Treating
      // that as a tag to intersect would empty the library.
      final candidates = filter.screen(_library);
      expect(_ids(candidates), contains('fx_4417_floor_breathing'));
    });

    test('an untagged move is removed while any restriction is in force', () {
      // Mirrors AllergyGuard case 2: unknown allergen data on a dish is unsafe
      // for a woman who has an allergy. Unknown tags on a move are unsafe for a
      // woman who has an avoid list.
      final candidates = filter.screen(_library);
      expect(_ids(candidates), isNot(contains('fx_4417_untagged_row')));
    });

    test('an untagged move IS offered when she was asked and named none', () {
      // The deliberate asymmetry, again mirroring AllergyGuard: with a known,
      // empty avoid list there is nothing to fail closed about, and removing
      // every untagged move would empty the picker for most women.
      final none = ExerciseCandidateFilter(
        ClientConstraintResolver.resolve(assessment: _assessment()),
      );
      expect(_ids(none.screen(_library)), contains('fx_4417_untagged_row'));
      expect(none.screen(_library), hasLength(_library.length));
    });
  });

  group('P0-ASMT-03 — constraints cannot be resolved', () {
    final unresolved = ClientConstraintResolver.resolve(assessment: null);
    final filter = ExerciseCandidateFilter(unresolved);

    test('only the quiet, low-impact, floor-based subset is returned', () {
      final candidates = filter.screen(_library);
      expect(_ids(candidates), [
        'fx_4417_side_lying_clam',
        'fx_4417_floor_breathing',
      ]);
    });

    test('no unrestricted list is ever shown', () {
      final candidates = filter.screen(_library);
      expect(candidates.length, lessThan(_library.length));
      for (final move in candidates) {
        expect(move.quiet, isTrue);
        expect(move.floorOnly, isTrue);
        expect(move.tagsKnown, isTrue);
      }
    });

    test('an unknown constraint is treated as present, not absent', () {
      // Every restricting tag is treated as if it might be the one she cannot
      // do, so a move carrying any of them is out — including supine_load,
      // which is quiet and floor-based and would otherwise look harmless.
      final candidates = filter.screen(_library);
      expect(_ids(candidates), isNot(contains('fx_4417_bridge_hold')));
    });

    test('an untagged move is out — unknown content is not safe content', () {
      final candidates = filter.screen(_library);
      expect(_ids(candidates), isNot(contains('fx_4417_untagged_row')));
    });

    test('a loud move is out even with no contraindication tag', () {
      final candidates = filter.screen(_library);
      expect(_ids(candidates), isNot(contains('fx_4417_loud_shuttle')));
    });

    test('the caller can tell this is the cold-start list', () {
      // W04 shows one line: "her constraints haven't loaded — showing the
      // safest moves". The screen needs to know, so the flag is on the value.
      expect(unresolved.isResolved, isFalse);
    });

    test('her own declaration narrows the cold-start list further', () {
      // She declared pregnancy in her profile; the assessment is unreadable.
      final declared = ClientConstraintResolver.resolve(
        assessment: null,
        selfDeclared: SelfDeclaredLifeStage(
          stage: LifeStage.pregnant,
          declaredAt: DateTime.utc(2031, 2, 17),
        ),
      );
      final candidates = ExerciseCandidateFilter(declared).screen(_library);
      for (final move in candidates) {
        expect(
          move.blocks(LifeStageSafetyPolicy.derivedAvoid(LifeStage.pregnant)),
          isFalse,
        );
      }
      expect(candidates.length, lessThanOrEqualTo(2));
    });
  });

  group('P1-RULE-20 — a refer outcome removes moves, and blocks nothing', () {
    final constraints = ClientConstraintResolver.resolve(
      assessment: _assessment(
        screening: [
          ScreeningItem(
            id: 'fx_scr_4417_pelvic',
            outcome: ScreeningOutcome.refer,
            suppresses: const {
              ContraindicationTag.pelvicFloorLoad,
              ContraindicationTag.jumping,
              ContraindicationTag.highImpact,
            },
          ),
        ],
      ),
    );

    test('the referred tags are absent from the picker', () {
      final candidates = ExerciseCandidateFilter(constraints).screen(_library);
      expect(_ids(candidates), isNot(contains('fx_4417_box_jump')));
    });

    test('publishing is NOT blocked by a referral', () {
      // HANDOFF 14: refer is not a failure state. The publish gate does not
      // take a referral at all — the only thing that can block is withheld
      // clearance during p0_6w.
      expect(
        ReferralRegistry.activeTags(
          _assessment(
            screening: [
              ScreeningItem(
                id: 'fx_scr_4417_pelvic',
                outcome: ScreeningOutcome.refer,
                suppresses: const {ContraindicationTag.pelvicFloorLoad},
              ),
            ],
          ),
        ),
        isNotEmpty,
      );
      final decision = LifeStageSafetyPolicy.publishGate(
        stage: LifeStage.none,
        clearance: null,
      );
      expect(decision.allowed, isTrue);
      expect(decision.reason, isNull);
    });

    test('the referral stays readable so K22 can render it prominently', () {
      expect(constraints.referrals, hasLength(1));
      expect(constraints.referrals.single.outcome, ScreeningOutcome.refer);
    });

    test('negative control — the rest of the library survives', () {
      final candidates = ExerciseCandidateFilter(constraints).screen(_library);
      expect(_ids(candidates), contains('fx_4417_deep_lunge'));
      expect(_ids(candidates), contains('fx_4417_seated_press'));
    });
  });

  group('a recorded life stage restricts on its own — PHASE3-PLAN §1.4', () {
    test(
      'pregnancy removes the jumping and supine moves with no avoid list',
      () {
        // The hole being closed: before this, a recorded pregnancy restricted
        // nothing unless a coach happened to tick the chips.
        final constraints = ClientConstraintResolver.resolve(
          assessment: _assessment(lifeStage: LifeStage.pregnant),
        );
        final candidates = ExerciseCandidateFilter(constraints)
            .screen(_library);
        expect(_ids(candidates), isNot(contains('fx_4417_box_jump')));
        expect(_ids(candidates), isNot(contains('fx_4417_bridge_hold')));
        expect(
          _ids(candidates),
          contains('fx_4417_deep_lunge'),
          reason: 'deep_knee_flexion is not derived, so it must survive',
        );
      },
    );

    test('her self-declared stage restricts even with a bare assessment', () {
      final constraints = ClientConstraintResolver.resolve(
        assessment: _assessment(),
        selfDeclared: SelfDeclaredLifeStage(
          stage: LifeStage.postpartum0to6w,
          declaredAt: DateTime.utc(2031, 2, 17),
        ),
      );
      final candidates = ExerciseCandidateFilter(constraints).screen(_library);
      expect(_ids(candidates), isNot(contains('fx_4417_box_jump')));
      expect(_ids(candidates), isNot(contains('fx_4417_bridge_hold')));
    });

    test('negative control — lifeStage none removes nothing by itself', () {
      final constraints = ClientConstraintResolver.resolve(
        assessment: _assessment(lifeStage: LifeStage.none),
      );
      expect(
        ExerciseCandidateFilter(constraints).screen(_library),
        hasLength(_library.length),
      );
    });
  });

  group('the guard has the same shape as AllergyGuard', () {
    test('screen takes the candidates and returns the survivors', () {
      final constraints = ClientConstraintResolver.resolve(
        assessment: _assessment(avoid: const {ContraindicationTag.wristLoad}),
      );
      final filter = ExerciseCandidateFilter(constraints);
      expect(filter.screen(const <ScreenableExercise>[]), isEmpty);
      expect(filter.constraints, same(constraints));
    });

    test('screening is stable — the same input gives the same list', () {
      final constraints = ClientConstraintResolver.resolve(
        assessment: _assessment(avoid: const {ContraindicationTag.supineLoad}),
      );
      final filter = ExerciseCandidateFilter(constraints);
      expect(_ids(filter.screen(_library)), _ids(filter.screen(_library)));
    });

    test('order is preserved — screening is not a ranking', () {
      final constraints = ClientConstraintResolver.resolve(
        assessment: _assessment(),
      );
      expect(
        _ids(ExerciseCandidateFilter(constraints).screen(_library)),
        _ids(_library),
      );
    });
  });
}
