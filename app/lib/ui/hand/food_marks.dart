/// Sixteen food marks, drawn rather than licensed.
///
/// ## Why these are painted and not pictures
///
/// The recipe book was made in Canva. Canva's Content Licence Agreement permits
/// using an element **within a design** and explicitly prohibits extracting one
/// and shipping it as a stand-alone asset, which is exactly what putting it in
/// an app binary is. So the book's own illustrations cannot come across.
///
/// Drawing them instead settles it by construction. A `CustomPainter` in the
/// app's existing hand language is licence-clean, costs nothing in binary size,
/// scales to any density without three WebP variants, takes its colours from
/// the theme, and looks more like this product than any stock pack would.
///
/// These sixteen went first, for the recipe cards. The open question they left
/// behind — `app/assets/art/`, whose `cupcake.webp` was byte-identical to the
/// cupcake on her Sweet Tooth divider — has since been answered the same way:
/// that pack is deleted and `art_marks.dart` draws the whole product's
/// illustrations, borrowing six of the shapes below rather than drawing a
/// second, slightly different fried egg. See `assets/art/LICENCE.md`.
///
/// ## They obey the rules the hand layer already has
///
/// `hand_marks.dart` opens with them: a mark is decoration over content that
/// already says what it means, carries no information on its own, takes no tap,
/// and is not read out. Every mark here is wrapped in `ExcludeSemantics` by
/// [FoodMark], because the card beside it already says `Lazy Cake` and a screen
/// reader announcing "cake drawing" afterwards is noise.
///
/// ## The rule about pictures on food rows, and why this is the other side of it
///
/// `app_art.dart` says the illustrations "are deliberately not attached to
/// individual rows. Putting `bowlSalad` on a food she logged, when the food is
/// not a salad bowl, tells her something untrue about her own data." That rule
/// forbids **mismatch**, not depiction. A drawing of a cake on the Lazy Cake
/// card is a label, and a wrong one is a bug a test can catch: every
/// `markKey` in the seed must be a name in [FoodMarks.all], and
/// `rahma_seed_test.dart` checks it.
///
/// `screen_art.dart`'s second rule — "no treats on food screens" — is about
/// *ambient* art beside a calorie total, where a cupcake floating next to her
/// day's figure is a nudge. On the card for her own cookies, a drawing of
/// cookies is the dish. **This reading is the owner's to ratify**, and it is
/// written here rather than assumed silently. The treats now live only here:
/// there is no cake, cupcake, cookie or chip anywhere in [AppArt], so the two
/// rules cannot be confused with each other by accident.
library;

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../theme/hand_tokens.dart';
import 'hand_geometry.dart';

/// The names a recipe may carry in `markKey`.
///
/// Sixteen, and each one is a different shape rather than a different subject:
/// a jar is a jar whether it holds chia pudding or overnight oats, and drawing
/// two nearly identical jars would be decoration pretending to be information.
abstract final class FoodMarks {
  static const String cakeSlice = 'cake_slice';
  static const String pancakeStack = 'pancake_stack';
  static const String jar = 'jar';
  static const String bowl = 'bowl';
  static const String saladBowl = 'salad_bowl';
  static const String sandwich = 'sandwich';
  static const String friedEgg = 'fried_egg';
  static const String fries = 'fries';
  static const String cheeseWedge = 'cheese_wedge';
  static const String flatbread = 'flatbread';
  static const String pot = 'pot';
  static const String pan = 'pan';
  static const String drumstick = 'drumstick';
  static const String steak = 'steak';
  static const String potato = 'potato';
  static const String cookie = 'cookie';

  static const List<String> all = [
    cakeSlice, pancakeStack, jar, bowl, saladBowl, sandwich, friedEgg, fries,
    cheeseWedge, flatbread, pot, pan, drumstick, steak, potato, cookie,
  ];
}

/// One drawn food mark, sized to [size] and excluded from the semantics tree.
class FoodMark extends StatelessWidget {
  const FoodMark({
    super.key,
    required this.markKey,
    this.size = 56,
    required this.ink,
    this.level = HandLevel.expressive,
  });

  final String markKey;
  final double size;

