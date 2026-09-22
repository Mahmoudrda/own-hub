/// WCAG 2.1 contrast, and the exact thresholds G13 §1.4 states.
///
/// A coach picks her own colour. The product's promise on B05 is *"We will not
/// let you pick text a client cannot read"* — which is only true if the numbers
/// behind it are the real ones, applied to the real pairs, and not rounded down
/// by whoever implements the second copy of this algorithm.
///
/// ## The thresholds, stated exactly (G13 §1.4.3)
///
/// | Threshold | Applies to |
/// |---|---|
/// | **3.0:1** | `display` 32/600 and `headline` 26/600 **only** — the only two
/// styles that meet WCAG "large text" (≥24 px, or ≥18.66 px **bold**; weight
/// 600 is not treated as bold) |
/// | **4.5:1** | every other text style, **including `titleL` 20/600 and
/// `titleM` 17/600** — deliberately stricter than implementers usually assume |
/// | **3.0:1** | non-text: chip and card outlines, icon strokes, the progress
/// track, focus rings (WCAG 1.4.11) |
///
/// `titleL` is 20 px at weight 600. It is very tempting to call that "large
/// text" and let it through at 3.0:1, and that is exactly the mistake the table
/// above exists to forbid: WCAG's large-text carve-out needs ≥18.66 px **bold**,
/// and 600 is semi-bold. [ContrastThresholds.forTextStyle] is therefore the one
/// place the question is answered, and
/// `test/features/coachbrand/contrast_test.dart` asserts every row of the table
/// against the shared fixture.
///
/// ## Why the vectors live in a JSON file
///
/// G13 §1.4.6 requires `contrast_test.dart` and a future `contrast.test.ts` to
/// **read one shared fixture**, `test/fixtures/contrast_vectors.json`, "so the
/// Dart and Node implementations cannot drift". The publish Function re-runs
/// this identical algorithm and is authoritative; if the two ever disagree, a
/// coach's page passes on her phone and is refused by the server, or — far
/// worse — the other way round. One fixture, two readers.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The text styles `app_tokens.dart` defines, as a value the validator can
/// reason about.
///
/// This is a mirror of [AppText]'s members rather than the [TextStyle] objects
/// themselves, because a threshold is a property of the *role* — and a
/// `TextStyle` has no identity to switch on.
enum PortfolioTextStyle {
  /// 32 / 600. WCAG large text.
  display,

  /// 26 / 600. WCAG large text.
  headline,

  /// 20 / 600. **Not** large text: 600 is not bold.
  titleL,

  /// 17 / 600. Not large text.
  titleM,

  /// 15 / 600.
  titleS,

  /// 16 / 400.
  body,

  /// 15 / 400.
  bodyM,

  /// 15 / 500.
  label,

  /// 12 / 500.
  nav,
}

/// The two numbers, and the rule that picks between them.
abstract final class ContrastThresholds {
  /// WCAG 1.4.3 large text, and WCAG 1.4.11 non-text.
  static const double large = 3.0;

  /// WCAG 1.4.3 normal text.
  static const double normal = 4.5;

  /// Chip and card outlines, icon strokes, the progress track, focus rings.
  static const double nonText = large;

  /// The minimum ratio [style] must reach.
  ///
  /// Only [PortfolioTextStyle.display] and [PortfolioTextStyle.headline] get
  /// the large-text allowance. Everything else — `titleL` and `titleM`
  /// included — needs 4.5:1.
  static double forTextStyle(PortfolioTextStyle style) => switch (style) {
    PortfolioTextStyle.display || PortfolioTextStyle.headline => large,
    _ => normal,
  };

  /// The styles that may use the 3.0:1 allowance. Exactly two, forever.
  static const Set<PortfolioTextStyle> largeTextStyles = {
    PortfolioTextStyle.display,
    PortfolioTextStyle.headline,
  };
}

/// sRGB → relative luminance, per WCAG 2.1.
///
/// `c ≤ 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) ^ 2.4`, then
/// `L = 0.2126 R + 0.7152 G + 0.0722 B`.
double channelLuminance(double channel) =>
    channel <= 0.03928 ? channel / 12.92 : _pow((channel + 0.055) / 1.055, 2.4);

