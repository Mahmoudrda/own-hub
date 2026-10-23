/// Drawing a mark on, once, and pressing something that gives.
///
/// Both honour the system's reduced-motion setting: with it on, a mark is
/// simply there and a press changes colour without moving.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../../app_state/haptics.dart';
import '../../theme/hand_tokens.dart';
import 'motion.dart';

/// Whether motion should be skipped. Reads the platform setting.
///
/// Android's "Remove animations" arrives as [MediaQueryData.disableAnimations];
/// iOS Reduce Motion does not set that flag and has to be read from the view.
bool handMotionOff(BuildContext context) {
  final mq = MediaQuery.maybeOf(context);
  if (mq == null || mq.disableAnimations || mq.accessibleNavigation) {
    return true;
  }
  final view = View.maybeOf(context);
  return view != null &&
      view.platformDispatcher.accessibilityFeatures.reduceMotion;
}

/// Runs a 0→1 value once, when first shown, and hands it to [builder].
///
/// Marks drawn on this way are the ones a person would actually be seen
/// drawing: a circle round the week, a tick on something done, a focus line.
/// Frames, rules and fills are never drawn on — the page is printed; only the
/// hand arrives.
class DrawOn extends StatefulWidget {
  const DrawOn({
    super.key,
    required this.builder,
    this.delay = Duration.zero,
    this.duration = HandMotion.draw,
    this.replayKey,
  });

  final Widget Function(BuildContext context, double progress) builder;
  final Duration delay;
  final Duration duration;

  /// Change this to draw the mark again — a new selection, a new focus.
  final Object? replayKey;

  @override
  State<DrawOn> createState() => _DrawOnState();
}

class _DrawOnState extends State<DrawOn> with SingleTickerProviderStateMixin {
  // The delay is the front of the same controller rather than a timer: a
  // timer still pending when a widget test ends fails that test, and a screen
  // closed mid-delay would otherwise leave one behind.
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.delay + widget.duration,
  );
  late final Animation<double> _t = CurvedAnimation(
    parent: _c,
    curve: Interval(
      widget.delay.inMicroseconds /
          (widget.delay + widget.duration).inMicroseconds,
      1,
      curve: HandMotion.pen,
    ),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _play();
    }
  }

  @override
  void didUpdateWidget(DrawOn old) {
    super.didUpdateWidget(old);
    if (old.replayKey != widget.replayKey) _play();
  }

  void _play() {
    if (handMotionOff(context)) {
      _c.value = 1;
      return;
    }
    _c.value = 0;
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _t,
    builder: (context, _) => widget.builder(context, _t.value),
  );
}

/// A tappable area that compresses under the finger.
///
/// Built on [InkWell] so focus, keyboard activation and the tap semantics
/// every screen reader expects stay exactly as they were — only the Material
/// ripple is gone, replaced by the surface giving a little. [builder] receives
/// how far it is pressed, 0 to 1, for surfaces that move toward their outline.
class HandPressable extends StatefulWidget {
  const HandPressable({
    super.key,
    required this.builder,
    this.onTap,
    this.onLongPress,
    this.scale = 0.975,
    this.spring = false,
    this.borderRadius,
    this.focusColor,
    this.haptic = false,
  });

  final Widget Function(BuildContext context, double pressed) builder;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// How small it gets at the bottom of the press.
  final double scale;

  /// Press and release on [HandTiming.spring] rather than a timed curve. The
  /// release overshoots a little and settles; hit area and semantics are the
  /// same either way.
  final bool spring;

  final BorderRadius? borderRadius;
  final Color? focusColor;

  /// A light tap under the finger when it lands, for a primary action. The
  /// platform's own haptics setting still decides whether it is felt.
  final bool haptic;

  @override
  State<HandPressable> createState() => _HandPressableState();
}

class _HandPressableState extends State<HandPressable>
    with SingleTickerProviderStateMixin {
  // Unbounded so the spring may overshoot its resting value.
  late final AnimationController _c = widget.spring
      ? AnimationController.unbounded(vsync: this)
      : AnimationController(
          vsync: this,
          duration: HandTiming.pressIn,
          reverseDuration: HandTiming.pressOut,
        );

  void _tap() {
    if (widget.haptic) unawaited(AppHaptics.play(HapticMoment.actionDone));
    widget.onTap?.call();
  }

  void _highlight(bool down) {
    if (widget.onTap == null && widget.onLongPress == null) return;
    if (handMotionOff(context)) {
      _c.value = down ? 1 : 0;
    } else if (widget.spring) {
      _c.animateWith(
        SpringSimulation(
          HandTiming.spring,
          _c.value,
          down ? 1 : 0,
          _c.velocity,
        ),
      );
    } else if (down) {
      _c.forward();
    } else {
      _c.reverse();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = handMotionOff(context);
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: widget.onTap == null ? null : _tap,
        onLongPress: widget.onLongPress,
        onHighlightChanged: _highlight,
        splashFactory: NoSplash.splashFactory,
        // With motion off the press cannot be felt as movement, so it is
        // shown as the faintest shade instead.
        highlightColor: still
            ? HandInk.print.withValues(alpha: 0.05)
            : Colors.transparent,
        hoverColor: Colors.transparent,
        focusColor: widget.focusColor ?? HandInk.marker.withValues(alpha: 0.6),
        borderRadius: widget.borderRadius,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final p = widget.spring
                ? _c.value
                : Curves.easeOut.transform(_c.value);
            // Always wrapped, pressed or not: adding the transform only
            // mid-press would change the tree shape and rebuild everything
            // inside from scratch, state and all.
            return Transform.scale(
              scale: still ? 1 : 1 - (1 - widget.scale) * p,
              child: widget.builder(context, p.clamp(0.0, 1.0)),
            );
          },
        ),
      ),
    );
  }
}
