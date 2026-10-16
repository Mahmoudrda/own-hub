/// A list row arriving: faded in and lifted a few pixels, once per visit.
///
/// Rows start [HandTiming.staggerStep] apart and take [HandTiming.medium] each;
/// only the first [HandTiming.staggerMax] are staggered, the rest are simply
/// there. Once per visit: a row scrolled out of a lazy list and back does not
/// arrive again, because the route remembers it came. The row is laid out
/// from the first frame, so nothing jumps and a screen reader finds it at
/// once. Under reduced motion it is not animated.
library;

import 'package:flutter/widgets.dart';

import 'draw_on.dart';
import 'motion.dart';

class StaggerIn extends StatefulWidget {
  const StaggerIn({
    super.key,
    required this.index,
    required this.child,
    this.group = '',
  });

  /// This row's place in the list, from 0.
  final int index;
  final Widget child;

  /// Names the list when a screen has more than one, so each keeps its own
  /// record of which rows have arrived.
  final String group;

  /// [children] with each wrapped in a [StaggerIn] by its place.
  static List<Widget> all(List<Widget> children) => [
    for (var i = 0; i < children.length; i++)
      StaggerIn(index: i, child: children[i]),
  ];

  @override
  State<StaggerIn> createState() => _StaggerInState();
}

class _StaggerInState extends State<StaggerIn>
    with SingleTickerProviderStateMixin {
  // The delay is the front of the one controller, not a timer: nothing is
  // left pending if the screen is closed or a test ends mid-entrance.
  late final int _lead = widget.index.clamp(0, HandTiming.staggerMax - 1);
  late final Duration _delay = HandTiming.staggerStep * _lead;
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: _delay + HandTiming.medium,
  );
  late final Animation<double> _t = CurvedAnimation(
    parent: _c,
    curve: Interval(
      _delay.inMicroseconds / (_delay + HandTiming.medium).inMicroseconds,
      1,
      curve: HandTiming.standard,
    ),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final bucket = PageStorage.maybeOf(context);
    final seen = ('stagger', widget.group, widget.index);
    if (widget.index >= HandTiming.staggerMax ||
        handMotionOff(context) ||
        !TickerMode.valuesOf(context).enabled ||
        bucket?.readState(context, identifier: seen) == true) {
      _c.value = 1;
    } else {
      bucket?.writeState(context, true, identifier: seen);
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _t,
    // Present to a screen reader from the first frame, as the page is.
    alwaysIncludeSemantics: true,
    child: AnimatedBuilder(
      animation: _t,
      child: widget.child,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, (1 - _t.value) * 8),
        child: child,
      ),
    ),
  );
}
