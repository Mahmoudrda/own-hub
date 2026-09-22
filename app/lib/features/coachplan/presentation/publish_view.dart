/// `W08` — the only screen in this feature that changes a plan.
///
/// ## The primary button is never disabled
///
/// `P2-OFF-W08`, and G14 §4.3 states it as a rule about the *control* rather
/// than about the copy: W08 "replaces its primary button's label, does **not**
/// disable it". [PublishButton.enabled] is a getter with no field behind it, so
/// there is no argument through which this screen could switch it off — and the
/// button below reads it rather than deciding for itself.
///
/// A disabled publish button, on a coach who has just planned a month with no
/// signal, reads as lost work. "Failed to save" for something that will sync is
/// a lie about her data. Neither appears here.
///
/// ## Offline says so twice, and neither says it failed
///
/// The primary button's label becomes *"We'll publish the moment you're back
/// online"*, and once she has pressed it the queued intent is badged *"Waiting
/// to send"*. Both are true of `PublishOutcome.queuedOffline`: the request is
/// held under its idempotency key, three presses queue one intent, and it
/// publishes exactly once on reconnect. Neither is an error card, and there is
/// no spinner on this screen to turn either of them into one.
///
/// ## A referral does not appear on this screen at all
///
/// HANDOFF 14: `refer` never blocks a publish and never colours a screen as a
/// failure. The cheapest way to keep that true is for the publish step not to
/// know referrals exist — the domain does not import the registry, and neither
/// does this file.
library;

import 'package:flutter/material.dart';

import '../../../domain/format/number_label.dart';
import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_sage_note.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/hand/hand.dart';
import '../domain/plan/coach_plan_publisher.dart';
import '../domain/plan/plan_draft.dart';
import 'coachplan_widgets.dart';
import 'workout_planner_view.dart' show monthDayKeys;

class PublishView extends StatelessWidget {
  const PublishView({
    super.key,
    required this.draft,
    required this.publishContext,
    this.hasAssessment = true,
    this.unreadableMealIds = const <String>[],
    this.outcome,
    this.onOpenAssessment,
    this.onPreviewDay,
    this.onFillGaps,
    this.onPublish,
    this.onBack,
  });

  final PlanDraft draft;

  /// Everything the gate needs — her life stage, the clearance on file,
  /// whether this coach is verified, and whether there is signal.
  final PublishContext publishContext;

  /// False when nothing has been recorded for her. It is named here and it
  /// does **not** block the button.
  final bool hasAssessment;

  /// Coach meals on a day that could not be read. Publishing is refused before
  /// it is attempted, because a published day pointing at a document she may
  /// not open is a blank dinner with no way to find out what it was.
  final List<String> unreadableMealIds;

  /// What the last attempt did, when there has been one.
  final PublishOutcome? outcome;

  final VoidCallback? onOpenAssessment;
  final VoidCallback? onPreviewDay;
  final VoidCallback? onFillGaps;
  final VoidCallback? onPublish;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final button = PublishButton.forContext(publishContext);
    final totalSlots =
        monthDayKeys(draft.month).length * PlanMealSlot.values.length;
    final refusal = outcome?.refusal;

