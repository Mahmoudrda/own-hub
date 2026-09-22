/// **M12 — the follow-up thread.** One post, several moments, one woman.
///
/// Matches `screens-community.mjs` → `M12`. The design note is the rule this
/// whole feature exists for:
///
/// > *"It gives the feed the transformation content it wants without ever
/// > putting two different women side by side, which is the comparison this
/// > product exists to avoid."*
///
/// ## Two women cannot be rendered here, by construction
///
/// [FollowUpThreadView] takes a [FollowUpThreadModel], which is built from a
/// `FollowUpChain` — and a chain whose moments name two authors **throws at
/// construction**. So `P0-COM-05` is not enforced by a check in this widget; it
/// is enforced by the widget being unable to accept the input that would break
/// it.
///
/// ## Missing copy
///
/// The strip's labels want a parameterised *"Week {n}"*; the dictionary carries
/// only fixed `Week 1` / `Week 4`, which would state the prototype's weeks as
/// hers. So each moment draws its **real** week number through `countLabel`, and
/// the last one reads `now`. The screen title in the prototype is likewise a
/// baked sample ("Eight weeks"), so it is left empty and reported.
library;

import '../../../ui/screen_art_strip.dart';

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_nav_bar.dart';
import '../../../ui/app_sage_note.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/hand/hand.dart';
import 'community_widgets.dart';
import 'create_view_model.dart';
import 'feed_view_model.dart';

class FollowUpThreadView extends StatelessWidget {
  const FollowUpThreadView({
    super.key,
    required this.model,
    required this.post,
    this.onBack,
    this.onMore,
    this.onLike,
    this.onSave,
    this.onOpenProfile,
    this.onSelectTab,
  });

  /// The chain. Cannot hold two authors — see the library comment.
  final FollowUpThreadModel model;

  /// The post card the chain belongs to.
  final PostCardModel post;

  final VoidCallback? onBack;
  final VoidCallback? onMore;
  final VoidCallback? onLike;
  final VoidCallback? onSave;
  final ValueChanged<String>? onOpenProfile;
  final ValueChanged<String>? onSelectTab;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return PaperPage(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        // The prototype's title is a baked sample, so there is none here.
        appBar: AppTopBar(
          onBack: onBack,
          actions: [
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
        body: ListView(
          padding: const EdgeInsets.only(bottom: 16),
          children: [
            const SizedBox(height: 4),
            const ScreenArtStrip(size: 80),
            const SizedBox(height: 8),
            PostHeader(
              post: post,
              followLabel: l10n.follow,
              followingLabel: l10n.following,
              onOpenProfile: () => onOpenProfile?.call(post.authorUid),
              onMore: onMore,
            ),
            const SizedBox(height: 9),

            // Week 1 → Week 4 → Now, all one woman.
            SizedBox(
              height: 160,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                itemCount: model.moments.length,
                separatorBuilder: (_, _) => const SizedBox(width: 9),
                itemBuilder: (context, i) => _Moment(
                  moment: model.moments[i],
                  nowLabel: l10n.now,
                  blurredLabel: l10n.facesBlurred,
                ),
              ),
            ),

            const SizedBox(height: 9),
            // Named, the way `M01`, `M02` and `M05` name them: a heart with a
            // count beside it reads as "0" to a screen reader and nothing
            // else.
            PostActionBar(
              post: post,
              onLike: onLike,
              onSave: onSave,
              likeLabel: l10n.like,
              saveLabel: l10n.save,
            ),

            if (post.caption.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
                child: Text(post.caption, style: AppText.body),
              ),

            // "What it cost her" — sessions and counted weeks, no weight shown.
            if (model.showsCost)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                child: AppCard(
                  variant: AppCardVariant.amber,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.emoji_events_outlined,
                          size: 22,
                          color: AppColors.amber,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l10n.whatItCostHer, style: AppText.titleM),
                              const SizedBox(height: 2),
                              Text(
                                '${model.sessionsLabel} · '
                                '${model.countedWeeksLabel}',
                                style: AppText.bodyM.copyWith(
                                  color: AppColors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: AppSageNote(l10n.aFollowUpStaysOnTheFirst),
            ),
          ],
        ),
      ),
    );
  }
}

class _Moment extends StatelessWidget {
  const _Moment({
    required this.moment,
    required this.nowLabel,
    required this.blurredLabel,
  });

  final FollowUpMomentModel moment;
  final String nowLabel;
  final String blurredLabel;

  @override
  Widget build(BuildContext context) {
    // Her real week, not the mockup's. "Week {n}" has no parameterised form,
    // so the number stands alone.
    final label = Text(
      moment.isNow ? nowLabel : moment.weekLabel,
      style: AppText.label.copyWith(color: AppColors.onSurfaceVariant),
    );
    return SizedBox(
      width: 112,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Room above and beside the label for the loop round "now".
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 7, top: 4),
            // The latest moment is ringed: where she is, against where she
            // started. The earlier weeks stay plain print.
            child: moment.isNow
                ? HandCircled(
                    level: HandLevel.crafted,
                    width: 1.2,
                    color: AppColors.primaryDim,
                    inflate: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    child: label,
                  )
                : label,
          ),
          const SizedBox(height: 5),
          const BlurredShot(height: 128, width: 112),
        ],
      ),
    );
  }
}
