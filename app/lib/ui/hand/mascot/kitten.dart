/// The kitten on the page: shows her the next thing to do on the few screens
/// where that is not obvious, then sits still.
///
/// Where it may appear is a short list on purpose: the start of onboarding,
/// the tour, the face check, the end of onboarding and the first day on Home.
/// One per screen. It never speaks, takes no tap and is not read out; the
/// words beside it carry the meaning.
library;

import 'package:flutter/widgets.dart';

import '../../../app_state/kitten_setting.dart';
import '../draw_on.dart';
import 'kitten_painter.dart';

export 'kitten_painter.dart' show KittenPose;

/// Whether the kitten should hold still: the system asks for less motion,
/// the screen is not the one being looked at, or she turned it off.
bool kittenStill(BuildContext context) =>
    handMotionOff(context) ||
    !TickerMode.valuesOf(context).enabled ||
    !KittenSetting.instance.moves;

/// The kitten, doing [pose] once when it first appears.
class Kitten extends StatefulWidget {
  const Kitten({
    super.key,
    required this.pose,
    this.size = 56,
    this.moment,
    this.replayKey,
  });

  final KittenPose pose;
  final double size;

  /// A name for this appearance. A named moment moves the first time it is
  /// seen in a run of the app and is simply there after that, so going back
  /// and forth between two screens does not make it perform again.
  final String? moment;

  /// Change to play the move again, as when the tour moves to the next stop.
  final Object? replayKey;

  /// Moments already played in this run of the app.
  static final Set<String> _played = {};

  @visibleForTesting
  static void resetPlayed() => _played.clear();

  @override
  State<Kitten> createState() => _KittenState();
}

class _KittenState extends State<Kitten> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: kittenRunFor(widget.pose),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _play();
    } else if (kittenStill(context) && _c.isAnimating) {
      // Reduce Motion switched on mid-move.
      _c.value = 1;
    }
  }

  @override
  void didUpdateWidget(Kitten old) {
    super.didUpdateWidget(old);
    if (old.pose != widget.pose || old.replayKey != widget.replayKey) {
      _c.duration = kittenRunFor(widget.pose);
      _play();
    }
  }

  void _play() {
    final moment = widget.moment;
    final seen = moment != null && Kitten._played.contains(moment);
    if (seen || kittenStill(context)) {
      _c.value = 1;
      return;
    }
    if (moment != null) Kitten._played.add(moment);
    _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.maybeOf(context) == TextDirection.rtl;
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: SizedBox.square(
          dimension: widget.size,
          child: CustomPaint(
            painter: KittenPainter(progress: _c, pose: widget.pose, rtl: rtl),
          ),
        ),
      ),
    );
  }
}
