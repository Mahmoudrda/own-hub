/// K21 and K23 — two steps, **one document**.
///
/// G14 §3.1: the two steps never write independently. "A half-saved assessment
/// is a half-stated constraint, and rule 13 makes the assessment the *only*
/// source — a partial source is worse than none." `P0-ASMT-01` kills the app
/// mid-step-2 and expects nothing to have been written.
///
/// So this form is a value held in memory. It has no repository, no `save`, and
/// nothing that could reach storage; [build] hands a finished record to the
/// caller, and until that happens there is nothing anywhere.
///
/// ## The avoid list is chips, not prose
///
/// Rule 13, and §1.5. [avoid] is a set of `ContraindicationTag`, which has no
/// constructor taking a string, so an avoid list that nothing can match is
/// unrepresentable rather than merely discouraged. [painNotes] sits beside it
/// and is **displayed, never parsed** — a filter driven by prose is a safety
/// claim the product cannot honour.
library;

import 'package:meta/meta.dart';

import '../../../../domain/safety/contraindication_tag.dart';
import '../../../../domain/safety/life_stage_safety_policy.dart';
import '../../../../domain/safety/referral_registry.dart';
import '../../../../domain/safety/safety_assessment.dart';
import '../prescription_only_validator.dart';
import 'assessment_record.dart';

/// Which half of the form she is on. K21 is step 1, K23 is step 2.
enum AssessmentStep { health, screening }

/// Why a save was refused, in words a screen can use.
enum AssessmentFormProblem {
  lifeStageMissing,
  clearanceMissing,
  screeningIncomplete,
  painNotesTooLong,
  avoidListTooLong,
}

/// The longest `painNotes` may be.
const int kMaxPainNotesLength = 500;

/// The most avoid tags one assessment may carry.
const int kMaxAvoidTags = 12;

/// The most screening items one assessment may carry.
const int kMaxScreeningItems = 12;

class AssessmentFormInvalid implements Exception {
  const AssessmentFormInvalid(this.problem);

  final AssessmentFormProblem problem;

  @override
  String toString() => 'AssessmentFormInvalid(${problem.name})';
}

/// The in-memory form behind K21 and K23.
@immutable
class AssessmentForm {
  AssessmentForm({
    required this.clientUid,
    this.coachUid,
    this.lifeStage,
    this.birthType,
    this.clearance,
    Set<ContraindicationTag> avoid = const <ContraindicationTag>{},
    this.painNotes,
    List<ScreeningItem> screening = const <ScreeningItem>[],
    Map<String, BaselineMeasure> baseline = const <String, BaselineMeasure>{},
    this.parentAssessmentId,
  }) : avoid = Set<ContraindicationTag>.unmodifiable(avoid),
       screening = List<ScreeningItem>.unmodifiable(screening),
       baseline = Map<String, BaselineMeasure>.unmodifiable(baseline);

  /// Pre-filled from the previous assessment — K22's premise, and K21's when
  /// one exists. Nothing is overwritten until she saves.
  factory AssessmentForm.from(
    AssessmentRecord previous, {
    List<ScreeningItem>? screening,
  }) => AssessmentForm(
    clientUid: previous.clientUid,
    coachUid: previous.coachUid,
    lifeStage: previous.assessment.lifeStage,
    birthType: previous.assessment.birthType,
    clearance: previous.assessment.clearance,
    avoid: previous.assessment.avoid,
    painNotes: previous.assessment.painNotes,
    screening: screening ?? previous.assessment.screening,
    baseline: previous.baseline,
    parentAssessmentId: previous.assessmentId,
  );

  final String clientUid;

  /// Null for a self-authored assessment. No screen writes one today — OQ-7 —
  /// and the field stays optional rather than being made required and then
  /// relaxed later.
  final String? coachUid;

  final LifeStage? lifeStage;
  final BirthType? birthType;

  /// `granted:false` is a recorded answer. Null is nobody having answered.
  final Clearance? clearance;

  final Set<ContraindicationTag> avoid;

  /// Displayed to the coach. Never parsed, never used to filter.
  final String? painNotes;

  final List<ScreeningItem> screening;
  final Map<String, BaselineMeasure> baseline;
  final String? parentAssessmentId;

  /// K21 → K23. Both answers are required: the life stage derives restrictions
  /// on its own, and the clearance gates publishing in the first six weeks.
  bool get canContinue => lifeStage != null && clearance != null;

