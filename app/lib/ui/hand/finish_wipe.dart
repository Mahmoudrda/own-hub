/// A pale-pink ribbon that sweeps across the page once and uncovers it.
///
/// For the moment R10 appears after a live session. It is not a second
/// celebration: no confetti, no sound, no haptic, just the page being brought
/// in. It plays once (the widget is kept in the tree by its position and
/// never restarts), lasts [finishWipeDuration], and a tap anywhere finishes
/// it and goes no further. Under Reduce Motion, or when tickers are off, it draws nothing.
library;

import 'package:flutter/widgets.dart';

import '../../theme/app_tokens.dart';
import 'draw_on.dart';
import 'motion.dart';

/// Within the 600 ms budget for the wipe.
const Duration finishWipeDuration = Duration(milliseconds: 560);

class FinishWipe extends StatefulWidget {
  const FinishWipe({super.key, this.onDone});

  /// Called once, when the ribbon has crossed or been skipped.
  final VoidCallback? onDone;

  @override
  State<FinishWipe> createState() => _FinishWipeState();
}

class _FinishWipeState extends State<FinishWipe>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: finishWipeDuration,
  )..addStatusListener(_status);
  bool _started = false;
  bool _gone = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (handMotionOff(context) || !TickerMode.valuesOf(context).enabled) {
      _gone = true;
      return;
    }
    _c.forward();
  }

  void _status(AnimationStatus s) {
    if (s != AnimationStatus.completed || _gone) return;
    setState(() => _gone = true);
    widget.onDone?.call();
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
  Widget build(BuildContext context) {
    if (_gone) return const SizedBox.shrink();
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => _skip(),
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => CustomPaint(
            key: const ValueKey('finish-wipe'),
            painter: _WipePainter(
              progress: HandTiming.emphasized.transform(_c.value),
              rtl: rtl,
            ),
            size: Size.infinite,
          ),
        ),
      ),
    );
  }
}

class _WipePainter extends CustomPainter {
  _WipePainter({required this.progress, required this.rtl});

  final double progress;
  final bool rtl;

  static const double _ribbon = 36;

  @override
  void paint(Canvas canvas, Size size) {
    // The edge travels from the reading start to the reading end; what is
    // behind it is uncovered.
    final edge = (size.width + _ribbon) * progress;
    final covered = (size.width - edge + _ribbon).clamp(0.0, size.width);
    if (covered <= 0) return;
    canvas.save();
    if (rtl) {
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }
    // The cover sits at the reading end and shrinks away; its leading edge is
    // a slightly deeper ribbon.
    final left = size.width - covered;
    canvas.drawRect(
      Rect.fromLTWH(left, 0, covered, size.height),
      Paint()..color = AppColors.primarySoft,
    );
    final ribbonLeft = left;
    canvas.drawRect(
      Rect.fromLTWH(ribbonLeft, 0, _ribbon.clamp(0, covered), size.height),
      Paint()..color = AppColors.primaryContainer,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_WipePainter old) =>
      old.progress != progress || old.rtl != rtl;
}
