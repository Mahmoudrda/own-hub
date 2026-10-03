/// C09 — One check, then you are in.
///
/// Matches `6-v2/src/screens-signup.mjs` → `C09`. The riskiest screen in the
/// product: it is where a woman is asked for her national ID and her face, and
/// it is the screen that decides whether she trusts the rest of it.
///
/// So it states exactly what is read, what is matched, what is deleted and how
/// long it takes — and it names the thing people actually fear: **we never guess
/// from your face.** That is rule 8, in her words. Sex is read from the 13th
/// digit of the national ID number, inside a Cloud Function, and from nothing
/// else.
///
/// **This screen is also the PDPL consent act.** Tapping "Scan my ID" is the
/// explicit consent that `startVerification` refuses to mint a session without.
/// The screen shows the text and reports the act; recording it is a callable's
/// job, not a widget's.
///
/// **The niqab path leaves from here and never comes back for a selfie.** It is
/// a button of its own on the primary screen, not a link hidden behind a
/// failure, because a woman who will not be photographed is not an edge case.
library;

import 'package:flutter/material.dart';

import '../../../domain/flags/feature_flags.dart';
import '../../../l10n/app_l10n.dart';
import '../../../routing/app_router.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_scaffold.dart';
import 'widgets/verification_bullet.dart';

class WhyWeCheckView extends StatelessWidget {
  const WhyWeCheckView({
    super.key,
    this.onScanId,
    this.onNiqabPath,
    this.onBack,
  });

  /// Consent, then `C10`. The two are the same tap by design.
  final VoidCallback? onScanId;

  /// Straight to `C15`. No selfie is requested on this route at any point.
  final VoidCallback? onNiqabPath;

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return AppScaffold(
      appBar: AppTopBar(onBack: onBack),
      footer: [
        AppButton(l10n.scanMyId, icon: Icons.badge, onPressed: onScanId),
        AppButton(
          l10n.iWearNiqabCheckMeAnotherWay,
          variant: AppButtonVariant.text,
          height: 48,
          fontSize: 15,
          onPressed: onNiqabPath,
        ),
      ],
      children: [
        Text(l10n.oneCheckThenYouAreIn, style: AppText.display),
        Text(
          AppRouter.featureFlags.isOn(Feature.community)
              ? l10n.thisIsTheWholeReasonTheCommunity
              : l10n.thisIsWhatKeepsOwnHubWomen,
          style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
        ),
        AppCard(
          variant: AppCardVariant.sage,
          children: [
            // The card itself says she is a woman — we never guess from her
            // face. Rule 8, stated before she is asked for anything.
            VerificationBullet(
              icon: Icons.badge,
              text: l10n.weReadYourNationalIdCardThe,
            ),
            VerificationBullet(
              icon: Icons.face,
              text: l10n.aSelfieIsMatchedToThePhoto,
            ),
            // Rule 7, promised here and repeated on C13 at the moment she is
            // most likely to believe it.
            VerificationBullet(
              icon: Icons.delete_outline,
              text: l10n.bothImagesAreDeletedAfterTheCheck,
            ),
            VerificationBullet(
              icon: Icons.schedule,
              text: l10n.itTakesAbout90Seconds,
            ),
          ],
        ),
        Text(
          l10n.checkedByOwnHubsOwnSystemYour,
          style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
        ),
      ],
    );
  }
}
