/// A small status pill, matching `pill()` in `6-v2/src/kit.mjs`.
///
/// Carries a fact about the screen rather than an action — her level, which week
/// of a programme she is on, how long the shortest session is. It is never
/// tappable, which is why it is not a chip.
///
/// Drawn as a swipe of marker behind the words rather than a pill: a fact on
/// the page that someone has highlighted, in the colour the caller gives.
///
/// The prototype fixes the height at 34. Here 34 is a *minimum*: at the largest
/// system text size a fixed 34 would clip the label, and a clipped level is a
/// worse outcome than a slightly taller pill.
library;

import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import 'hand/hand.dart';

class AppPill extends StatelessWidget {
  const AppPill(
    this.label, {
    super.key,
    this.background = AppColors.primarySoft,
    this.foreground = AppColors.primaryDim,
    this.icon,
  });

  final String label;
  final Color background;
  final Color foreground;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 34),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: CustomPaint(
          painter: MarkerPainter(
            seed: handSeed(['pill', label]),
            color: background,
            cover: 0.78,
            textDirection: Directionality.of(context),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: foreground),
                  const SizedBox(width: 6),
                ],
                // Flexible so a long label in Arabic shortens instead of
                // overflowing the row it sits in.
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.label.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: foreground,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
