/// **M03 — Create.**
///
/// Matches `screens-community.mjs` → `M03`. The design note: *"Creating is
/// camera-first … and the blur switch is visible before anything is chosen."*
///
/// ## What this screen offers is decided by flags, not by this file
///
/// The launch scope is photos and text. The Reel tile and the voice-note row
/// are **deferred**, and both are absent because [CreateOptionsModel] asked
/// `FeatureFlags` — not because they were deleted. That distinction is the
/// whole point of shipping dark: when `communityVideo` is switched on, the tile
/// returns with no code change.
///
/// The follow-up tile is different again. It is in the launch scope, but it
/// needs a post to attach to, so it appears only once she has one — and until
/// then the screen says so with `onceYouHaveAPostToFollow` rather than offering
/// an action that cannot succeed.
///
/// ## The blur switch is on, and says so before anything is chosen
///
/// Rule 6. `onBeforeYouAskTapToShow` — *"On before you ask. Tap to show
/// yours."* The switch is rendered at the point she is deciding what to make,
/// which is the moment the promise means something.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_list_item.dart';
import '../../../ui/app_nav_bar.dart';
import '../../../ui/app_sage_note.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/app_toggle.dart';
import '../../../ui/hand/hand.dart';
import 'create_view_model.dart';

class CreateView extends StatelessWidget {
  const CreateView({
    super.key,
    required this.model,
    this.onClose,
    this.onOpenRecord,
    this.onWritePost,
    this.onOpenFollowUp,
    this.onOpenPhotoPost,
    this.onOpenPersonalBest,
    this.onOpenVoiceNote,
    this.onToggleBlur,
    this.onSelectTab,
  });

  final CreateOptionsModel model;
  final VoidCallback? onClose;
  final VoidCallback? onOpenRecord;

  /// Opens the text composer. The launch scope is photos **and text**, and
  /// text is the half this build can actually make — there is no camera in it.
  final VoidCallback? onWritePost;

  final VoidCallback? onOpenFollowUp;
  final VoidCallback? onOpenPhotoPost;
  final VoidCallback? onOpenPersonalBest;
  final VoidCallback? onOpenVoiceNote;
  final ValueChanged<bool>? onToggleBlur;
  final ValueChanged<String>? onSelectTab;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppTopBar(
        title: l10n.create,
        onBack: onClose,
        leadingIcon: Icons.close,
      ),
      bottomNavigationBar: AppNavBar(
        activeScreenId: 'M01',
        onSelect: onSelectTab,
      ),
      body: AppScaffold(
        children: [
          // The two big tiles, when they are offered at all.
          if (model.offers(CreateOption.reel) ||
              model.offers(CreateOption.followUp))
            Row(
              children: [
                if (model.offers(CreateOption.reel))
                  Expanded(
                    child: _Tile(
                      icon: Icons.videocam_outlined,
                      label: l10n.reel,
                      onTap: onOpenRecord,
                    ),
                  ),
                if (model.offers(CreateOption.reel) &&
                    model.offers(CreateOption.followUp))
                  const SizedBox(width: 10),
                if (model.offers(CreateOption.followUp))
                  Expanded(
                    child: _Tile(
                      icon: Icons.history,
                      label: l10n.followUp,
                      onTap: onOpenFollowUp,
                    ),
                  ),
              ],
            ),

          // Words, with no picture. The other half of the launch scope, and
          // the half that works without a camera — so it is offered first.
          if (model.offers(CreateOption.photoOrPost))
            AppListItem(
              leading: const Icon(
                Icons.edit_outlined,
                size: 23,
                color: AppColors.primaryDim,
              ),
              title: l10n.writeAPost,
              trailing: const Icon(
                Icons.chevron_right,
                size: 21,
                color: AppColors.onSurfaceVariant,
              ),
              onTap: onWritePost,
            ),

          if (model.offers(CreateOption.photoOrPost))
            AppListItem(
              leading: const Icon(
                Icons.image_outlined,
                size: 23,
                color: AppColors.primaryDim,
              ),
              title: l10n.photoOrPost,
              subtitle: l10n.facesBlurredBeforeItUploads,
              trailing: const Icon(
                Icons.chevron_right,
                size: 21,
                color: AppColors.onSurfaceVariant,
              ),
              onTap: onOpenPhotoPost,
            ),

          if (model.offers(CreateOption.personalBest))
            AppListItem(
              leading: const Icon(
                Icons.emoji_events_outlined,
                size: 23,
                color: AppColors.amber,
              ),
              title: l10n.aPersonalBest,
              // Numbers she lifted, never a scale weight. There is no field on
              // the payload that could carry one.
              subtitle: l10n.numbersOnlyNeverAWeightFromThe_1oov4,
              trailing: const Icon(
                Icons.chevron_right,
                size: 21,
                color: AppColors.onSurfaceVariant,
              ),
              onTap: onOpenPersonalBest,
            ),

          if (model.offers(CreateOption.voiceNote))
            AppListItem(
              leading: const Icon(
                Icons.mic_none,
                size: 23,
                color: AppColors.primaryDim,
              ),
              title: l10n.aVoiceNote,
              subtitle: l10n.upToAMinuteForTheGroup,
              trailing: const Icon(
                Icons.chevron_right,
                size: 21,
                color: AppColors.onSurfaceVariant,
              ),
              onTap: onOpenVoiceNote,
            ),

          // She has nothing to follow up on yet. An explanation beats a tile
          // that would fail.
          if (model.explainsFollowUpLater)
            AppListItem(
              leading: const Icon(
                Icons.history,
                size: 23,
                color: AppColors.onSurfaceVariant,
              ),
              title: l10n.addAFollowUp,
              subtitle: l10n.onceYouHaveAPostToFollow,
            ),

          // Rule 6, made visible before anything is chosen.
          AppCard(
            variant: AppCardVariant.tonal,
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.blur_on,
                    size: 23,
                    color: AppColors.primaryDim,
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.facesBlurred, style: AppText.titleM),
                        const SizedBox(height: 2),
                        Text(
                          l10n.onBeforeYouAskTapToShow,
                          style: AppText.bodyM.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AppToggle(
                    value: model.blurOn,
                    onChanged: onToggleBlur,
                    semanticLabel: l10n.facesBlurred,
                  ),
                ],
              ),
            ],
          ),

          AppSageNote(l10n.onlyVerifiedWomenCanSeeAnythingYou),
        ],
      ),
    );
  }
}

/// One of the two big camera-first tiles.
class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // Pencil-hatched like the picture placeholders elsewhere: a frame about
    // to hold something she makes, not a menu button.
    return HandSurface(
      seed: handSeed(['create-tile', label]),
      fill: AppColors.surfaceHigh,
      hatch: AppColors.secondary,
      radius: 6,
      looseCorner: 18,
      onTap: onTap,
      semanticsButton: true,
      child: Container(
        height: 126,
        alignment: AlignmentDirectional.bottomStart,
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon, size: 19, color: AppColors.onSurface),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.titleS,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