  /// Every item answered. `P2-ERR-K23` names the unanswered one.
  List<ScreeningItem> get unansweredItems => <ScreeningItem>[
    for (final item in screening)
      if (item.outcome == ScreeningOutcome.unset) item,
  ];

  bool get canSave => problems().isEmpty;

  List<AssessmentFormProblem> problems() {
    final found = <AssessmentFormProblem>[];
    if (lifeStage == null) found.add(AssessmentFormProblem.lifeStageMissing);
    if (clearance == null) found.add(AssessmentFormProblem.clearanceMissing);
    if (unansweredItems.isNotEmpty) {
      found.add(AssessmentFormProblem.screeningIncomplete);
    }
    if ((painNotes ?? '').length > kMaxPainNotesLength) {
      found.add(AssessmentFormProblem.painNotesTooLong);
    }
    if (avoid.length > kMaxAvoidTags) {
      found.add(AssessmentFormProblem.avoidListTooLong);
    }
    return found;
  }

  AssessmentForm withHealth({
    LifeStage? lifeStage,
    BirthType? birthType,
    Clearance? clearance,
    Set<ContraindicationTag>? avoid,
    String? painNotes,
  }) => AssessmentForm(
    clientUid: clientUid,
    coachUid: coachUid,
    lifeStage: lifeStage ?? this.lifeStage,
    birthType: birthType ?? this.birthType,
    clearance: clearance ?? this.clearance,
    avoid: avoid ?? this.avoid,
    painNotes: painNotes ?? this.painNotes,
    screening: screening,
    baseline: baseline,
    parentAssessmentId: parentAssessmentId,
  );

  /// Sets one screening answer. A `refer` carries the tags it suppresses, so
  /// the outcome and the avoid list speak one vocabulary.
  AssessmentForm withOutcome(
    String screeningId,
    ScreeningOutcome outcome, {
    Set<ContraindicationTag>? suppresses,
  }) => AssessmentForm(
    clientUid: clientUid,
    coachUid: coachUid,
    lifeStage: lifeStage,
    birthType: birthType,
    clearance: clearance,
    avoid: avoid,
    painNotes: painNotes,
    screening: <ScreeningItem>[
      for (final item in screening)
        if (item.id == screeningId)
          ScreeningItem(
            id: item.id,
            outcome: outcome,
            suppresses: suppresses ?? item.suppresses,
          )
        else
          item,
    ],
    baseline: baseline,
    parentAssessmentId: parentAssessmentId,
  );

  AssessmentForm withBaseline(String measureId, BaselineMeasure measure) {
    final next = <String, BaselineMeasure>{...baseline, measureId: measure};
    PrescriptionOnlyValidator.assertNoBodyMeasure(<String, Object?>{
      for (final key in next.keys) key: null,
    });
    return AssessmentForm(
      clientUid: clientUid,
      coachUid: coachUid,
      lifeStage: lifeStage,
      birthType: birthType,
      clearance: clearance,
      avoid: avoid,
      painNotes: painNotes,
      screening: screening,
      baseline: next,
      parentAssessmentId: parentAssessmentId,
    );
  }

  /// The document id: `{scopeKey}__{takenAtIso}`.
  ///
  /// Deterministic, so a two-step form saved offline and replayed overwrites
  /// itself instead of creating a second assessment.
  String idFor(DateTime takenAt) {
    final scope = coachUid == null
        ? 'self_$clientUid'
        : '${coachUid}_$clientUid';
    return '${scope}__${takenAt.toIso8601String()}';
  }

  /// The finished record. Throws rather than returning a partial one.
  ///
  /// [carryFrom] is the previous assessment, when there is one: its uncleared
  /// referrals come forward here, so a re-assessment that simply omits one has
  /// not cleared it.
  AssessmentRecord build({
    required DateTime takenAt,
    AssessmentRecord? carryFrom,
  }) {
    final found = problems();
    if (found.isNotEmpty) throw AssessmentFormInvalid(found.first);

    final items = carryFrom == null
        ? screening
        : ReferralRegistry.carryForward(
            previous: carryFrom.assessment,
            next: screening,
          );

    return AssessmentRecord(
      assessment: SafetyAssessment(
        assessmentId: idFor(takenAt),
        clientUid: clientUid,
        coachUid: coachUid,
        takenAt: takenAt,
        lifeStage: lifeStage!,
        birthType: birthType,
        clearance: clearance,
        avoid: avoid,
        painNotes: painNotes,
        screening: items,
        parentAssessmentId: parentAssessmentId ?? carryFrom?.assessmentId,
      ),
      baseline: baseline,
    );
  }
}
