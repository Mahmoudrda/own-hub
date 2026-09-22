/// The hand layer: how much of a person's mark each part of the app carries.
///
/// The Annotated Edition has two layers. Underneath, an exact printed page —
/// the grid, the type, the controls — which never bends. On top, a reader's
/// hand in ink, pencil and marker. This file sets how visible that hand is.
///
/// Hand-written, deliberately separate from the generated `app_tokens.dart`:
/// a token regeneration must never be able to wipe the hand layer.
///
/// ## The four levels
///
/// Imperfection is only valuable against precision, so it is rationed. Most of
/// every screen is [HandLevel.structural]: navigation, forms, values and the
/// grid stay exact. Each screen spends a few [HandLevel.signature] marks at
/// most.
library;

import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';

import 'app_tokens.dart';

/// How strongly a mark shows the hand that drew it.
enum HandLevel {
  /// Navigation, forms, layout and key controls. Drawn clean.
  structural(wobble: 0, overshoot: 0, taper: 0),

  /// Cards, separators, progress, secondary controls. A pen held steadily.
  crafted(wobble: 1.0, overshoot: 3, taper: 0.35),

  /// Annotations, highlights, illustrations' frames. Visibly drawn.
  expressive(wobble: 1.6, overshoot: 7, taper: 0.55),

  /// The one or two marks a screen is remembered by.
  signature(wobble: 2.4, overshoot: 11, taper: 0.7);

  const HandLevel({
    required this.wobble,
    required this.overshoot,
    required this.taper,
  });

  /// How far, in logical pixels, a stroke drifts from the line it means.
  final double wobble;

  /// How far a line runs past where it should stop — the pen not quite lifting.
  final double overshoot;

  /// How much a stroke thins toward its ends. 0 is uniform, 1 is a fine point.
  final double taper;
}

/// The inks the hand writes with. All of them are existing brand colours;
/// only their role is new.
abstract final class HandInk {
  /// Fine ink: the reader's pen. Circles, arrows, underlines, ticks.
  static const Color ink = AppColors.primary;

  /// A deeper ink for marks that sit on blush, so they keep their contrast.
  static const Color inkDeep = AppColors.primaryDim;

  /// Pencil: construction lines, hatching, quiet separators.
  static const Color pencil = AppColors.outline;

  /// Marker: the highlight laid behind a word.
  static const Color marker = AppColors.primaryContainer;

  /// Done. Sage, because nothing in this product is "won".
  static const Color done = AppColors.tertiary;

  /// The page itself.
  static const Color page = AppColors.surface;

  /// Printed type and structural rules.
  static const Color print = AppColors.ink;
}

/// Stroke widths, in logical pixels.
abstract final class HandStroke {
  /// A fine pen: frames, arrows, ticks at small size.
  static const double fine = 1.25;

  /// The reader's usual pen.
  static const double pen = 1.7;

  /// A felt tip, for a signature circle or an emphatic underline.
  static const double felt = 2.4;

  /// Pencil hatching and grain.
  static const double pencil = 0.7;
}

/// Motion for marks being drawn. Short, so it reads as a hand, not a loader.
abstract final class HandMotion {
  static const Duration draw = Duration(milliseconds: 420);
  static const Duration settle = Duration(milliseconds: 260);

  /// A pen accelerates off the page and slows into its end.
  static const Curve pen = Cubic(0.33, 0.0, 0.2, 1.0);
}

/// Type set at editorial scale, for the few places a screen is a cover.
///
/// Rubik still — no serif, no second family for reading — but at a size and
/// weight the generated scale does not reach: a large, slightly tight medium
/// weight for the one thing a screen is about, against small quiet type for
/// everything around it. The contrast is the editorial part.
abstract final class EditorialType {
  /// The focal line of a cover screen.
  static const TextStyle cover = TextStyle(
    fontFamily: 'Rubik',
    fontSize: 38,
    height: 1.08,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.6,
    color: HandInk.print,
  );

  /// A smaller cover line, for a screen whose focal object is a section.
  static const TextStyle section = TextStyle(
    fontFamily: 'Rubik',
    fontSize: 28,
    height: 1.14,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.35,
    color: HandInk.print,
  );

  /// The masthead's date line.
  static const TextStyle folio = TextStyle(
    fontFamily: 'Rubik',
    fontSize: 17,
    height: 1.3,
    fontWeight: FontWeight.w500,
    color: HandInk.print,
  );
}
