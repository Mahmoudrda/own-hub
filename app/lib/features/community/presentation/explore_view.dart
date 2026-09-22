/// **M10 — Explore.**
///
/// Matches `screens-community.mjs` → `M10`: a search field, a row of chips, and
/// a mixed grid. The prototype's app bar has **no title**, which is reproduced
/// here rather than filled in — the search field is the heading.
///
/// ## The chips are an enum, never free tags
///
/// A free tag is a search surface and a harassment vector nobody owns, so
/// `topics` is `≤5` values of a fixed enum. Two of the five —
/// `CommunityTopic.beginner` and `CommunityTopic.walking` — had **no label in
/// the dictionary**, and their chips were omitted rather than drawn in invented
/// English. Both words have since been minted, so all five chips are drawn and
/// [topicLabel] still returns null rather than a fallback for any that is not.
///
/// ## Nothing here is ranked
///
/// There is no "trending", no "popular" and no "for you" ordering. `For you` is
/// a chip that clears the filter, not a recommendation: [ExploreQueryFactory]
/// has one ordering and no parameter that could select another.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_chip_row.dart';
import '../../../ui/app_field.dart';
import '../../../ui/app_nav_bar.dart';
import '../../../ui/app_scaffold.dart';
import '../domain/community_models.dart';
import 'community_widgets.dart';
import 'profile_view_model.dart';

/// The chip label, or null when the dictionary has none for this topic.
///
/// Returning null rather than a fallback string is the point: a chip with
/// invented English would bypass the dictionary and show English to an Arabic
/// reader, and no test of the English UI would notice.
String? topicLabel(CommunityTopic topic, AppL10n l10n) => switch (topic) {
  CommunityTopic.postpartum => l10n.postpartum,
  CommunityTopic.quiet => l10n.quiet,
  CommunityTopic.ramadan => l10n.ramadan,
  // Both were unlabelled and both chips were omitted rather than drawn in
  // invented English. The two words are in the dictionary now, so all five
  // topics carry a chip and the grid can be narrowed by any of them.
  CommunityTopic.beginner => l10n.beginners,
  CommunityTopic.walking => l10n.walking,
};

class ExploreView extends StatelessWidget {
  const ExploreView({
    super.key,
    required this.model,
    this.onBack,
    this.onSelectTopic,
    this.onOpenPost,
    this.onSearch,
    this.onSelectTab,
  });

  final ExploreScreenModel model;
  final VoidCallback? onBack;

  /// Null clears the chip.
  final ValueChanged<CommunityTopic?>? onSelectTopic;

  final ValueChanged<String>? onOpenPost;
  final ValueChanged<String>? onSearch;
  final ValueChanged<String>? onSelectTab;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    // "For you" first — it is the cleared state, not a recommendation.
    final labelled = <CommunityTopic>[
      for (final topic in model.chips)
        if (topicLabel(topic, l10n) != null) topic,
    ];
    final items = <String>[
      l10n.forYou,
      for (final topic in labelled) topicLabel(topic, l10n)!,
    ];
    final selectedIndex = model.selectedChip == null
        ? 0
        : labelled.indexOf(model.selectedChip!) + 1;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppTopBar(onBack: onBack),
      bottomNavigationBar: AppNavBar(
        activeScreenId: 'M01',
        onSelect: onSelectTab,
      ),
      body: AppScaffold(
        children: [
          AppField(
            hint: l10n.searchWomenGroupsAndMoves,
            onChanged: onSearch,
            trailing: const Icon(
              Icons.search,
              size: 21,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          AppChipRow(
            items: items,
            selected: <int>{if (selectedIndex >= 0) selectedIndex},
            grow: false,
            onTap: (i) => onSelectTopic?.call(i == 0 ? null : labelled[i - 1]),
          ),
          if (!model.isEmpty)
            CommunityGrid(
              tiles: model.tiles,
              onOpen: (tile) => onOpenPost?.call(tile.postId),
            ),
          // "Nothing matches that" is not in the dictionary. The grid is simply
          // absent, and the chip above remains tappable to clear the filter —
          // which is the one smallest action this empty state wants.
        ],
      ),
    );
  }
}
