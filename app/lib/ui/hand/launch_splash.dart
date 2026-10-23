/// The Own Hub mark drawing itself on over the first screen at a cold start.
///
/// The app is already built underneath when this appears and never waits on
/// it. A tap during the splash (under 700 ms) is absorbed, so it cannot land
/// on a screen she cannot see yet. The ring is drawn round, the blade slides out, and
/// the whole thing is gone within [HandTiming.splash]. With Reduce Motion on,
/// or on any start but a cold one, it is not shown at all.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';
import 'draw_on.dart';
import 'motion.dart';

class LaunchSplash extends StatefulWidget {
  const LaunchSplash({super.key, required this.show, required this.child});

  /// Set by `main` for the cold start only; a resume never builds this again.
  static bool enabled = false;

  /// Read once and cleared, so only the first app built in a run shows it.
  static bool takeColdStart() {
    final was = enabled;
    enabled = false;
    return was;
  }

  final bool show;
  final Widget child;

  @override
  State<LaunchSplash> createState() => _LaunchSplashState();
}

class _LaunchSplashState extends State<LaunchSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: HandTiming.splash,
  );
  bool _done = true;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!widget.show || handMotionOff(context)) return;
    _done = false;
    _c.forward().whenComplete(() {
      if (mounted) setState(() => _done = true);
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The app stays at the same place in the tree whether or not the splash
    // is up, so its navigator keeps its state when the splash goes.
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (!_done)
          ExcludeSemantics(
            child: AbsorbPointer(
              child: AnimatedBuilder(
                animation: _c,
                builder: (context, _) {
                  if (_c.isCompleted) return const SizedBox.shrink();
                  // The draw takes the first 60% (420 ms), the fade the rest.
                  final t = _c.value;
                  final draw = Curves.easeOutCubic.transform(
                    (t / 0.6).clamp(0.0, 1.0),
                  );
                  final fade = 1 - ((t - 0.6) / 0.4).clamp(0.0, 1.0);
                  return Opacity(
                    opacity: fade,
                    child: ColoredBox(
                      color: AppColors.brandLinen,
                      child: Center(
                        child: SizedBox(
                          width: 120,
                          height: 120,
                          child: CustomPaint(
                            painter: OwnHubMarkPainter(progress: draw),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}

/// `assets/brand/ownhub-mark.svg` as geometry: a ring with the blade cut
/// through it, drawn on by [progress] from 0 to 1.
class OwnHubMarkPainter extends CustomPainter {
  OwnHubMarkPainter({
    required this.progress,
    this.color = AppColors.brandPetrol,
  });

  final double progress;
  final Color color;

  static Path _blade() => Path()
    ..moveTo(153.27, 995.18)
    ..quadraticBezierTo(585.19, 559.65, 846.73, 4.82)
    ..quadraticBezierTo(414.81, 440.35, 153.27, 995.18)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 1000, size.height / 1000);
    final ringP = (progress / 0.7).clamp(0.0, 1.0);
    final bladeP = ((progress - 0.35) / 0.65).clamp(0.0, 1.0);
    final blade = _blade().transform(
      (Matrix4.identity()
            ..translateByDouble(500, 500, 0, 1)
            ..scaleByDouble(bladeP, bladeP, 1, 1)
            ..translateByDouble(-500, -500, 0, 1))
          .storage,
    );

    canvas.saveLayer(const Rect.fromLTWH(0, 0, 1000, 1000), Paint());
    canvas.drawArc(
      Rect.fromCircle(center: const Offset(500, 500), radius: 327.5),
      -math.pi / 2,
      2 * math.pi * ringP,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 125
        ..color = color,
    );
    if (bladeP > 0) {
      final clear = Paint()..blendMode = BlendMode.clear;
      canvas.drawPath(blade, clear);
      canvas.drawPath(
        blade,
        clear
          ..style = PaintingStyle.stroke
          ..strokeWidth = 60
          ..strokeJoin = StrokeJoin.round,
      );
    }
    canvas.restore();
    if (bladeP > 0) canvas.drawPath(blade, Paint()..color = color);
    canvas.restore();
  }

  @override
  bool shouldRepaint(OwnHubMarkPainter old) =>
      old.progress != progress || old.color != color;
}
