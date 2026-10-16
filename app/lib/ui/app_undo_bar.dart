/// The confirmation that is not a confirmation — `snackbar()` in
/// `6-v2/src/kit.mjs`.
///
/// §2 rule 9: logging saves immediately and offers five seconds to take it back.
/// This bar is the visible half of that rule; [LogCommandBus] is the half that
/// makes it true. Note what is absent — there is no "are you sure", no Cancel,
/// and no way to pass this widget a dialog.
///
/// It is drawn **in the page**, not raised as a Material `SnackBar`, because the
/// prototype places it inline above the content and because a floating snackbar
/// would sit over the rest timer it is announcing.
///
/// The text must name the same numbers the button named. If the button said
/// "12 kg × 10", this says "12 kg × 10" — a woman should never have to wonder
/// what she just agreed to.
///
/// A tick is drawn on beside the words (D48): every completed action gets a
/// response she can see.
library;

import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import 'hand/hand.dart';

class AppUndoBar extends StatelessWidget {
  const AppUndoBar({
    super.key,
    required this.message,
    required this.undoLabel,
    this.onUndo,
  });

  /// What was saved, in her numbers.
  final String message;

  final String undoLabel;

  /// Null once the five-second window has closed. The bar then reads as a plain
  /// statement of what was saved, which is honest: there is no longer anything
  /// to undo, and offering a button that does nothing is worse than offering none.
  final VoidCallback? onUndo;

  @override
  Widget build(BuildContext context) {
    return HandSurface(
      seed: handSeed(['undo', message]),
      fill: AppColors.inverseSurface,
      radius: 5,
      looseCorner: 14,
      padding: const EdgeInsetsDirectional.fromSTEB(18, 8, 8, 8),
      child: Row(
        children: [
          // The hand draws the tick as the bar arrives: the save is seen as
          // well as read. Instant under reduced motion.
          const HandTick(
            size: 18,
            color: AppColors.primaryContainer,
            drawOn: true,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AppText.bodyM.copyWith(color: AppColors.inverseOnSurface),
            ),
          ),
          if (onUndo != null) ...[
            const SizedBox(width: 12),
            // The way back, underlined by hand in blush on the dark bar.
            HandPressable(
              onTap: onUndo,
              scale: 0.95,
              borderRadius: BorderRadius.circular(6),
              builder: (context, _) => Container(
                constraints: const BoxConstraints(minHeight: 44),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.center,
                child: HandUnderline(
                  color: AppColors.primaryContainer,
                  level: HandLevel.crafted,
                  width: 1.3,
                  gap: 1,
                  child: Text(
                    undoLabel,
                    style: AppText.label.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.inverseOnSurface,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
