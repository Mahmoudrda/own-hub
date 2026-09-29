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
/// ## The same shape, in two places, in one hand
///
/// A mark here is drawn twice over: at 30 to 48 pt on a recipe card, where it
/// is the only drawing on the card, and inside `art_marks.dart`'s strip at
/// 92 pt, where it stands next to a mark drawn by [ArtMarkPainter]. Those two
/// painters used to carry their own pen widths, so a borrowed `pot` came out
/// 23% thicker and with 1.64x the wobble of the `buddha_bowl` beside it at the
/// top of E05 — two pen weights in one header strip. The pen is a parameter
/// now ([HandMarkPen]), the card keeps [HandMarkPen.recipeCard], and the
/// borrower hands down its own.
///
/// Marks also stand on one rule, [handMarkBaseline], for the same reason.
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

/// The rule every mark stands on: the lowest ink in the 0..1 box.
///
/// `art_marks.dart` has always documented "figures stand on the same baseline,
/// feet at 0.88", and the figures did. Nothing else did: ground strokes were
/// drawn at 0.90, objects stopped wherever their shape happened to end — the
/// dumbbell at 0.70 — and food marks between 0.76 and 0.84. R01 places
/// `dumbbells` next to `running` and E05 places a borrowed `pot` next to
/// `buddha_bowl`, so the rule was visible exactly where two marks met.
///
/// It lives in this file because `art_marks.dart` already imports it for the
/// shapes it borrows, and an import the other way round would be a cycle.
/// `app_art_test.dart` measures the lowest inked row of every mark in both
/// sets against it.
const double handMarkBaseline = 0.88;

/// The pen a mark is drawn with.
///
/// Width and wobble are parameters rather than constants because the same
/// shapes are drawn at two sizes for two purposes. [recipeCard] is the pen the
/// sixteen marks below were drawn and reviewed at, on a card where the mark
/// stands alone. `ArtMarkPainter.artPen` is finer, because those marks carry
/// limbs and frames that close up into a blob at the heavier weight — and when
/// it borrows a shape from this file it hands its own pen down, so a strip
/// with one borrowed and one native mark in it is drawn in one hand.
@immutable
class HandMarkPen {
  const HandMarkPen({
    required this.strokeFactor,
    required this.minStroke,
    required this.wobbleReference,
  });

  /// Nib width as a fraction of the mark's box.
  final double strokeFactor;

  /// The thinnest the nib goes, so a 24 pt mark is still ink and not a hair.
  final double minStroke;

  /// The size this pen's wobble was judged at. Drift scales with the drawing,
  /// so a mark at 2x the reference wobbles twice as far in absolute terms and
  /// looks like the same hand rather than a tighter one.
  final double wobbleReference;

  /// The recipe card's pen. These two numbers are what every card in the book
  /// was drawn and looked at with; changing them changes all sixteen marks on
  /// every card at once, so `food_marks_test.dart` pins them.
  static const HandMarkPen recipeCard = HandMarkPen(
    strokeFactor: 0.032,
    minStroke: 1.2,
    wobbleReference: 56,
  );

  double widthFor(double s) => math.max(minStroke, s * strokeFactor);

  double wobbleFor(double s, HandLevel level) =>
      level.wobble * (s / wobbleReference);

  @override
  bool operator ==(Object other) =>
      other is HandMarkPen &&
      other.strokeFactor == strokeFactor &&
      other.minStroke == minStroke &&
      other.wobbleReference == wobbleReference;

