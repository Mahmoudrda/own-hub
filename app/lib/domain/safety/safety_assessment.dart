/// The assessment document, as a value — G14 §1.4.
///
/// HANDOFF 13: **this is the only source of a client's constraints.** Nothing
/// else feeds `ClientConstraints`, and no coach screen has an input that
/// reaches one.
///
/// ## `painNotes` is carried and never read
///
/// G14 §1.4: "Displayed to the coach; **never parsed, never used to filter** —
/// a filter driven by prose is a safety claim the product cannot honour." A
/// coach writing "diastasis, 4-finger gap" changes no tag, and that inertness
/// is deliberate rather than unfinished. `safety_product_rules_test.dart` scans
/// this folder and fails if the field is ever passed to a matcher, a splitter
/// or a regex.
///
/// ## No weight, anywhere
///
/// `baseline{}` is not modelled here at all. G14 §1.4 requires it to carry
/// **no weight key of any kind** (C7), and the safest way to keep a rule about
/// a field is to not have the field — the same reason `VerificationResult` has
/// nowhere to put a photograph. Nothing in the safety chain needs a baseline to
/// decide what may be prescribed, so nothing in the safety chain holds one.
///
/// ## No `actual*` at any depth
///
/// This type describes what was *recorded about her*, never what she did.
/// There is no field a widget could pre-fill with a result.
library;

import 'package:meta/meta.dart';

import 'contraindication_tag.dart';
import 'life_stage_safety_policy.dart';
import 'screening_item.dart';

/// One recorded assessment. Immutable, and corrected by recording a new one —
/// never by editing this one (HANDOFF 13, P0-ASMT-05).
@immutable
class SafetyAssessment {
  SafetyAssessment({
    required this.assessmentId,
    required this.clientUid,
    required this.takenAt,
    required this.lifeStage,
    this.coachUid,
    this.birthType,
    this.clearance,
    Set<ContraindicationTag> avoid = const {},
    this.painNotes,
    List<ScreeningItem> screening = const [],
    this.parentAssessmentId,
  }) : avoid = Set.unmodifiable(avoid),
       screening = List.unmodifiable(screening);

  /// Builds one from stored strings, refusing anything outside the vocabulary.
  ///
  /// This is the fail-closed boundary: a stored tag that nothing can match
  /// would read as an authored constraint and filter nothing, so it throws
  /// here and the caller resolves to "constraints unknown" rather than to a
  /// list that is quietly short by one tag.
  factory SafetyAssessment.fromWire({
    required String assessmentId,
    required String clientUid,
    required DateTime takenAt,
    required String lifeStage,
    String? coachUid,
    List<String> avoid = const [],
    String? birthType,
    Clearance? clearance,
    String? painNotes,
    List<ScreeningItem> screening = const [],
    String? parentAssessmentId,
  }) {
    final stage = LifeStage.fromWire(lifeStage);
    if (stage == null) {
      throw ArgumentError.value(
        lifeStage,
        'lifeStage',
        'Not one of G14 §1.4\'s five life stages',
      );
    }
    final BirthType? birth;
    if (birthType == null) {
      birth = null;
    } else {
      birth = BirthType.fromWire(birthType);
      if (birth == null) {
        throw ArgumentError.value(birthType, 'birthType', 'Unknown birth type');
      }
    }
    return SafetyAssessment(
      assessmentId: assessmentId,
      clientUid: clientUid,
      takenAt: takenAt,
      lifeStage: stage,
      coachUid: coachUid,
      birthType: birth,
      clearance: clearance,
      avoid: ContraindicationTag.parseAll(avoid),
      painNotes: painNotes,
      screening: screening,
      parentAssessmentId: parentAssessmentId,
    );
  }

  final String assessmentId;
  final String clientUid;

  /// Null for a self-authored assessment.
  final String? coachUid;

  final DateTime takenAt;
  final LifeStage lifeStage;
  final BirthType? birthType;

  /// K21's toggle. Null means nobody has answered — not "not granted".
  final Clearance? clearance;

  /// K21's chips. A controlled vocabulary, never free text.
  final Set<ContraindicationTag> avoid;

  /// K21's free-text field. **Displayed, never parsed.** See the library note.
  final String? painNotes;

  final List<ScreeningItem> screening;

  /// Set on a re-assessment, so the chain is readable without a query.
  final String? parentAssessmentId;

  /// G14 §1.4's deterministic id scope: a replayed save overwrites itself
  /// instead of creating a second assessment.
  String get scopeKey =>
      coachUid == null ? 'self_$clientUid' : '${coachUid}_$clientUid';

  @override
  String toString() =>
      'SafetyAssessment($assessmentId, ${lifeStage.wireName}, '
      'avoid: ${avoid.length}, screening: ${screening.length})';
}
