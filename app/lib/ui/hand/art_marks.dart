/// The product's illustrations, drawn rather than licensed.
///
/// ## Why these are painted and not pictures
///
/// Until this change `app/assets/art/` shipped 57 WebP illustrations at three
/// densities, about 4.8 MB, with **no licence record for any of them**. Worse,
/// `cupcake.webp` was byte-for-byte the cupcake on the Sweet Tooth divider of
/// the owner's `Rahoma's Recipe Book.pdf`, a Canva document. Canva's Content
/// Licence Agreement permits using an element **within a design** and
/// explicitly prohibits extracting one and shipping it as a stand-alone asset,
/// which is exactly what an illustration inside an app binary is. The owner
/// confirmed the source and asked for the designs without the exposure, so the
/// pack was deleted and every placement it served is drawn here instead.
///
/// `assets/art/LICENCE.md` keeps that finding as history. Read it before ever
/// adding a stock asset to this product.
///
/// Drawing them settles the question by construction. A [CustomPainter] is
/// licence-clean, costs nothing in binary size, scales to any density without
/// three WebP variants, and takes its colours from the product rather than from
/// whatever palette a stock contributor happened to use.
///
/// ## They were line drawings first, and that was the wrong answer
///
/// The first version of this file drew all 32 in a single thin rose ink. The
/// owner looked at it and rejected it, and he was right: what he had asked for
/// was clean, flat, colourful illustrations, and a page of one-ink line
/// drawings is none of those three.
///
/// The licensed sets were then compared properly — Microsoft Fluent Emoji
/// (MIT), Twemoji, OpenMoji, Noto — and the table in `assets/art/LICENCE.md`
/// records why none of them could be used. The short version is that it was
/// never the licence that was binding. Fluent Emoji is MIT and its objects are
/// excellent; its people all have a face, a skin tone and visible hair, and
/// twelve of the marks below are a woman's body. No openly licensed flat
/// illustration set draws a faceless, hairless human figure.
///
/// So the geometry stayed and the paint changed. See `art_palette.dart`: every
/// mark has a solid fill and a deeper line, plus a second colour where part of
/// a shape is not the colour of the rest of it. The marks are flat and
/// colourful now, and still cost nothing.
///
/// This is the same move `food_marks.dart` already made for the recipe cards,
/// extended across the whole product. Where a shape already exists there — a
/// fried egg, a pancake stack, a pot — this file **delegates** to
/// [FoodMarkPainter] rather than drawing a second, slightly different one.
///
/// ## Thirty-two marks for what used to be fifty-seven files
///
/// The old set named subjects, not shapes. `running`, `run_side`, `jogger` and
/// `dumbbell_run` were four files of a woman running; `bowl_salad`,
/// `bowl_green`, `salad_blue` and `salad_wood` were four bowls of leaves. At
/// 92 pt on a page, in one ink, those are one drawing each — and four
/// near-identical drawings would be decoration pretending to be information,
/// which is the defect `app_art.dart` already forbids on food rows.
///
/// So the vocabulary is **one name per drawing**, and [AppArt.forScreen] in
/// `screen_art.dart` names the drawing it wants. The test that matters is not
/// how many marks exist but whether a woman can tell two screens apart:
/// `screen_art_test.dart` asserts every screen still draws at least one, and
/// that no screen draws the same mark twice — a check the old set could not
/// even express, because two different file names could be the same picture.
///
/// ## How a figure is drawn, and the one thing left out of it
///
/// Twelve marks are her — eleven whole bodies and one flexed arm. Every figure
/// has a **plain circle for a head**: no face, no hair, no covering. Every one
/// is also a **single flat colour**, head and limbs alike, so there is no skin
/// tone either. That is a decision, not an omission. This app is for women in
/// Egypt, where whether a woman's hair is covered is hers to decide and not a
/// thing an empty-state drawing should take a position on. The Canva pack drew
/// loose hair, a bare midriff and a specific complexion on every figure, and so
/// does every licensed set that was considered as its replacement. A rose
/// pictogram says "a woman training" and stops there.
///
/// `app_art_test.dart` asserts it rather than trusting it: every name in
/// [figures] is [ArtTones.rose] and none of them has an entry in [accentFor],
/// because it takes a second colour to draw a face or a covering.
///
/// Every mark stands on the same baseline, [handMarkBaseline], so two marks
/// side by side in [ScreenArtStrip] sit on the pencil rule under them instead
/// of floating at different heights — which the old pack, being square images
/// with their own internal margins, never managed.
///
/// The figures always did. Nothing else did: ground strokes were drawn at 0.90
/// and objects stopped wherever the shape ended, so R01 — `dumbbells` beside
/// `running` — was a planted runner next to a dumbbell hovering 18 points of
/// the box above the rule. The number is one constant now, in `food_marks.dart`
/// where both painters can reach it, and every mark below refers to it instead
/// of repeating a literal.
///
/// ## One pen across both painters
///
/// Six of these marks are shapes `food_marks.dart` draws, and it draws them
/// with a heavier pen: the recipe card's 0.032 nib against this file's 0.026,
/// and 1.64x the wobble. Borrowed unchanged, that put two pen weights side by
/// side at the top of E05, where `pasta` (borrowed) sits next to `buddha_bowl`
/// (native). [HandMarkPen] makes the pen a parameter and [ArtMarkPainter.pen]
/// goes down with the shape, so a borrowed mark is drawn in the same hand
/// as the mark beside it while the recipe cards keep the pen they were drawn
/// with.
///
/// ## They obey the rules the hand layer already has
///
/// `hand_marks.dart` opens with them: a mark is decoration over content that
/// already says what it means, carries no information on its own, takes no tap,
/// and is not read out. [ArtMark] wraps every drawing in `ExcludeSemantics`,
/// because the screen beside it already says what it is about.
library;

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../theme/hand_tokens.dart';
import 'art_palette.dart';
import 'food_marks.dart';
import 'hand_geometry.dart';

/// One drawn illustration, sized to [size] and excluded from the semantics
/// tree.
///
/// [markKey] is a name from `AppArt.all`. An unknown name draws the fallback
/// rather than nothing: a blank where a drawing should be reads as a failed
/// image load, and `app_art_test.dart` catches the name before a woman does.
class ArtMark extends StatelessWidget {
  const ArtMark({
    super.key,
    required this.markKey,
    this.size = 92,
    this.ink = HandInk.ink,
    this.level = HandLevel.expressive,
  });