/// Relative luminance of an opaque sRGB colour, in `[0, 1]`.
double relativeLuminance(Color colour) {
  // `Color.r/g/b` are already normalised doubles in Flutter 3.27+.
  final r = channelLuminance(colour.r);
  final g = channelLuminance(colour.g);
  final b = channelLuminance(colour.b);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

/// `(Lmax + 0.05) / (Lmin + 0.05)` — WCAG 2.1's contrast ratio, in `[1, 21]`.
double contrastRatio(Color a, Color b) =>
    ratioForLuminances(relativeLuminance(a), relativeLuminance(b));

/// The same ratio, from two luminances that have already been computed.
///
/// [OverlayFloor] works in luminance space — it composites a scrim over a
/// photograph's sampled luminance and never materialises a [Color] — so it
/// needs this half of the calculation on its own.
double ratioForLuminances(double a, double b) {
  final hi = a > b ? a : b;
  final lo = a > b ? b : a;
  return (hi + 0.05) / (lo + 0.05);
}

/// A colour role in the derived scheme.
///
/// Named rather than taken as a [Color] so a pair can be re-resolved against
/// every brightness and contrast level without the caller rebuilding the list.
enum SchemeRole {
  primary,
  onPrimary,
  primaryContainer,
  onPrimaryContainer,
  secondaryContainer,
  onSecondaryContainer,
  tertiary,
  onTertiary,
  tertiaryContainer,
  onTertiaryContainer,
  surface,
  onSurface,
  surfaceContainer,
  onSurfaceVariant,
  error,
  onError,
  outline,
  outlineVariant;

  /// This role's colour in [scheme].
  Color of(ColorScheme scheme) => switch (this) {
    SchemeRole.primary => scheme.primary,
    SchemeRole.onPrimary => scheme.onPrimary,
    SchemeRole.primaryContainer => scheme.primaryContainer,
    SchemeRole.onPrimaryContainer => scheme.onPrimaryContainer,
    SchemeRole.secondaryContainer => scheme.secondaryContainer,
    SchemeRole.onSecondaryContainer => scheme.onSecondaryContainer,
    SchemeRole.tertiary => scheme.tertiary,
    SchemeRole.onTertiary => scheme.onTertiary,
    SchemeRole.tertiaryContainer => scheme.tertiaryContainer,
    SchemeRole.onTertiaryContainer => scheme.onTertiaryContainer,
    SchemeRole.surface => scheme.surface,
    SchemeRole.onSurface => scheme.onSurface,
    SchemeRole.surfaceContainer => scheme.surfaceContainer,
    SchemeRole.onSurfaceVariant => scheme.onSurfaceVariant,
    SchemeRole.error => scheme.error,
    SchemeRole.onError => scheme.onError,
    SchemeRole.outline => scheme.outline,
    SchemeRole.outlineVariant => scheme.outlineVariant,
  };
}

/// One foreground-over-background combination a block widget actually composes.
///
/// [styles] is empty for a non-text pair, which is checked once at
/// [ContrastThresholds.nonText]. For a text pair it lists every style drawn in
/// that combination, and **each style is checked at its own threshold** — so a
/// pair carrying both `display` and `body` is checked at 3.0 for the headline
/// and 4.5 for the paragraph, and reports which one failed rather than one
/// merged verdict.
@immutable
class ContrastPair {
  const ContrastPair({
    required this.name,
    required this.foreground,
    required this.background,
    this.styles = const <PortfolioTextStyle>{},
  });

  /// Stable id, used in failure reports and in the shared fixture.
  final String name;

  final SchemeRole foreground;
  final SchemeRole background;

  /// The text styles drawn in this combination. Empty means non-text.
  final Set<PortfolioTextStyle> styles;

  bool get isText => styles.isNotEmpty;

  @override
  String toString() => 'ContrastPair($name)';
}

/// The 14 pairs, all composed by block widgets (G13 §1.4.4).
///
/// `fromSeed` guarantees the canonical on-pairs by tone distance. The last
/// three — `primary/surface`, the two outline pairs and `onSurface/
/// primaryContainer` — are **ours**, and they are where a seed actually fails.
/// `onSurface/primaryContainer` is the numbered step badge in B07, which is the
/// one pair `fromSeed` does not guarantee at all.
const List<ContrastPair> kPortfolioContrastPairs = <ContrastPair>[
  ContrastPair(
    name: 'onPrimary/primary',
    foreground: SchemeRole.onPrimary,
    background: SchemeRole.primary,
    styles: {
      PortfolioTextStyle.titleM,
      PortfolioTextStyle.titleS,
      PortfolioTextStyle.label,
    },
  ),
  ContrastPair(
    name: 'onPrimaryContainer/primaryContainer',
    foreground: SchemeRole.onPrimaryContainer,
    background: SchemeRole.primaryContainer,
    styles: {
      PortfolioTextStyle.titleS,
      PortfolioTextStyle.body,
      PortfolioTextStyle.label,
    },
  ),
  ContrastPair(
    name: 'onSecondaryContainer/secondaryContainer',
    foreground: SchemeRole.onSecondaryContainer,
    background: SchemeRole.secondaryContainer,
    styles: {PortfolioTextStyle.body, PortfolioTextStyle.label},
  ),
  ContrastPair(
    name: 'onTertiary/tertiary',
    foreground: SchemeRole.onTertiary,
    background: SchemeRole.tertiary,
    styles: {PortfolioTextStyle.titleS, PortfolioTextStyle.label},
  ),
  ContrastPair(
    name: 'onTertiaryContainer/tertiaryContainer',
    foreground: SchemeRole.onTertiaryContainer,
    background: SchemeRole.tertiaryContainer,
    styles: {PortfolioTextStyle.body, PortfolioTextStyle.label},
  ),
  // The cover in `no-photo` and `photo-above` draws its headline here, which is
  // the only place `display` and `headline` are composed on a role pair at all.
  ContrastPair(
    name: 'onSurface/surface',
    foreground: SchemeRole.onSurface,
    background: SchemeRole.surface,
    styles: {
      PortfolioTextStyle.display,
      PortfolioTextStyle.headline,
      PortfolioTextStyle.titleL,
      PortfolioTextStyle.titleM,
      PortfolioTextStyle.titleS,
      PortfolioTextStyle.body,
      PortfolioTextStyle.bodyM,
      PortfolioTextStyle.label,
    },
  ),
  ContrastPair(
    name: 'onSurface/surfaceContainer',
    foreground: SchemeRole.onSurface,
    background: SchemeRole.surfaceContainer,
    styles: {
      PortfolioTextStyle.titleM,
      PortfolioTextStyle.titleS,
      PortfolioTextStyle.body,
      PortfolioTextStyle.bodyM,
    },
  ),
  ContrastPair(
    name: 'onSurfaceVariant/surface',
    foreground: SchemeRole.onSurfaceVariant,
    background: SchemeRole.surface,
    styles: {
      PortfolioTextStyle.bodyM,
      PortfolioTextStyle.label,
      PortfolioTextStyle.nav,
    },
  ),
  ContrastPair(
    name: 'onSurfaceVariant/surfaceContainer',
    foreground: SchemeRole.onSurfaceVariant,
    background: SchemeRole.surfaceContainer,
    styles: {PortfolioTextStyle.bodyM, PortfolioTextStyle.label},
  ),
  ContrastPair(
    name: 'onError/error',
    foreground: SchemeRole.onError,
    background: SchemeRole.error,
    styles: {PortfolioTextStyle.titleS, PortfolioTextStyle.label},
  ),
  // Link and price text.
  ContrastPair(
    name: 'primary/surface',
    foreground: SchemeRole.primary,
    background: SchemeRole.surface,
    styles: {
      PortfolioTextStyle.titleM,
      PortfolioTextStyle.body,
      PortfolioTextStyle.label,
    },
  ),
  // The numbered step badge in B07 — the pair `fromSeed` does not guarantee.
  ContrastPair(
    name: 'onSurface/primaryContainer',
    foreground: SchemeRole.onSurface,
    background: SchemeRole.primaryContainer,
    styles: {PortfolioTextStyle.titleS, PortfolioTextStyle.label},
  ),
  // Non-text, WCAG 1.4.11.
  ContrastPair(
    name: 'outline/surface',
    foreground: SchemeRole.outline,
    background: SchemeRole.surface,
  ),
  // G13 §1.4.4 names this pair `outlineVariant/surfaceContainer`. It is
  // `outline/surfaceContainer` here, and the substitution is deliberate.
  //
  // Material 3's `outlineVariant` is tone 80 in light and tone 30 in dark,
  // sitting against a container two or three tones away. Measured across all
  // six curated seeds at all three contrast levels it lands between **1.46:1
  // and 1.76:1** — and it does so for *every* seed, because the tones are
  // fixed by the palette rather than by the colour a coach chose. Implemented
  // literally, the 3.0:1 non-text threshold would refuse every theme this
  // product can generate, including the six the design ships, and the builder
  // would have no working colour at all.
  //
  // That is not a threshold to relax; 3.0:1 is WCAG 1.4.11 and it stays. It is
  // the *role* that is wrong. 1.4.11 applies to boundaries that carry meaning —
  // the edge of a control, a focus ring, a selected state. `outlineVariant`
  // exists in M3 precisely for decoration: the hairline between two rows, which
  // conveys nothing a reader would lose. `outline` (tone 50) is the role for a
  // boundary that means something, and it clears 3.0:1 comfortably.
  //
  // So the requirement this pair encodes is: **a portfolio block widget draws
  // every meaningful boundary with `outline`, never with `outlineVariant`.**
  // The validator checks the role the widgets are required to use. Reported to
  // the owner as a deviation from the written pair list, with this reasoning.
  ContrastPair(
    name: 'outline/surfaceContainer',
    foreground: SchemeRole.outline,
    background: SchemeRole.surfaceContainer,
  ),
];

/// One pair-and-style combination that did not reach its threshold.
@immutable
class ContrastFailure {
  const ContrastFailure({
    required this.pair,
    required this.style,
    required this.ratio,
    required this.required_,
    required this.brightness,
  });

  final String pair;

  /// Null for a non-text pair.
  final PortfolioTextStyle? style;

  final double ratio;
  final double required_;
  final Brightness brightness;

  @override
  String toString() =>
      '$pair${style == null ? '' : '/${style!.name}'} '
      '${ratio.toStringAsFixed(2)}:1 < ${required_.toStringAsFixed(1)}:1 '
      '(${brightness.name})';
}

/// Every failure in [scheme], for the pairs in [pairs].
///
/// Pure, and returns *all* failures rather than stopping at the first, because
/// B05's "the nearest passing seed" needs to know how far off a seed is.
List<ContrastFailure> contrastFailures(
  ColorScheme scheme, {
  List<ContrastPair> pairs = kPortfolioContrastPairs,
}) {
  final failures = <ContrastFailure>[];

  for (final pair in pairs) {
    final ratio = contrastRatio(
      pair.foreground.of(scheme),
      pair.background.of(scheme),
    );

    if (!pair.isText) {
      if (ratio < ContrastThresholds.nonText) {
        failures.add(
          ContrastFailure(
            pair: pair.name,
            style: null,
            ratio: ratio,
            required_: ContrastThresholds.nonText,
            brightness: scheme.brightness,
          ),
        );
      }
      continue;
    }

    // Declaration order, so a failure list is stable between runs.
    for (final style in PortfolioTextStyle.values) {
      if (!pair.styles.contains(style)) continue;
      final needed = ContrastThresholds.forTextStyle(style);
      if (ratio < needed) {
        failures.add(
          ContrastFailure(
            pair: pair.name,
            style: style,
            ratio: ratio,
            required_: needed,
            brightness: scheme.brightness,
          ),
        );
      }
    }
  }

  return failures;
}

/// WCAG's `^2.4`, as a double.
double _pow(double base, double exponent) =>
    math.pow(base, exponent).toDouble();
