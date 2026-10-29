/// A package the way a member reads it.
library;

import 'package:flutter/material.dart';

import '../../../../domain/format/number_label.dart';
import '../../../../l10n/app_l10n.dart';
import '../../../../theme/app_tokens.dart';
import '../../../../ui/app_card.dart';
import '../../../../ui/app_pill.dart';
import '../../domain/coach_profile.dart';

class PackagePreviewCard extends StatelessWidget {
  const PackagePreviewCard(this.package, {super.key});

  final CoachPackage package;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final facts = <String>[
      l10n.countPluralOneCountLiveOneTo(package.liveSessionsPerMonth),
      l10n.daysPluralOne1DayOtherDays(package.durationDays),
      l10n.countMin(countLabel(package.sessionMinutes)),
    ].join(' · ');
    return AppCard(
      children: [
        Text(package.title, style: AppText.titleL),
        Text(
          facts,
          style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
        ),
        if (package.description.isNotEmpty)
          Text(package.description, style: AppText.body),
        for (final line in package.includes)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 3),
                child: Icon(Icons.check, size: 18, color: AppColors.tertiary),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(line, style: AppText.body)),
            ],
          ),
        if (package.priceFinalEgp > 0)
          Text(
            l10n.membersSeeEgpPrice(countLabel(package.priceFinalEgp)),
            style: AppText.titleM,
          ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: AppPill(l10n.askToJoin),
        ),
      ],
    );
  }
}
