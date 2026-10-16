/// The assessment document — G14 §1.4 — around the safety type.
///
/// `SafetyAssessment` in `domain/safety/` is the recorded answer the whole
/// safety chain reads, and it deliberately holds **no baseline**: "the safest
/// way to keep a rule about a field is to not have the field". The stored
/// document does carry one (K23 records a plank hold, a waist measurement),
/// so this type is the document: the safety value, plus the fields nothing in
/// the safety chain is allowed to see.
///
/// The baseline is validated on the way in and may never name a body weight —
/// C7, and rule 11 behind it. A baseline that cannot hold one cannot be ranked
/// by one.
///
/// ## Status is workflow; `lifeStage` is her body
///
/// G14 §1.4 renamed the spine's `stage` for exactly this reason: two readers
/// had already taken it for a workflow state. [AssessmentStatus] is the
/// workflow, and it has two values because an assessment is append-only —
/// `recorded → superseded` is the only transition there is.
library;

import 'package:meta/meta.dart';

import '../../../../domain/safety/safety_assessment.dart';
import '../prescription_only_validator.dart';

/// G14 §3.1's terminal states. There is no `edited`.
enum AssessmentStatus {
  recorded('recorded'),
  superseded('superseded');

  const AssessmentStatus(this.wireName);

  final String wireName;
}

/// One measured thing. K23's "plank hold: 45 s", "waist: 78 cm".
@immutable
class BaselineMeasure {
  const BaselineMeasure({required this.value, required this.unit});

  final num value;
  final String unit;

  Map<String, Object?> toWire() => <String, Object?>{
    'value': value,
    'unit': unit,
  };

  @override
  String toString() => 'BaselineMeasure($value $unit)';
}

/// The stored assessment.
@immutable
class AssessmentRecord {
  AssessmentRecord({
    required this.assessment,
    Map<String, BaselineMeasure> baseline = const <String, BaselineMeasure>{},
    this.status = AssessmentStatus.recorded,
  }) : baseline = Map<String, BaselineMeasure>.unmodifiable(baseline) {
    PrescriptionOnlyValidator.assertNoBodyMeasure(<String, Object?>{
      for (final key in this.baseline.keys) key: null,
    });
  }

  final SafetyAssessment assessment;

  /// Keyed by measure id. Never a weight, of any kind.
  final Map<String, BaselineMeasure> baseline;

  final AssessmentStatus status;

  String get assessmentId => assessment.assessmentId;
  String get clientUid => assessment.clientUid;
  String? get coachUid => assessment.coachUid;
  DateTime get takenAt => assessment.takenAt;

  bool get isRecorded => status == AssessmentStatus.recorded;

  /// The only permitted update, and it is written by the child's transaction.
  AssessmentRecord superseded() => AssessmentRecord(
    assessment: assessment,
    baseline: baseline,
    status: AssessmentStatus.superseded,
  );

  Map<String, Object?> toWire() => <String, Object?>{
    if (assessment.coachUid != null) 'coachUid': assessment.coachUid,
    'clientUid': assessment.clientUid,
    'takenAt': assessment.takenAt.toIso8601String(),
    'lifeStage': assessment.lifeStage.wireName,
    if (assessment.birthType != null)
      'birthType': assessment.birthType!.wireName,
    if (assessment.clearance != null)
      'clearance': <String, Object?>{
        'granted': assessment.clearance!.granted,
        'recordedAt': assessment.clearance!.recordedAt.toIso8601String(),
        if (assessment.clearance!.note != null)
          'note': assessment.clearance!.note,
      },
    'avoid': <String>[for (final tag in assessment.avoid) tag.wireName],
    if (assessment.painNotes != null) 'painNotes': assessment.painNotes,
    'screening': <Map<String, Object?>>[
      for (final item in assessment.screening)
        <String, Object?>{
          'id': item.id,
          'outcome': item.outcome.name,
          'suppresses': <String>[
            for (final tag in item.suppresses) tag.wireName,
          ],
          if (item.clearedReason != null) 'clearedReason': item.clearedReason,
          if (item.clearedAt != null)
            'clearedAt': item.clearedAt!.toIso8601String(),
        },
    ],
    'baseline': <String, Object?>{
      for (final entry in baseline.entries) entry.key: entry.value.toWire(),
    },
    if (assessment.parentAssessmentId != null)
      'parentAssessmentId': assessment.parentAssessmentId,
    'status': status.wireName,
  };

  @override
  String toString() => 'AssessmentRecord($assessmentId, ${status.wireName})';
}
