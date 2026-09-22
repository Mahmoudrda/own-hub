/// **M11 — Add a follow-up.** The new idea.
///
/// Matches `screens-community.mjs` → `M11`. The design note: *"Instead of
/// posting a fresh before-and-after, she attaches a picture to a post she
/// already made, so the pair is always her own two moments."*
///
/// ## Only her own posts appear, and that is decided in domain
///
/// The candidate list comes from [FollowUpComposerModel], which filters through
/// [FollowUpPolicy] — not through a `where` written in this file. `P0-COM-04`
/// requires the action to be *"not offered in the UI"* **and** refused by the
/// security rules, and this is the first half. The second half is a `get()` on
/// the parent in `firestore.rules`, because a domain check alone is a
/// client-side check.
///
/// ## Blur applies to both frames
///
/// Including the old one. `facesBlurredInBoth` / `onByDefaultOnTheOldOne`.
///
/// ## What it cost her is two integers
///
/// Sessions and counted weeks, and there is no field on [FollowUpCost] a scale
/// weight could occupy. Rule 11, and `P1-COM-02` greps for exactly this.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_field.dart';
import '../../../ui/app_list_item.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/app_toggle.dart';
import 'community_widgets.dart';
import 'create_view_model.dart';

class FollowUpComposerView extends StatelessWidget {
  const FollowUpComposerView({
    super.key,
    required this.model,
    this.onClose,
    this.onSelectParent,
    this.onCaptionChanged,
    this.onToggleBlur,
    this.onToggleCost,
    this.onPost,
  });

  final FollowUpComposerModel model;
  final VoidCallback? onClose;
  final ValueChanged<String>? onSelectParent;
  final ValueChanged<String>? onCaptionChanged;
  final ValueChanged<bool>? onToggleBlur;
  final ValueChanged<bool>? onToggleCost;
  final VoidCallback? onPost;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppTopBar(
        title: l10n.addAFollowUp,
        onBack: onClose,
        leadingIcon: Icons.close,
      ),
      body: AppScaffold(
        footer: [
          AppButton(
            l10n.postTheFollowUp,
            // Publishing has no dialog and a five-second undo. Disabled only
            // while there is genuinely no parent to attach to.
            onPressed: model.canPost ? onPost : null,
          ),
        ],
        children: [
          Text(
            l10n.pickThePostYouAreFollowingUp,
            style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
          ),

          // Her own posts only. A post that is already a follow-up is absent
          // too — a chain is one level deep.
          for (final candidate in model.candidates)
            AppListItem(
              variant: candidate.selected
                  ? AppCardVariant.selected
                  : AppCardVariant.outlined,
              leading: const BlurredShot(
                height: 56,
                width: 56,
                borderRadius: AppRadius.sm,
              ),
              title: candidate.caption,
              trailing: candidate.selected
                  ? const Icon(
                      Icons.check_circle,
                      size: 23,
                      color: AppColors.primary,
                    )
                  : null,
              onTap: () => onSelectParent?.call(candidate.postId),
            ),

          if (model.canPost) ...[
            // Then and now — her own two moments, side by side.
            Row(
              children: const [
                Expanded(child: BlurredShot(height: 128)),
                SizedBox(width: 9),
                Expanded(child: BlurredShot(height: 128)),
              ],
            ),

            AppField(label: l10n.sayWhatChanged, onChanged: onCaptionChanged),

            _SwitchCard(
              icon: Icons.blur_on,
              iconColour: AppColors.primaryDim,
              title: l10n.facesBlurredInBoth,
              subtitle: l10n.onByDefaultOnTheOldOne,
              value: model.blurBothFrames,
              onChanged: onToggleBlur,
              variant: AppCardVariant.tonal,
            ),

            _SwitchCard(
              icon: Icons.emoji_events_outlined,
              iconColour: AppColors.amber,
              title: l10n.addWhatItCostYou,
              // Two integers, rendered from her own counters. Never a weight —
              // there is no field for one.
              subtitle: model.sessionsLabel == null
                  ? ''
                  : '${model.sessionsLabel} · ${model.countedWeeksLabel}',
              value: model.cost != null,
              onChanged: onToggleCost,
              variant: AppCardVariant.amber,
            ),
          ],
        ],
      ),
    );
  }
}

class _SwitchCard extends StatelessWidget {
  const _SwitchCard({
    required this.icon,
    required this.iconColour,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.variant,
    this.onChanged,
  });

  final IconData icon;
  final Color iconColour;
  final String title;
  final String subtitle;
  final bool value;
  final AppCardVariant variant;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      variant: variant,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      children: [
        Row(
          children: [
            Icon(icon, size: 22, color: iconColour),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppText.titleM),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppText.bodyM.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            AppToggle(value: value, onChanged: onChanged, semanticLabel: title),
          ],
        ),
      ],
    );
  }
}
