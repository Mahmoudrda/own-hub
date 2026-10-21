/// D40 — R10 arrives one result at a time.
///
/// The first video study's pack opening turns one moment into several by
/// revealing them in turn; the second's peak-end rule says the end of an
/// experience is what is remembered. Own Hub keeps the reveal and drops the
/// chance: every stage is something she really did, in a fixed order, so the
/// only thing she does not know in advance is which of her own results are
/// there to show.
///
/// - **Laid out from the start.** Every stage takes its place before the first
///   frame and only its ink arrives, so nothing on the page jumps as the
///   reveal runs and a screen reader finds the whole page at once.
/// - **One controller.** No timers: a widget test that ends mid-reveal leaves
///   nothing pending, and a screen closed mid-reveal leaves nothing behind.
/// - **A tap finishes it.** Any touch brings every stage in at once; she is
///   never made to wait for her own results.
/// - **Still under Reduce Motion**, and when the reveal is switched off: the
///   page is complete on its first frame.
library;

import 'package:flutter/widgets.dart';

import '../../../ui/hand/draw_on.dart';
import '../../../ui/hand/motion.dart';

/// Runs the reveal for [stages] stages and hands each [RevealStage] below it
/// its share of the animation.
class FinishReveal extends StatefulWidget {
  const FinishReveal({
    super.key,
    required this.stages,
    required this.child,
    this.step = HandTiming.short,
    this.enabled = true,
    this.hold = false,
    this.onStageShown,
  });

  final int stages;
  final Widget child;

  /// How long each stage takes to arrive.
  final Duration step;

  /// False draws every stage at once.
  final bool enabled;

  /// True keeps the reveal from starting, for a page that is covered for a
  /// moment first. It runs from the start when this turns false.
  final bool hold;

  /// Called once for each stage as it arrives, in order — and for every stage
  /// at once when the reveal is skipped or still.
  final ValueChanged<int>? onStageShown;

  @override
  State<FinishReveal> createState() => _FinishRevealState();
}

class _FinishRevealState extends State<FinishReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.step * (widget.stages < 1 ? 1 : widget.stages),
  )..addListener(_announce);
  bool _started = false;
  bool _waiting = false;
  int _shown = -1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!widget.enabled ||
        handMotionOff(context) ||
        !TickerMode.valuesOf(context).enabled) {
      _c.value = 1;
      return;
    }
    if (widget.hold) {
      _waiting = true;
      return;
    }
    _c.forward();
  }

  @override
  void didUpdateWidget(FinishReveal old) {
    super.didUpdateWidget(old);
    if (_waiting && old.hold && !widget.hold) {
      _waiting = false;
      _c.forward();
      return;
    }
    // R10 can draw before its summary lands: the first stage alone, still.
    // When the rest arrives the reveal runs on from there, rather than taking
    // the first stage away and bringing it back.
    if (old.enabled || !widget.enabled) return;
    // Nothing was announced while it waited: there was no one to tell.
    _shown = -1;
    if (handMotionOff(context) || !TickerMode.valuesOf(context).enabled) {
      _announce();
      return;
    }
    _c.value = 1 / (widget.stages < 1 ? 1 : widget.stages);
    if (widget.hold) {
      _waiting = true;
      return;
    }
    _c.forward();
  }

  void _announce() {
    final upTo = (_c.value * widget.stages).ceil().clamp(0, widget.stages) - 1;
    while (_shown < upTo) {
      _shown++;
      widget.onStageShown?.call(_shown);
    }
  }

  void _skip() {
    if (_c.isAnimating) _c.value = 1;
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.translucent,
    onPointerDown: (_) => _skip(),
    child: _RevealScope(
      animation: _c,
      stages: widget.stages,
      step: widget.step,
      child: widget.child,
    ),
  );
}

class _RevealScope extends InheritedWidget {
  const _RevealScope({
    required this.animation,
    required this.stages,
    required this.step,
    required super.child,
  });

  final Animation<double> animation;
  final int stages;
  final Duration step;

  @override
  bool updateShouldNotify(_RevealScope old) =>
      old.animation != animation || old.stages != stages || old.step != step;
}

