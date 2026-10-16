/// C03 — What's inside.
///
/// Matches `6-v2/src/screens-signup.mjs` → `C03`. Four promises, each an icon
/// beside a title and a line of plain speech. The prototype builds them with a
/// local `promise()` helper; here it is [_Promise], with the same geometry:
/// a 26px icon in `primaryDim`, 14px from the text, both top-aligned so the icon
/// sits with the first line rather than floating in the middle of a wrapped
/// paragraph — which matters more in Arabic, where these lines run longer.
library;

import '../../../theme/app_art.dart';

import 'package:flutter/material.dart';

import '../../../domain/flags/feature_flags.dart';
import '../../../l10n/app_l10n.dart';
import '../../../routing/app_router.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/hand/hand.dart';

class WhatsInsideView extends StatelessWidget {
  const WhatsInsideView({
    super.key,
    this.onCreateAccount,
    this.onLookAround,
    this.onBack,
  });

  final VoidCallback? onCreateAccount;
  final VoidCallback? onLookAround;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return AppScaffold(
      appBar: AppTopBar(onBack: onBack),
      footer: [
        AppButton(l10n.createMyAccount, onPressed: onCreateAccount),
        AppButton(
          l10n.lookAroundFirst,
          variant: AppButtonVariant.text,
          height: 48,
          fontSize: 15,
          onPressed: onLookAround,
        ),
      ],
      children: [
        // C03 is the pitch, and it was carried entirely by type. Quiet training
        // at home is the first thing the product promises, so that is what it
        // shows.
        Center(child: AppArt.image(AppArt.stretchSeated, size: 140)),
        const SizedBox(height: 12),
        // A contents page: the heading marked once, the way she would mark
        // the page she means to come back to.
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: MarkerHighlight(
            drawOn: true,
            delay: HandTiming.medium,
            child: Text(
              l10n.whatsInside,
              textWidthBasis: TextWidthBasis.longestLine,
              style: EditorialType.section,
            ),
          ),
        ),
        const SizedBox(height: 4),
        // The prototype sets an 18px gap on this body rather than the default
        // 10, because stacked promises need air to read as separate things.
        // The pencil rules take that gap, so they read as entries in a list.
        _Promise(
          icon: Icons.volume_off,
          title: l10n.quietWorkoutsForHome,
          body: l10n.noJumpingNoEquipmentTenMinutesCounts,
        ),
        const HandRule(seed: 31, height: 8),
        _Promise(
          icon: Icons.restaurant,
          title: l10n.foodYouAlreadyCook,
          body: l10n.koshariFulAndMolokhiaInThePortions,
        ),
        // Before she signs in this names the daily check-in, never the cycle
        // behind it. Promised only with that feature on.
        if (AppRouter.featureFlags.isOn(Feature.cycle)) ...[
          const HandRule(seed: 34, height: 8),
          _Promise(
            icon: Icons.water_drop_outlined,
            title: l10n.aPlanThatAdjustsToHowYou,
            body: l10n.sayHowYouFeelTodayOnHarder,
          ),
        ],
        const HandRule(seed: 32, height: 8),
        _Promise(
          icon: Icons.verified_user,
          title: l10n.womenOnlyEveryMemberChecked,
          // "A single post" names the community; with it off the promise is
          // the check itself.
          body: AppRouter.featureFlags.isOn(Feature.community)
              ? l10n.everyAccountIsVerifiedWithIdBefore
              : l10n.everyAccountIsVerifiedWithIdBefore_p7ucu,
        ),
        // Coaches she pays monthly need the coach app, the directory and a
        // payment rail. `payments` sits under `marketplace`, so one check on
        // each end covers all three.
        if (AppRouter.featureFlags.isOn(Feature.coachApp) &&
            AppRouter.featureFlags.isOn(Feature.payments)) ...[
          const HandRule(seed: 33, height: 8),
          _Promise(
            icon: Icons.sports_gymnastics,
            title: l10n.coachesWhoGetIt,
            body: l10n.verifiedWomenCoachesPaidMonthlyInEgyptian,
          ),
        ],
      ],
    );
  }
}

class _Promise extends StatelessWidget {
  const _Promise({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 26, color: AppColors.primaryDim),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppText.titleM),
              const SizedBox(height: 2),
              Text(
                body,
                style: AppText.bodyM.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
