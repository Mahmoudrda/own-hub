/// A card that leans toward the finger on it, then springs back.
///
/// Reads raw pointer events, so it never enters the gesture arena: the page
/// still scrolls under a finger that starts on the card, and a tap on
/// anything inside it still lands. Still under reduced motion.
library;

import 'dart:math' as math;

import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

import 'draw_on.dart';
import 'motion.dart';

class FingerTilt extends StatefulWidget {
  const FingerTilt({super.key, required this.child, this.maxDegrees = 6});

  final Widget child;

  /// The furthest it leans, in degrees, on either axis.
  final double maxDegrees;

  @override
  State<FingerTilt> createState() => _FingerTiltState();
}

class _FingerTiltState extends State<FingerTilt>
    with SingleTickerProviderStateMixin {
  // How far from rest, 1 at the lean the finger asked for and 0 at rest.
  // Unbounded so the return may overshoot a hair.
  late final AnimationController _back = AnimationController.unbounded(
    vsync: this,
    value: 0,
  );
  Offset _lean = Offset.zero;

  void _toward(Offset local) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || handMotionOff(context)) return;
    final half = box.size.center(Offset.zero);
    if (half.dx == 0 || half.dy == 0) return;
    _back.stop();
    _back.value = 1;
    setState(() {
      _lean = Offset(
        ((local.dx - half.dx) / half.dx).clamp(-1.0, 1.0),
        ((local.dy - half.dy) / half.dy).clamp(-1.0, 1.0),
      );
    });
  }

  void _release() {
    if (_back.value == 0) return;
    if (handMotionOff(context)) {
      _back.value = 0;
      return;
    }
    _back.animateWith(
      SpringSimulation(HandTiming.spring, _back.value, 0, _back.velocity),
    );
  }

  @override
  void dispose() {
    _back.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (handMotionOff(context)) return widget.child;
    final max = widget.maxDegrees * math.pi / 180;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (e) => _toward(e.localPosition),
      onPointerMove: (e) => _toward(e.localPosition),
      onPointerUp: (_) => _release(),
      onPointerCancel: (_) => _release(),
      child: AnimatedBuilder(
        animation: _back,
        child: widget.child,
        builder: (context, child) {
          final k = _back.value;
          // A finger below centre lays the bottom edge away from her, a
          // finger to the right lays the right edge away.
          final rx = (-_lean.dy * max * k).clamp(-max, max);
          final ry = (_lean.dx * max * k).clamp(-max, max);
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0012)
              ..rotateX(rx)
              ..rotateY(ry),
            child: child,
          );
        },
      ),
    );
  }
}
