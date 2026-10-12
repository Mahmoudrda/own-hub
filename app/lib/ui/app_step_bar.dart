/// How far through a step-by-step flow she is: one stroke per step, inked up
/// to the one she is on.
///
/// Every setup flow in the product asks one thing per screen, and this bar is
/// what makes that bearable: she sees how many are left before she starts and
/// watches the line fill as she goes. It sits under the bar title, which still
/// says the count in words ("2 of 6") for a screen reader and for anyone who
/// would rather read than look.
///
/// Steps, not days: it is never used to count time, and an unfilled stroke is
/// the neutral pencil of a step still to come, never a mark of something
/// missed.
library;

import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import 'hand/hand.dart';
import 'hand/hand_geometry.dart' show wobblyLine;
import 'hand/hand_painters.dart' show paintInk, paintPencil;

class AppStepBar extends StatelessWidget implements HandSeedName {
  @override
  String get handSeedName => 'AppStepBar';

  const AppStepBar({
    super.key,
    required this.step,
    required this.total,
    this.height = 6,
    this.color = AppColors.primary,
  }) : assert(total > 0),
       assert(step >= 0 && step <= total);

  /// The step she is on, counted from 1. Steps up to and including it are
  /// inked.
  final int step;

  /// How many steps the flow has.
  final int total;

  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final dir = Directionality.of(context);
    return ExcludeSemantics(
      child: SizedBox(
        height: height + 4,
        child: Row(
          children: [
            for (var i = 0; i < total; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              Expanded(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: i < step ? 1 : 0),
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  builder: (context, inked, _) => CustomPaint(
                    size: Size.infinite,
                    painter: _StepPainter(
                      inked: inked,
                      seed: handSeed(['step', i, total]),
                      thickness: height,
                      color: color,
                      textDirection: dir,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StepPainter extends CustomPainter {
  _StepPainter({
    required this.inked,
    required this.seed,
    required this.thickness,
    required this.color,
    required this.textDirection,
  });

  /// 0 for a step still to come, 1 for one done, between while it fills.
  final double inked;
  final int seed;
  final double thickness;
  final Color color;
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final rtl = textDirection == TextDirection.rtl;
    Offset at(double t) => Offset(
      rtl ? size.width - 1 - t * (size.width - 2) : 1 + t * (size.width - 2),
      y,
    );
    paintPencil(
      canvas,
      wobblyLine(at(0), at(1), seed: seed, wobble: 0.4, steps: 8),
      color: AppColors.outline,
      width: 1.1,
      seed: seed,
    );
    if (inked <= 0) return;
    paintInk(
      canvas,
      wobblyLine(at(0), at(inked), seed: seed + 7, wobble: 0.4, steps: 8),
      color: color,
      width: thickness,
      taper: 0.12,
      seed: seed,
    );
  }

  @override
  bool shouldRepaint(_StepPainter old) =>
      old.inked != inked ||
      old.seed != seed ||
      old.thickness != thickness ||
      old.color != color ||
      old.textDirection != textDirection;
}