  final String markKey;
  final double size;

  /// The page's own pen. A mark is never a second colour: it is a drawing in
  /// the ink the page is already written with.
  final Color ink;

  final HandLevel level;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: ArtMarkPainter(
            markKey: markKey,
            ink: ink,
            level: level,
            // Directional marks face the way the page is read. A runner
            // heading into the left margin of an Arabic screen is running
            // backwards, exactly as `HandArrow` would be pointing backwards.
            rtl: Directionality.maybeOf(context) == TextDirection.rtl,
          ),
        ),
      ),
    );
  }
}

/// The painter. Every shape is drawn in a 0..1 box and scaled, so one mark is
/// the same drawing at 64 pt inside an empty state and at 128 pt as a hero.
class ArtMarkPainter extends CustomPainter {
  ArtMarkPainter({
    required this.markKey,
    required this.ink,
    this.level = HandLevel.expressive,
    this.rtl = false,
    this.pen = artPen,
  });

  final String markKey;

  /// The page's pen. Since the set became coloured this is only the fallback
  /// for a name with no entry in [toneFor] — which, because `app_art_test`
  /// fails the build on one, means in practice never. It is kept because
  /// [ArtMark] still takes it and because a mark drawn in one ink is what the
  /// recipe cards still want.
  final Color ink;

  final HandLevel level;
  final bool rtl;

  /// The pen to draw with, native shapes and borrowed ones alike. It is a
  /// field rather than a constant read at the point of use so that a test can
  /// hand in a different one and see BOTH kinds of mark change with it.
  final HandMarkPen pen;

  /// The pen these marks are drawn with, and the one handed down to
  /// `food_marks.dart` for the six shapes borrowed from it.
  ///
  /// Thinner than the recipe card's 0.032: these carry limbs and frames rather
  /// than one silhouette, and at 0.032 a figure's arms close up into a blob.
  static const HandMarkPen artPen = HandMarkPen(
    strokeFactor: 0.026,
    minStroke: 1.1,
    wobbleReference: 92,
  );

  /// Art names that are one of `food_marks.dart`'s shapes rather than a
  /// drawing of their own, so a fried egg is the same fried egg wherever it
  /// appears in the product.
  ///
  /// A map rather than six `case`s because the pairing is a fact the tests
  /// need: [facing] and `FoodMarkPainter.facing` have to agree about these six
  /// or a borrowed mark flips in one place and not the other.
  /// The marks that are a body rather than a thing.
  ///
  /// They are drawn with a heavier nib than the objects, and the reason is
  /// structural rather than decorative. An object is mostly closed shapes, so
  /// colouring the set gave it a solid body straight away — a bag, a bowl, an
  /// apple all filled in. A figure is a small filled torso with four open
  /// polylines coming off it, and an open polyline cannot be filled, so at the
  /// object's nib the women came out as spindly wire next to solid fruit. The
  /// limbs ARE the figure, so the limbs have to carry an object's worth of
  /// weight.
  ///
  /// [figureNib] is the multiplier. It is applied to whatever [pen] is handed
  /// in rather than baked into [artPen], so a test that swaps the pen still
  /// sees every mark move with it.
  static const Set<String> figures = {
    'running',
    'dance',
    'strong_arms',
    'squat_weights',
    'lunge_kneeling',
    'lunge_warrior',
    'plank',
    'stretch_seated',
    'side_stretch',
    'rest_floor',
    'meditation',
    'overhead_raise',
  };

  /// How much heavier a figure's nib is than an object's. See [figures].
  static const double figureNib = 1.9;

  /// What colour each mark is, and where a second colour goes.
  ///
  /// The whole set is painted from the twelve tones in `art_palette.dart`
  /// rather than from one colour each: thirty-two unrelated colours is a swatch
  /// sheet, and two bowls of leaves on one screen have to look like they came
  /// from the same hand.
  ///
  /// **Every figure is [ArtTones.rose], head included.** There is no skin tone
  /// in this set and no hair, for the reason set out at the top of this file
  /// and in `art_palette.dart`: whether a woman covers her hair is hers to
  /// decide, and so is what colour she is.
  ///
  /// `app_art_test.dart` asserts every name in `AppArt.all` has an entry, so a
  /// mark cannot be added and silently come out in the fallback ink.
  static const Map<String, ArtTone> toneFor = {
    // Her: one colour, always.
    'running': ArtTones.rose,
    'dance': ArtTones.rose,
    'strong_arms': ArtTones.rose,
    'squat_weights': ArtTones.rose,
    'lunge_kneeling': ArtTones.rose,
    'lunge_warrior': ArtTones.rose,
    'plank': ArtTones.rose,
    'stretch_seated': ArtTones.rose,
    'side_stretch': ArtTones.rose,
    'rest_floor': ArtTones.rose,
    'meditation': ArtTones.rose,
    'overhead_raise': ArtTones.rose,
    // Kit. Metal is slate, what she wears or carries is not, so a strip of
    // three pieces of equipment is not three grey objects.
    'dumbbells': ArtTones.slate,
    'boxing_gloves': ArtTones.ember,
    'yoga_mat': ArtTones.teal,
    'trainers': ArtTones.plum,
    'gym_bag': ArtTones.berry,
    'spin_bike': ArtTones.slate,
    'headphones': ArtTones.plum,
    // Food. Leaves green, bread amber, crockery cream, meat and red fruit
    // ember — the colour says what it is before the shape does.
    'bowl_salad': ArtTones.leaf,
    'buddha_bowl': ArtTones.cream,
    'plate_mixed': ArtTones.cream,
    'steak': ArtTones.ember,
    'toast_egg': ArtTones.cream,
    'breakfast': ArtTones.amber,
    'bruschetta': ArtTones.amber,
    'pasta': ArtTones.slate,
    'fruit_basket': ArtTones.amber,
    'apple': ArtTones.ember,
    'grapes': ArtTones.berry,
    'watermelon': ArtTones.ember,
    'nuts': ArtTones.amber,
  };

