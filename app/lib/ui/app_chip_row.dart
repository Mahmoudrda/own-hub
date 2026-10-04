/// Chips and a row of them, matching `chip()` and `chipRow()` in
/// `6-v2/src/kit.mjs`.
///
/// A chip is the product's answer to a short list of short answers — days a
/// week, minutes a session, what she owns. It is deliberately not a dropdown and
/// not a list: every option is visible at once, so the honest answer is never
/// hidden behind a tap.
///
/// Two departures from the prototype's CSS, both for the same reason the rest of
/// `lib/ui` departs from it:
///
///  * **The visual height is 40, the tap target is never under 44.** Same floor
///    [AppButton] enforces, for the same reason — this product is tapped
///    one-handed, mid-set. The chip grows past 44 rather than clipping when the
///    system text size is large, which is what stops "دمبل" from being cut in
///    half at 1.6.
///  * **`grow: false` wraps instead of scrolling.** The prototype hides the
///    overflow (`overflow:hidden`), which on a phone means an option she owns can
///    sit off-screen where she will never find it. Four equipment chips in Arabic
///    at the largest text size do not fit one line, so they take two.
///
/// Selection state is the caller's, never the chip's. A chip that remembered its
/// own selection would be a second source of truth beside the intake it is
/// editing.
library;

import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import 'hand/hand.dart';

/// One chip. 40 high, 15px medium label. Framed in pencil; chosen, it is
/// filled with blush and ringed in rose ink, the way she would mark it.
class AppChip extends StatelessWidget {
  const AppChip(
    this.label, {
    super.key,
    this.selected = false,
    this.icon,
    this.onTap,
    this.height = 40,
  });

  final String label;
  final bool selected;

  /// The prototype's `ic` — a leading glyph. Unused by the intake screens, and
  /// part of `chip()`'s contract.
  final IconData? icon;

  final VoidCallback? onTap;

  /// The visual height. The tap target is `max(height, 44)`.
  final double height;

  @override
  Widget build(BuildContext context) {
    final foreground = selected
        ? AppColors.onPrimaryContainer
        : AppColors.onSurface;
    final iconColour = selected
        ? AppColors.onPrimaryContainer
        : AppColors.onSurfaceVariant;

    // Selected is said, not only drawn: a screen reader announces the ring
    // and the fill as "selected", or it could not tell her answer apart.
    return Semantics(
      selected: selected,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: height < 44 ? 44 : height),
        child: HandSurface(
          seed: handSeed(['chip', label, selected]),
          fill: selected ? AppColors.primaryContainer : null,
          frame: selected
              ? AppColors.primary
              : AppColors.outline.withValues(alpha: 0.7),
          frameWidth: selected ? 1.6 : 1.1,
          level: selected ? HandLevel.expressive : HandLevel.crafted,
          radius: 6,
          looseCorner: 13,
          onTap: onTap,
          pressable: true,
          pressScale: 0.96,
          // No fixed height: the constraint above sets the floor, and the chip
          // grows with the system text size rather than clipping.
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: iconColour),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: AppText.label.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
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

/// A row of chips, 8px apart.
///
/// [selected] holds the indexes that are on, so the same widget serves a
/// single-choice row (one index) and a multiple-choice row (several) without a
/// mode flag deciding which it is today.
class AppChipRow extends StatelessWidget implements HandSeedName {
  @override
  String get handSeedName => 'AppChipRow';

  const AppChipRow({
    super.key,
    required this.items,
    required this.selected,
    this.onTap,
    this.grow = true,
    this.height = 40,
  });

  final List<String> items;

  /// Indexes of [items] that are currently chosen.
  final Set<int> selected;

  final ValueChanged<int>? onTap;

  /// Whether the chips share the width equally, as `chipRow`'s `grow` does.
  ///
  /// True for a row of equal-weight answers (2/3/4/5). False where the labels
  /// have their own natural widths and one of them is much shorter than the
  /// rest — the prototype's equipment row.
  final bool grow;

  final double height;

  @override
  Widget build(BuildContext context) {
    Widget chipAt(int i) => AppChip(
      items[i],
      selected: selected.contains(i),
      height: height,
      onTap: onTap == null ? null : () => onTap!(i),
    );

    if (!grow) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [for (var i = 0; i < items.length; i++) chipAt(i)],
      );
    }

    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: chipAt(i)),
        ],
      ],
    );
  }
}
