/// D40 — the one celebration, drawn by hand.
///
/// R10's header has promised confetti since the first build, and there was
/// none: no widget, no package, only the sentence. This is it, in the
/// product's own hand — torn paper scraps in rose, sage and pencil, the three
/// inks the page is already written in, never gold, because nothing here is a
/// prize (DESIGN.md, "Nothing Is Won").
///
/// - **Once.** One controller runs forward one time and the scraps are gone;
///   nothing loops and nothing is left on the page.
/// - **Never under Reduce Motion**, or when tickers are off: the page arrives
///   as it would have anyway, and the reveal says the same things in print.
/// - **Never in the way.** It ignores touches, is invisible to a screen
///   reader, and repaints on its own layer.
/// - **The same every time for the same session.** The scraps are placed from
///   a seed with a fixed arithmetic sequence, not from chance; nothing about a
///   celebration in this product is random.
///
/// `test/gamification_rules_test.dart` keeps it on R10.
library;

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../theme/app_tokens.dart';
import 'draw_on.dart';
import 'motion.dart';

/// One scrap: where it starts across the page (0–1), how far it drifts, how
/// fast it turns, its size, and its ink.
typedef ConfettiScrap = ({
  double x,
  double drift,
  double spin,
  double width,
  double height,
  double delay,
  Color color,
});

/// The scraps for [seed], placed by a small linear congruential sequence so
/// the same seed draws the same burst.
List<ConfettiScrap> confettiScraps(int seed, int pieces) {
  var state = (seed.abs() % 2147483646) + 1;
  double next() {
    state = (state * 48271) % 2147483647;
    return state / 2147483647;
  }

  const inks = [AppColors.primary, AppColors.tertiary, AppColors.outline];
  return [
    for (var i = 0; i < pieces; i++)
      (
        x: 0.08 + next() * 0.84,
        drift: (next() - 0.5) * 0.18,
        spin: (next() - 0.5) * 6,
        width: 5 + next() * 6,
        height: 3 + next() * 4,
        delay: next() * 0.25,
        color: inks[i % inks.length],
      ),
  ];
}

class PaperConfetti extends StatefulWidget {
  const PaperConfetti({
    super.key,
    required this.seed,
    this.pieces = 18,
    this.duration = HandTiming.confetti,
    this.height = 220,
  });

  final int seed;
  final int pieces;
  final Duration duration;

  /// How far the scraps fall, in logical pixels.
  final double height;

  @override
  State<PaperConfetti> createState() => _PaperConfettiState();
}

class _PaperConfettiState extends State<PaperConfetti>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  late final List<ConfettiScrap> _scraps = confettiScraps(
    widget.seed,
    widget.pieces,
  );
  bool _started = false;
  bool _still = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _still = handMotionOff(context) || !TickerMode.valuesOf(context).enabled;
    if (_still) return;
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_still) return const SizedBox.shrink();
    return IgnorePointer(
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: SizedBox(
            height: widget.height,
            width: double.infinity,
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) => _c.isCompleted
                  ? const SizedBox.shrink()
                  : CustomPaint(
                      painter: PaperConfettiPainter(
                        progress: _c.value,
                        scraps: _scraps,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class PaperConfettiPainter extends CustomPainter {
  PaperConfettiPainter({required this.progress, required this.scraps});

  final double progress;
  final List<ConfettiScrap> scraps;

  @override
  void paint(Canvas canvas, Size size) {
    for (final scrap in scraps) {
      final local = ((progress - scrap.delay) / (1 - scrap.delay))
          .clamp(0.0, 1.0)
          .toDouble();
      if (local <= 0) continue;
      // Falls with a little ease, drifts sideways, fades over the last third.
      final fall = Curves.easeOutCubic.transform(local);
      final dx = (scrap.x + scrap.drift * fall) * size.width;
      final dy = -12 + fall * (size.height + 12);
      final opacity = local < 0.66 ? 1.0 : (1 - (local - 0.66) / 0.34);
      final paint = Paint()
        ..color = scrap.color.withValues(
          alpha: 0.85 * opacity.clamp(0.0, 1.0).toDouble(),
        )
        ..style = PaintingStyle.fill;
      canvas
        ..save()
        ..translate(dx, dy)
        ..rotate(scrap.spin * fall * math.pi / 2);
      // A torn scrap rather than a clean rectangle: one corner pulled in.
      final w = scrap.width;
      final h = scrap.height;
      final path = Path()
        ..moveTo(-w / 2, -h / 2)
        ..lineTo(w / 2, -h / 2 + h * 0.2)
        ..lineTo(w / 2 - w * 0.15, h / 2)
        ..lineTo(-w / 2, h / 2 - h * 0.1)
        ..close();
      canvas
        ..drawPath(path, paint)
        ..restore();
    }
  }

  @override
  bool shouldRepaint(PaperConfettiPainter old) => old.progress != progress;
}
