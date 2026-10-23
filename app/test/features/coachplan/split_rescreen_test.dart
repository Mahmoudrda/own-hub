// P0-ASMT-02 and P0-ASMT-03 at the boundary a template crosses — the cases
// `split_test.dart` does not reach.
//
// P0-SPLIT-04 proves that a move on her avoid list is absent from a month
// applied from a split. Three neighbouring things have to be true as well, and
// each one fails silently if it is not:
//
//  * **An untagged move is unknown content.** Nobody has said what it loads.
//    While any restriction is in force it must not cross, for the reason a
//    dish with no allergen list is blocked.
//  * **Unresolved is not empty.** When her constraints cannot be read at all,
//    only the quiet, low-impact, floor-based subset crosses — the same
//    fail-closed subset W04's picker falls back to.
//  * **An approved alternative is a move.** It is one tap away mid-session, so
//    it is screened on its own account and named when it is removed.
//
// Written after a mutation run: deleting the `ExerciseCandidateFilter` call
// from the applicator altogether broke nothing, because every existing case
// was also covered by the template rule that runs after it. These are the
// cases where only the filter can be the thing that saves her.

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/safety/client_constraints.dart';
import 'package:own_hub/domain/safety/contraindication_tag.dart';
import 'package:own_hub/domain/safety/exercise_candidate_filter.dart';
import 'package:own_hub/domain/safety/life_stage_safety_policy.dart';
import 'package:own_hub/domain/safety/referral_registry.dart';
import 'package:own_hub/domain/safety/safety_assessment.dart';
import 'package:own_hub/features/coachplan/domain/prescription.dart';
import 'package:own_hub/features/coachplan/domain/split/split.dart';
import 'package:own_hub/features/coachplan/domain/split/split_applicator.dart';
import 'package:own_hub/features/coachplan/domain/split/split_assignment_guard.dart';

final DateTime _today = DateTime(2026, 9, 19);

const _moves = <String, ScreenableExercise>{
  // Quiet, floor-based, restricts nothing. The only move that survives a cold
  // start, and it is what `_safeWhileConstraintsAreUnknown` describes.
  'glute_bridge': ScreenableExercise(
    exerciseId: 'glute_bridge',
    tags: <ContraindicationTag>{ContraindicationTag.none},
    quiet: true,
    floorOnly: true,
  ),
  // Restricts nothing either, but it is neither quiet nor floor-based.
  'standing_march': ScreenableExercise(
    exerciseId: 'standing_march',
    tags: <ContraindicationTag>{ContraindicationTag.none},
    quiet: false,
    floorOnly: false,
  ),
  // **Nobody has authored its tags.** Not "carries none".
  'unlabelled_move': ScreenableExercise(
    exerciseId: 'unlabelled_move',
    tags: null,
    quiet: true,
    floorOnly: true,
  ),
  'goblet_squat': ScreenableExercise(
    exerciseId: 'goblet_squat',
    tags: <ContraindicationTag>{ContraindicationTag.deepKneeFlexion},
    quiet: true,
    floorOnly: false,
  ),
};

ScreenableExercise? _catalogue(String id) => _moves[id];

PrescribedMove _move(String id, int order) => PrescribedMove(
  exerciseId: id,
  order: order,
  sets: 3,
  reps: 12,
  load: const PrescribedLoad.bodyweight(),
);

Split _split({
  List<String> moves = const <String>['glute_bridge', 'unlabelled_move'],
  List<ApprovedAlternative> alternatives = const <ApprovedAlternative>[],
}) => Split(
  splitId: 's_1',
  name: 'Three days',
  cycleLength: 3,
  ownerKind: SplitOwnerKind.coach,
  carryApproved: true,
  daySlots: <SplitDaySlot>[
    SplitDaySlot(
      dayIndex: 1,
      kind: DaySlotKind.session,
      title: 'Day one',
      minutes: 20,
      moves: <PrescribedMove>[
        for (var i = 0; i < moves.length; i++) _move(moves[i], i + 1),
      ],
      approvedAlternatives: alternatives,
    ),
    SplitDaySlot.rest(dayIndex: 2),
    SplitDaySlot.rest(dayIndex: 3),
  ],
);

ClientConstraints _resolved({Set<ContraindicationTag> avoid = const {}}) =>
    ClientConstraintResolver.resolve(
      assessment: SafetyAssessment(
        assessmentId: 'c1_u1__2026-09-01',
        clientUid: 'u1',
        coachUid: 'c1',
        takenAt: DateTime(2026, 9, 1),
        lifeStage: LifeStage.over1y,
        avoid: avoid,
      ),
      allergies: const <String>{},
      dietary: const <String>{},
    );

SplitApplication _apply(
  Split split,
  ClientConstraints constraints, {
  int days = 1,
}) => const SplitApplicator().materialise(
  split: split,
  clientUid: 'u1',
  dates: <DateTime>[
    for (var i = 0; i < days; i++) _today.add(Duration(days: i)),
  ],
  actor: const PlanningActor.coach('c1'),
  hasActiveRelationship: true,
  constraints: constraints,
  catalogue: _catalogue,
);

List<String> _movesOnFirstDay(SplitApplication applied) => applied
    .days['2026-09-19']!
    .workout!
    .moves
    .map((m) => m.exerciseId)
    .toList();

