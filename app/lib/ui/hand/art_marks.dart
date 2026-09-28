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
/// Drawing them settles the question by construction. A [CustomPainter] in the
/// app's existing hand language is licence-clean, costs nothing in binary size,
/// scales to any density without three WebP variants, takes its colour from the
/// theme, and looks more like this product than any stock pack could: the old
/// set was flat saturated vector art in magenta and lime that sat on the warm
/// page like a sticker, while these are pen drawings on the same page the rest
/// of the Annotated Edition is written on.
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
/// Eleven marks are a woman's body. Every one of them has a **plain circle for
/// a head**: no face, no hair, no covering. That is a decision, not an
/// omission. This app is for women in Egypt, where whether a woman's hair is
/// covered is hers to decide and not a thing an empty-state drawing should
/// take a position on. The old pack drew loose hair on every figure. A circle
/// says "a woman training" and stops there.
///
/// Figures stand on the same baseline, feet at 0.88 of the box, so two marks
/// side by side in [ScreenArtStrip] sit on the pencil rule under them instead
/// of floating at different heights — which the old pack, being square images
/// with their own internal margins, never managed.
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
  });

  final String markKey;
  final Color ink;
  final HandLevel level;
  final bool rtl;

  /// Marks with a front and a back, which turn round in a right-to-left page.
  ///
  /// Everything else — a dumbbell, a bowl, a seated figure seen head-on — is
  /// symmetrical enough that flipping it would only change which way its
  /// hand-drawn wobble leans, so it is left alone.
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
    final stroke = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      // Thinner than a food mark's 0.032: these carry limbs and frames rather
      // than one silhouette, and at 0.032 a figure's arms close up into a blob.
      ..strokeWidth = math.max(1.1, s * 0.026)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()
      ..color = ink.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;
    final solid = Paint()
      ..color = ink
      ..style = PaintingStyle.fill;

    void line(List<Offset> pts, {bool close = false, bool filled = false}) {
      final scaled = [for (final p in pts) Offset(p.dx * s, p.dy * s)];
      final path = smoothPath(
        perturbLoop(scaled, seed: seed, wobble: level.wobble * (s / 92)),
        close: close,
      );
      if (filled) canvas.drawPath(path, fill);
      canvas.drawPath(path, stroke);
    }

    void oval(
      Offset centre,
      double rx,
      double ry, {
      bool filled = false,
      bool ink = false,
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
            perturbLoop(scaled, seed: seed, wobble: level.wobble * (s / 92)),
            close: true,
          ),
          solid,
        );
        return;
      }
      line(pts, close: true, filled: filled);
    }

    void circle(Offset centre, double r, {bool filled = false}) =>
        oval(centre, r, r, filled: filled);

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
    ).paint(canvas, size);

    switch (markKey) {
      // ------------------------------------------------------- training
      case 'running':
        // One foot planted, the other swept up behind: the frame of a stride
        // that reads as movement even at 56 pt, which a two-feet-down figure
        // does not.
        head(const Offset(0.60, 0.16));
        line([
          const Offset(0.48, 0.28), const Offset(0.66, 0.25),
          const Offset(0.63, 0.50), const Offset(0.45, 0.53),
        ], close: true, filled: true);
        line([
          const Offset(0.64, 0.30), const Offset(0.76, 0.36),
          const Offset(0.73, 0.46),
        ]);
        line([
          const Offset(0.49, 0.31), const Offset(0.36, 0.33),
          const Offset(0.31, 0.24),
        ]);
        line([
          const Offset(0.57, 0.51), const Offset(0.67, 0.67),
          const Offset(0.68, 0.87), const Offset(0.77, 0.89),
        ]);
        line([
          const Offset(0.49, 0.52), const Offset(0.34, 0.61),
          const Offset(0.23, 0.73), const Offset(0.15, 0.72),
        ]);

      case 'dance':
        // One arm thrown overhead, the weight on one leg. The only mark in the
        // set that is not doing anything measurable, which is the point: M and
        // C screens about people, not about sets and reps.
        head(const Offset(0.44, 0.15));
        line([
          const Offset(0.35, 0.27), const Offset(0.52, 0.25),
          const Offset(0.58, 0.49), const Offset(0.39, 0.51),
        ], close: true, filled: true);
        line([
          const Offset(0.51, 0.28), const Offset(0.64, 0.17),
          const Offset(0.76, 0.11),
        ]);
        // The far arm curves out and DOWN to hip height. Angled up, it read as
        // a third leg coming out of the shoulder.
        line([
          const Offset(0.36, 0.30), const Offset(0.24, 0.41),
          const Offset(0.16, 0.36),
        ]);
        line([
          const Offset(0.51, 0.50), const Offset(0.55, 0.69),
          const Offset(0.53, 0.88), const Offset(0.62, 0.89),
        ]);
        line([
          const Offset(0.44, 0.51), const Offset(0.34, 0.67),
          const Offset(0.38, 0.86), const Offset(0.29, 0.88),
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
        line([
          const Offset(0.09, 0.86), const Offset(0.36, 0.84),
          const Offset(0.60, 0.80), const Offset(0.75, 0.66),
          const Offset(0.81, 0.46), const Offset(0.78, 0.26),
          const Offset(0.62, 0.20), const Offset(0.51, 0.31),
          const Offset(0.55, 0.50), const Offset(0.46, 0.62),
          const Offset(0.33, 0.46), const Offset(0.19, 0.51),
          const Offset(0.09, 0.66),
        ], close: true, filled: true);
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
        line([
          const Offset(0.34, 0.30), const Offset(0.56, 0.30),
          const Offset(0.50, 0.56), const Offset(0.32, 0.54),
        ], close: true, filled: true);
        line([const Offset(0.36, 0.31), const Offset(0.24, 0.30)]);
        line([const Offset(0.56, 0.31), const Offset(0.70, 0.30)]);
        line([
          const Offset(0.44, 0.55), const Offset(0.68, 0.60),
          const Offset(0.64, 0.87), const Offset(0.74, 0.89),
        ]);
        line([
          const Offset(0.38, 0.56), const Offset(0.56, 0.63),
          const Offset(0.50, 0.88),
        ]);

      case 'lunge_kneeling':
        // Front knee up, back knee down. Distinct from `lunge_warrior` at a
        // glance only because the back shin lies along the floor, so the floor
        // is drawn: without it the back leg reads as a second stride and the
        // two lunges become the same mark.
        line([const Offset(0.06, 0.90), const Offset(0.94, 0.90)]);
        head(const Offset(0.32, 0.15), 0.078);
        line([
          const Offset(0.24, 0.27), const Offset(0.42, 0.27),
          const Offset(0.45, 0.53), const Offset(0.26, 0.55),
        ], close: true, filled: true);
        line([const Offset(0.26, 0.31), const Offset(0.21, 0.50)]);
        line([
          const Offset(0.42, 0.53), const Offset(0.66, 0.57),
          const Offset(0.68, 0.87), const Offset(0.78, 0.88),
        ]);
        line([
          const Offset(0.31, 0.55), const Offset(0.27, 0.87),
          const Offset(0.11, 0.88), const Offset(0.06, 0.80),
        ]);

      case 'lunge_warrior':
        // Warrior II: level arms, wide stance, and the one mark in the set
        // that is symmetrical, which is why it carries the screens about
        // holding a position rather than repeating one.
        head(const Offset(0.50, 0.14));
        line([
          const Offset(0.42, 0.26), const Offset(0.58, 0.26),
          const Offset(0.57, 0.50), const Offset(0.43, 0.50),
        ], close: true, filled: true);
        line([const Offset(0.43, 0.29), const Offset(0.10, 0.33)]);
        line([const Offset(0.57, 0.29), const Offset(0.90, 0.33)]);
        line([
          const Offset(0.46, 0.50), const Offset(0.30, 0.67),
          const Offset(0.22, 0.88), const Offset(0.12, 0.89),
        ]);
        line([
          const Offset(0.54, 0.50), const Offset(0.72, 0.68),
          const Offset(0.82, 0.88), const Offset(0.91, 0.89),
        ]);

      case 'plank':
        // A body held on its forearms. Read as a diagonal, which is why the
        // ground line under the elbows is drawn: without it the figure looks
        // like it is falling over rather than holding still.
        line([const Offset(0.10, 0.88), const Offset(0.36, 0.88)]);
        line([const Offset(0.30, 0.87), const Offset(0.29, 0.64)]);
        head(const Offset(0.20, 0.58), 0.074);
        line([
          const Offset(0.28, 0.60), const Offset(0.56, 0.70),
          const Offset(0.54, 0.78), const Offset(0.28, 0.70),
        ], close: true, filled: true);
        line([
          const Offset(0.55, 0.74), const Offset(0.78, 0.83),
          const Offset(0.88, 0.88),
        ]);
        line([const Offset(0.88, 0.88), const Offset(0.86, 0.80)]);

      case 'stretch_seated':
        // Sitting, legs out along the floor, reaching forward over them. The
        // calm counterpart to `side_stretch`, and the mark the onboarding
        // cards use.
        //
        // The floor line comes first and the legs lie on it as a long closed
        // shape, because the earlier version drew the legs as one stroke and
        // the whole mark collapsed into an unreadable hunch.
        line([const Offset(0.10, 0.90), const Offset(0.90, 0.90)]);
        line([
          const Offset(0.20, 0.76), const Offset(0.74, 0.80),
          const Offset(0.74, 0.88), const Offset(0.20, 0.88),
        ], close: true, filled: true);
        line([const Offset(0.74, 0.82), const Offset(0.82, 0.70)]);
        line([
          const Offset(0.14, 0.80), const Offset(0.26, 0.52),
          const Offset(0.42, 0.56), const Offset(0.32, 0.84),
        ], close: true, filled: true);
        head(const Offset(0.44, 0.44), 0.082);
        line([
          const Offset(0.38, 0.56), const Offset(0.58, 0.66),
          const Offset(0.72, 0.76),
        ]);

      case 'side_stretch':
        // Standing, one arm arcing over the head. Reads as reaching rather
        // than as waving because the arm is a long arc that carries past the
        // head and the far arm stays down along the body.
        head(const Offset(0.38, 0.17), 0.078);
        line([
          const Offset(0.31, 0.29), const Offset(0.47, 0.27),
          const Offset(0.55, 0.52), const Offset(0.36, 0.54),
        ], close: true, filled: true);
        line([
          const Offset(0.45, 0.30), const Offset(0.54, 0.16),
          const Offset(0.68, 0.14), const Offset(0.78, 0.24),
        ]);
        line([
          const Offset(0.34, 0.32), const Offset(0.26, 0.44),
          const Offset(0.30, 0.55),
        ]);
        line([
          const Offset(0.42, 0.53), const Offset(0.40, 0.88),
          const Offset(0.31, 0.89),
        ]);
        line([
          const Offset(0.51, 0.53), const Offset(0.54, 0.88),
          const Offset(0.63, 0.89),
        ]);

      case 'rest_floor':
        // Lying down, one knee drawn up. Used wherever the product is telling
        // her to stop, so nothing in it is doing work: the raised knee is the
        // only thing off the floor and it is a rest position, not a movement.
        line([const Offset(0.06, 0.90), const Offset(0.94, 0.90)]);
        head(const Offset(0.14, 0.75), 0.082);
        line([
          const Offset(0.22, 0.70), const Offset(0.50, 0.74),
          const Offset(0.50, 0.88), const Offset(0.22, 0.87),
        ], close: true, filled: true);
        line([
          const Offset(0.48, 0.78), const Offset(0.62, 0.56),
          const Offset(0.74, 0.86), const Offset(0.84, 0.88),
        ]);
        line([const Offset(0.50, 0.86), const Offset(0.88, 0.88)]);
        line([const Offset(0.26, 0.86), const Offset(0.44, 0.89)]);

      case 'meditation':
        // The most-placed mark in the product: her cycle, her privacy, the
        // safety centre, every screen where she waits. Seated head-on and
        // perfectly still, so it never suggests effort on a screen that is
        // asking her for none.
        head(const Offset(0.50, 0.18), 0.095);
        line([
          const Offset(0.38, 0.31), const Offset(0.62, 0.31),
          const Offset(0.67, 0.63), const Offset(0.33, 0.63),
        ], close: true, filled: true);
        line([
          const Offset(0.22, 0.66), const Offset(0.34, 0.82),
          const Offset(0.50, 0.86), const Offset(0.66, 0.82),
          const Offset(0.78, 0.66),
        ], close: true, filled: true);
        line([const Offset(0.40, 0.79), const Offset(0.60, 0.79)]);
        line([
          const Offset(0.39, 0.36), const Offset(0.25, 0.56),
          const Offset(0.28, 0.68),
        ]);
        line([
          const Offset(0.61, 0.36), const Offset(0.75, 0.56),
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
        line([
          const Offset(0.42, 0.42), const Offset(0.58, 0.42),
          const Offset(0.57, 0.64), const Offset(0.43, 0.64),
        ], close: true, filled: true);
        line([
          const Offset(0.46, 0.64), const Offset(0.44, 0.88),
          const Offset(0.35, 0.89),
        ]);
        line([
          const Offset(0.54, 0.64), const Offset(0.56, 0.88),
          const Offset(0.65, 0.89),
        ]);

      case 'dumbbells':
        line([const Offset(0.30, 0.52), const Offset(0.70, 0.52)]);
        line([
          const Offset(0.14, 0.34), const Offset(0.28, 0.34),
          const Offset(0.28, 0.70), const Offset(0.14, 0.70),
        ], close: true, filled: true);
        line([
          const Offset(0.72, 0.34), const Offset(0.86, 0.34),
          const Offset(0.86, 0.70), const Offset(0.72, 0.70),
        ], close: true, filled: true);
        line([const Offset(0.30, 0.42), const Offset(0.30, 0.62)]);
        line([const Offset(0.70, 0.42), const Offset(0.70, 0.62)]);

      case 'boxing_gloves':
        line([
          const Offset(0.24, 0.46), const Offset(0.34, 0.26),
          const Offset(0.58, 0.21), const Offset(0.76, 0.32),
          const Offset(0.80, 0.56), const Offset(0.64, 0.70),
          const Offset(0.36, 0.68),
        ], close: true, filled: true);
        line([
          const Offset(0.26, 0.50), const Offset(0.16, 0.56),
          const Offset(0.22, 0.64), const Offset(0.34, 0.62),
        ], close: true, filled: true);
        line([
          const Offset(0.40, 0.68), const Offset(0.68, 0.70),
          const Offset(0.66, 0.86), const Offset(0.40, 0.84),
        ], close: true, filled: true);
        line([const Offset(0.42, 0.77), const Offset(0.66, 0.78)]);

      case 'yoga_mat':
        // Rolled, not laid flat: a flat mat at 92 pt is a rectangle, and a
        // rectangle is not an illustration of anything.
        //
        // The open end is an ELLIPSE rather than a circle, and it overlaps the
        // tube. A circle the height of the tube made the whole mark read as a
        // tin can; the ellipse is what says this is a roll seen end-on.
        line([
          const Offset(0.30, 0.36), const Offset(0.84, 0.39),
          const Offset(0.84, 0.75), const Offset(0.30, 0.78),
        ], close: true, filled: true);
        oval(const Offset(0.30, 0.57), 0.11, 0.21, filled: true);
        oval(const Offset(0.30, 0.57), 0.055, 0.105);
        line([const Offset(0.56, 0.38), const Offset(0.56, 0.77)]);
        line([const Offset(0.64, 0.38), const Offset(0.64, 0.77)]);

      case 'trainers':
        // A shoe in profile, toe to the right. The shape only reads if the
        // collar dips behind the tongue — the first version ran the upper in
        // one smooth sweep from heel to toe and came out as a bread roll.
        line([
          const Offset(0.10, 0.72), const Offset(0.12, 0.48),
          const Offset(0.25, 0.40), const Offset(0.34, 0.52),
          const Offset(0.44, 0.38), const Offset(0.62, 0.50),
          const Offset(0.82, 0.58), const Offset(0.90, 0.72),
        ], close: true, filled: true);
        line([
          const Offset(0.07, 0.71), const Offset(0.91, 0.71),
          const Offset(0.91, 0.83), const Offset(0.07, 0.82),
        ], close: true, filled: true);
        // Laces across the tongue, and one long line for the shoe's side
        // panel, which is the detail that says trainer rather than slipper.
        line([const Offset(0.37, 0.50), const Offset(0.45, 0.45)]);
        line([const Offset(0.41, 0.57), const Offset(0.49, 0.51)]);
        line([const Offset(0.46, 0.64), const Offset(0.54, 0.57)]);
        line([const Offset(0.20, 0.66), const Offset(0.56, 0.68)]);

      case 'gym_bag':
        line([
          const Offset(0.36, 0.44), const Offset(0.50, 0.28),
          const Offset(0.64, 0.44),
        ]);
        line([
          const Offset(0.14, 0.46), const Offset(0.86, 0.46),
          const Offset(0.81, 0.80), const Offset(0.19, 0.80),
        ], close: true, filled: true);
        line([const Offset(0.16, 0.55), const Offset(0.84, 0.55)]);
        line([const Offset(0.44, 0.60), const Offset(0.56, 0.60)]);

      case 'spin_bike':
        circle(const Offset(0.30, 0.70), 0.17);
        circle(const Offset(0.30, 0.70), 0.05, filled: true);
        circle(const Offset(0.76, 0.68), 0.12, filled: true);
        line([
          const Offset(0.30, 0.70), const Offset(0.50, 0.46),
          const Offset(0.76, 0.68),
        ]);
        line([const Offset(0.50, 0.46), const Offset(0.66, 0.34)]);
        line([const Offset(0.36, 0.48), const Offset(0.54, 0.44)]);
        line([const Offset(0.58, 0.31), const Offset(0.78, 0.30)]);
        line([const Offset(0.66, 0.34), const Offset(0.68, 0.31)]);

      case 'headphones':
        line([
          const Offset(0.16, 0.60), const Offset(0.22, 0.30),
          const Offset(0.50, 0.19), const Offset(0.78, 0.30),
          const Offset(0.84, 0.60),
        ]);
        line([
          const Offset(0.10, 0.58), const Offset(0.24, 0.58),
          const Offset(0.24, 0.80), const Offset(0.10, 0.80),
        ], close: true, filled: true);
        line([
          const Offset(0.76, 0.58), const Offset(0.90, 0.58),
          const Offset(0.90, 0.80), const Offset(0.76, 0.80),
        ], close: true, filled: true);

      // ----------------------------------------------------------- food
      //
      // Six of these are shapes `food_marks.dart` already draws for the recipe
      // cards. They are borrowed rather than redrawn, so a fried egg is the
      // same fried egg wherever it appears in the product.
      case 'bowl_salad':
        borrow(FoodMarks.saladBowl);

      case 'steak':
        borrow(FoodMarks.steak);

      case 'toast_egg':
        borrow(FoodMarks.friedEgg);

      case 'breakfast':
        borrow(FoodMarks.pancakeStack);

      case 'bruschetta':
        borrow(FoodMarks.flatbread);

      case 'pasta':
        borrow(FoodMarks.pot);

      case 'buddha_bowl':
        // Seen from above and divided, where `bowl_salad` is seen from the
        // side. That is the whole reason both exist: W06, the meal planner,
        // places them side by side and two side-view bowls would read as one
        // drawing printed twice.
        circle(const Offset(0.50, 0.52), 0.35, filled: true);
        circle(const Offset(0.50, 0.52), 0.27);
        line([const Offset(0.50, 0.25), const Offset(0.50, 0.79)]);
        line([const Offset(0.23, 0.52), const Offset(0.77, 0.52)]);
        circle(const Offset(0.38, 0.40), 0.05);
        circle(const Offset(0.62, 0.42), 0.04);
        circle(const Offset(0.40, 0.65), 0.04);
        circle(const Offset(0.63, 0.64), 0.05);

      case 'plate_mixed':
        oval(const Offset(0.44, 0.56), 0.32, 0.30, filled: true);
        oval(const Offset(0.44, 0.56), 0.24, 0.22);
        circle(const Offset(0.36, 0.50), 0.07, filled: true);
        line([
          const Offset(0.48, 0.48), const Offset(0.60, 0.56),
          const Offset(0.46, 0.66), const Offset(0.38, 0.62),
        ], close: true, filled: true);
        line([const Offset(0.84, 0.30), const Offset(0.82, 0.84)]);
        line([const Offset(0.79, 0.28), const Offset(0.80, 0.42)]);
        line([const Offset(0.89, 0.28), const Offset(0.87, 0.42)]);

      case 'fruit_basket':
        line([
          const Offset(0.16, 0.54), const Offset(0.84, 0.54),
          const Offset(0.74, 0.86), const Offset(0.26, 0.86),
        ], close: true, filled: true);
        line([const Offset(0.18, 0.66), const Offset(0.82, 0.66)]);
        line([const Offset(0.38, 0.55), const Offset(0.36, 0.85)]);
        line([const Offset(0.62, 0.55), const Offset(0.64, 0.85)]);
        circle(const Offset(0.33, 0.44), 0.11, filled: true);
        circle(const Offset(0.55, 0.39), 0.13, filled: true);
        circle(const Offset(0.73, 0.46), 0.09, filled: true);
        line([const Offset(0.55, 0.26), const Offset(0.70, 0.20)]);

      case 'apple':
        line([
          const Offset(0.27, 0.44), const Offset(0.38, 0.31),
          const Offset(0.50, 0.36), const Offset(0.62, 0.31),
          const Offset(0.73, 0.44), const Offset(0.74, 0.64),
          const Offset(0.61, 0.81), const Offset(0.50, 0.83),
          const Offset(0.39, 0.81), const Offset(0.26, 0.64),
        ], close: true, filled: true);
        line([const Offset(0.50, 0.35), const Offset(0.53, 0.18)]);
        line([
          const Offset(0.53, 0.22), const Offset(0.68, 0.14),
          const Offset(0.66, 0.27),
        ], close: true, filled: true);

      case 'grapes':
        circle(const Offset(0.34, 0.47), 0.10, filled: true);
        circle(const Offset(0.52, 0.44), 0.10, filled: true);
        circle(const Offset(0.69, 0.49), 0.10, filled: true);
        circle(const Offset(0.43, 0.62), 0.10, filled: true);
        circle(const Offset(0.61, 0.64), 0.10, filled: true);
        circle(const Offset(0.51, 0.78), 0.10, filled: true);
        line([const Offset(0.52, 0.34), const Offset(0.50, 0.18)]);
        line([
          const Offset(0.50, 0.22), const Offset(0.34, 0.14),
          const Offset(0.36, 0.27),
        ], close: true, filled: true);

      case 'watermelon':
        line([
          const Offset(0.12, 0.62), const Offset(0.50, 0.22),
          const Offset(0.88, 0.62), const Offset(0.70, 0.80),
          const Offset(0.50, 0.84), const Offset(0.30, 0.80),
        ], close: true, filled: true);
        line([
          const Offset(0.20, 0.63), const Offset(0.50, 0.32),
          const Offset(0.80, 0.63),
        ]);
        circle(const Offset(0.40, 0.58), 0.032, filled: true);
        circle(const Offset(0.58, 0.55), 0.032, filled: true);
        circle(const Offset(0.50, 0.71), 0.032, filled: true);

      case 'nuts':
        line([
          const Offset(0.20, 0.52), const Offset(0.32, 0.42),
          const Offset(0.44, 0.52), const Offset(0.32, 0.66),
        ], close: true, filled: true);
        line([const Offset(0.26, 0.50), const Offset(0.36, 0.58)]);
        line([
          const Offset(0.52, 0.38), const Offset(0.66, 0.30),
          const Offset(0.76, 0.42), const Offset(0.62, 0.54),
        ], close: true, filled: true);
        line([const Offset(0.58, 0.38), const Offset(0.69, 0.44)]);
        line([
          const Offset(0.44, 0.68), const Offset(0.58, 0.60),
          const Offset(0.70, 0.70), const Offset(0.56, 0.84),
        ], close: true, filled: true);
        line([const Offset(0.50, 0.68), const Offset(0.61, 0.74)]);

      default:
        // A name with no drawing behind it falls back to the yoga mat rather
        // than to nothing, because a blank corner reads as a failed image
        // load. `app_art_test.dart` asserts every name in `AppArt.all` is a
        // case above, so reaching here is a bug caught before release.
        line([
          const Offset(0.28, 0.40), const Offset(0.84, 0.43),
          const Offset(0.84, 0.71), const Offset(0.28, 0.72),
        ], close: true, filled: true);
        circle(const Offset(0.28, 0.56), 0.16, filled: true);
        circle(const Offset(0.28, 0.56), 0.07);
    }
  }

  @override
  bool shouldRepaint(covariant ArtMarkPainter old) =>
      old.markKey != markKey ||
      old.ink != ink ||
      old.level != level ||
      old.rtl != rtl;
}