    return Scaffold(
      backgroundColor: AppColors.surface,
      // "Publish to Nour" names the prototype's sample client to every coach
      // about every woman. The act is the title instead; who it is for is the
      // client the planner is already about.
      appBar: AppTopBar(title: l10n.previewAndPublish, onBack: onBack),
      body: AppScaffold(
        footer: [
          AppButton(
            // The label varies; `enabled` cannot. Offline it says so, and it
            // still publishes the moment there is signal.
            _publishLabel(l10n, button.label),
            key: CoachPlanKeys.publish,
            height: 56,
            icon: Icons.send,
            onPressed: button.enabled ? onPublish : null,
          ),
        ],
        children: [
          AppCard(
            gap: 0,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: SectionHead(l10n.plan)),
                    // Once it has gone out, the summary is ticked off in sage
                    // beside its heading — done, drawn on once. Only on a
                    // real receipt: a queued intent has not gone anywhere.
                    if (outcome?.isPublished ?? false) ...[
                      const SizedBox(width: 12),
                      const HandTick(size: 44, seed: 13, drawOn: true),
                    ],
                  ],
                ),
              ),
              LabelledValue(
                label: l10n.dates,
                value: draft.effectiveFrom ?? draft.month,
              ),
              LabelledValue(
                label: l10n.workouts,
                value: countLabel(draft.workoutDayCount),
              ),
              LabelledValue(
                label: l10n.rest,
                value: countLabel(draft.restDayCount),
              ),
              LabelledValue(
                label: l10n.meals,
                value: l10n.countOfTotal(
                  '${draft.filledMealSlots}',
                  '$totalSlots',
                ),
              ),
              LabelledValue(
                label: l10n.approvedOptions,
                value: countLabel(_approvedOptionCount()),
              ),
            ],
          ),
          // Named, and not a blocker. She may publish anyway.
          if (!hasAssessment)
            AppCard(
              key: const Key('W08.noAssessment'),
              variant: AppCardVariant.amber,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.checklist,
                      size: 22,
                      color: AppColors.amber,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.noAssessmentOnFilePublishAnywayOr,
                        style: AppText.bodyM,
                      ),
                    ),
                    const SizedBox(width: 10),
                    AppButton(
                      l10n.assessment,
                      variant: AppButtonVariant.tonal,
                      height: 36,
                      fontSize: 13,
                      onPressed: onOpenAssessment,
                    ),
                  ],
                ),
              ],
            ),
          // Counted before publishing. Publishing turns each one into a
          // stated free choice rather than leaving it undefined.
          if (draft.unfilledMealSlots > 0)
            AppCard(
              key: const Key('W08.gaps'),
              variant: AppCardVariant.amber,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              gap: 8,
              children: [
                LabelledValue(
                  label: l10n.meals,
                  value: l10n.countOfTotal(
                    '${draft.filledMealSlots}',
                    '$totalSlots',
                  ),
                ),
                AppButton(
                  l10n.fillTheGaps,
                  variant: AppButtonVariant.text,
                  height: 44,
                  fontSize: 14,
                  onPressed: onFillGaps,
                ),
              ],
            ),
          // Queued, not failed. `PublishOutcome.queuedOffline` means the
          // intent is held under its idempotency key and will publish exactly
          // once — so this is a badge saying what is true, never an error
          // card and never a spinner.
          if (outcome?.isQueued ?? false)
            AppCard(
              key: CoachPlanKeys.queued,
              variant: AppCardVariant.filled,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.schedule_send,
                      size: 20,
                      color: AppColors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(l10n.waitingToSend, style: AppText.bodyM),
                    ),
                  ],
                ),
              ],
            ),
          if (refusal != null) _refusalCard(l10n, refusal),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  l10n.previewHerDay,
                  variant: AppButtonVariant.outlined,
                  height: 44,
                  fontSize: 14,
                  onPressed: onPreviewDay,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppButton(
                  l10n.fillTheGaps,
                  variant: AppButtonVariant.text,
                  height: 44,
                  fontSize: 14,
                  onPressed: onFillGaps,
                ),
              ),
            ],
          ),
          AppSageNote(l10n.revisionsDefaultToFutureDatesASession),
        ],
      ),
    );
  }

  /// W08's primary label.
  ///
  /// Offline it reads **"We'll publish the moment you're back online"** — which
  /// is what actually happens: the intent is queued idempotently and publishes
  /// exactly once on reconnect. It is not `publishPlan`, which would claim the
  /// plan has gone out, and not a "failed to save", which would be a lie about
  /// work that will sync. The control itself stays enabled either way.
  static String _publishLabel(AppL10n l10n, PublishButtonLabel label) =>
      switch (label) {
        PublishButtonLabel.publishNow => l10n.publishPlan,
        PublishButtonLabel.publishWhenOnline =>
          l10n.wellPublishTheMomentYoureBackOnline,
      };

  int _approvedOptionCount() {
    var total = 0;
    for (final day in draft.days.values) {
      total += day.workout?.approvedAlternatives.length ?? 0;
    }
    return total;
  }

  /// Why a publish was refused before it was attempted.
  ///
  /// There is deliberately no branch for a referral: `PublishRefusal` has no
  /// value for one, so this switch could not render it as a failure even if
  /// somebody wanted it to.
  Widget _refusalCard(AppL10n l10n, PublishRefusal refusal) {
    // TODO(l10n): `clearanceWithheld` and `clearanceUnrecorded` have no
    // sentence in the dictionary. Both are named by the thing that is missing
    // — her doctor's clearance — with a way to record it, rather than by copy
    // invented here.
    final (title, action) = switch (refusal) {
      PublishRefusal.clearanceWithheld || PublishRefusal.clearanceUnrecorded =>
        (l10n.doctorsClearanceToTrain, l10n.assessment),
      PublishRefusal.coachNotVerified => (
        l10n.weAreCheckingYourCertificates,
        null,
      ),
      PublishRefusal.coachMealUnreadable => (
        unreadableMealIds.isEmpty ? l10n.meals : unreadableMealIds.join(' · '),
        null,
      ),
    };

    return AppCard(
      key: const Key('W08.refusal'),
      // Amber: a thing to do next, not a failure of hers.
      variant: AppCardVariant.amber,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      gap: 8,
      children: [
        Text(title, style: AppText.titleM),
        if (action != null)
          AppButton(
            action,
            variant: AppButtonVariant.tonal,
            height: 40,
            fontSize: 14,
            onPressed: onOpenAssessment,
          ),
      ],
    );
  }
}
