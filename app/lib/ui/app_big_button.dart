/// The two-line primary action, matching `bigBtn()` in `6-v2/src/kit.mjs`.
///
/// Exactly one screen in this product needs a button this size: R07, where a
/// woman mid-set taps once to log what she just lifted. It is large because it is
/// tapped with a shaking hand, on a phone on the floor, without reading carefully.
///
/// The label states what will be saved and the sub-line states what happens next
/// ("Rest starts itself"), which is what makes confirming and logging one action
/// instead of two — §2 rule 9.
library;

import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import 'hand/hand.dart';

class AppBigButton extends StatelessWidget {
  const AppBigButton(
    this.label, {
    super.key,
    required this.subtitle,
    this.onPressed,
    this.sage = false,
  });

  final String label;

  /// The second line. Never decorative — it says what the tap causes.
  final String subtitle;

  final VoidCallback? onPressed;

  /// Sage rather than pink, for a restorative action.
  final bool sage;

  @override
  Widget build(BuildContext context) {
    final onColour = sage ? AppColors.onTertiary : AppColors.onActionPrimary;

    // The largest printed block in the product, set off-register like every
    // primary action, and pushed into the page by the tap that logs the set.
    return HandSurface(
      seed: handSeed(['big', label]),
      fill: sage ? AppColors.tertiary : AppColors.actionPrimary,
      pressedFill: sage ? null : AppColors.actionPressed,
      offsetOutline: sage
          ? AppColors.onTertiaryContainer
          : AppColors.primaryDim,
      frameWidth: 1.4,
      offset: const Offset(4, 4),
      radius: 9,
      looseCorner: 24,
      onTap: onPressed,
      pressable: true,
      semanticsButton: true,
      child: Container(
        // The prototype's 84 is a floor, not a fixed height: at the largest
        // system text size two lines need more room, and a clipped primary
        // action is the worst possible thing to clip.
        constraints: const BoxConstraints(minHeight: 84),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              textAlign: TextAlign.center,
              style: AppText.label.copyWith(
                fontSize: 23,
                fontWeight: FontWeight.w600,
                color: onColour,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: AppText.label.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w400,
                color: onColour.withValues(alpha: 0.92),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
