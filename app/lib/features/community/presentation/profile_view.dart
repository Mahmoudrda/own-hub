/// **M07 — a member profile.**
///
/// Matches `screens-community.mjs` → `M07`. The design note names the restraint:
/// *"no logs, no weight, no photos she did not choose, and nothing that ranks
/// one woman against another."*
///
/// ## Follower counts do not render
///
/// `Feature.communityFollowerCounts` is off, so [ProfileScreenModel] returns
/// null for both labels and the two stat columns are absent. The screen asks the
/// model rather than deciding for itself, and the model asks the flag — so
/// turning the flag on brings them back with no change here.
///
/// Her **post count** still renders, because it is not a ranking signal and it
/// is hers.
///
/// ## Not available is one rendering for three causes
///
/// A woman who turned her profile off, a woman who blocked her, and a woman who
/// was never there all produce [SurfaceAvailability.notAvailable]. This screen
/// cannot tell them apart, which is exactly the guarantee: nothing anywhere
/// tells her she has been blocked.
///
/// The "Not available" sentence itself is **absent from the dictionary**, so
/// [NotAvailablePanel] draws its icon alone rather than fabricating English.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_avatar.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_nav_bar.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/screen_art_strip.dart';
import '../../../ui/hand/hand.dart';
import '../domain/follow_state.dart';
import 'community_widgets.dart';
import 'profile_view_model.dart';

class ProfileView extends StatelessWidget {
  const ProfileView({
    super.key,
    required this.model,
    this.onBack,
    this.onMore,
    this.onFollow,
    this.onMessage,
    this.onOpenSaved,
    this.onOpenPost,
    this.onSelectTabIndex,
    this.selectedTab = 0,
    this.onSelectTab,
  });

  final ProfileScreenModel model;
  final VoidCallback? onBack;
  final VoidCallback? onMore;
  final VoidCallback? onFollow;
  final VoidCallback? onMessage;
  final VoidCallback? onOpenSaved;
  final ValueChanged<String>? onOpenPost;
  final ValueChanged<int>? onSelectTabIndex;
  final int selectedTab;
  final ValueChanged<String>? onSelectTab;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return PaperPage(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppTopBar(
          title: model.isAvailable ? model.name : '',
          onBack: onBack,
          actions: [
            if (model.isAvailable && !model.isSelf)
              IconButton(
                onPressed: onMore,
                color: AppColors.onSurface,
                icon: const Icon(Icons.more_vert),
              ),
          ],
        ),
        bottomNavigationBar: AppNavBar(
          activeScreenId: 'M01',
          onSelect: onSelectTab,
        ),
        body: !model.isAvailable
            ? const AppScaffold(children: [NotAvailablePanel()])
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                children: [
                  // This screen lays out its own list rather than using
                  // AppScaffold, so it places the page's drawing itself.
                  const ScreenArtStrip(),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppAvatar(firstName: model.name, size: 72, isSelf: false),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _Stat(value: model.postLabel, label: l10n.posts),
                            // Both absent while follower counts are off.
                            if (model.followerLabel != null)
                              _Stat(
                                value: model.followerLabel!,
                                label: l10n.followers,
                              ),
                            if (model.followingLabel != null)
                              _Stat(
                                value: model.followingLabel!,
                                label: l10n.following,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 11),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          model.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.titleM,
                        ),
                      ),
                      if (model.verified) ...[
                        const SizedBox(width: 5),
                        const Icon(
                          Icons.verified,
                          size: 17,
                          color: AppColors.primaryDim,
                        ),
                      ],
                    ],
                  ),
                  if (model.bio.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(model.bio, style: AppText.bodyM),
                  ],
                  const SizedBox(height: 11),
                  Row(
                    children: [
                      if (model.showsFollowButton)
                        Expanded(
                          child: FollowPill(
                            state: model.followState,
                            followLabel: l10n.follow,
                            followingLabel: l10n.following,
                            onTap: onFollow,
                            height: 38,
                          ),
                        ),
                      if (model.showsMessageButton) ...[
                        const SizedBox(width: 8),
                        AppButton(
                          l10n.message,
                          variant: AppButtonVariant.outlined,
                          height: 38,
                          fontSize: 14,
                          onPressed: onMessage,
                        ),
                      ],
                      if (model.isSelf) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: onOpenSaved,
                          tooltip: l10n.saved,
                          color: AppColors.onSurface,
                          icon: const Icon(Icons.bookmark_border),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  // "She chooses what shows here. Logs, weight and photos are
                  // never on a profile."
                  Text(
                    l10n.sheChoosesWhatShowsHereLogsWeight,
                    style: AppText.bodyM.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  // A pencil line under what she wrote about herself; the grid
                  // below is hers too, but it is a different kind of thing.
                  const HandRule(seed: 23, height: 16),
                  _Tabs(
                    tabs: model.tabs,
                    selected: selectedTab,
                    onSelect: onSelectTabIndex,
                    photosLabel: l10n.photos,
                    reelsLabel: l10n.reels,
                    followUpsLabel: l10n.followUp,
                  ),
                  const SizedBox(height: 8),
                  if (model.showsOwnEmptyState)
                    Text(l10n.yourPageIsEmpty, style: AppText.titleM)
                  else
                    CommunityGrid(
                      tiles: model.tiles,
                      onOpen: (tile) => onOpenPost?.call(tile.postId),
                    ),
                ],
              ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: AppText.titleM),
        Text(
          label,
          style: AppText.label.copyWith(color: AppColors.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// The grid's tabs. Reels only exists when video does.
class _Tabs extends StatelessWidget {
  const _Tabs({
    required this.tabs,
    required this.selected,
    required this.photosLabel,
    required this.reelsLabel,
    required this.followUpsLabel,
    this.onSelect,
  });

  final List<ProfileTab> tabs;
  final int selected;
  final String photosLabel;
  final String reelsLabel;
  final String followUpsLabel;
  final ValueChanged<int>? onSelect;

  IconData _icon(ProfileTab tab) => switch (tab) {
    ProfileTab.photos => Icons.photo_library_outlined,
    ProfileTab.reels => Icons.videocam_outlined,
    ProfileTab.followUps => Icons.history,
  };

  String _label(ProfileTab tab) => switch (tab) {
    ProfileTab.photos => photosLabel,
    ProfileTab.reels => reelsLabel,
    ProfileTab.followUps => followUpsLabel,
  };

  /// Space the underline takes, reserved under every tab so the icons stay
  /// on one line whichever is chosen.
  static const double _markRoom = 4 + HandStroke.pen;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < tabs.length; i++)
          Expanded(
            // Which tab is open is drawn in pen, and said in words: the
            // underline is invisible to a screen reader, and colour alone was
            // the only other signal.
            child: Semantics(
              selected: i == selected,
              child: HandPressable(
                onTap: onSelect == null ? null : () => onSelect!(i),
                builder: (_, _) {
                  final icon = Icon(
                    _icon(tabs[i]),
                    size: 22,
                    semanticLabel: _label(tabs[i]),
                    color: i == selected
                        ? AppColors.onSurface
                        : AppColors.onSurfaceVariant,
                  );
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Center(
                      // The chosen tab is underlined in pen, as she would mark
                      // it; colour alone would be the only signal otherwise.
                      child: i == selected
                          ? HandUnderline(
                              seed: 40 + i,
                              level: HandLevel.crafted,
                              width: HandStroke.pen,
                              gap: 4,
                              child: icon,
                            )
                          : Padding(
                              padding: const EdgeInsets.only(bottom: _markRoom),
                              child: icon,
                            ),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}
