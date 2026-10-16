/// The one-tap log control, matching `logBtn()` in `6-v2/src/kit.mjs`.
///
/// It exists as its own widget rather than as a small [AppButton] because it
/// carries a rule: a tap on this saves immediately and offers five seconds to
/// undo (§2 rule 9). It never opens a dialog, never asks "are you sure", and
/// never leads to a second screen to confirm what the label already said.
///
/// Height is a 44 minimum rather than a fixed 44: it is tapped one-handed,
/// mid-set, and it must not shrink below the minimum target at any text size.
library;

import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import 'hand/hand.dart';

class AppLogButton extends StatelessWidget {
  const AppLogButton(
    this.label, {
    super.key,
    this.onPressed,
    this.primary = false,
  });

  final String label;
  final VoidCallback? onPressed;

  /// The likeliest answer on the screen. One per list, so the eye lands on it.
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final foreground = primary
        ? AppColors.onActionPrimary
        : AppColors.primaryDim;

    // The likeliest answer is printed and set off-register like the primary
    // button; the others are blush slips, pressed into the page when tapped.
    return HandSurface(
      seed: handSeed(['log', label]),
      fill: primary ? AppColors.actionPrimary : AppColors.primarySoft,
      pressedFill: primary ? AppColors.actionPressed : null,
      offsetOutline: primary ? AppColors.primaryDim : null,
      frame: primary ? null : AppColors.primary.withValues(alpha: 0.35),
      frameWidth: 1.1,
      offset: const Offset(2.5, 2.5),
      radius: 6,
      looseCorner: 13,
      onTap: onPressed,
      pressable: true,
      semanticsButton: true,
      pressScale: 0.96,
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppText.label.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: foreground,
          ),
        ),
      ),
    );
  }
}
