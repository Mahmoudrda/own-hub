/// `K18` — her public profile.
///
/// Matches `6-v2/src/screens-coach.mjs` → `K18`.
///
/// # It reads offers; it cannot write one
///
/// This screen is handed a [CoachPublicProfileViewModel], built from an
/// `OfferReader`. There is no write method within reach — `K04` is the single
/// writer, and `B06` is G13's editor for the portfolio block. G12 §9 **Q5**
/// records the failure that avoids: a price edited in one place and stale in the
/// other, on the screen that takes money.
///
/// # Two claims this screen refuses to make up
///
///  * **Her reply time.** `K18`'s own copy says "measured, not typed", and it is
///    a Cloud-Function-computed 30-day rolling p50. Null means we have not
///    measured it, and null renders **no claim** rather than a plausible
///    "about 2 hours".
///  * **Her rating.** Displayed only at five or more reviews
///    ([RatingDisplay]), and there is no minted string for a bare average, so
///    nothing on this screen draws one. A rating is also not a field on her
///    document — a numeric field on a world-readable document is auto-indexed
///    and therefore sortable, which is a ranking of women whatever the code
///    intends (G12 §1.5, §9 Q11).
///
/// # Authored, and not yet public
///
/// A coach still being checked sees everything she has written and an amber
/// line saying none of it is live. Hiding her own work from her would be worse:
/// she wrote it, it is hers, and `K06` promised she could.
library;

import 'package:flutter/material.dart';

import '../../../domain/rewards/stated_figure.dart';
import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_list_item.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/app_split_row.dart';
import '../../../ui/hand/hand.dart';
import 'coach_setup_scaffold.dart';
import 'coach_view_models.dart';

class CoachPublicProfileView extends StatelessWidget {
  const CoachPublicProfileView({
    super.key,
    required this.model,
    this.onBack,
    this.onPreviewAsClient,
    this.onEditBasics,
    this.onDesignPage,
    this.onOpenPackages,
    this.note,
  });

  final CoachPublicProfileViewModel model;

  /// A sentence about how this page came to be visible, when that is not the
  /// ordinary way. The test build's only caller says that nobody checked her
  /// certificates, which is why no badge is drawn above. Null renders nothing.
  final String? note;

  final VoidCallback? onBack;
  final VoidCallback? onPreviewAsClient;
  final VoidCallback? onEditBasics;
  final VoidCallback? onDesignPage;
  final VoidCallback? onOpenPackages;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final profile = model.profile;

    const chevron = Icon(
      Icons.chevron_right,
      size: 22,
      color: AppColors.onSurfaceVariant,
    );

    // The mockup's "12 of 20 taken" is a sentence with one coach's roster
    // baked in. `countOfTotal` is the parameterised form the dictionary
    // already carries, so the row under "Spots" states HER roster — right for
    // every coach instead of only the one on twelve of twenty.
    final spotsLine = l10n.countOfTotal(
      '${profile.capacity.taken}',
      '${profile.capacity.max}',
    );

    // Same treatment for the reply-time claim, which is the screen's own
    // "measured, not typed" promise.
    final replyLine = model.showsReplyTime
        ? statedLine(
            l10n.about2HoursMeasuredNotTyped,
            states: 120,
            hers: model.replyTimeMinutes,
          )
        : null;

    return AppScaffold(
      appBar: AppTopBar(
        title: l10n.yourPublicProfile,
        onBack: () => goToScreen(context, 'K17', onBack),
        actions: [
          IconButton(
            tooltip: l10n.preview,
            color: AppColors.onSurfaceVariant,
            icon: const Icon(Icons.visibility_outlined),
            // `H02` is the client-side coach profile — the real thing, not a
            // preview mode that could drift from it.
            onPressed: () => goToScreen(context, 'H02', onPreviewAsClient),
          ),
        ],
      ),
      children: [
        if (note case final String text)
          AppCard(
            variant: AppCardVariant.amber,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            children: [
              Text(
                text,
                style: AppText.bodyM.copyWith(color: AppColors.onSurface),
              ),
            ],
          ),
        AppCard(
          variant: AppCardVariant.tonal,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.visibility,
                  size: 22,
                  color: AppColors.primaryDim,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.thisIsExactlyWhatAClientSees,
                    style: AppText.bodyM.copyWith(color: AppColors.onSurface),
                  ),
                ),
              ],
            ),
          ],
        ),

        AppSplitRow(
          start: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  profile.photoBlurred ? Icons.blur_on : Icons.person,
                  size: 30,
                  color: AppColors.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Her name in marker, as the client's copy of this page
                  // (`H02`) sets it — this screen is that page, seen by her.
                  MarkerHighlight(
                    child: Text(profile.displayName, style: AppText.titleM),
                  ),
                  if (profile.city.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      profile.city,
                      style: AppText.bodyM.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          end: IconButton(
            tooltip: l10n.edit,
            color: AppColors.onSurfaceVariant,
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => goToScreen(context, 'K01', onEditBasics),
          ),
        ),

        // She may author everything and publish nothing, said where it matters.
        if (!model.isLive)
          AppCard(
            variant: AppCardVariant.amber,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.weAreCheckingYourCertificates,
                    style: AppText.titleM,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.usuallyTheSameDayYouCanBuild,
                    style: AppText.bodyM.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),

        AppListItem(
          variant: AppCardVariant.tonal,
          leading: const Icon(
            Icons.edit,
            size: 22,
            color: AppColors.primaryDim,
          ),
          title: l10n.designYourPage,
          subtitle: l10n.sectionsColoursAndWordsAllYours,
          trailing: chevron,
          onTap: () => goToScreen(context, 'B01', onDesignPage),
        ),

        AppListItem(
          title: l10n.certificates,
          trailing: model.showsVerifiedBadge
              ? const Icon(Icons.verified, size: 22, color: AppColors.tertiary)
              : const Icon(
                  Icons.hourglass_top,
                  size: 22,
                  color: AppColors.amber,
                ),
        ),

        AppListItem(
          title: l10n.packages,
          // Read-only here. `K04` writes them, `B06` arranges them on her page.
          trailing: chevron,
          onTap: () => goToScreen(context, 'B06', onOpenPackages),
        ),

        AppListItem(title: l10n.spots, subtitle: spotsLine),

        AppListItem(
          title: l10n.replyTimeShownToClients,
          subtitle: replyLine ?? '',
        ),
      ],
    );
  }
}