void main() {
  group('an untagged move is unknown content, not unrestricted content', () {
    test('it does not cross while a restriction is in force', () {
      final applied = _apply(
        _split(),
        _resolved(
          avoid: <ContraindicationTag>{ContraindicationTag.deepKneeFlexion},
        ),
      );

      expect(_movesOnFirstDay(applied), <String>['glute_bridge']);
      expect(
        applied.suppressedExerciseIds,
        contains('unlabelled_move'),
        reason:
            'a missing tag reads as unknown, therefore unsafe — the move '
            'half of the rule a dish with no allergen list is blocked by',
      );
    });

    test('a referral alone is enough to put the restriction in force', () {
      final constraints = ClientConstraintResolver.resolve(
        assessment: SafetyAssessment(
          assessmentId: 'c1_u1__2026-09-01',
          clientUid: 'u1',
          coachUid: 'c1',
          takenAt: DateTime(2026, 9, 1),
          lifeStage: LifeStage.over1y,
          screening: <ScreeningItem>[
            ScreeningItem(
              id: 'pelvic_floor',
              outcome: ScreeningOutcome.refer,
              suppresses: const <ContraindicationTag>{
                ContraindicationTag.pelvicFloorLoad,
              },
            ),
          ],
        ),
        allergies: const <String>{},
        dietary: const <String>{},
      );

      expect(
        _movesOnFirstDay(_apply(_split(), constraints)),
        <String>['glute_bridge'],
        reason:
            'a refer suppresses moves; it is not a failure state, and it '
            'is not nothing either',
      );
    });

    test('a move the catalogue has never heard of is named, not lost', () {
      final applied = _apply(
        _split(moves: const <String>['glute_bridge', 'withdrawn_move']),
        _resolved(),
      );
      expect(_movesOnFirstDay(applied), <String>['glute_bridge']);
      expect(applied.suppressedExerciseIds, contains('withdrawn_move'));
    });
  });

  group('P0-ASMT-03 at this boundary — unresolved is not empty', () {
    test('only the quiet, floor-based, unrestricted subset crosses', () {
      final applied = _apply(
        _split(
          moves: const <String>[
            'glute_bridge',
            'standing_march',
            'unlabelled_move',
            'goblet_squat',
          ],
        ),
        ClientConstraintResolver.unresolved(),
      );

      expect(
        _movesOnFirstDay(applied),
        <String>['glute_bridge'],
        reason:
            'her constraints could not be read, so every restricting tag '
            'is treated as though it might be the one she cannot do',
      );
      expect(
        applied.suppressedExerciseIds,
        containsAll(<String>[
          'standing_march',
          'unlabelled_move',
          'goblet_squat',
        ]),
      );
    });

    test('a cold start never produces an unrestricted month', () {
      final applied = _apply(
        _split(moves: const <String>['standing_march']),
        ClientConstraintResolver.unresolved(),
      );
      expect(_movesOnFirstDay(applied), isEmpty);
      expect(
        applied.days['2026-09-19']!.isRest,
        isFalse,
        reason:
            'an emptied session is still a session she can see and a coach '
            'can fill — it is not silently turned into a rest day',
      );
    });

    test('her own declared life stage narrows it further still', () {
      final applied = _apply(
        _split(moves: const <String>['glute_bridge']),
        ClientConstraintResolver.unresolved(
          selfDeclared: SelfDeclaredLifeStage(
            stage: LifeStage.pregnant,
            declaredAt: DateTime(2026, 8, 1),
          ),
        ),
      );
      expect(
        _movesOnFirstDay(applied),
        <String>['glute_bridge'],
        reason:
            'the bridge carries no restricting tag, so the floor derived '
            'from her pregnancy does not reach it',
      );
    });
  });

  group('an approved alternative is screened on its own account', () {
    test('a contraindicated substitute is removed, and named', () {
      final applied = _apply(
        _split(
          moves: const <String>['glute_bridge'],
          alternatives: const <ApprovedAlternative>[
            ApprovedAlternative(
              exerciseId: 'goblet_squat',
              forExerciseId: 'glute_bridge',
            ),
          ],
        ),
        _resolved(
          avoid: <ContraindicationTag>{ContraindicationTag.deepKneeFlexion},
        ),
      );

      expect(_movesOnFirstDay(applied), <String>['glute_bridge']);
      expect(
        applied.days['2026-09-19']!.workout!.approvedAlternatives,
        isEmpty,
        reason:
            'an easier option she can tap mid-session is prescribed '
            'content like any other',
      );
      expect(applied.suppressedExerciseIds, contains('goblet_squat'));
    });

    test('an untagged substitute is removed too', () {
      final applied = _apply(
        _split(
          moves: const <String>['glute_bridge'],
          alternatives: const <ApprovedAlternative>[
            ApprovedAlternative(
              exerciseId: 'unlabelled_move',
              forExerciseId: 'glute_bridge',
            ),
          ],
        ),
        _resolved(
          avoid: <ContraindicationTag>{ContraindicationTag.deepKneeFlexion},
        ),
      );
      expect(
        applied.days['2026-09-19']!.workout!.approvedAlternatives,
        isEmpty,
      );
      expect(applied.suppressedExerciseIds, contains('unlabelled_move'));
    });

    test('a substitute that survives both screens is carried', () {
      final applied = _apply(
        _split(
          moves: const <String>['goblet_squat', 'glute_bridge'],
          alternatives: const <ApprovedAlternative>[
            ApprovedAlternative(
              exerciseId: 'glute_bridge',
              forExerciseId: 'goblet_squat',
            ),
          ],
        ),
        _resolved(),
      );

      expect(_movesOnFirstDay(applied), <String>[
        'goblet_squat',
        'glute_bridge',
      ]);
      expect(
        applied.days['2026-09-19']!.workout!.approvedAlternatives.single,
        const ApprovedAlternative(
          exerciseId: 'glute_bridge',
          forExerciseId: 'goblet_squat',
        ),
        reason:
            'she was asked and named nothing, so the template crosses whole',
      );
      expect(applied.suppressedExerciseIds, isEmpty);
    });
  });
}
