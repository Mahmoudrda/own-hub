/// A progress ring with a figure in it, matching `ringStat()` in
/// `6-v2/src/kit.mjs`.
///
/// Painted by hand over a pencil guide circle: a nib stroke that starts at
/// twelve o'clock and sweeps **exactly** the fraction given — the hand varies
/// the stroke's weight, never its length. The figures sit in the hole in print,
/// because they are her numbers and have to be read, not admired.
///
/// [fraction] is a completed share of a known total — steps of an arc, sessions
/// of a week. It is never a share of a *day*, and this widget has no idea what a
/// day is (§2 rule 3).
library;

import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import 'hand/hand.dart';

class AppRingStat extends StatelessWidget {
  const AppRingStat({
    super.key,
    required this.fraction,
    required this.big,
    required this.small,
    this.size = 96,
    this.thickness = 12,
    this.color = AppColors.tertiarySoft,
    this.bigColor = AppColors.onSurface,
    this.smallColor = AppColors.onSurfaceVariant,
    // A sentinel, like `AppProgressBar.trackColour`: swapped for
    // `AppColors.outline` in `build`, never painted as itself.
    this.trackColor = AppColors.outlineVariant,
  });

  /// 0–1. Clamped, so a miscounted caller cannot draw more than a full circle.
  final double fraction;

  final String big;
  final String small;
  final double size;
  final double thickness;
  final Color color;

  /// The three colours exist because R06 puts this ring on the dark follow-along
  /// player, where the defaults — near-black figures on `inverseSurface` — are
  /// unreadable. Defaulted to the light-surface values, so every existing caller
  /// renders exactly as before.
  final Color bigColor;
  final Color smallColor;
  final Color trackColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: RingPainter(
          // Not from [big]: on the rest timer that is the clock, and a seed
          // that changes every second redrew the ring by a different hand
          // every second.
          seed: handSeed(['ring', small, size]),
          fraction: fraction.clamp(0.0, 1.0),
          thickness: thickness * 0.85,
          color: color,
          // The default track is the light-surface hairline; the pencil guide
          // wants the darker pencil there. A caller's own track colour — R06's
          // on the dark player — is kept as given.
          guide: trackColor == AppColors.outlineVariant
              ? AppColors.outline
              : trackColor,
          textDirection: Directionality.of(context),
        ),
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(thickness + 2),
            // The ring is a fixed-size graphic, so its figures scale with it
            // rather than with the system text size — which would otherwise push
            // them outside the hole at the largest setting.
            child: FittedBox(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    big,
                    style: AppText.titleL.copyWith(
                      fontSize: size / 4.2,
                      height: 1,
                      color: bigColor,
                    ),
                  ),
                  Text(
                    small,
                    style: AppText.bodyM.copyWith(
                      fontSize: 13,
                      color: smallColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
