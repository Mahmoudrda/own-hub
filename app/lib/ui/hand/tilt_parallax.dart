/// A little give with the phone: art that drifts a few pixels as it tilts.
///
/// Reads the accelerometer, which on both platforms needs no permission and
/// no privacy declaration. It listens only while its screen is the one being
/// looked at, lets go the moment it is covered or disposed, and sits still
/// under reduced motion or when she has turned the kitten's motion off in
/// Profile. Never put it round the kitten.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../app_state/kitten_setting.dart';
import 'draw_on.dart';

class TiltParallax extends StatefulWidget {
  const TiltParallax({
    super.key,
    required this.child,
    this.maxShift = 8,
    this.smoothing = 0.1,
  });

  final Widget child;

  /// The furthest it moves from rest, in logical pixels, on either axis.
  final double maxShift;

  /// The low-pass filter's weight on each new reading.
  final double smoothing;

  /// Where readings come from. Tests replace it.
  @visibleForTesting
  static Stream<AccelerometerEvent> Function() source = () =>
      accelerometerEventStream(samplingPeriod: SensorInterval.uiInterval);

  @override
  State<TiltParallax> createState() => _TiltParallaxState();
}

class _TiltParallaxState extends State<TiltParallax> {
  static const double _gravity = 9.80665;

  final ValueNotifier<Offset> _shift = ValueNotifier(Offset.zero);
  StreamSubscription<AccelerometerEvent>? _sub;
  double _fx = 0;
  double _fy = 0;

  // How she was holding the phone when the screen opened: the art rests
  // there, and moves only as she tips it away.
  double? _baseX;
  double _baseY = 0;

  @override
  void initState() {
    super.initState();
    KittenSetting.instance.addListener(_sync);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  void _sync() {
    if (!mounted) return;
    final live =
        !handMotionOff(context) &&
        TickerMode.valuesOf(context).enabled &&
        KittenSetting.instance.moves &&
        (ModalRoute.of(context)?.isCurrent ?? true);
    if (live && _sub == null) {
      _sub = TiltParallax.source().listen(_onReading, onError: (_) {});
    } else if (!live && _sub != null) {
      _sub!.cancel();
      _sub = null;
      _fx = 0;
      _fy = 0;
      _baseX = null;
      _shift.value = Offset.zero;
    }
  }

  void _onReading(AccelerometerEvent e) {
    // Gravity on each axis as a fraction of one g, smoothed so a shaky hand
    // does not shake the art.
    final x = (e.x / _gravity).clamp(-1.0, 1.0);
    final y = (e.y / _gravity).clamp(-1.0, 1.0);
    if (_baseX == null) {
      _baseX = _fx = x;
      _baseY = _fy = y;
      return;
    }
    final a = widget.smoothing;
    _fx += a * (x - _fx);
    _fy += a * (y - _fy);
    final m = widget.maxShift;
    // About twenty degrees of tip takes it to the edge of its range.
    const reach = 0.35;
    _shift.value = Offset(
      (-(_fx - _baseX!) / reach * m).clamp(-m, m),
      ((_fy - _baseY) / reach * m).clamp(-m, m),
    );
  }

  @override
  void dispose() {
    KittenSetting.instance.removeListener(_sync);
    _sub?.cancel();
    _sub = null;
    _shift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<Offset>(
    valueListenable: _shift,
    child: widget.child,
    builder: (context, shift, child) =>
        Transform.translate(offset: shift, child: child),
  );
}