  /// The second colour, for the marks that have a part which is not the colour
  /// of the rest: an apple's leaf, a yolk in its white, the leaves in a bowl.
  ///
  /// Deliberately short. A mark with three colours in it at 92 pt is a diagram.
  static const Map<String, ArtTone> accentFor = {
    'buddha_bowl': ArtTones.leaf,
    'toast_egg': ArtTones.yolk,
    'breakfast': ArtTones.yolk,
    'bruschetta': ArtTones.leaf,
    'apple': ArtTones.leaf,
    'grapes': ArtTones.leaf,
    'watermelon': ArtTones.leaf,
    'fruit_basket': ArtTones.ember,
    'plate_mixed': ArtTones.leaf,
    'bowl_salad': ArtTones.cream,
    'steak': ArtTones.cream,
    'pasta': ArtTones.ember,
    'trainers': ArtTones.rose,
    'spin_bike': ArtTones.rose,
    'gym_bag': ArtTones.rose,
    'boxing_gloves': ArtTones.cream,
  };

  static const Map<String, String> borrowed = {
    'bowl_salad': FoodMarks.saladBowl,
    'steak': FoodMarks.steak,
    'toast_egg': FoodMarks.friedEgg,
    'breakfast': FoodMarks.pancakeStack,
    'bruschetta': FoodMarks.flatbread,
    'pasta': FoodMarks.pot,
  };

