/// The `white` button variant from `btn()` in `6-v2/src/kit.mjs`.
///
/// It exists for exactly one situation: a primary action sitting on the dark
/// capture screens, `C10` and `C11`, where every other variant either disappears
/// into `inverseSurface` or drags the product's pink onto a camera viewfinder.
///
/// It is a separate file rather than a sixth value of [AppButtonVariant] because
/// several feature groups are building on `app_button.dart` at once and a shared
/// enum is the worst possible place for two of them to meet. **Fold it into
/// `AppButtonVariant.white` when that work has landed** — the geometry below is
/// copied from [AppButton] and duplicated geometry is exactly the thing
/// `app_button.dart` exists to prevent.
library;

import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import 'hand/hand.dart';

class AppWhiteButton extends StatelessWidget {
  const AppWhiteButton(
    this.label, {
    super.key,
    this.onPressed,
    this.height = 56,
    this.fontSize = 17,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final double height;
  final double fontSize;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    const background = AppColors.surfaceLowest;
    const foreground = AppColors.onSurface;

    final child = Text(
      label,
      textAlign: TextAlign.center,
      style: AppText.label.copyWith(
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
        color: foreground,
      ),
    );

    return ConstrainedBox(
      // The visual height may be less than 44; the tap target never is.
      constraints: BoxConstraints(minHeight: height < 44 ? 44 : height),
      child: HandSurface(
        seed: handSeed(['white', label]),
        fill: background,
        // On the dark capture screens the off-register outline is white too:
        // the only mark that reads on a viewfinder.
        offsetOutline: AppColors.surfaceLowest.withValues(alpha: 0.7),
        frameWidth: 1.2,
        radius: 7,
        looseCorner: 15,
        onTap: onPressed,
        pressable: true,
        semanticsButton: true,
        child: Container(
          constraints: BoxConstraints(minHeight: height),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: icon == null
              ? child
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 20, color: foreground),
                    const SizedBox(width: 8),
                    Flexible(child: child),
                  ],
                ),
        ),
      ),
    );
  }
}
