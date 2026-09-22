/// The darkening a photograph needs before a headline can sit on it.
///
/// B04's "Darken the photo" slider is the one control in the builder a coach
/// could use to make her own page unreadable, and a colour validator cannot
/// catch it: the failure is between her text and *a photograph*, which has no
/// role in any scheme.
///
/// ## The 90th percentile, and why not the mean (G13 §1.4.5)
///
/// Decode a 32×32 thumbnail of **the region under the text box only**, take the
/// **90th-percentile** relative luminance `Lp`, composite
/// `L' = (1 − α)·Lp + α·L(scrim)`, and solve for the smallest `α` in 0.01 steps
/// where `ratio(L(text), L') ≥ 4.5`.
///
/// The percentile is the whole point. A mean is dominated by the bulk of the
/// region, so a photograph that is mostly dark stone with one blown-out patch of
/// Cairo sky behind the third word gets a low mean, a low floor, and a headline
/// with an illegible word in the middle of it. The 90th percentile asks "how
/// bright is the bright part", which is the part that breaks.
///
/// ## The one case where the builder says no
///
/// If α = 0.9 still fails, the layout is **refused** and `photo-above` is
/// offered. Everywhere else this product nudges rather than blocks; here there
/// is nothing left to nudge with, and a 0.95 scrim is not a photograph any more.
library;

import 'package:flutter/material.dart';

import 'contrast.dart';

/// The largest scrim the builder will draw. Beyond this it is not a photo.
const double kMaxOverlayAlpha = 0.9;

/// The step the floor is solved on. 1% — finer than a slider can express.
const double kOverlayAlphaStep = 0.01;

/// What the text on a cover has to reach. Not 3.0:1.
///
/// A cover headline renders at `display`, which WCAG would let through at
/// 3.0:1. G13 §1.4.5 specifies 4.5 for the photo case anyway, and that is not
/// an oversight: a scrim's effect varies across the image, the sample is 32×32,
/// and the subline underneath it is `bodyM` — normal text — in the same box.
const double kOverlayTargetRatio = ContrastThresholds.normal;

/// What the validator decided about a text-over-photo layout.
@immutable
class OverlayDecision {
  const OverlayDecision._({required this.minAlpha, required this.refused});

  /// A workable floor. The slider is clamped to [minAlpha] as its minimum.
  const OverlayDecision.allowed(double minAlpha)
    : this._(minAlpha: minAlpha, refused: false);

  /// Even [kMaxOverlayAlpha] does not reach [kOverlayTargetRatio].
  ///
  /// B04 refuses `text-over-photo` and offers `photo-above` instead.
  const OverlayDecision.refusedLayout()
    : this._(minAlpha: kMaxOverlayAlpha, refused: true);

  /// The smallest alpha that works, rounded up to a whole 1% step.
  final double minAlpha;

  /// True when no alpha works and the layout itself must change.
  final bool refused;

  bool get isAllowed => !refused;

  @override
  String toString() => refused
      ? 'OverlayDecision.refusedLayout()'
      : 'OverlayDecision.allowed(${minAlpha.toStringAsFixed(2)})';
}

/// Solves the darkening floor for one text box over one photograph.
abstract final class OverlayFloor {
  /// The 90th-percentile luminance of [luminances], by nearest rank.
  ///
  /// [luminances] is the 32×32 sample of **the region under the text box**, not
  /// of the whole image. Passing the whole image is the bug this parameter name
  /// exists to make visible at the call site.
  ///
  /// Nearest rank: sort ascending, take index `ceil(0.9 × n) − 1`. For n = 1024
  /// that is index 921 — the 922nd darkest sample, so the brightest 10% of the
  /// region is what the scrim is solved against.
  static double percentile90(List<double> luminances) {
    if (luminances.isEmpty) {
      throw ArgumentError.value(
        luminances,
        'luminances',
        'An empty region cannot be sampled. A cover with no decodable photo is '
            'not a text-over-photo cover.',
      );
    }
    final sorted = [...luminances]..sort();
    final rank = (0.9 * sorted.length).ceil();
    final index = (rank - 1).clamp(0, sorted.length - 1);
    return sorted[index];
  }

  /// The smallest scrim alpha that makes [textColour] readable.
  ///
  /// [regionLuminances] is the sampled region under the text box;
  /// [scrim] is the colour being composited over it, black in every layout the
  /// builder currently offers.
  ///
  /// Returns [OverlayDecision.refusedLayout] when [kMaxOverlayAlpha] is not
  /// enough — which happens with white text on a white-ish photograph, and is
  /// the honest answer rather than a slider that silently does nothing.
  static OverlayDecision minAlpha({
    required List<double> regionLuminances,
    required Color textColour,
    Color scrim = const Color(0xFF000000),
    double target = kOverlayTargetRatio,
  }) {
    final lp = percentile90(regionLuminances);
    final ls = relativeLuminance(scrim);
    final lt = relativeLuminance(textColour);

    // Whole 1% steps from 0, so the answer is a value the slider can hold.
    final steps = (kMaxOverlayAlpha / kOverlayAlphaStep).round();
    for (var i = 0; i <= steps; i++) {
      final alpha = i * kOverlayAlphaStep;
      final composited = (1 - alpha) * lp + alpha * ls;
      if (ratioForLuminances(lt, composited) >= target) {
        // Guard the accumulated floating-point drift of 90 additions.
        return OverlayDecision.allowed(double.parse(alpha.toStringAsFixed(2)));
      }
    }

    return const OverlayDecision.refusedLayout();
  }

  /// The value the slider should hold after a change.
  ///
  /// P0-PORT-07: replacing the photo, changing the layout, or lengthening the
  /// headline recomputes the floor **and raises the current value if it is now
  /// too low**. It never lowers a coach's deliberate choice to darken further —
  /// she is allowed to be stricter than the validator.
  static double raiseToFloor(double current, OverlayDecision decision) =>
      current < decision.minAlpha ? decision.minAlpha : current;
}
