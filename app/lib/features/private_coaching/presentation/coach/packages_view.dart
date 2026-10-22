/// Her packages: up to six, each with her own price. Tap one to edit it.
library;

import 'package:flutter/material.dart';

import '../../../../domain/format/number_label.dart';
import '../../../../l10n/app_l10n.dart';
import '../../../../theme/app_tokens.dart';
import '../../../../ui/app_button.dart';
import '../../../../ui/app_empty_state.dart';
import '../../../../ui/app_list_item.dart';
import '../../../../ui/app_pill.dart';
import '../../../../ui/app_sage_note.dart';
import '../../../../ui/app_scaffold.dart';
import '../../domain/coach_profile.dart';
import '../../domain/coaching_contract.dart';
import '../member/coach_labels.dart';
import 'coach_data.dart';
import 'coach_widgets.dart';
import 'package_edit_view.dart';

class PackagesView extends StatelessWidget {
  const PackagesView({super.key, required this.data});

  final CoachSpaceData data;

  void _open(BuildContext context, CoachPackage? package) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => PackageEditView(data: data, package: package),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return AppScaffold(
      showArt: false,
      appBar: AppTopBar(
        title: l10n.myPackages,
        onBack: () => Navigator.of(context).maybePop(),
      ),
      children: [
        CoachDataGate(
          data: data,
          builder: (context) {
            final packages = <CoachPackage>[...data.packages]
              ..sort((a, b) => a.order.compareTo(b.order));
            final full = packages.length >= CoachingLimits.maxPackages;
            final anyOn = packages.any((p) => p.active);
            return <Widget>[
              if (packages.isEmpty)
                AppEmptyState(
                  icon: Icons.inventory_2_outlined,
                  title: l10n.noPackagesYet,
                  body: l10n.startFromATemplateThenSetYour,
                )
              else ...[
                Text(
                  l10n.countOf6Packages(countLabel(packages.length)),
                  style: AppText.bodyM.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                if (!anyOn) AppSageNote(l10n.turnOnAtLeastOnePackageTo),
                for (final p in packages)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AppListItem(
                      variant: AppCardVariant.filled,
                      title: p.title,
                      subtitle: [
                        l10n.membersSeeEgpPrice(countLabel(p.priceFinalEgp)),
                        l10n.daysPluralOne1DayOtherDays(p.durationDays),
                        if (!coachingPaymentsOn)
                          l10n.freeForMembersUntilPaymentsOpen,
                      ].join(' · '),
                      trailing: AppPill(
                        p.active ? l10n.onForMembers : l10n.off,
                        background: p.active
                            ? AppColors.tertiaryContainer
                            : AppColors.surfaceHighest,
                        foreground: p.active
                            ? AppColors.onTertiaryContainer
                            : AppColors.onSurfaceVariant,
                      ),
                      onTap: () => _open(context, p),
                    ),
                  ),
              ],
              if (full)
                Text(
                  l10n.youHaveAllCountPackages('${CoachingLimits.maxPackages}'),
                  style: AppText.bodyM,
                )
              else
                AppButton(
                  l10n.addAPackage,
                  icon: Icons.add,
                  onPressed: () => _open(context, null),
                ),
            ];
          },
        ),
      ],
    );
  }
}
