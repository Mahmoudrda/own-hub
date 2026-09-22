/// The empty state, matching `nothingYet()` in `6-v2/src/screens-firstrun.mjs`.
///
/// HANDOFF rule 17: **the empty state is the onboarding.** There is no tour, no
/// overlay and no tutorial mode anywhere in this product, so each empty surface
/// has to do that work itself — say what will appear here, why it is empty, and
/// offer the single smallest action that starts it.
///
/// It reads as an explanation rather than a warning, never amber and never an
/// error. Nothing has gone wrong; she is simply new. So it is drawn as the one
/// thing on a printed page that is honestly empty: a dashed pencil box, the
/// space left for her to fill in, with the drawing or icon sitting inside it.
library;

import 'package:flutter/material.dart';

import '../theme/app_art.dart';
import '../theme/app_tokens.dart';
import 'app_list_item.dart' show HandIconRing;
import 'hand/hand.dart';

class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.onTap,
    this.art,
  });

  final IconData icon;

  /// An optional illustration from [AppArt], shown instead of [icon].
  ///
  /// Used only where the subject really is food or training. An empty payout
  /// screen keeps the neutral icon: a drawing above "no earnings yet" is
  /// decoration pretending to be meaning, and rule 17 asks this card to
  /// explain rather than decorate. [icon] stays required, so every caller
  /// keeps an honest fallback.
  final String? art;
  final String title;

  /// What will appear here, and what starts it.
  final String body;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final stacked = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    return HandSurface(
      seed: handSeed(['empty', title]),
      frame: AppColors.outline.withValues(alpha: 0.75),
      frameWidth: 1.1,
      dashed: true,
      radius: 5,
      looseCorner: 18,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 15),
      onTap: onTap,
      // Side by side at ordinary sizes; at a large text size the drawing
      // goes above the words, which would otherwise be squeezed into a
      // column a few words wide.
      child: Flex(
        direction: stacked ? Axis.vertical : Axis.horizontal,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (art != null)
            // Bigger than the icon it replaces: an illustration at 22px is a
            // smudge. Decorative to a screen reader -- the title and body
            // already say what is missing.
            AppArt.image(art!, size: 64)
          else
            HandIconRing(
              icon: Icon(icon, size: 22, color: AppColors.onSurfaceVariant),
              seed: title.hashCode,
              size: 44,
            ),
          SizedBox(width: 12, height: stacked ? 10 : 0),
          Flexible(
            fit: stacked ? FlexFit.loose : FlexFit.tight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: AppText.titleM),
                if (body.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    body,
                    style: AppText.bodyM.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
