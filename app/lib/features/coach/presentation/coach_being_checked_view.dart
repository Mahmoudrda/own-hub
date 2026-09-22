/// `K06` — Being checked.
///
/// Matches `6-v2/src/screens-coach.mjs` → `K06`.
///
/// # Waiting is not a dead end (HANDOFF 17, `P0-CVER-01`)
///
/// The test case asks for exactly this: *"K06 states the check is in progress
/// and offers real work instead of a dead end."* The card under the hourglass is
/// that work, and it is true work rather than a tour — a plan template and a
/// meal template that her first client gets on day one.
///
/// # She may author everything and publish nothing
///
/// [CoachPublishingRights.isAuthoringWhileUnpublished] is the state this screen
/// exists in, and the copy is written from it. Nothing she builds while she
/// waits is visible to anyone, and nothing she builds is lost.
///
/// # It is amber, never error
///
/// Amber is this product's "a caution that is not a failure"; red is reserved
/// for genuine problems and medical guidance. `C14` made the same choice for the
/// same reason, and D8 fixes the substance for both: we are reviewing to keep
/// this community safe, and nobody is accused of anything.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_list_item.dart' show HandIconRing;
import '../../../ui/app_scaffold.dart';
import '../../../ui/hand/hand.dart';
import '../domain/coach_verification.dart';
import 'coach_setup_scaffold.dart';
import 'coach_view_models.dart';

class CoachBeingCheckedView extends StatelessWidget {
  const CoachBeingCheckedView({
    super.key,
    this.verification = CoachVerificationState.submitted,
    this.onBuildFirstPlan,
    this.onSeeToday,
    this.onReplaceCertificate,
    this.note,
  });

  final CoachVerificationState verification;

  /// A sentence about *how* this state was reached, when that is not the
  /// ordinary way. Today its only caller is the test build, where a coach
  /// counts as checked because no account is required — and the screen has to
  /// say so, or the tick above would claim a reviewer looked at her papers.
  /// Null renders nothing.
  final String? note;

  final VoidCallback? onBuildFirstPlan;
  final VoidCallback? onSeeToday;

  /// `K02`, for a coach whose certificate was not cleared. The replace path
  /// stays open (`P0-CVER-03`).
  final VoidCallback? onReplaceCertificate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final rights = CoachPublishingRights.forState(verification);
    final cleared = verification.holdsCoachClaim;
    final refused = verification == CoachVerificationState.rejected;

    return AppScaffold(
      scrollable: false,
      appBar: AppTopBar(title: stepTitle(l10n, CoachSetupStep.beingChecked)),
      footer: [
        if (refused)
          AppButton(
            l10n.addAnotherCertificate,
            height: 56,
            onPressed: () => goToScreen(context, 'K02', onReplaceCertificate),
          )
        else
          AppButton(
            l10n.buildMyFirstPlan,
            height: 56,
            // K20 is G14's split builder. Real work, available now.
            onPressed: () => goToScreen(context, 'K20', onBuildFirstPlan),
          ),
        AppButton(
          l10n.seeMyToday,
          variant: AppButtonVariant.text,
          height: 44,
          fontSize: 15,
          // K24 is a STATE of the K07 route, never a destination (HANDOFF 16).
          // Today decides which branch to draw from her roster.
          onPressed: () => goToScreen(context, 'K07', onSeeToday),
        ),
      ],
      children: [
        const AppSpacer(),
        // A flat disc of the state's colour with a pencil ring drawn round
        // it. Once she is cleared, a sage tick is set against it by hand:
        // the check is done, and done is the only thing sage ever says.
        Center(
          child: SizedBox.square(
            dimension: 88,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                HandSurface(
                  seed: 88,
                  fill: cleared
                      ? AppColors.tertiaryContainer
                      : AppColors.amberContainer,
                  radius: 44,
                  looseCorner: 44,
                  child: const SizedBox.square(dimension: 88),
                ),
                // A little wider than the disc, so the pencil line drifts
                // off its edge instead of tracing it.
                Positioned(
                  left: -6,
                  top: -6,
                  right: -6,
                  bottom: -6,
                  child: HandIconRing(
                    seed: 6,
                    size: 100,
                    icon: Icon(
                      cleared ? Icons.verified_user : Icons.hourglass_top,
                      size: 46,
                      color: cleared ? AppColors.tertiary : AppColors.amber,
                    ),
                  ),
                ),
                if (cleared)
                  const PositionedDirectional(
                    top: -18,
                    end: -26,
                    child: HandTick(size: 52, drawOn: true),
                  ),
              ],
            ),
          ),
        ),
        Text(
          cleared
              ? l10n.certificatesChecked
              : l10n.wereCheckingYourCertificates,
          textAlign: TextAlign.center,
          style: AppText.headline.copyWith(
            height: 34 / 26,
            color: AppColors.onPrimaryContainer,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            cleared
                ? l10n.yourPageIsVisibleAndYouCan
                : l10n.usuallyTheSameDayWeWillText,
            textAlign: TextAlign.center,
            style: AppText.body.copyWith(color: AppColors.onSurfaceVariant),
          ),
        ),
        // Rule 17: the wait states what she can do, and it is real.
        if (rights.isAuthoringWhileUnpublished)
          AppCard(
            variant: AppCardVariant.sage,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.youCanStartNow, style: AppText.titleM),
                  const SizedBox(height: 4),
                  Text(
                    l10n.buildYourFirstPlanAndAMeal,
                    style: AppText.bodyM.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        if (note case final String text)
          AppCard(
            variant: AppCardVariant.amber,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            children: [
              Text(
                text,
                style: AppText.bodyM.copyWith(color: AppColors.onSurface),
              ),
            ],
          ),
        const AppSpacer(),
      ],
    );
  }
}
