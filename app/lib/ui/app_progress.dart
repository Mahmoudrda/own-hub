/// The continuous progress bar, matching `linear()` in `6-v2/src/kit.mjs`.
///
/// A quantity that genuinely is continuous — points toward the next level. It is
/// deliberately **not** how a week is drawn: a week is a count of sessions, and
/// `AppWeekSegments` draws it as separate blocks for that reason. Rendering a
/// week as a smooth bar would quietly reintroduce the daily-progress feeling §2
/// rule 3 exists to avoid.
///
/// This carries no number of its own, so it cannot become a score.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import 'hand/hand_geometry.dart' show wobblyLine;
import 'hand/hand_painters.dart' show paintInk, paintPencil;

/// A pencil line the full width, and over it a nib stroke that ends **exactly**
/// at the value. The hand shows in the stroke's weight and drift across it,
/// never in how far it reaches.
class AppProgressBar extends StatelessWidget {
  const AppProgressBar({
    super.key,
    required this.percent,
    this.height = 8,
    this.colour = AppColors.tertiarySoft,
    // A SENTINEL, not a paint colour: `build` reads it back and swaps in
    // `AppColors.outline`, the pencil tone, so the track a woman sees is the
    // boundary role. A caller's own colour is kept as given.
    this.trackColour = AppColors.outlineVariant,
  });

  /// 0–100, clamped.
  final double percent;
  final double height;
  final Color colour;
  final Color trackColour;

  @override
  Widget build(BuildContext context) {
    final fraction = (percent.clamp(0, 100)) / 100;

    return SizedBox(
      height: height + 4,
      width: double.infinity,
      child: CustomPaint(
        painter: _BarPainter(
          fraction: fraction.toDouble(),
          thickness: height,
          colour: colour,
          track: trackColour == AppColors.outlineVariant
              ? AppColors.outline
              : trackColour,
          // Directional, so in Arabic the bar fills from the right.
          textDirection: Directionality.of(context),
        ),
      ),
    );
  }
}

class _BarPainter extends CustomPainter {
  _BarPainter({
    required this.fraction,
    required this.thickness,
    required this.colour,
    required this.track,
    required this.textDirection,
  });

  final double fraction;
  final double thickness;
  final Color colour;
  final Color track;
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final rtl = textDirection == TextDirection.rtl;
    double x(double t) => rtl ? size.width * (1 - t) : size.width * t;
    final steps = math.max(8, (size.width / 12).round());
    paintPencil(
      canvas,
      wobblyLine(
        Offset(x(0), y),
        Offset(x(1), y),
        seed: 71,
        wobble: 0.4,
        steps: steps,
      ),
      color: track,
      width: 1,
      opacity: 0.75,
      seed: 71,
    );
    if (fraction <= 0) return;
    // Inset by half the nib so the stroke's rounded ends land on 0 and on the
    // value rather than past them.
    final inset = thickness * 0.35;
    final a = Offset(x(0) + (rtl ? -inset : inset), y);
    final b = Offset(x(fraction) + (rtl ? inset : -inset), y);
    if ((b - a).distance < 1) return;
    paintInk(
      canvas,
      wobblyLine(a, b, seed: 72, wobble: 0.5, steps: steps),
      color: colour,
      width: thickness,
      taper: 0.1,
      seed: 72,
    );
  }

  @override
  bool shouldRepaint(_BarPainter old) =>
      old.fraction != fraction ||
      old.thickness != thickness ||
      old.colour != colour ||
      old.track != track ||
      old.textDirection != textDirection;
}

// `segs()` lives in app_week_segments.dart as AppWeekSegments. A second
// implementation of the same shape once stood here; it is gone rather than kept
// "just in case", because two widgets drawing a week is how they drift apart.
