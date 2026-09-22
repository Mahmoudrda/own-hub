/// A bottom sheet, matching `sheet()` in `6-v2/src/kit.mjs`.
///
/// Scrim over the screen, and the sheet as a leaf of paper laid over it: squarer
/// top corners than a stock sheet, and a short pencil stroke for the grab
/// handle so it reads as draggable before she touches it.
///
/// Used for a decision that belongs *to* the screen underneath rather than
/// replacing it — "save this workout?" while she is still looking at the
/// workout. A full page would lose that context, which is the whole point of
/// asking here.
///
/// Note what this is not: it is **not** a confirmation dialog for a log. §2 rule
/// 9 is that logging offers undo and never asks "are you sure", and nothing in
/// the logging path may route through here.
library;

import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import 'hand/hand.dart';

/// Shows [children] in a modal sheet over the current screen.
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required List<Widget> children,
  double gap = 14,
  bool dismissible = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    isDismissible: dismissible,
    enableDrag: dismissible,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.ink.withValues(alpha: 0.45),
    builder: (_) => AppSheet(gap: gap, children: children),
  );
}

class AppSheet extends StatelessWidget {
  const AppSheet({super.key, required this.children, this.gap = 14});

  final List<Widget> children;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.surfaceLowest,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(14),
          topRight: Radius.circular(22),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: SafeArea(
        top: false,
        // Scrolls once it is taller than the screen: at the largest text size
        // a sheet's options can outgrow the phone, and a fixed column would
        // cut the last of them off.
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // The grab handle. Centred, and not stretched by the column.
              const Center(
                child: SizedBox(
                  width: 40,
                  child: HandRule(
                    seed: 23,
                    height: 6,
                    level: HandLevel.expressive,
                  ),
                ),
              ),
              SizedBox(height: gap),
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) SizedBox(height: gap),
                children[i],
              ],
              SizedBox(height: gap),
            ],
          ),
        ),
      ),
    );
  }
}
