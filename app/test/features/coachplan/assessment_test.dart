// P0-ASMT-01 … 05 and P1-RULE-21 — the only source of her constraints.
//
// Three properties are being protected here and they are easy to confuse:
//
//  * **One document.** K21 and K23 never write independently, because a
//    half-saved assessment is a half-stated constraint.
//  * **Append-only.** A recorded answer is corrected by recording a new one.
//    The single permitted update is `recorded → superseded`.
//  * **A referral cannot be cleared by silence.** Omitting it carries it
//    forward; ending it takes an explicit action with a reason, on a new
//    document.

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/safety/client_constraints.dart';
import 'package:own_hub/domain/safety/contraindication_tag.dart';
import 'package:own_hub/domain/safety/life_stage_safety_policy.dart';
import 'package:own_hub/domain/safety/referral_registry.dart';
import 'package:own_hub/domain/safety/safety_assessment.dart';
import 'package:own_hub/features/coachplan/domain/assessment/assessment_form.dart';
import 'package:own_hub/features/coachplan/domain/assessment/assessment_record.dart';
import 'package:own_hub/features/coachplan/domain/assessment/assessment_repository.dart';
import 'package:own_hub/features/coachplan/domain/assessment/reassessment_service.dart';
import 'package:own_hub/features/coachplan/domain/prescription_only_validator.dart';

final DateTime _september = DateTime(2026, 9, 2, 10, 30);
final DateTime _october = DateTime(2026, 10, 1, 9, 0);

ScreeningItem _item(
  String id,
  ScreeningOutcome outcome, {
  Set<ContraindicationTag> suppresses = const <ContraindicationTag>{},
}) => ScreeningItem(id: id, outcome: outcome, suppresses: suppresses);

/// "This test did not say." Distinct from `null`, which is a stated answer:
/// **nobody has recorded a clearance**, and the form must refuse to continue on
/// it (G14 §3.1). A `clearance ?? <granted>` default here would swallow the
/// null and make `_form(clearance: null)` unreachable — the fixture would be
/// asserting the opposite of what it reads.
const Object _notPassed = Object();

final Clearance _granted = Clearance(
  granted: true,
  recordedAt: DateTime(2026, 9, 2),
);

AssessmentForm _form({
  LifeStage? lifeStage = LifeStage.postpartum6wTo1y,
  Object? clearance = _notPassed,
  List<ScreeningItem>? screening,
  Set<ContraindicationTag> avoid = const <ContraindicationTag>{},
  String? painNotes,
  String? parentAssessmentId,
}) => AssessmentForm(
  clientUid: 'u1',
  coachUid: 'c1',
  lifeStage: lifeStage,
  clearance: identical(clearance, _notPassed)
      ? _granted
      : clearance as Clearance?,
  avoid: avoid,
  painNotes: painNotes,
  parentAssessmentId: parentAssessmentId,
  screening:
      screening ??
      <ScreeningItem>[
        _item('pelvic_floor', ScreeningOutcome.pass),
        _item('knee', ScreeningOutcome.modify),
      ],
);