  /// The card's own ink. The mark is never a second colour: it is a drawing in
  /// the pen the page is already written with.
  final Color ink;

  final HandLevel level;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: FoodMarkPainter(markKey: markKey, ink: ink, level: level),
        ),
      ),
    );
  }
}

/// The painter. Every shape is drawn in a 0..1 box and scaled, so one mark is
/// the same drawing at 28 pt beside a list row and at 72 pt on a card.
class FoodMarkPainter extends CustomPainter {
  FoodMarkPainter({
    required this.markKey,
    required this.ink,
    this.level = HandLevel.expressive,
  });

  final String markKey;
  final Color ink;
  final HandLevel level;

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    // Seeded from the name, so a given mark wobbles the same way every time it
    // is drawn. A mark that shivered on every rebuild would read as a glitch
    // rather than as a hand.
    final seed = handSeed(['food-mark', markKey]);
    final stroke = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.2, s * 0.032)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()
      ..color = ink.withValues(alpha: 0.13)
      ..style = PaintingStyle.fill;

    void line(List<Offset> pts, {bool close = false, bool filled = false}) {
      final scaled = [for (final p in pts) Offset(p.dx * s, p.dy * s)];
      final path = smoothPath(
        perturbLoop(scaled, seed: seed, wobble: level.wobble * (s / 56)),
        close: close,
      );
      if (filled) canvas.drawPath(path, fill);
      canvas.drawPath(path, stroke);
    }

    void circle(Offset centre, double r, {bool filled = false}) {
      final pts = <Offset>[
        for (var i = 0; i <= 22; i++)
          Offset(
            centre.dx + r * math.cos(i / 22 * 2 * math.pi),
            centre.dy + r * math.sin(i / 22 * 2 * math.pi),
          ),
      ];
      line(pts, close: true, filled: filled);
    }

    switch (markKey) {
      case FoodMarks.cakeSlice:
        // A wedge seen from the side, with one layer line across it.
        line([
          const Offset(0.18, 0.76), const Offset(0.30, 0.26),
          const Offset(0.82, 0.40), const Offset(0.74, 0.80),
        ], close: true, filled: true);
        line([const Offset(0.23, 0.56), const Offset(0.79, 0.62)]);

      case FoodMarks.pancakeStack:
        for (var i = 0; i < 3; i++) {
          final y = 0.68 - i * 0.16;
          line([
            Offset(0.20, y), Offset(0.30, y - 0.10), Offset(0.70, y - 0.10),
            Offset(0.80, y), Offset(0.70, y + 0.08), Offset(0.30, y + 0.08),
          ], close: true, filled: i == 0);
        }

      case FoodMarks.jar:
        line([const Offset(0.30, 0.24), const Offset(0.70, 0.24)]);
        line([
          const Offset(0.32, 0.30), const Offset(0.68, 0.30),
          const Offset(0.72, 0.80), const Offset(0.28, 0.80),
        ], close: true, filled: true);
        line([const Offset(0.30, 0.54), const Offset(0.70, 0.54)]);

      case FoodMarks.bowl:
        line([
          const Offset(0.16, 0.42), const Offset(0.84, 0.42),
          const Offset(0.70, 0.80), const Offset(0.30, 0.80),
        ], close: true, filled: true);
        // Steam, which is the only thing that says the bowl is hot.
        line([const Offset(0.42, 0.32), const Offset(0.46, 0.22)]);
        line([const Offset(0.58, 0.32), const Offset(0.54, 0.22)]);

      case FoodMarks.saladBowl:
        line([
          const Offset(0.14, 0.48), const Offset(0.86, 0.48),
          const Offset(0.70, 0.82), const Offset(0.30, 0.82),
        ], close: true, filled: true);
        circle(const Offset(0.36, 0.40), 0.10);
        circle(const Offset(0.56, 0.36), 0.12);
        circle(const Offset(0.72, 0.42), 0.08);

      case FoodMarks.sandwich:
        line([
          const Offset(0.16, 0.70), const Offset(0.84, 0.70),
          const Offset(0.50, 0.24),
        ], close: true, filled: true);
        line([const Offset(0.27, 0.56), const Offset(0.73, 0.56)]);

      case FoodMarks.friedEgg:
        line([
          const Offset(0.16, 0.46), const Offset(0.30, 0.26),
          const Offset(0.58, 0.24), const Offset(0.82, 0.38),
          const Offset(0.80, 0.66), const Offset(0.56, 0.80),
          const Offset(0.28, 0.74),
        ], close: true);
        circle(const Offset(0.50, 0.50), 0.15, filled: true);

      case FoodMarks.fries:
        line([
          const Offset(0.30, 0.44), const Offset(0.70, 0.44),
          const Offset(0.64, 0.82), const Offset(0.36, 0.82),
        ], close: true, filled: true);
        for (var i = 0; i < 4; i++) {
          final x = 0.34 + i * 0.11;
          line([Offset(x, 0.44), Offset(x - 0.02, 0.20 + i % 2 * 0.06)]);
        }

      case FoodMarks.cheeseWedge:
        line([
          const Offset(0.18, 0.72), const Offset(0.80, 0.34),
          const Offset(0.82, 0.62), const Offset(0.24, 0.82),
        ], close: true, filled: true);
        circle(const Offset(0.42, 0.66), 0.05);
        circle(const Offset(0.62, 0.55), 0.04);

      case FoodMarks.flatbread:
        circle(const Offset(0.50, 0.52), 0.32, filled: true);
        circle(const Offset(0.40, 0.44), 0.04);
        circle(const Offset(0.60, 0.50), 0.05);
        circle(const Offset(0.48, 0.64), 0.04);

      case FoodMarks.pot:
        line([
          const Offset(0.22, 0.40), const Offset(0.78, 0.40),
          const Offset(0.70, 0.82), const Offset(0.30, 0.82),
        ], close: true, filled: true);
        line([const Offset(0.16, 0.40), const Offset(0.84, 0.40)]);
        line([const Offset(0.44, 0.30), const Offset(0.56, 0.30)]);

      case FoodMarks.pan:
        circle(const Offset(0.44, 0.56), 0.26, filled: true);
        line([const Offset(0.69, 0.48), const Offset(0.90, 0.36)]);

      case FoodMarks.drumstick:
        line([
          const Offset(0.34, 0.74), const Offset(0.28, 0.54),
          const Offset(0.40, 0.34), const Offset(0.62, 0.26),
          const Offset(0.78, 0.36), const Offset(0.76, 0.56),
          const Offset(0.58, 0.66),
        ], close: true, filled: true);
        line([const Offset(0.34, 0.74), const Offset(0.20, 0.86)]);
        line([const Offset(0.20, 0.86), const Offset(0.14, 0.78)]);

      case FoodMarks.steak:
        line([
          const Offset(0.18, 0.56), const Offset(0.34, 0.30),
          const Offset(0.68, 0.26), const Offset(0.84, 0.48),
          const Offset(0.70, 0.76), const Offset(0.34, 0.78),
        ], close: true, filled: true);
        line([const Offset(0.32, 0.48), const Offset(0.66, 0.44)]);
        line([const Offset(0.36, 0.62), const Offset(0.70, 0.58)]);

      case FoodMarks.potato:
        line([
          const Offset(0.22, 0.52), const Offset(0.34, 0.30),
          const Offset(0.62, 0.26), const Offset(0.80, 0.44),
          const Offset(0.76, 0.70), const Offset(0.46, 0.80),
          const Offset(0.26, 0.70),
        ], close: true, filled: true);
        line([const Offset(0.40, 0.44), const Offset(0.62, 0.60)]);

      case FoodMarks.cookie:
      default:
        // The fallback is a cookie rather than nothing, because a card with a
        // blank corner reads as a failed image load. A name that reaches here
        // is a bug the seed test catches before a woman does.
        circle(const Offset(0.50, 0.52), 0.30, filled: true);
        circle(const Offset(0.42, 0.42), 0.045, filled: true);
        circle(const Offset(0.60, 0.48), 0.05, filled: true);
        circle(const Offset(0.48, 0.64), 0.04, filled: true);
    }
  }

  @override
  bool shouldRepaint(covariant FoodMarkPainter old) =>
      old.markKey != markKey || old.ink != ink || old.level != level;
}
