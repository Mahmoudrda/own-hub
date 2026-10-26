/// What coaching on Own Hub is, what she will need, and the way in.
library;

import 'package:flutter/material.dart';

import '../../../../app_state/coach_application_draft.dart';
import '../../../../l10n/app_l10n.dart';
import '../../../../theme/app_tokens.dart';
import '../../../../ui/app_button.dart';
import '../../../../ui/app_card.dart';
import '../../../../ui/app_sage_note.dart';
import '../../../../ui/app_scaffold.dart';
import 'apply_rules.dart';

class ApplyIntroView extends StatelessWidget {
  const ApplyIntroView({
    super.key,
    required this.isVerifiedWoman,
    this.hasDraft,
    this.onStart,
    this.onVerify,
    this.onBack,
  });

  /// Only a verified woman can start. Anyone else is offered verification.
  final bool isVerifiedWoman;

  /// Whether a draft is waiting; defaults to the phone's draft.
  final bool? hasDraft;

  final VoidCallback? onStart;
  final VoidCallback? onVerify;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final draft = hasDraft ?? CoachApplicationDraft.instance.touched;
    final needs = <String>[
      l10n.aClearPhotoOfYou,
      l10n.photosOfYourDegreeAndCertificates,
      l10n.twoMessagesFromWomenYouTrained,
      l10n.aClientTransformationWithHerWrittenConsent,
    ];
    return AppScaffold(
      appBar: AppTopBar(onBack: onBack),
      footer: [
        if (isVerifiedWoman)
          AppButton(
            draft ? l10n.continueMyApplication : l10n.start,
            onPressed: onStart,
          )
        else
          AppButton(l10n.verifyMyAccount, onPressed: onVerify),
      ],
      children: [
        Semantics(
          header: true,
          child: Text(
            l10n.coachWomenOnOwnHub,
            style: AppText.headline.copyWith(
              color: AppColors.onPrimaryContainer,
            ),
          ),
        ),
        Text(
          l10n.applyToJoinAsACoachOwn,
          style: AppText.body.copyWith(color: AppColors.onSurfaceVariant),
        ),
        AppCard(
          children: [
            Text(
              l10n.whatYouWillNeed,
              style: AppText.titleM.copyWith(color: AppColors.onSurface),
            ),
            for (final need in needs)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsetsDirectional.only(top: 2, end: 10),
                    child: Icon(
                      Icons.check,
                      size: 18,
                      color: AppColors.primary,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      need,
                      style: AppText.bodyM.copyWith(color: AppColors.onSurface),
                    ),
                  ),
                ],
              ),
          ],
        ),
        Text(
          l10n.reviewTakesUpToDaysWorkingDays('$kReviewWorkingDays'),
          style: AppText.bodyM.copyWith(color: AppColors.onSurface),
        ),
        AppSageNote(l10n.ownHubIsForWomenOnlyOnly),
        if (!isVerifiedWoman) ...[
          Semantics(
            header: true,
            child: Text(
              l10n.verifyThatYouAreAWomanFirst,
              style: AppText.titleM.copyWith(color: AppColors.onSurface),
            ),
          ),
          Text(
            l10n.applyingNeedsAVerifiedAccountVerificationTakes,
            style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}