  @override
  int get hashCode => Object.hash(strokeFactor, minStroke, wobbleReference);
}

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
          painter: FoodMarkPainter(
            markKey: markKey,
            ink: ink,
            level: level,
            // A pan whose handle points away from the reader, and a drumstick
            // whose bone points into the margin, are drawn backwards on an
            // Arabic page for the same reason a runner would be. `ArtMark`
            // has read this since the art set was drawn; these sixteen did
            // not, so the recipe book stayed left-handed in Arabic.
            rtl: Directionality.maybeOf(context) == TextDirection.rtl,
          ),
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
    this.rtl = false,
    this.pen = HandMarkPen.recipeCard,
  });

  final String markKey;
  final Color ink;
  final HandLevel level;

  /// Whether the page is read right to left. Only the marks in [facing] turn
  /// round; see the note there.
  final bool rtl;

  /// The pen to draw with. Defaults to the recipe card's, which is where
  /// fifteen of the sixteen placements are.
  final HandMarkPen pen;

  /// Food marks with a front and a back, which turn round in a right-to-left
  /// page.
  ///
  /// A pan's handle and a drumstick's bone point somewhere, a wedge of cake
  /// and a wedge of cheese taper toward one side, and a steak's bone lies
  /// along one edge: all six read as pointing into the margin when the page
  /// is mirrored and they are not.
  ///
  /// Everything else is left alone on the same test `ArtMarkPainter.facing`
  /// applies: a bowl, a jar, a pot, a stack of pancakes and a fried egg have
  /// no front, and a cookie's bite or a flatbread's tear is a place the shape
  /// is missing rather than a direction it faces — flipping those would only
  /// change which way their hand-drawn wobble leans, in one language and not
  /// the other, for nothing.
  static const Set<String> facing = {
    FoodMarks.pan,
    FoodMarks.drumstick,
    FoodMarks.steak,
    FoodMarks.cheeseWedge,
    FoodMarks.cakeSlice,
  };

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    final mirror = rtl && facing.contains(markKey);
    if (mirror) {
      canvas.save();
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }
    _draw(canvas, s);
    if (mirror) canvas.restore();
  }

  void _draw(Canvas canvas, double s) {
    // Seeded from the name, so a given mark wobbles the same way every time it
    // is drawn. A mark that shivered on every rebuild would read as a glitch
    // rather than as a hand.
    final seed = handSeed(['food-mark', markKey]);
    final stroke = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = pen.widthFor(s)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()
      ..color = ink.withValues(alpha: 0.13)
      ..style = PaintingStyle.fill;

    void line(List<Offset> pts, {bool close = false, bool filled = false}) {
      final scaled = [for (final p in pts) Offset(p.dx * s, p.dy * s)];
      final path = smoothPath(
        perturbLoop(scaled, seed: seed, wobble: pen.wobbleFor(s, level)),
        close: close,
      );
      if (filled) canvas.drawPath(path, fill);
      canvas.drawPath(path, stroke);
    }

    void oval(Offset centre, double rx, double ry, {bool filled = false}) {
      final pts = <Offset>[
        for (var i = 0; i <= 22; i++)
          Offset(
            centre.dx + rx * math.cos(i / 22 * 2 * math.pi),
            centre.dy + ry * math.sin(i / 22 * 2 * math.pi),
          ),
      ];
      line(pts, close: true, filled: filled);
    }

    void circle(Offset centre, double r, {bool filled = false}) =>
        oval(centre, r, r, filled: filled);

    switch (markKey) {
      case FoodMarks.cakeSlice:
        // The section mark for Sweet Tooth Breakfast, which is the first
        // drawing a woman meets in the recipe book. It was a rounded
        // quadrilateral with one line across it and QA read it as a pillow.
        //
        // Three cues carry it: the cut face is a triangle with a real point at
        // the bottom left, two layer lines cross it, and a cherry sits on the
        // crest.
        //
        // The edges are drawn with points along them rather than corner to
        // corner, because the outline is smoothed through every point it is
        // given: four corners alone came back as a rounded lump, which is the
        // pillow QA saw.
        line([
          const Offset(0.12, 0.86), const Offset(0.26, 0.68),
          const Offset(0.40, 0.52), const Offset(0.54, 0.36),
          // The crest is three points, not a corner: two would be pulled into
          // a peak by the smoothing and the slice would come out a party hat.
          const Offset(0.64, 0.33), const Offset(0.74, 0.34),
          const Offset(0.82, 0.38), const Offset(0.83, 0.62),
          const Offset(0.82, 0.86), const Offset(0.56, handMarkBaseline),
          const Offset(0.34, handMarkBaseline),
        ], close: true, filled: true);
        // The icing, following the top edge and over the crest.
        line([
          const Offset(0.15, 0.80), const Offset(0.32, 0.62),
          const Offset(0.52, 0.42), const Offset(0.70, 0.40),
          const Offset(0.81, 0.46),
        ]);
        // Two layers across the cut face.
        line([const Offset(0.38, 0.60), const Offset(0.78, 0.595)]);
        line([const Offset(0.26, 0.745), const Offset(0.79, 0.735)]);
        // The cherry, resting on the crest rather than floating over it.
        circle(const Offset(0.68, 0.26), 0.055, filled: true);
        line([const Offset(0.68, 0.21), const Offset(0.74, 0.15)]);

      case FoodMarks.pancakeStack:
        for (var i = 0; i < 3; i++) {
          final y = handMarkBaseline - 0.08 - i * 0.16;
          line([
            Offset(0.20, y), Offset(0.30, y - 0.10), Offset(0.70, y - 0.10),
            Offset(0.80, y), Offset(0.70, y + 0.08), Offset(0.30, y + 0.08),
          ], close: true, filled: i == 0);
        }

      case FoodMarks.jar:
        line([const Offset(0.30, 0.24), const Offset(0.70, 0.24)]);
        line([
          const Offset(0.32, 0.30), const Offset(0.68, 0.30),
          const Offset(0.70, 0.60),
          const Offset(0.72, handMarkBaseline),
          // A point in the middle of the base. The outline is smoothed through
          // the points it is given, so a base drawn corner to corner sags
          // below the rule by more than the nib is wide.
          const Offset(0.50, handMarkBaseline),
          const Offset(0.28, handMarkBaseline),
          const Offset(0.30, 0.60),
        ], close: true, filled: true);
        line([const Offset(0.30, 0.58), const Offset(0.70, 0.58)]);

      case FoodMarks.bowl:
        line([
          const Offset(0.16, 0.46), const Offset(0.84, 0.46),
          const Offset(0.70, handMarkBaseline),
          const Offset(0.50, handMarkBaseline),
          const Offset(0.30, handMarkBaseline),
        ], close: true, filled: true);
        // Steam, which is the only thing that says the bowl is hot.
        line([const Offset(0.42, 0.38), const Offset(0.46, 0.26)]);
        line([const Offset(0.58, 0.38), const Offset(0.54, 0.26)]);

      case FoodMarks.saladBowl:
        line([
          const Offset(0.14, 0.50), const Offset(0.86, 0.50),
          const Offset(0.70, handMarkBaseline),
          const Offset(0.50, handMarkBaseline),
          const Offset(0.30, handMarkBaseline),
        ], close: true, filled: true);
        circle(const Offset(0.36, 0.42), 0.10);
        circle(const Offset(0.56, 0.38), 0.12);
        circle(const Offset(0.72, 0.44), 0.08);

      case FoodMarks.sandwich:
        line([
          const Offset(0.14, handMarkBaseline),
          const Offset(0.50, handMarkBaseline),
          const Offset(0.86, handMarkBaseline),
          const Offset(0.68, 0.59), const Offset(0.50, 0.30),
          const Offset(0.32, 0.59),
        ], close: true, filled: true);
        line([const Offset(0.26, 0.68), const Offset(0.74, 0.68)]);

      case FoodMarks.friedEgg:
        line([
          const Offset(0.14, 0.48), const Offset(0.28, 0.28),
          const Offset(0.58, 0.26), const Offset(0.84, 0.42),
          const Offset(0.82, 0.70), const Offset(0.56, handMarkBaseline),
          const Offset(0.26, 0.80),
        ], close: true);
        circle(const Offset(0.48, 0.54), 0.15, filled: true);

      case FoodMarks.fries:
        line([
          const Offset(0.28, 0.46), const Offset(0.72, 0.46),
          const Offset(0.66, handMarkBaseline),
          const Offset(0.50, handMarkBaseline),
          const Offset(0.34, handMarkBaseline),
        ], close: true, filled: true);
        for (var i = 0; i < 4; i++) {
          final x = 0.34 + i * 0.11;
          line([Offset(x, 0.46), Offset(x - 0.02, 0.20 + i % 2 * 0.06)]);
        }

      case FoodMarks.cheeseWedge:
        line([
          const Offset(0.16, 0.78), const Offset(0.80, 0.36),
          const Offset(0.84, 0.64), const Offset(0.22, handMarkBaseline),
        ], close: true, filled: true);
        circle(const Offset(0.42, 0.70), 0.05);
        circle(const Offset(0.62, 0.58), 0.04);

      case FoodMarks.flatbread:
        // An oval with a torn rim, a fold and open bubbles. It and `cookie`
        // were the same circle with the same three dots in it, which is two
        // names for one drawing — the defect `app_art.dart` forbids, in the
        // one vocabulary that is allowed to label a specific dish.
        // Wide and flat rather than round, so it is not the cookie's disc and
        // not `potato`'s lump either: those two were the shapes it kept being
        // mistaken for.
        line([
          const Offset(0.50, 0.32), const Offset(0.72, 0.36),
          const Offset(0.88, 0.48), const Offset(0.90, 0.62),
          const Offset(0.74, 0.80), const Offset(0.50, handMarkBaseline),
          const Offset(0.28, 0.85), const Offset(0.13, 0.72),
          const Offset(0.10, 0.56), const Offset(0.22, 0.42),
          // The tear: one rim point pulled in toward the middle.
          const Offset(0.30, 0.46), const Offset(0.38, 0.34),
        ], close: true, filled: true);
        // The folded-over edge along the bottom left, drawn as a crescent
        // inside the rim. A single slash across the middle was `potato`'s
        // crease, which is exactly the confusion this is fixing.
        line([
          const Offset(0.17, 0.66), const Offset(0.28, 0.79),
          const Offset(0.46, 0.84),
        ]);
        // Scorched bubbles: open and unequal, against the cookie's three solid
        // chips, so the two are still different at 28 pt.
        circle(const Offset(0.60, 0.52), 0.055);
        circle(const Offset(0.44, 0.62), 0.032);
        circle(const Offset(0.72, 0.66), 0.022);

      case FoodMarks.pot:
        line([
          const Offset(0.22, 0.44), const Offset(0.78, 0.44),
          const Offset(0.70, handMarkBaseline),
          const Offset(0.50, handMarkBaseline),
          const Offset(0.30, handMarkBaseline),
        ], close: true, filled: true);
        line([const Offset(0.16, 0.44), const Offset(0.84, 0.44)]);
        line([const Offset(0.44, 0.34), const Offset(0.56, 0.34)]);

      case FoodMarks.pan:
        circle(const Offset(0.46, 0.60), 0.28, filled: true);
        line([const Offset(0.71, 0.49), const Offset(0.93, 0.38)]);

      case FoodMarks.drumstick:
        line([
          const Offset(0.34, 0.72), const Offset(0.28, 0.52),
          const Offset(0.40, 0.32), const Offset(0.62, 0.24),
          const Offset(0.78, 0.34), const Offset(0.76, 0.54),
          const Offset(0.58, 0.64),
        ], close: true, filled: true);
        line([const Offset(0.34, 0.72), const Offset(0.20, handMarkBaseline)]);
        line([const Offset(0.20, handMarkBaseline), const Offset(0.13, 0.80)]);

      case FoodMarks.steak:
        // A rounded mass with two parallel lines across it, which is what this
        // was, is a stone or a bread roll — QA read it as both. At 28 pt the
        // outline is the whole drawing, so the bone is part of the silhouette
        // rather than a detail inside it, and the marbling is hooked so it
        // cannot be mistaken for a pair of grill bars on a pebble.
        line([
          const Offset(0.16, 0.56), const Offset(0.26, 0.36),
          const Offset(0.48, 0.28), const Offset(0.72, 0.30),
          const Offset(0.86, 0.46), const Offset(0.84, 0.66),
          const Offset(0.66, 0.84), const Offset(0.42, handMarkBaseline),
          const Offset(0.22, 0.74),
        ], close: true, filled: true);
        // The fat cap: a band hugging the top right edge, closed at both ends
        // so it reads as a rim of fat along one side of the cut rather than as
        // a crease. This is the cue that separates a steak from a stone, and
        // it has to be in the silhouette's edge because at 28 pt nothing in
        // the middle of the shape survives.
        line([
          const Offset(0.48, 0.28), const Offset(0.72, 0.30),
          const Offset(0.86, 0.46), const Offset(0.78, 0.49),
          const Offset(0.66, 0.38), const Offset(0.48, 0.36),
        ], close: true);
        // Grill marks: three, leaning together. Two parallel strokes on a
        // rounded shape is what QA read as a bread roll.
        line([const Offset(0.34, 0.54), const Offset(0.48, 0.48)]);
        line([const Offset(0.40, 0.68), const Offset(0.56, 0.61)]);
        line([const Offset(0.54, 0.78), const Offset(0.68, 0.71)]);

      case FoodMarks.potato:
        line([
          const Offset(0.22, 0.52), const Offset(0.34, 0.30),
          const Offset(0.62, 0.26), const Offset(0.80, 0.44),
          const Offset(0.76, 0.74), const Offset(0.46, handMarkBaseline),
          const Offset(0.26, 0.74),
        ], close: true, filled: true);
        line([const Offset(0.40, 0.46), const Offset(0.62, 0.62)]);

      case FoodMarks.cookie:
      default:
        // A disc with a bite out of the top right and three big chips. The
        // bite and the chip size are what tell it from `flatbread` at 28 pt;
        // the two used to be the same circle with the same dots.
        //
        // The fallback is a cookie rather than nothing, because a card with a
        // blank corner reads as a failed image load. A name that reaches here
        // is a bug the seed test catches before a woman does.
        line([
          const Offset(0.50, 0.24), const Offset(0.66, 0.28),
          // The bite: two rim points pulled in, so the edge is chewed rather
          // than dented.
          const Offset(0.68, 0.40), const Offset(0.74, 0.48),
          const Offset(0.82, 0.56), const Offset(0.73, 0.79),
          const Offset(0.50, handMarkBaseline), const Offset(0.27, 0.79),
          const Offset(0.18, 0.56), const Offset(0.27, 0.33),
        ], close: true, filled: true);
        circle(const Offset(0.40, 0.45), 0.06, filled: true);
        circle(const Offset(0.58, 0.66), 0.065, filled: true);
        circle(const Offset(0.34, 0.70), 0.055, filled: true);
    }
  }

  @override
  bool shouldRepaint(covariant FoodMarkPainter old) =>
      old.markKey != markKey ||
      old.ink != ink ||
      old.level != level ||
      old.rtl != rtl ||
      old.pen != pen;
}
