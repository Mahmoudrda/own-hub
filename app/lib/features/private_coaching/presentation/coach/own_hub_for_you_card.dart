/// "What Own Hub does for you", in the coach space. Copy only.
library;

import 'package:flutter/material.dart';

import '../../../../l10n/app_l10n.dart';
import '../../../../theme/app_tokens.dart';
import '../../../../ui/app_card.dart';

class OwnHubForYouCard extends StatelessWidget {
  const OwnHubForYouCard({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return AppCard(
      key: const ValueKey('own-hub-for-you'),
      variant: AppCardVariant.tonal,
      gap: 6,
      children: [
        Semantics(
          header: true,
          child: Text(l10n.whatOwnHubDoesForYou, style: AppText.titleL),
        ),
        for (final point in [
          l10n.clientsFindYouInFindACoach,
          l10n.plansChatAndCheckInsLiveIn,
          l10n.contactDetailsStayProtectedYoursAndYour,
          l10n.ownHubStaffAreThereWhenYou,
          l10n.disagreementsAreHandledFairlyWithBothSides,
        ])
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsetsDirectional.only(top: 2, end: 10),
                child: Icon(Icons.check, size: 18, color: AppColors.primary),
              ),
              Expanded(child: Text(point, style: AppText.bodyM)),
            ],
          ),
      ],
    );
  }
}