/// How long until stage [index] of the enclosing [FinishReveal] begins, for
/// ink that draws itself on and so needs a delay rather than a gate. Zero
/// outside a reveal, once it has finished or been skipped, and under reduced
/// motion.
Duration revealLead(BuildContext context, int index) {
  final scope = context.getInheritedWidgetOfExactType<_RevealScope>();
  if (scope == null || scope.animation.isCompleted || handMotionOff(context)) {
    return Duration.zero;
  }
  // Measured from now, not from the start: when the summary lands after the
  // page opened, the reveal has already moved on.
  final remaining =
      scope.step * index - scope.step * (scope.stages * scope.animation.value);
  return remaining.isNegative ? Duration.zero : remaining;
}

/// One stage of the reveal: present in the layout from the first frame, its
/// ink arriving in its turn. Outside a [FinishReveal] it is simply its child.
class RevealStage extends StatelessWidget {
  const RevealStage({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_RevealScope>();
    if (scope == null || scope.stages <= 0) return child;
    final start = index / scope.stages;
    final end = (index + 1) / scope.stages;
    // Driven by the one controller through a curve, so the fade is the
    // framework's own `FadeTransition`: it repaints on a tick without
    // rebuilding its child, where a builder with an `Opacity` rebuilt every
    // stage on every frame of the reveal. Only the small translate below is
    // rebuilt per frame, and its child is passed through untouched.
    final ink = scope.animation.drive(
      CurveTween(
        curve: Interval(start, end.clamp(0.0, 1.0), curve: Curves.easeOutCubic),
      ),
    );
    return FadeTransition(
      opacity: ink,
      // Present to a screen reader from the first frame, as the page is.
      alwaysIncludeSemantics: true,
      child: AnimatedBuilder(
        animation: ink,
        child: child,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, (1 - ink.value) * 8),
          child: child,
        ),
      ),
    );
  }
}

/// Builds [child] only once stage [index] has begun to arrive, and keeps it.
///
/// For the things on R10 that move on their own — the kitten's cheer and the
/// confetti. Mounted with the page, they would play out behind a stage still
/// at nothing and be spent unseen: the cheer's one move a sitting, the burst
/// before the moment it is for. Outside a [FinishReveal] it is simply its
/// child.
class RevealOnArrival extends StatefulWidget {
  const RevealOnArrival({
    super.key,
    required this.index,
    required this.child,
    this.placeholder = const SizedBox.shrink(),
  });

  final int index;
  final Widget child;

  /// What holds the place until the stage arrives.
  final Widget placeholder;

  @override
  State<RevealOnArrival> createState() => _RevealOnArrivalState();
}

class _RevealOnArrivalState extends State<RevealOnArrival> {
  bool _arrived = false;

  @override
  Widget build(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_RevealScope>();
    if (scope == null || scope.stages <= 0) return widget.child;
    final start = widget.index / scope.stages;
    // One shape for the whole life of the widget, so the child is mounted
    // exactly once: a cheer is never cut off half-way and a burst never
    // starts again.
    return AnimatedBuilder(
      animation: scope.animation,
      child: widget.child,
      builder: (context, child) {
        if (!_arrived &&
            (scope.animation.value >= start || scope.animation.isCompleted)) {
          _arrived = true;
        }
        return _arrived ? child! : widget.placeholder;
      },
    );
  }
}

/// A figure that counts up to [value] when stage [index] arrives, as
/// "[value] of [total]" is read out by [format].
///
/// The place is held, at the final figure and unseen, until the stage
/// arrives, so nothing moves on the page; a screen reader is given the final
/// figure from the first frame. A reveal that has been skipped, or is still,
/// shows the final figure at once.
class RevealCount extends StatelessWidget {
  const RevealCount({
    super.key,
    required this.index,
    required this.value,
    required this.format,
    this.style,
    this.from = 0,
  });

  /// Where the count starts.
  final int from;

  final int index;
  final int value;
  final String Function(int shown) format;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_RevealScope>();
    final done = format(value);
    if (scope == null || handMotionOff(context)) {
      return Text(done, style: style);
    }
    return Semantics(
      label: done,
      excludeSemantics: true,
      child: RevealOnArrival(
        index: index,
        placeholder: Opacity(opacity: 0, child: Text(done, style: style)),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: from.toDouble(), end: value.toDouble()),
          // A skip lands the figure with everything else.
          duration: scope.animation.isCompleted
              ? Duration.zero
              : HandTiming.medium,
          curve: HandTiming.standard,
          builder: (context, v, _) => Text(format(v.round()), style: style),
        ),
      ),
    );
  }
}
