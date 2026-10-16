/// K22 — a re-assessment records, and **ends at DRAFT**.
///
/// HANDOFF 15, and `P1-RULE-21`: save a re-assessment with changed baselines
/// and a cleared referral, and "the published version and all assignments are
/// unchanged. The draft's status is 'draft'. No callable was invoked. 'Save and
/// adjust her plan' navigates to W03 and publishes nothing."
///
/// This file therefore does not import `CoachPlanPublisher`, and there is no
/// field or parameter through which one could be handed in. [save] returns a
/// [PlanRevisionSuggestion] — a navigation hint the coach may take or ignore.
/// A suggestion is the whole of what a re-assessment may do to a plan.
///
/// ## A referral survives silence
///
/// `P0-ASMT-04`: a four-week-old `refer` that the new assessment simply does
/// not mention is carried forward by `ReferralRegistry`, still suppressing.
/// "It cannot expire or be cleared by silence." Clearing is [clearReferral],
/// which needs an explicit reason and writes a **new** document.
library;

import 'package:meta/meta.dart';

import '../../../../domain/safety/referral_registry.dart';
import 'assessment_form.dart';
import 'assessment_record.dart';
import 'assessment_repository.dart';

/// What the coach may do next. A hint, never an action.
@immutable
class PlanRevisionSuggestion {
  const PlanRevisionSuggestion({
    required this.clientUid,
    required this.month,
    required this.activeReferralCount,
    required this.newlyClearedCount,
  });

  final String clientUid;

  /// The month W03 would open. Nothing is opened here.
  final String month;

  /// Still suppressing. Rendered prominently on K22, never as an error.
  final int activeReferralCount;

  final int newlyClearedCount;

  bool get hasActiveReferrals => activeReferralCount > 0;

  /// Always false. Named, so the absence is visible in the type rather than
  /// only in the prose: nothing a re-assessment produces publishes anything.
  bool get publishes => false;
}

/// Saves a re-assessment, and clears a referral properly.
class ReassessmentService {
  const ReassessmentService(this.repository);

  final AssessmentRepository repository;

  /// Writes the child and supersedes the parent, in one transaction.
  ///
  /// The parent's uncleared referrals come forward through
  /// `ReferralRegistry.carryForward`, so omitting one does not drop it.
  Future<PlanRevisionSuggestion> save({
    required AssessmentForm form,
    required AssessmentRecord parent,
    required DateTime takenAt,
    required String month,
  }) async {
    final child = form.build(takenAt: takenAt, carryFrom: parent);

    await repository.recordSuperseding(
      child: child,
      parentId: parent.assessmentId,
    );

    return PlanRevisionSuggestion(
      clientUid: child.clientUid,
      month: month,
      activeReferralCount: ReferralRegistry.activeReferrals(child.assessment)
          .length,
      newlyClearedCount: _newlyCleared(parent, child),
    );
  }

  /// The only exit from `REFER`, and it writes a new document.
  ///
  /// The reason is mandatory — `ReferralRegistry.clearReferral` throws on a
  /// blank one, so neither a stray tap nor an empty text field can end a
  /// suppression. The owner's decision, recorded against OQ-8: a coach may
  /// clear, with a reason, on a new assessment.
  Future<AssessmentRecord> clearReferral({
    required AssessmentRecord previous,
    required String screeningId,
    required String reason,
    required DateTime takenAt,
  }) async {
    final cleared = ReferralRegistry.clearReferral(
      previous: previous.assessment,
      screeningId: screeningId,
      reason: reason,
      takenAt: takenAt,
    );

    final child = AssessmentRecord(
      assessment: cleared,
      baseline: previous.baseline,
    );

    await repository.recordSuperseding(
      child: child,
      parentId: previous.assessmentId,
    );
    return child;
  }

  int _newlyCleared(AssessmentRecord parent, AssessmentRecord child) {
    final wasReferred = <String>{
      for (final item in ReferralRegistry.activeReferrals(parent.assessment))
        item.id,
    };
    var cleared = 0;
    for (final item in child.assessment.screening) {
      if (item.outcome == ScreeningOutcome.cleared &&
          wasReferred.contains(item.id)) {
        cleared += 1;
      }
    }
    return cleared;
  }
}