  /// Marks with a front and a back, which turn round in a right-to-left page.
  ///
  /// Everything else — a dumbbell, a bowl, a seated figure seen head-on — is
  /// symmetrical enough that flipping it would only change which way its
  /// hand-drawn wobble leans, so it is left alone.
  ///
  /// `steak` is here because the drawing has a bone down one side. It is also
  /// in `FoodMarkPainter.facing`, since the same shape is directional on a
  /// recipe card; [_draw] stops the two flips from cancelling each other.
  static const Set<String> facing = {
    'running',
    'dance',
    'strong_arms',
    'squat_weights',
    'lunge_kneeling',
    'plank',
    'stretch_seated',
    'side_stretch',
    'rest_floor',
    'trainers',
    'spin_bike',
    'boxing_gloves',
    'plate_mixed',
    'steak',
  };

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    if (rtl && facing.contains(markKey)) {
      canvas.save();
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }
    _draw(canvas, size, s);
    if (rtl && facing.contains(markKey)) canvas.restore();
  }

  void _draw(Canvas canvas, Size size, double s) {
    // Seeded from the name, so a given mark wobbles the same way every time it
    // is drawn. A mark that shivered on every rebuild would read as a glitch
    // rather than as a hand.
    final seed = handSeed(['art-mark', markKey]);
    // The mark's own two colours. Everything below draws through `tone` and
    // `accent` and never reaches for `ink` again, so changing what a mark is
    // made of is an edit to [toneFor] rather than to its geometry.
    final tone = toneFor[markKey] ?? ArtTone(ink.withValues(alpha: 0.12), ink);
    final accent = accentFor[markKey] ?? tone;
    final nib = pen.widthFor(s) * (figures.contains(markKey) ? figureNib : 1.0);
    final stroke = Paint()
      ..color = tone.line
      ..style = PaintingStyle.stroke
      ..strokeWidth = nib
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()
      ..color = tone.fill
      ..style = PaintingStyle.fill;
    final solid = Paint()
      ..color = tone.line
      ..style = PaintingStyle.fill;
    final accentStroke = Paint()
      ..color = accent.line
      ..style = PaintingStyle.stroke
      ..strokeWidth = nib
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final accentFill = Paint()
      ..color = accent.fill
      ..style = PaintingStyle.fill;

    void line(
      List<Offset> pts, {
      bool close = false,
      bool filled = false,
      bool second = false,
    }) {
      final scaled = [for (final p in pts) Offset(p.dx * s, p.dy * s)];
      final path = smoothPath(
        perturbLoop(scaled, seed: seed, wobble: pen.wobbleFor(s, level)),
        close: close,
      );
      if (filled) canvas.drawPath(path, second ? accentFill : fill);
      canvas.drawPath(path, second ? accentStroke : stroke);
    }

    void oval(
      Offset centre,
      double rx,
      double ry, {
      bool filled = false,
      bool ink = false,
      bool second = false,
    }) {
      final pts = <Offset>[
        for (var i = 0; i <= 22; i++)
          Offset(
            centre.dx + rx * math.cos(i / 22 * 2 * math.pi),
            centre.dy + ry * math.sin(i / 22 * 2 * math.pi),
          ),
      ];
      if (ink) {
        final scaled = [for (final p in pts) Offset(p.dx * s, p.dy * s)];
        canvas.drawPath(
          smoothPath(
            perturbLoop(scaled, seed: seed, wobble: pen.wobbleFor(s, level)),
            close: true,
          ),
          solid,
        );
        return;
      }
      line(pts, close: true, filled: filled, second: second);
    }

    void circle(
      Offset centre,
      double r, {
      bool filled = false,
      bool second = false,
    }) => oval(centre, r, r, filled: filled, second: second);

    /// A head. Always a plain circle: see the note at the top of this file.
    void head(Offset centre, [double r = 0.082]) =>
        circle(centre, r, filled: true);

    /// A weight plate, for the two marks that carry a bar.
    void plate(Offset centre) => oval(centre, 0.035, 0.10, filled: true);

    /// One of the shapes `food_marks.dart` already draws, rather than a second
    /// slightly different one drawn here.
    void borrow(String foodKey) => FoodMarkPainter(
      markKey: foodKey,
      ink: ink,
      level: level,
      // The colours go down with the pen, for the same reason the pen does: a
      // borrowed `pot` sitting next to a native `buddha_bowl` at the top of
      // E05 in one ink while the bowl beside it is painted would be two
      // illustrators in one header strip again, in a second medium. The recipe
      // cards pass neither and stay the one-ink drawings they were drawn as.
      tone: tone,
      accent: accentFor[markKey],
      // This file's pen, not the recipe card's. Without it the borrowed shape
      // is drawn 23% thicker and with 1.64x the wobble of the native mark next
      // to it, which is two illustrators in one header strip.
      pen: pen,
      // [paint] has already mirrored the canvas for the names in [facing], so
      // telling the inner painter to mirror as well would turn the shape back
      // the way it came. For a name that is not in [facing] the inner set is
      // the one that decides.
      rtl: rtl && !facing.contains(markKey),
    ).paint(canvas, size);

    final borrowedShape = borrowed[markKey];
    if (borrowedShape != null) {
      borrow(borrowedShape);
      return;
    }

    switch (markKey) {
      // ------------------------------------------------------- training
      case 'running':
        // One foot planted, the other swept up behind: the frame of a stride
        // that reads as movement even at 56 pt, which a two-feet-down figure
        // does not.
        head(const Offset(0.60, 0.16));
        line(
          [
            const Offset(0.48, 0.28),
            const Offset(0.66, 0.25),
            const Offset(0.63, 0.50),
            const Offset(0.45, 0.53),
          ],
          close: true,
          filled: true,
        );
        line([
          const Offset(0.64, 0.30),
          const Offset(0.76, 0.36),
          const Offset(0.73, 0.46),
        ]);
        line([
          const Offset(0.49, 0.31),
          const Offset(0.36, 0.33),
          const Offset(0.31, 0.24),
        ]);
        line([
          const Offset(0.57, 0.51),
          const Offset(0.67, 0.67),
          const Offset(0.68, 0.86),
          const Offset(0.77, handMarkBaseline),
        ]);
        line([
          const Offset(0.49, 0.52),
          const Offset(0.34, 0.61),
          const Offset(0.23, 0.73),
          const Offset(0.15, 0.72),
        ]);

      case 'dance':
        // One arm thrown overhead, the weight on one leg. The only mark in the
        // set that is not doing anything measurable, which is the point: M and
        // C screens about people, not about sets and reps.
        head(const Offset(0.44, 0.15));
        line(
          [
            const Offset(0.35, 0.27),
            const Offset(0.52, 0.25),
            const Offset(0.58, 0.49),
            const Offset(0.39, 0.51),
          ],
          close: true,
          filled: true,
        );
        line([
          const Offset(0.51, 0.28),
          const Offset(0.64, 0.17),
          const Offset(0.76, 0.11),
        ]);
        // The far arm curves out and DOWN to hip height. Angled up, it read as
        // a third leg coming out of the shoulder.
        line([
          const Offset(0.36, 0.30),
          const Offset(0.24, 0.41),
          const Offset(0.16, 0.36),
        ]);
        line([
          const Offset(0.51, 0.50),
          const Offset(0.55, 0.69),
          const Offset(0.53, 0.87),
          const Offset(0.62, handMarkBaseline),
        ]);
        line([
          const Offset(0.44, 0.51),
          const Offset(0.34, 0.67),
          const Offset(0.38, 0.86),
          const Offset(0.29, handMarkBaseline),
        ]);

      case 'strong_arms':
        // An arm, not a figure. It is the mark for finishing a session and for
        // a personal best, and a whole body at that moment is a smaller
        // gesture than one arm filling the frame.
        //
        // Drawn as ONE closed silhouette rather than as strokes for the upper
        // arm, the forearm and the fist. Three separate strokes meeting at an
        // elbow read as a bent stick; the silhouette, with the bicep as a bulge
        // along its top edge, is what makes it an arm.
        line(
          [
            const Offset(0.09, handMarkBaseline),
            const Offset(0.22, handMarkBaseline),
            const Offset(0.36, handMarkBaseline),
            const Offset(0.60, 0.80),
            const Offset(0.75, 0.66),
            const Offset(0.81, 0.46),
            const Offset(0.78, 0.26),
            const Offset(0.62, 0.20),
            const Offset(0.51, 0.31),
            const Offset(0.55, 0.50),
            const Offset(0.46, 0.62),
            const Offset(0.33, 0.46),
            const Offset(0.19, 0.51),
            const Offset(0.09, 0.66),
          ],
          close: true,
          filled: true,
        );
        // The crease at the inside of the elbow, which is what tells the eye
        // the arm is bent rather than simply a curved shape.
        line([const Offset(0.36, 0.58), const Offset(0.49, 0.64)]);
        line([const Offset(0.58, 0.40), const Offset(0.76, 0.36)]);

      case 'squat_weights':
        // The bar across the shoulders is what separates this from a lunge at
        // a glance, so it is drawn first and runs the full width.
        line([const Offset(0.10, 0.28), const Offset(0.90, 0.28)]);
        plate(const Offset(0.12, 0.28));
        plate(const Offset(0.88, 0.28));
        head(const Offset(0.44, 0.15), 0.078);
        line(
          [
            const Offset(0.34, 0.30),
            const Offset(0.56, 0.30),
            const Offset(0.50, 0.56),
            const Offset(0.32, 0.54),
          ],
          close: true,
          filled: true,
        );
        line([const Offset(0.36, 0.31), const Offset(0.24, 0.30)]);
        line([const Offset(0.56, 0.31), const Offset(0.70, 0.30)]);
        line([
          const Offset(0.44, 0.55),
          const Offset(0.68, 0.60),
          const Offset(0.64, 0.86),
          const Offset(0.74, handMarkBaseline),
        ]);
        line([
          const Offset(0.38, 0.56),
          const Offset(0.56, 0.63),
          const Offset(0.50, handMarkBaseline),
        ]);

      case 'lunge_kneeling':
        // Front knee up, back knee down. Distinct from `lunge_warrior` at a
        // glance only because the back shin lies along the floor, so the floor
        // is drawn: without it the back leg reads as a second stride and the
        // two lunges become the same mark. It is drawn ON the shared rule, not
        // two points below it, so a figure beside an object is standing on the
        // same floor the object rests on.
        line([
          const Offset(0.06, handMarkBaseline),
          const Offset(0.94, handMarkBaseline),
        ]);
        head(const Offset(0.32, 0.15), 0.078);
        line(
          [
            const Offset(0.24, 0.27),
            const Offset(0.42, 0.27),
            const Offset(0.45, 0.53),
            const Offset(0.26, 0.55),
          ],
          close: true,
          filled: true,
        );
        line([const Offset(0.26, 0.31), const Offset(0.21, 0.50)]);
        line([
          const Offset(0.42, 0.53),
          const Offset(0.66, 0.57),
          const Offset(0.68, 0.86),
          const Offset(0.78, handMarkBaseline),
        ]);
        line([
          const Offset(0.31, 0.55),
          const Offset(0.27, 0.86),
          const Offset(0.11, handMarkBaseline),
          const Offset(0.06, 0.80),
        ]);

      case 'lunge_warrior':
        // Warrior II: level arms, wide stance, and the one mark in the set
        // that is symmetrical, which is why it carries the screens about
        // holding a position rather than repeating one.
        head(const Offset(0.50, 0.14));
        line(
          [
            const Offset(0.42, 0.26),
            const Offset(0.58, 0.26),
            const Offset(0.57, 0.50),
            const Offset(0.43, 0.50),
          ],
          close: true,
          filled: true,
        );
        line([const Offset(0.43, 0.29), const Offset(0.10, 0.33)]);
        line([const Offset(0.57, 0.29), const Offset(0.90, 0.33)]);
        line([
          const Offset(0.46, 0.50),
          const Offset(0.30, 0.67),
          const Offset(0.22, 0.86),
          const Offset(0.12, handMarkBaseline),
        ]);
        line([
          const Offset(0.54, 0.50),
          const Offset(0.72, 0.68),
          const Offset(0.82, 0.86),
          const Offset(0.91, handMarkBaseline),
        ]);

      case 'plank':
        // A body held on its forearms. Read as a diagonal, which is why the
        // ground line under the elbows is drawn: without it the figure looks
        // like it is falling over rather than holding still.
        line([
          const Offset(0.10, handMarkBaseline),
          const Offset(0.36, handMarkBaseline),
        ]);
        line([const Offset(0.30, 0.87), const Offset(0.29, 0.64)]);
        head(const Offset(0.20, 0.58), 0.074);
        line(
          [
            const Offset(0.28, 0.60),
            const Offset(0.56, 0.70),
            const Offset(0.54, 0.78),
            const Offset(0.28, 0.70),
          ],
          close: true,
          filled: true,
        );
        line([
          const Offset(0.55, 0.74),
          const Offset(0.78, 0.83),
          const Offset(0.88, handMarkBaseline),
        ]);
        line([const Offset(0.88, handMarkBaseline), const Offset(0.86, 0.80)]);

      case 'stretch_seated':
        // Sitting, legs out along the floor, reaching forward over them. The
        // calm counterpart to `side_stretch`, and the mark the onboarding
        // cards use.
        //
        // The floor line comes first and the legs lie on it as a long closed
        // shape, because the earlier version drew the legs as one stroke and
        // the whole mark collapsed into an unreadable hunch.
        line([
          const Offset(0.10, handMarkBaseline),
          const Offset(0.90, handMarkBaseline),
        ]);
        line(
          [
            const Offset(0.20, 0.76),
            const Offset(0.74, 0.80),
            const Offset(0.74, handMarkBaseline),
            const Offset(0.20, handMarkBaseline),
          ],
          close: true,
          filled: true,
        );
        line([const Offset(0.74, 0.82), const Offset(0.82, 0.70)]);
        line(
          [
            const Offset(0.14, 0.80),
            const Offset(0.26, 0.52),
            const Offset(0.42, 0.56),
            const Offset(0.32, 0.84),
          ],
          close: true,
          filled: true,
        );
        head(const Offset(0.44, 0.44), 0.082);
        line([
          const Offset(0.38, 0.56),
          const Offset(0.58, 0.66),
          const Offset(0.72, 0.76),
        ]);

      case 'side_stretch':
        // Standing, one arm arcing over the head. Reads as reaching rather
        // than as waving because the arm is a long arc that carries past the
        // head and the far arm stays down along the body.
        head(const Offset(0.38, 0.17), 0.078);
        line(
          [
            const Offset(0.31, 0.29),
            const Offset(0.47, 0.27),
            const Offset(0.55, 0.52),
            const Offset(0.36, 0.54),
          ],
          close: true,
          filled: true,
        );
        line([
          const Offset(0.45, 0.30),
          const Offset(0.54, 0.16),
          const Offset(0.68, 0.14),
          const Offset(0.78, 0.24),
        ]);
        line([
          const Offset(0.34, 0.32),
          const Offset(0.26, 0.44),
          const Offset(0.30, 0.55),
        ]);
        line([
          const Offset(0.42, 0.53),
          const Offset(0.40, 0.86),
          const Offset(0.31, handMarkBaseline),
        ]);
        line([
          const Offset(0.51, 0.53),
          const Offset(0.54, 0.86),
          const Offset(0.63, handMarkBaseline),
        ]);

      case 'rest_floor':
        // Lying down, one knee drawn up. Used wherever the product is telling
        // her to stop, so nothing in it is doing work: the raised knee is the
        // only thing off the floor and it is a rest position, not a movement.
        line([
          const Offset(0.06, handMarkBaseline),
          const Offset(0.94, handMarkBaseline),
        ]);
        head(const Offset(0.14, 0.75), 0.082);
        line(
          [
            const Offset(0.22, 0.70),
            const Offset(0.50, 0.74),
            const Offset(0.50, handMarkBaseline),
            const Offset(0.22, 0.87),
          ],
          close: true,
          filled: true,
        );
        line([
          const Offset(0.48, 0.78),
          const Offset(0.62, 0.56),
          const Offset(0.74, 0.86),
          const Offset(0.84, handMarkBaseline),
        ]);
        line([const Offset(0.50, 0.86), const Offset(0.88, handMarkBaseline)]);
        line([const Offset(0.26, 0.86), const Offset(0.44, handMarkBaseline)]);

      case 'meditation':
        // The most-placed mark in the product: her cycle, her privacy, the
        // safety centre, every screen where she waits. Seated head-on and
        // perfectly still, so it never suggests effort on a screen that is
        // asking her for none.
        head(const Offset(0.50, 0.18), 0.095);
        line(
          [
            const Offset(0.38, 0.31),
            const Offset(0.62, 0.31),
            const Offset(0.67, 0.63),
            const Offset(0.33, 0.63),
          ],
          close: true,
          filled: true,
        );
        line(
          [
            const Offset(0.22, 0.66),
            const Offset(0.34, 0.83),
            const Offset(0.50, handMarkBaseline),
            const Offset(0.66, 0.83),
            const Offset(0.78, 0.66),
          ],
          close: true,
          filled: true,
        );
        line([const Offset(0.40, 0.79), const Offset(0.60, 0.79)]);
        line([
          const Offset(0.39, 0.36),
          const Offset(0.25, 0.56),
          const Offset(0.28, 0.68),
        ]);
        line([
          const Offset(0.61, 0.36),
          const Offset(0.75, 0.56),
          const Offset(0.72, 0.68),
        ]);

      case 'overhead_raise':
        // A bar above the head: a press, a raise and a pull-up are all "a bar
        // over her and her arms straight to it" at this size, so they are one
        // drawing rather than three that differ by a wrist angle nobody sees.
        line([const Offset(0.12, 0.13), const Offset(0.88, 0.13)]);
        plate(const Offset(0.14, 0.13));
        plate(const Offset(0.86, 0.13));
        line([const Offset(0.41, 0.36), const Offset(0.33, 0.15)]);
        line([const Offset(0.59, 0.36), const Offset(0.67, 0.15)]);
        head(const Offset(0.50, 0.32), 0.075);
        line(
          [
            const Offset(0.42, 0.42),
            const Offset(0.58, 0.42),
            const Offset(0.57, 0.64),
            const Offset(0.43, 0.64),
          ],
          close: true,
          filled: true,
        );
        line([
          const Offset(0.46, 0.64),
          const Offset(0.44, 0.86),
          const Offset(0.35, handMarkBaseline),
        ]);
        line([
          const Offset(0.54, 0.64),
          const Offset(0.56, 0.86),
          const Offset(0.65, handMarkBaseline),
        ]);

      case 'dumbbells':
        // Lying on the rule rather than hovering in the middle of the box. It
        // used to end at 0.70, and R01 draws it beside `running`: a planted
        // runner next to a floating dumbbell. Same proportions, moved down and
        // grown to reach [handMarkBaseline].
        line([const Offset(0.28, 0.65), const Offset(0.72, 0.65)]);
        line(
          [
            const Offset(0.10, 0.42), const Offset(0.26, 0.42),
            const Offset(0.26, handMarkBaseline),
            // A point in the middle of each base: the outline is smoothed
            // through the points it is given, so a base drawn corner to corner
            // bows below the rule by more than the nib is wide.
            const Offset(0.18, handMarkBaseline),
            const Offset(0.10, handMarkBaseline),
          ],
          close: true,
          filled: true,
        );
        line(
          [
            const Offset(0.74, 0.42),
            const Offset(0.90, 0.42),
            const Offset(0.90, handMarkBaseline),
            const Offset(0.82, handMarkBaseline),
            const Offset(0.74, handMarkBaseline),
          ],
          close: true,
          filled: true,
        );
        line([const Offset(0.28, 0.52), const Offset(0.28, 0.78)]);
        line([const Offset(0.72, 0.52), const Offset(0.72, 0.78)]);

      case 'boxing_gloves':
        // One glove, in profile, facing left. It was a fist blob with a small
        // blob beside it and QA read it as two blobs, because the three things
        // that say "glove" were missing: a cuff at the wrist, a thumb that is
        // its own lobe with daylight between it and the fist, and lacing.
        //
        // The fist first, with the knuckle edge to the left.
        line(
          [
            const Offset(0.30, 0.38),
            const Offset(0.42, 0.22),
            const Offset(0.62, 0.20),
            const Offset(0.78, 0.30),
            const Offset(0.82, 0.48),
            const Offset(0.74, 0.62),
            const Offset(0.50, 0.66),
            const Offset(0.34, 0.58),
          ],
          close: true,
          filled: true,
        );
        // The seam over the knuckles: the padded front is a separate panel,
        // and that line is half of why a glove is not a mitten.
        line([
          const Offset(0.40, 0.25),
          const Offset(0.36, 0.42),
          const Offset(0.44, 0.60),
        ]);
        // The thumb, drawn as its own closed lobe below and left of the fist
        // with a gap between the two outlines.
        line(
          [
            const Offset(0.31, 0.50),
            const Offset(0.19, 0.55),
            const Offset(0.18, 0.66),
            const Offset(0.29, 0.69),
            const Offset(0.36, 0.60),
          ],
          close: true,
          filled: true,
        );
        // The cuff, down to the rule. Wider than the wrist and rolled at the
        // bottom, which is what a glove has and a fist does not.
        line(
          [
            const Offset(0.40, 0.64),
            const Offset(0.74, 0.62),
            const Offset(0.72, handMarkBaseline),
            const Offset(0.57, 0.875),
            const Offset(0.42, 0.86),
          ],
          close: true,
          filled: true,
          second: true,
        );
        line([
          const Offset(0.41, 0.80),
          const Offset(0.73, 0.78),
        ], second: true);
        // The lacing up the inside of the cuff.
        line([
          const Offset(0.57, 0.64),
          const Offset(0.56, 0.86),
        ], second: true);
        line([
          const Offset(0.50, 0.69),
          const Offset(0.64, 0.68),
        ], second: true);
        line([
          const Offset(0.50, 0.76),
          const Offset(0.64, 0.75),
        ], second: true);

      case 'yoga_mat':
        // Rolled, not laid flat: a flat mat at 92 pt is a rectangle, and a
        // rectangle is not an illustration of anything.
        //
        // The open end is an ELLIPSE rather than a circle, and it overlaps the
        // tube. A circle the height of the tube made the whole mark read as a
        // tin can; the ellipse is what says this is a roll seen end-on.
        line(
          [
            const Offset(0.30, 0.36),
            const Offset(0.84, 0.40),
            const Offset(0.84, 0.84),
            const Offset(0.56, 0.866),
            const Offset(0.30, handMarkBaseline),
          ],
          close: true,
          filled: true,
        );
        oval(const Offset(0.30, 0.62), 0.11, 0.26, filled: true);
        oval(const Offset(0.30, 0.62), 0.055, 0.13);
        line([const Offset(0.56, 0.38), const Offset(0.56, 0.86)]);
        line([const Offset(0.64, 0.39), const Offset(0.64, 0.85)]);

      case 'trainers':
        // A shoe in profile, toe to the right. The shape only reads if the
        // collar dips behind the tongue — the first version ran the upper in
        // one smooth sweep from heel to toe and came out as a bread roll.
        line(
          [
            const Offset(0.10, 0.76),
            const Offset(0.12, 0.50),
            const Offset(0.25, 0.42),
            const Offset(0.34, 0.55),
            const Offset(0.44, 0.40),
            const Offset(0.62, 0.53),
            const Offset(0.82, 0.61),
            const Offset(0.90, 0.76),
          ],
          close: true,
          filled: true,
        );
        line(
          [
            const Offset(0.07, 0.75),
            const Offset(0.91, 0.75),
            const Offset(0.91, handMarkBaseline),
            const Offset(0.07, 0.87),
          ],
          close: true,
          filled: true,
          second: true,
        );
        // Laces across the tongue, and one long line for the shoe's side
        // panel, which is the detail that says trainer rather than slipper.
        line([const Offset(0.37, 0.53), const Offset(0.45, 0.48)]);
        line([const Offset(0.41, 0.60), const Offset(0.49, 0.54)]);
        line([const Offset(0.46, 0.67), const Offset(0.54, 0.60)]);
        line([const Offset(0.20, 0.69), const Offset(0.56, 0.71)]);

      case 'gym_bag':
        // The most-placed mark in the set: B06, H03, K04, K25, O02, R11, Z01,
        // Z08 and Z11, nine screens. It was a rounded rectangle with a line
        // across it and one arc over the top, and QA read it as a wallet.
        //
        // A duffel reads by its silhouette: ends that round off, a body that
        // sags between them, a zip along the top and two handles that meet
        // above it. All four are drawn, in that order.
        line(
          [
            const Offset(0.12, 0.60), const Offset(0.26, 0.50),
            const Offset(0.50, 0.48), const Offset(0.74, 0.50),
            const Offset(0.88, 0.60),
            // A point at the middle of each end, so the ends come out rounded
            // instead of pointed: a lens reads as a purse.
            const Offset(0.90, 0.68), const Offset(0.88, 0.76),
            const Offset(0.74, 0.86), const Offset(0.50, handMarkBaseline),
            const Offset(0.26, 0.86), const Offset(0.12, 0.76),
            const Offset(0.10, 0.68),
          ],
          close: true,
          filled: true,
        );
        // The end panels. Without them the body is a pill and the pill is the
        // wallet.
        line([const Offset(0.27, 0.51), const Offset(0.26, 0.86)]);
        line([const Offset(0.73, 0.51), const Offset(0.74, 0.86)]);
        // The zip along the top, with its pull hanging off the middle.
        line([const Offset(0.20, 0.56), const Offset(0.80, 0.55)]);
        line([const Offset(0.52, 0.56), const Offset(0.55, 0.63)]);
        // Two handles, meeting above the bag.
        line([
          const Offset(0.37, 0.51),
          const Offset(0.42, 0.30),
          const Offset(0.50, 0.26),
        ], second: true);
        line([
          const Offset(0.63, 0.51),
          const Offset(0.58, 0.30),
          const Offset(0.50, 0.26),
        ], second: true);
        // The grip where the two are held together.
        line([
          const Offset(0.45, 0.31),
          const Offset(0.55, 0.31),
        ], second: true);

      case 'spin_bike':
        // Both wheels on the rule, so the bike stands rather than leans: the
        // rear one used to stop 8 points of the box short of the front one.
        circle(const Offset(0.30, 0.71), 0.17);
        circle(const Offset(0.30, 0.71), 0.05, filled: true);
        circle(const Offset(0.76, 0.76), 0.12, filled: true);
        line([
          const Offset(0.30, 0.71),
          const Offset(0.50, 0.46),
          const Offset(0.76, 0.76),
        ]);
        line([const Offset(0.50, 0.46), const Offset(0.66, 0.34)]);
        line([const Offset(0.36, 0.48), const Offset(0.54, 0.44)]);
        line([
          const Offset(0.58, 0.31),
          const Offset(0.78, 0.30),
        ], second: true);
        line([
          const Offset(0.66, 0.34),
          const Offset(0.68, 0.31),
        ], second: true);

      case 'headphones':
        line([
          const Offset(0.16, 0.64),
          const Offset(0.22, 0.30),
          const Offset(0.50, 0.18),
          const Offset(0.78, 0.30),
          const Offset(0.84, 0.64),
        ]);
        line(
          [
            const Offset(0.10, 0.62),
            const Offset(0.24, 0.62),
            const Offset(0.24, handMarkBaseline),
            const Offset(0.17, handMarkBaseline),
            const Offset(0.10, handMarkBaseline),
          ],
          close: true,
          filled: true,
        );
        line(
          [
            const Offset(0.76, 0.62),
            const Offset(0.90, 0.62),
            const Offset(0.90, handMarkBaseline),
            const Offset(0.83, handMarkBaseline),
            const Offset(0.76, handMarkBaseline),
          ],
          close: true,
          filled: true,
        );

      // ----------------------------------------------------------- food
      //
      // Six more food names are shapes `food_marks.dart` already draws for the
      // recipe cards. They are borrowed above, from [borrowed], rather than
      // redrawn here, so a fried egg is the same fried egg wherever it appears
      // in the product.
      case 'buddha_bowl':
        // Seen from above and divided, where `bowl_salad` is seen from the
        // side. That is the whole reason both exist: W06, the meal planner,
        // places them side by side and two side-view bowls would read as one
        // drawing printed twice.
        circle(const Offset(0.50, 0.53), 0.35, filled: true);
        circle(const Offset(0.50, 0.53), 0.27);
        line([const Offset(0.50, 0.26), const Offset(0.50, 0.80)]);
        line([const Offset(0.23, 0.53), const Offset(0.77, 0.53)]);
        circle(const Offset(0.38, 0.41), 0.05, filled: true, second: true);
        circle(const Offset(0.62, 0.43), 0.04, filled: true, second: true);
        circle(const Offset(0.40, 0.66), 0.04, filled: true, second: true);
        circle(const Offset(0.63, 0.65), 0.05, filled: true, second: true);

      case 'plate_mixed':
        oval(const Offset(0.44, 0.58), 0.32, 0.30, filled: true);
        oval(const Offset(0.44, 0.58), 0.24, 0.22);
        circle(const Offset(0.36, 0.52), 0.07, filled: true, second: true);
        line(
          [
            const Offset(0.48, 0.50),
            const Offset(0.60, 0.58),
            const Offset(0.46, 0.68),
            const Offset(0.38, 0.64),
          ],
          close: true,
          filled: true,
          second: true,
        );
        line([const Offset(0.84, 0.32), const Offset(0.82, handMarkBaseline)]);
        line([const Offset(0.79, 0.30), const Offset(0.80, 0.44)]);
        line([const Offset(0.89, 0.30), const Offset(0.87, 0.44)]);

      case 'fruit_basket':
        line(
          [
            const Offset(0.16, 0.54),
            const Offset(0.84, 0.54),
            const Offset(0.74, handMarkBaseline),
            const Offset(0.50, handMarkBaseline),
            const Offset(0.26, handMarkBaseline),
          ],
          close: true,
          filled: true,
        );
        line([const Offset(0.18, 0.67), const Offset(0.82, 0.67)]);
        line([const Offset(0.38, 0.55), const Offset(0.36, 0.87)]);
        line([const Offset(0.62, 0.55), const Offset(0.64, 0.87)]);
        circle(const Offset(0.33, 0.44), 0.11, filled: true, second: true);
        circle(const Offset(0.55, 0.39), 0.13, filled: true, second: true);
        circle(const Offset(0.73, 0.46), 0.09, filled: true, second: true);
        line([const Offset(0.55, 0.26), const Offset(0.70, 0.20)]);

      case 'apple':
        line(
          [
            const Offset(0.26, 0.44),
            const Offset(0.38, 0.30),
            const Offset(0.50, 0.35),
            const Offset(0.62, 0.30),
            const Offset(0.74, 0.44),
            const Offset(0.75, 0.66),
            const Offset(0.61, 0.85),
            const Offset(0.50, handMarkBaseline),
            const Offset(0.39, 0.85),
            const Offset(0.25, 0.66),
          ],
          close: true,
          filled: true,
        );
        line([
          const Offset(0.50, 0.35),
          const Offset(0.53, 0.18),
        ], second: true);
        line(
          [
            const Offset(0.53, 0.22),
            const Offset(0.68, 0.14),
            const Offset(0.66, 0.27),
          ],
          close: true,
          filled: true,
          second: true,
        );

      case 'grapes':
        circle(const Offset(0.34, 0.47), 0.10, filled: true);
        circle(const Offset(0.52, 0.44), 0.10, filled: true);
        circle(const Offset(0.69, 0.49), 0.10, filled: true);
        circle(const Offset(0.43, 0.62), 0.10, filled: true);
        circle(const Offset(0.61, 0.64), 0.10, filled: true);
        circle(const Offset(0.51, handMarkBaseline - 0.10), 0.10, filled: true);
        line([
          const Offset(0.52, 0.34),
          const Offset(0.50, 0.18),
        ], second: true);
        line(
          [
            const Offset(0.50, 0.22),
            const Offset(0.34, 0.14),
            const Offset(0.36, 0.27),
          ],
          close: true,
          filled: true,
          second: true,
        );

      case 'watermelon':
        line(
          [
            const Offset(0.12, 0.62),
            const Offset(0.50, 0.20),
            const Offset(0.88, 0.62),
            const Offset(0.72, 0.82),
            const Offset(0.50, handMarkBaseline),
            const Offset(0.28, 0.82),
          ],
          close: true,
          filled: true,
        );
        line([
          const Offset(0.20, 0.63),
          const Offset(0.50, 0.31),
          const Offset(0.80, 0.63),
        ], second: true);
        // Solid in the LINE colour, not the fill: a seed filled with the same
        // flesh colour it sits on is an outline of a seed, which at 30 pt
        // beside a list row is nothing at all.
        oval(const Offset(0.40, 0.58), 0.032, 0.032, ink: true);
        oval(const Offset(0.58, 0.55), 0.032, 0.032, ink: true);
        oval(const Offset(0.50, 0.73), 0.032, 0.032, ink: true);

      case 'nuts':
        line(
          [
            const Offset(0.20, 0.52),
            const Offset(0.32, 0.42),
            const Offset(0.44, 0.52),
            const Offset(0.32, 0.66),
          ],
          close: true,
          filled: true,
        );
        line([const Offset(0.26, 0.50), const Offset(0.36, 0.58)]);
        line(
          [
            const Offset(0.52, 0.38),
            const Offset(0.66, 0.30),
            const Offset(0.76, 0.42),
            const Offset(0.62, 0.54),
          ],
          close: true,
          filled: true,
        );
        line([const Offset(0.58, 0.38), const Offset(0.69, 0.44)]);
        line(
          [
            const Offset(0.42, 0.70),
            const Offset(0.58, 0.60),
            const Offset(0.72, 0.72),
            const Offset(0.56, handMarkBaseline),
          ],
          close: true,
          filled: true,
        );
        line([const Offset(0.50, 0.70), const Offset(0.62, 0.77)]);

      default:
        // A name with no drawing behind it falls back to the yoga mat rather
        // than to nothing, because a blank corner reads as a failed image
        // load. `app_art_test.dart` asserts every name in `AppArt.all` is a
        // case above, so reaching here is a bug caught before release.
        //
        // Deliberately not `yoga_mat`'s own coordinates: the test tells "this
        // name drew the fallback" from "this name drew a mat" by comparing the
        // two pictures, and two shapes separated only by their wobble seed
        // would make that comparison a coin toss.
        line(
          [
            const Offset(0.28, 0.48),
            const Offset(0.84, 0.51),
            const Offset(0.84, 0.85),
            const Offset(0.56, 0.87),
            const Offset(0.28, handMarkBaseline),
          ],
          close: true,
          filled: true,
        );
        circle(const Offset(0.28, 0.68), 0.20, filled: true);
        circle(const Offset(0.28, 0.68), 0.09);
    }
  }

  @override
  bool shouldRepaint(covariant ArtMarkPainter old) =>
      old.markKey != markKey ||
      old.ink != ink ||
      old.level != level ||
      old.rtl != rtl ||
      old.pen != pen;
}
