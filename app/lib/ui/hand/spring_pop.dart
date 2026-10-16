/// A mark that arrives with a small spring, once.
///
/// It starts a little under size and settles past 1 and back on
/// [HandTiming.spring]. With motion off it is simply there.
library;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import 'draw_on.dart';
import 'motion.dart';

class SpringPop extends StatefulWidget {
  const SpringPop({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.from = 0.4,
  });

  final Widget child;

  /// How long to wait before the pop.
  final Duration delay;

  /// The scale it starts from.
  final double from;

  @override
  State<SpringPop> createState() => _SpringPopState();
}

class _SpringPopState extends State<SpringPop> with TickerProviderStateMixin {
  late final AnimationController _c = AnimationController.unbounded(
    vsync: this,
    value: 0,
  );
  AnimationController? _wait;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (handMotionOff(context)) {
      _c.value = 1;
      return;
    }
    void pop() => _c.animateWith(SpringSimulation(HandTiming.spring, 0, 1, 0));
    if (widget.delay == Duration.zero) {
      pop();
      return;
    }
    // The wait is a controller, not a timer: a timer still pending when a
    // widget test ends fails that test.
    _wait = AnimationController(vsync: this, duration: widget.delay)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) pop();
      })
      ..forward();
  }

  @override
  void dispose() {
    _wait?.dispose();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    child: widget.child,
    builder: (context, child) {
      final t = _c.value;
      final scale = widget.from + (1 - widget.from) * t;
      return Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.scale(scale: scale, child: child),
      );
    },
  );
}
