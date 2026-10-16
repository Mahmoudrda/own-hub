/// A placeholder for something still loading, with a soft light passing over.
///
/// The sweep is the one animation that repeats, so it exists only while the
/// placeholder is on screen: when the data arrives the placeholder is
/// replaced and the controller goes with it. Under reduced motion, or off
/// screen, it is a still block.
library;

import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';
import 'draw_on.dart';
import 'motion.dart';

class Skeleton extends StatefulWidget {
  const Skeleton({super.key, this.width, this.height, this.radius = 8});

  final double? width;
  final double? height;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: HandTiming.shimmer,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still =
        handMotionOff(context) || !TickerMode.valuesOf(context).enabled;
    if (still) {
      _c.stop();
      _c.value = 0.5;
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final x = -1.0 + 3.0 * _c.value;
          return Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.radius),
              gradient: LinearGradient(
                begin: Alignment(x - 1, 0),
                end: Alignment(x + 1, 0),
                colors: const [
                  AppColors.surfaceContainer,
                  AppColors.surfaceHigh,
                  AppColors.surfaceContainer,
                ],
              ),
            ),
          );
        },
      ),
    ),
  );
}
