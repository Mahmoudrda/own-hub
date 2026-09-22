/// **M15 — Saved.**
///
/// Matches `screens-community.mjs` → `M15`. The design note: *"Saved posts are
/// collections only she can see, which is how women actually use saving on
/// Instagram — as a private library, not a public signal."*
///
/// ## A deleted post becomes a tile that says so
///
/// `P0-COM-18`: *"It disappears from every surface on the next load, including
/// the saved grid which shows the not-available tile."* The thumbnail is
/// denormalised onto `users/{uid}/saved/{postId}`, so the grid costs **no post
/// reads** — and when the post is deleted the thumbnail goes with it and
/// [ProfileTileModel.available] is false. The tile renders as unavailable rather
/// than as a broken image.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_chip_row.dart';
import '../../../ui/app_nav_bar.dart';
import '../../../ui/app_scaffold.dart';
import 'community_widgets.dart';
import 'profile_view_model.dart';

class SavedView extends StatelessWidget {
  const SavedView({
    super.key,
    required this.model,
    this.selectedFilter = 0,
    this.onBack,
    this.onSelectFilter,
    this.onOpenPost,
    this.onSelectTab,
  });

  final SavedScreenModel model;
  final int selectedFilter;
  final VoidCallback? onBack;
  final ValueChanged<int>? onSelectFilter;
  final ValueChanged<String>? onOpenPost;
  final ValueChanged<String>? onSelectTab;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppTopBar(title: l10n.saved, onBack: onBack),
      bottomNavigationBar: AppNavBar(
        activeScreenId: 'M01',
        onSelect: onSelectTab,
      ),
      body: AppScaffold(
        children: [
          AppChipRow(
            items: <String>[l10n.all, l10n.quietMoves, l10n.meals],
            selected: <int>{selectedFilter},
            grow: false,
            onTap: onSelectFilter,
          ),
          if (model.isEmpty)
            Text(l10n.nothingSavedYet, style: AppText.titleM)
          else
            CommunityGrid(
              tiles: model.tiles,
              onOpen: (tile) => onOpenPost?.call(tile.postId),
            ),
          // Only she can see any of this. It is stated because a private
          // library is only reassuring if she knows it is private.
          Text(
            l10n.onlyYouCanSeeWhatYouSaved,
            style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
