/// C16 — How we treat each other.
///
/// Matches `6-v2/src/screens-signup.mjs` → `C16`. Three rules, each one
/// sentence, agreed once. The body-comments rule is the one that makes a
/// women-only fitness community survive its first month, which is why it is
/// stated as "not even a compliment" rather than left to good manners.
///
/// Accepting writes `users/{uid}.pledge` — a version and a timestamp, monotonic,
/// which is why the screen reports acceptance rather than performing it. **It is
/// also why accepting offline cannot be an exploit:** the community opens on a
/// server-minted claim, so a queued pledge write grants nothing until the server
/// has seen it. Queue the write, keep the door shut.
library;

import 'package:flutter/material.dart';

import '../../../domain/flags/feature_flags.dart';
import '../../../l10n/app_l10n.dart';
import '../../../routing/app_router.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/hand/hand.dart';

class PledgeView extends StatelessWidget {
  const PledgeView({super.key, this.onAgree, this.onBack});

  /// She has agreed — on to `O01`, where her programme starts.
  final VoidCallback? onAgree;

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return AppScaffold(
      appBar: AppTopBar(onBack: onBack),
      footer: [
        AppButton(l10n.iAgreeLetMeIn, onPressed: onAgree),
        Text(
          l10n.breakOneAndYouLoseYourPlace,
          style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
        ),
      ],
      children: [
        Text(l10n.howWeTreatEachOther, style: AppText.display),
        Text(
          l10n.threeRulesTheyAreTheWholeReason,
          style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
        ),
        // Three clauses set open on the page and ruled apart, as house rules
        // are printed — three identical boxes would read as a form to tick.
        const HandRule(seed: 41, height: 8),
        _Rule(
          title: l10n.n1WhatIsSaidHereStaysHere,
          body: l10n.noScreenshotsNoSharingAnyoneElseOutside,
        ),
        const HandRule(seed: 42, height: 8),
        _Rule(
          title: l10n.n2NoCommentsOnAnyoneElsesBody,
          body: l10n.notEvenAComplimentTalkAboutThe,
        ),
        const HandRule(seed: 43, height: 8),
        _Rule(
          title: l10n.n3NoSellingNoRecruiting,
          // Coach profiles exist only with the coach app.
          body: AppRouter.featureFlags.isOn(Feature.coachApp)
              ? l10n.coachesHaveProfilesForThat
              : l10n.ownHubIsForTrainingNotFor,
        ),
      ],
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: AppText.titleM),
        const SizedBox(height: 4),
        Text(
          body,
          style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
        ),
      ],
    );
  }
}