void main() {
  group('P0-ASMT-01 — two steps, one document', () {
    test('nothing is written until step two is saved', () async {
      final repo = InMemoryAssessmentRepository();

      // Step one answered: she may continue, and the repository is untouched.
      final stepOne = _form(screening: const <ScreeningItem>[]);
      expect(stepOne.canContinue, isTrue);
      expect(repo.writes, 0);
      expect(repo.contents, isEmpty);

      // The app is killed here. There is nothing to clean up.
      expect(repo.contents, isEmpty);

      await repo.record(_form().build(takenAt: _september));
      expect(repo.writes, 1);
      expect(repo.contents, hasLength(1));
    });

    test('step one incomplete cannot continue', () {
      expect(_form(lifeStage: null).canContinue, isFalse);
      expect(_form(clearance: null).canContinue, isFalse);
    });

    test('an unanswered screening item is named, and blocks the save', () {
      final form = _form(
        screening: <ScreeningItem>[
          _item('pelvic_floor', ScreeningOutcome.pass),
          _item('knee', ScreeningOutcome.unset),
        ],
      );

      expect(form.canSave, isFalse);
      expect(form.unansweredItems.single.id, 'knee');
      expect(
        () => form.build(takenAt: _september),
        throwsA(
          isA<AssessmentFormInvalid>().having(
            (e) => e.problem,
            'problem',
            AssessmentFormProblem.screeningIncomplete,
          ),
        ),
      );
    });

    test(
      'the id is deterministic, so a replayed save is one document',
      () async {
        final repo = InMemoryAssessmentRepository();
        final record = _form().build(takenAt: _september);

        await repo.record(record);
        await repo.record(record);

        expect(repo.contents, hasLength(1));
        expect(record.assessmentId, 'c1_u1__${_september.toIso8601String()}');
      },
    );
  });

  group('P0-ASMT-02 — the avoid list is chips, and it suppresses', () {
    test('tags resolve into constraints the move filter reads', () {
      final record = _form(
        avoid: <ContraindicationTag>{
          ContraindicationTag.highImpact,
          ContraindicationTag.deepKneeFlexion,
        },
      ).build(takenAt: _september);

      final constraints = ClientConstraintResolver.resolve(
        assessment: record.assessment,
        allergies: const <String>{},
        dietary: const <String>{},
      );

      expect(constraints.isResolved, isTrue);
      expect(
        constraints.blockedTags,
        containsAll(<ContraindicationTag>{
          ContraindicationTag.highImpact,
          ContraindicationTag.deepKneeFlexion,
        }),
      );
    });

    test('a stored tag outside the vocabulary fails closed, loudly', () {
      expect(
        () => SafetyAssessment.fromWire(
          assessmentId: 'c1_u1__x',
          clientUid: 'u1',
          takenAt: _september,
          lifeStage: 'over_1y',
          avoid: const <String>['deep_knee_flexion', 'knee'],
        ),
        throwsA(isA<UnknownContraindicationTag>()),
      );
    });

    test('free prose is carried and never becomes a constraint', () {
      final record = _form(
        painNotes: 'Right knee, sore on stairs since March. No jumping.',
      ).build(takenAt: _september);

      expect(record.assessment.painNotes, isNotNull);
      expect(
        record.assessment.avoid,
        isEmpty,
        reason: 'the word "jumping" in prose changes no tag',
      );

      final constraints = ClientConstraintResolver.resolve(
        assessment: record.assessment,
        allergies: const <String>{},
        dietary: const <String>{},
      );
      expect(constraints.blockedTags, isEmpty);
    });
  });

  group('P0-ASMT-03 — constraints that cannot be resolved', () {
    test('unresolved is not empty, and the picker fails closed', () {
      final unknown = ClientConstraintResolver.resolve(assessment: null);
      expect(unknown.isResolved, isFalse);
      expect(unknown.avoid, isNull, reason: 'null means "could not be read"');
    });
  });

  group('P0-ASMT-04 — a referral survives re-assessment', () {
    test('omitting it does not clear it', () async {
      final repo = InMemoryAssessmentRepository();
      final parent = _form(
        screening: <ScreeningItem>[
          _item(
            'pelvic_floor',
            ScreeningOutcome.refer,
            suppresses: <ContraindicationTag>{
              ContraindicationTag.pelvicFloorLoad,
              ContraindicationTag.jumping,
            },
          ),
        ],
      ).build(takenAt: _september);
      await repo.record(parent);

      // Four weeks later she re-assesses and simply does not mention it.
      final suggestion = await ReassessmentService(repo).save(
        form: _form(
          screening: <ScreeningItem>[_item('knee', ScreeningOutcome.pass)],
          parentAssessmentId: parent.assessmentId,
        ),
        parent: parent,
        takenAt: _october,
        month: '2026-10',
      );

      final child = repo.contents.values.firstWhere(
        (r) => r.takenAt == _october,
      );
      expect(
        ReferralRegistry.activeTags(child.assessment),
        contains(ContraindicationTag.pelvicFloorLoad),
        reason: 'it cannot be cleared by silence',
      );
      expect(suggestion.activeReferralCount, 1);
      expect(suggestion.publishes, isFalse);
    });

    test(
      'clearing needs an explicit reason, and writes a new document',
      () async {
        final repo = InMemoryAssessmentRepository();
        final parent = _form(
          screening: <ScreeningItem>[
            _item(
              'pelvic_floor',
              ScreeningOutcome.refer,
              suppresses: <ContraindicationTag>{
                ContraindicationTag.pelvicFloorLoad,
              },
            ),
          ],
        ).build(takenAt: _september);
        await repo.record(parent);

        final service = ReassessmentService(repo);

        expect(
          () => service.clearReferral(
            previous: parent,
            screeningId: 'pelvic_floor',
            reason: '   ',
            takenAt: _october,
          ),
          throwsA(isA<ArgumentError>()),
          reason: 'neither a stray tap nor an empty field ends a suppression',
        );

        final cleared = await service.clearReferral(
          previous: parent,
          screeningId: 'pelvic_floor',
          reason: 'Physiotherapist discharged her on 28 September.',
          takenAt: _october,
        );

        expect(repo.contents, hasLength(2), reason: 'a new document');
        expect(
          repo.contents[parent.assessmentId]!.status,
          AssessmentStatus.superseded,
        );
        expect(
          repo
              .contents[parent.assessmentId]!
              .assessment
              .screening
              .single
              .outcome,
          ScreeningOutcome.refer,
          reason: 'the old document is untouched, not rewritten',
        );
        expect(ReferralRegistry.activeTags(cleared.assessment), isEmpty);
        expect(
          cleared.assessment.screening.single.clearedReason,
          contains('Physiotherapist'),
        );
      },
    );

    test('a referral has no clock to expire against', () {
      final parent = _form(
        screening: <ScreeningItem>[
          _item(
            'pelvic_floor',
            ScreeningOutcome.refer,
            suppresses: <ContraindicationTag>{ContraindicationTag.jumping},
          ),
        ],
      ).build(takenAt: DateTime(2020, 1, 1));

      // Six years later, to the extent that anything here could notice.
      expect(
        ReferralRegistry.activeTags(parent.assessment),
        contains(ContraindicationTag.jumping),
      );
    });
  });

  group('P0-ASMT-05 — an assessment is a record', () {
    test('rewriting a recorded answer is refused', () async {
      final repo = InMemoryAssessmentRepository();
      final record = _form(
        avoid: <ContraindicationTag>{ContraindicationTag.highImpact},
      ).build(takenAt: _september);
      await repo.record(record);

      final edited = AssessmentRecord(
        assessment: SafetyAssessment(
          assessmentId: record.assessmentId,
          clientUid: 'u1',
          coachUid: 'c1',
          takenAt: _september,
          lifeStage: LifeStage.postpartum6wTo1y,
          clearance: record.assessment.clearance,
          avoid: const <ContraindicationTag>{},
          screening: record.assessment.screening,
        ),
      );

      expect(() => repo.record(edited), throwsA(isA<AssessmentIsAppendOnly>()));
    });

    test('deletion is denied outright', () {
      final repo = InMemoryAssessmentRepository();
      expect(
        () => repo.delete('c1_u1__whatever'),
        throwsA(isA<AssessmentIsAppendOnly>()),
      );
    });

    test('the only permitted update is the supersede flip', () async {
      final repo = InMemoryAssessmentRepository();
      final parent = _form().build(takenAt: _september);
      await repo.record(parent);

      await ReassessmentService(repo).save(
        form: _form(parentAssessmentId: parent.assessmentId),
        parent: parent,
        takenAt: _october,
        month: '2026-10',
      );

      expect(
        repo.contents[parent.assessmentId]!.status,
        AssessmentStatus.superseded,
      );
      expect(
        repo.contents[parent.assessmentId]!.assessment.avoid,
        parent.assessment.avoid,
        reason: 'nothing else about a recorded answer changed',
      );
    });

    test('child and parent move together, or not at all', () async {
      final repo = InMemoryAssessmentRepository();
      final parent = _form().build(takenAt: _september);
      await repo.record(parent);

      // A child that does not name its parent must not supersede it.
      final orphan = _form().build(takenAt: _october);
      expect(
        () => repo.recordSuperseding(
          child: orphan,
          parentId: parent.assessmentId,
        ),
        throwsA(isA<AssessmentIsAppendOnly>()),
      );
      expect(
        repo.contents[parent.assessmentId]!.status,
        AssessmentStatus.recorded,
        reason: 'the parent was not flipped by a failed transaction',
      );
    });
  });

  group('no weight, anywhere', () {
    test('a baseline naming a body weight is refused', () {
      for (final key in kForbiddenBodyMeasureKeys) {
        expect(
          () => AssessmentRecord(
            assessment: _form().build(takenAt: _september).assessment,
            baseline: <String, BaselineMeasure>{
              key: const BaselineMeasure(value: 60, unit: 'kg'),
            },
          ),
          throwsA(isA<BodyMeasureInBaseline>()),
          reason: key,
        );
      }
    });

    test('a plank hold and a waist are fine', () {
      final record = AssessmentRecord(
        assessment: _form().build(takenAt: _september).assessment,
        baseline: const <String, BaselineMeasure>{
          'plank_hold': BaselineMeasure(value: 45, unit: 's'),
          'waist': BaselineMeasure(value: 78, unit: 'cm'),
        },
      );
      expect(record.baseline, hasLength(2));
    });

    test('the form refuses one too, before it reaches a record', () {
      expect(
        () => _form().withBaseline(
          'weightKg',
          const BaselineMeasure(value: 60, unit: 'kg'),
        ),
        throwsA(isA<BodyMeasureInBaseline>()),
      );
    });
  });

  group('K22 — the re-assessment is filled in from her intake', () {
    test(
      'the form pre-fills, and nothing is overwritten until saved',
      () async {
        final repo = InMemoryAssessmentRepository();
        final parent = _form(
          avoid: <ContraindicationTag>{ContraindicationTag.highImpact},
          painNotes: 'Knee sore on stairs',
        ).build(takenAt: _september);
        await repo.record(parent);

        final prefilled = AssessmentForm.from(parent);
        expect(prefilled.avoid, parent.assessment.avoid);
        expect(prefilled.painNotes, 'Knee sore on stairs');
        expect(prefilled.parentAssessmentId, parent.assessmentId);
        expect(
          repo.contents[parent.assessmentId]!.status,
          AssessmentStatus.recorded,
          reason: 'opening K22 wrote nothing',
        );
      },
    );

    test('history is at most five, newest first', () async {
      final repo = InMemoryAssessmentRepository();
      for (var month = 1; month <= 7; month++) {
        await repo.record(_form().build(takenAt: DateTime(2026, month, 1, 8)));
      }
      final history = await repo.history(clientUid: 'u1', coachUid: 'c1');
      expect(history, hasLength(5));
      expect(history.first.takenAt.month, 7);
    });
  });
}
