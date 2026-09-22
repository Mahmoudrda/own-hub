/// **M04 — Groups.**
///
/// Matches `screens-community.mjs` → `M04`. The design note: *"Groups are built
/// around situations rather than interests: beginners, postpartum, Ramadan,
/// city. Suggested groups say why they were suggested and how big they are."*
///
/// ## Joining raises nothing
///
/// Rule 9. Tapping Join joins, and the row flips to Joined. There is no "are you
/// sure", because joining a group is reversible and reversible things get undo
/// rather than confirmation.
///
/// ## The size is shown, and cannot be sorted by
///
/// `memberCount` is rendered through `countLabel` — her real figure in Western
/// digits, never the prototype's. Ordering groups by size is unexecutable in the
/// deployed project because `groups.memberCount` carries a single-field index
/// exemption, and there is no comparator on it anywhere in the Dart either.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_list_item.dart';
import '../../../ui/app_nav_bar.dart';
import '../../../ui/app_scaffold.dart';
import 'groups_view_model.dart';

class GroupsView extends StatelessWidget {
  const GroupsView({
    super.key,
    required this.model,
    this.onBack,
    this.onOpenSearch,
    this.onOpenGroup,
    this.onJoin,
    this.onSelectTab,
  });

  final GroupsScreenModel model;
  final VoidCallback? onBack;
  final VoidCallback? onOpenSearch;
  final ValueChanged<String>? onOpenGroup;
  final ValueChanged<String>? onJoin;
  final ValueChanged<String>? onSelectTab;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppTopBar(
        title: l10n.groups,
        onBack: onBack,
        actions: [
          IconButton(
            onPressed: onOpenSearch,
            tooltip: l10n.search,
            color: AppColors.onSurface,
            icon: const Icon(Icons.search),
          ),
        ],
      ),
      bottomNavigationBar: AppNavBar(
        activeScreenId: 'M01',
        onSelect: onSelectTab,
      ),
      body: AppScaffold(
        children: [
          if (model.yours.isNotEmpty) ...[
            Text(l10n.yours, style: AppText.titleM),
            for (final group in model.yours)
              _GroupRow(
                group: group,
                joinedLabel: l10n.joined,
                joinLabel: l10n.join,
                onOpen: () => onOpenGroup?.call(group.groupId),
                onJoin: () => onJoin?.call(group.groupId),
              ),
          ],
          if (model.suggested.isNotEmpty) ...[
            Text(l10n.suggestedForYou, style: AppText.titleM),
            for (final group in model.suggested)
              _GroupRow(
                group: group,
                joinedLabel: l10n.joined,
                joinLabel: l10n.join,
                onOpen: () => onOpenGroup?.call(group.groupId),
                onJoin: () => onJoin?.call(group.groupId),
              ),
          ],
        ],
      ),
    );
  }
}

class _GroupRow extends StatelessWidget {
  const _GroupRow({
    required this.group,
    required this.joinedLabel,
    required this.joinLabel,
    this.onOpen,
    this.onJoin,
  });

  final GroupRowModel group;
  final String joinedLabel;
  final String joinLabel;
  final VoidCallback? onOpen;
  final VoidCallback? onJoin;

  @override
  Widget build(BuildContext context) {
    return AppListItem(
      leading: const Icon(
        Icons.groups_outlined,
        size: 23,
        color: AppColors.primaryDim,
      ),
      title: group.name,
      // What the room is for, and her real figure once there is one. No
      // dictionary string carries a member count, because every one that does
      // bakes in the prototype's 4,210 — and a room nobody has joined shows no
      // number at all rather than a zero.
      subtitle: group.blurb.isNotEmpty
          ? group.blurb
          : (group.showsMemberCount ? group.memberLabel : ''),
      trailing: group.offersJoin
          // One tap, no dialog.
          ? AppButton(
              joinLabel,
              variant: AppButtonVariant.tonal,
              height: 38,
              fontSize: 14,
              onPressed: onJoin,
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (group.muted)
                  const Padding(
                    padding: EdgeInsetsDirectional.only(end: 6),
                    child: Icon(
                      Icons.do_not_disturb_on_outlined,
                      size: 18,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                Text(
                  joinedLabel,
                  style: AppText.label.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  size: 22,
                  color: AppColors.onSurfaceVariant,
                ),
              ],
            ),
      onTap: onOpen,
    );
  }
}
