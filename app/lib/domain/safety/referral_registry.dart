/// HANDOFF 14 — a `refer` outcome suppresses moves, and is not a failure.
///
/// G14 §3.2's table, in one place:
///
/// | State | Suppresses? | Shown on K22? | Blocks publish? |
/// |---|---|---|---|
/// | `PASS` | no | as a row | no |
/// | `MODIFY` | no | as a row | no |
/// | `REFER` | **yes** | **prominently, until cleared** | **no** |
/// | `CLEARED` | no | as history, with the reason | no |
///
/// ## It cannot expire, decay, or be cleared by silence
///
/// Three separate properties, each enforced by shape rather than by review:
///
///  * **No expiry.** [activeTags] takes an assessment and *nothing else*. There
///    is no clock in the signature, so there is no date a referral could be
///    compared against. `safety_product_rules_test.dart` additionally fails the
///    build if `DateTime.now()` ever appears in this folder.
///  * **No decay.** Nothing here weights, ages or scores an outcome.
///  * **No clearing by silence.** [carryForward] is the answer to a
///    re-assessment that simply does not mention the referral: the item comes
///    forward unchanged. P0-ASMT-04 — "it cannot expire or be cleared by
///    silence" — is this method.
///
/// ## Clearing writes a new document
///
/// [clearReferral] returns a **new** [SafetyAssessment] carrying the reason,
/// with `parentAssessmentId` pointing at the one it supersedes. The previous
/// assessment is untouched, because G14 §3.2 requires clearing to be "recorded
/// on a new assessment document — never by editing the old one", and because
/// P0-ASMT-05 makes a recorded assessment append-only.
library;

import 'contraindication_tag.dart';
import 'safety_assessment.dart';
import 'screening_item.dart';

export 'screening_item.dart';

/// Reads referrals out of an assessment, and clears one properly.
class ReferralRegistry {
  const ReferralRegistry._();

  /// Every item currently suppressing moves.
  static List<ScreeningItem> activeReferrals(SafetyAssessment assessment) =>
      List.unmodifiable(
        assessment.screening.where((item) => item.isActiveReferral),
      );

  /// The tags a `refer` outcome suppresses. `pass` and `modify` contribute
  /// nothing — G14 §3.2's table, not an interpretation of it.
  ///
  /// Takes no clock. See the library note.
  static Set<ContraindicationTag> activeTags(SafetyAssessment assessment) {
    final tags = <ContraindicationTag>{};
    for (final item in assessment.screening) {
      if (!item.isActiveReferral) continue;
      for (final tag in item.suppresses) {
        if (tag.restricts) tags.add(tag);
      }
    }
    return Set.unmodifiable(tags);
  }

  /// [next] plus every still-active referral from [previous] that [next] does
  /// not restate.
  ///
  /// A re-assessment that omits a referral has not cleared it. A restated one
  /// is not duplicated, and a **cleared** one is not resurrected — otherwise
  /// `CLEARED` would be unreachable and the referral genuinely permanent,
  /// which is not the rule either.
  static List<ScreeningItem> carryForward({
    required SafetyAssessment previous,
    required List<ScreeningItem> next,
  }) {
    final restated = {for (final item in next) item.id};
    return List.unmodifiable(<ScreeningItem>[
      ...next,
      for (final item in activeReferrals(previous))
        if (!restated.contains(item.id)) item,
    ]);
  }

  /// [successor] with [previous]'s uncleared referrals carried into it.
  static SafetyAssessment mergeIntoSuccessor({
    required SafetyAssessment previous,
    required SafetyAssessment successor,
  }) => _withScreening(
    successor,
    carryForward(previous: previous, next: successor.screening),
    parentAssessmentId: successor.parentAssessmentId,
    assessmentId: successor.assessmentId,
    takenAt: successor.takenAt,
  );

  /// Clears one referral, on a **new** assessment, with a reason.
  ///
  /// The only exit from `REFER`. Throws when the reason is blank or when the
  /// named item is not an active referral, so neither a stray tap nor an empty
  /// text field can end a suppression.
  static SafetyAssessment clearReferral({
    required SafetyAssessment previous,
    required String screeningId,
    required String reason,
    required DateTime takenAt,
  }) {
    if (reason.trim().isEmpty) {
      throw ArgumentError.value(
        reason,
        'reason',
        'Clearing a referral requires an explicit reason (G14 §3.2)',
      );
    }
    final isActive = previous.screening.any(
      (item) => item.id == screeningId && item.isActiveReferral,
    );
    if (!isActive) {
      throw ArgumentError.value(
        screeningId,
        'screeningId',
        'No active referral with this id on the assessment being superseded',
      );
    }

    return _withScreening(
      previous,
      <ScreeningItem>[
        for (final item in previous.screening)
          if (item.id == screeningId)
            ScreeningItem(
              id: item.id,
              outcome: ScreeningOutcome.cleared,
              suppresses: item.suppresses,
              clearedReason: reason,
              clearedAt: takenAt,
            )
          else
            item,
      ],
      parentAssessmentId: previous.assessmentId,
      assessmentId: '${previous.scopeKey}__${takenAt.toIso8601String()}',
      takenAt: takenAt,
    );
  }

  /// A copy of [source] with a different screening list. Every other recorded
  /// answer is carried by value — clearing a referral is not an opportunity to
  /// quietly change her life stage or her avoid list.
  static SafetyAssessment _withScreening(
    SafetyAssessment source,
    List<ScreeningItem> screening, {
    required String assessmentId,
    required DateTime takenAt,
    String? parentAssessmentId,
  }) => SafetyAssessment(
    assessmentId: assessmentId,
    clientUid: source.clientUid,
    takenAt: takenAt,
    lifeStage: source.lifeStage,
    coachUid: source.coachUid,
    birthType: source.birthType,
    clearance: source.clearance,
    avoid: source.avoid,
    painNotes: source.painNotes,
    screening: screening,
    parentAssessmentId: parentAssessmentId,
  );
}
