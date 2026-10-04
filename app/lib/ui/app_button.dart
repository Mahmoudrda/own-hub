/// Buttons, matching `btn()` in `6-v2/src/kit.mjs` exactly.
///
/// Five variants, one default height of 56, label at 17. The numbers are the
/// prototype's; they live here once so a change reaches every screen.
///
/// Every button meets a 44pt minimum tap target even when its visual height is
/// smaller — a text button at 48 is already fine, but the floor is enforced
/// rather than assumed, because this product is tapped mid-set with one hand.
///
/// ## How they are drawn
///
/// The filled variants are printed blocks with their outline set a few pixels
/// off-register. A press pushes the block onto its outline — it goes *into*
/// the page, which is what a press on paper would do — and the offset closes.
/// `outlined` is framed in ink by hand; `text` is a word underlined in pen.
/// None of them is a pill: this page is cut, not moulded.
library;

import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import 'hand/hand.dart';

enum AppButtonVariant {
  /// The primary action. One per screen.
  filled,

  /// A secondary action of equal weight.
  tonal,

  /// Used where the action is restorative rather than driving — "take a rest
  /// week". Sage, not pink.
  sage,

  /// Bordered. For a real alternative that should not compete with `filled`.
  outlined,

  /// Lowest weight. Never for a destructive action.
  text,
}

class AppButton extends StatelessWidget implements HandSeedName {
  @override
  String get handSeedName => 'AppButton';

  const AppButton(
    this.label, {
    super.key,
    this.onPressed,
    this.variant = AppButtonVariant.filled,
    this.height = 56,
    this.fontSize = 17,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final double height;
  final double fontSize;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final (fill, foreground, outline, frame) = switch (variant) {
      AppButtonVariant.filled => (
        AppColors.primary,
        AppColors.onPrimary,
        AppColors.primaryDim,
        null,
      ),
      AppButtonVariant.tonal => (
        AppColors.primaryContainer,
        AppColors.onPrimaryContainer,
        AppColors.primary,
        null,
      ),
      AppButtonVariant.sage => (
        AppColors.tertiary,
        AppColors.onTertiary,
        AppColors.onTertiaryContainer,
        null,
      ),
      AppButtonVariant.outlined => (
        null,
        AppColors.onSurface,
        null,
        AppColors.onSurface.withValues(alpha: 0.72),
      ),
      AppButtonVariant.text => (null, AppColors.primaryDim, null, null),
    };

    Widget label = Text(
      this.label,
      textAlign: TextAlign.center,
      style: AppText.label.copyWith(
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
        color: foreground,
      ),
    );
    if (variant == AppButtonVariant.text) {
      label = HandUnderline(
        level: HandLevel.crafted,
        width: 1.2,
        color: AppColors.primaryDim.withValues(alpha: 0.8),
        gap: 1,
        child: label,
      );
    }

    final content = icon == null
        ? label
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: foreground),
              const SizedBox(width: 8),
              Flexible(child: label),
            ],
          );

    return ConstrainedBox(
      // The visual height may be less than 44; the tap target never is.
      constraints: BoxConstraints(minHeight: height < 44 ? 44 : height),
      child: HandSurface(
        seed: handSeed(['btn', this.label, variant.index]),
        fill: fill,
        frame: frame,
        frameWidth: 1.2,
        offsetOutline: outline,
        offset: const Offset(3, 3),
        level: HandLevel.crafted,
        radius: 7,
        looseCorner: 15,
        onTap: onPressed,
        pressable: true,
        semanticsButton: true,
        pressScale: 0.97,
        // A floor, not a fixed height: at the largest text size a label that
        // wraps grows the button instead of overflowing it.
        child: Container(
          constraints: BoxConstraints(minHeight: height),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: content,
        ),
      ),
    );
  }
}
