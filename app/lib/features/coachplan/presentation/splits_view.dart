/// `K19` — her splits. A week shape written once and used on everybody.
///
/// ## "on 7 clients" is displayed, never an `orderBy`
///
/// r11. `appliedCount` is a stored field the publish Function increments, and
/// it is shown on a card because that is what makes a coach careful about
/// editing one. It is **not** a sort key: `SplitRepository.splits` returns
/// newest-edited first and offers no sort parameter at all, so there is no
/// argument this screen could pass to rank her splits by how many women are on
/// them.
///
/// ## Editing one reaches no published plan
///
/// The note at the top says so, and r12 makes it true by absence rather than
/// by a guard: a split is copied by value into a draft, and no function takes a
/// `splitId` and mutates a plan.
library;

import 'package:flutter/material.dart' hide Split;

import '../../../domain/format/number_label.dart';
import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_list_item.dart';
import '../../../ui/app_pill.dart';
import '../../../ui/app_scaffold.dart';
import '../domain/split/split.dart';
import 'coachplan_widgets.dart';

class SplitsView extends StatelessWidget {
  const SplitsView({
    super.key,
    required this.splits,
    this.onOpenSplit,
    this.onBuildSplit,
    this.onBack,
    this.onTab,
  });

  /// Newest-edited first, as the repository returned them. This screen does
  /// not re-sort.
  final List<Split> splits;

  final ValueChanged<Split>? onOpenSplit;
  final VoidCallback? onBuildSplit;
  final VoidCallback? onBack;
  final ValueChanged<String>? onTab;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return Scaffold(
      backgroundColor: AppColors.surface,
      bottomNavigationBar: CoachPlanNavBar(activeScreenId: 'W01', onTab: onTab),
      appBar: AppTopBar(title: l10n.mySplits, onBack: onBack),
      body: AppScaffold(
        children: [
          Text(
            l10n.aSplitIsAWeekShapeYou,
            style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
          ),
          for (final split in splits)
            AppListItem(
              key: Key('split:${split.splitId}'),
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
              leading: const Icon(
                Icons.repeat,
                size: 22,
                color: AppColors.primaryDim,
              ),
              title: split.name,
              // Her cycle, as a count of days. The dictionary has no "{n}
              // days" form, so the number stands beside the word rather than
              // inside an invented sentence.
              subtitle: '${countLabel(split.cycleLength)} · ${l10n.days}',
              // Displayed. Never a sort key — see the library note.
              trailing: split.isCoachOwned
                  ? AppPill(
                      countLabel(split.appliedCount),
                      background: AppColors.surfaceContainer,
                      foreground: AppColors.onSurfaceVariant,
                    )
                  : null,
              onTap: onOpenSplit == null ? null : () => onOpenSplit!(split),
            ),
          AppCard(
            variant: AppCardVariant.filled,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            onTap: onBuildSplit,
            children: [
              Row(
                children: [
                  const Icon(Icons.add, size: 23, color: AppColors.primaryDim),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      l10n.buildASplit,
                      style: AppText.titleM.copyWith(
                        color: AppColors.primaryDim,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
