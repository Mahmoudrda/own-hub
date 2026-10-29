/// "Why stay in Own Hub": four plain reasons, on My coach and in the join
/// sheet. Copy only.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_card.dart';

class WhyStayNote extends StatelessWidget {
  const WhyStayNote({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return AppCard(
      key: const ValueKey('why-stay-note'),
      variant: AppCardVariant.tonal,
      gap: 6,
      children: [
        Semantics(
          header: true,
          child: Text(l10n.whyStayInOwnHub, style: AppText.titleM),
        ),
        for (final point in [
          l10n.yourPlansStayHereWithEverythingYou,
          l10n.yourChatWithYourCoachIsPrivate,
          l10n.ownHubNeverShowsYourNumberTo,
          l10n.ownHubStaffAreHereToHelp,
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
