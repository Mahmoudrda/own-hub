/// Card surfaces, matching `card()` and the `CARD_V` map in `6-v2/src/kit.mjs`.
///
/// The variant→colour mapping lives here and only here. [AppCard] and
/// [AppListItem] are the same surface at different sizes, so a second copy of
/// this switch is how a tonal card and a tonal row end up subtly different
/// colours six months from now.
///
/// ## How each variant is drawn
///
/// The colours are the prototype's. What changed is the hand: each variant is
/// a different kind of thing on a printed page, and is drawn as one, so a
/// screen of cards is not one template repeated.
///
///  * **outlined** — a sheet laid on the page: white, framed in pencil.
///  * **filled** — a grouped area: a flat tint, no frame at all.
///  * **tonal** — the app speaking: blush pencil hatching with its outline
///    printed slightly off-register.
///  * **sage** — restful: sage pencil hatching, and no line at all.
///  * **amber** — a caution: a precise outline and no tint.
///  * **error** — a genuine problem: kept precise, in its own tint.
///  * **selected** — ringed in ink, the way she would mark her choice.
///
/// Three corners are tight and one is loose, chosen per card, so no two cards
/// on a screen share a silhouette.
library;

import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import 'hand/hand.dart';
import 'screen_scope.dart';

enum AppCardVariant {
  /// The default: a white surface with a hairline border. Carries no emphasis.
  outlined,

  /// A filled grey surface. For something grouped rather than highlighted.
  filled,

  /// Pink. The product's own voice — used where the app is speaking to her.
  tonal,

  /// Green. Restorative: rest weeks, things that cost her nothing.
  sage,

  /// Amber. A caution that is not a failure — a draft, something unpublished.
  amber,

  /// Red. Reserved for genuine problems and medical guidance.
  error,

  /// A 2px primary border rather than a fill, so a chosen row reads as chosen
  /// without changing its weight on the page.
  selected,
}

/// Background, border colour and border width for a variant.
({Color background, Color border, double borderWidth}) cardStyle(
  AppCardVariant variant,
) {
  return switch (variant) {
    // `outline`, not `outlineVariant`. The border of a card is a boundary
    // that carries meaning — it is what makes an outlined card one object
    // rather than text on the page — so WCAG 1.4.11 applies to it and the role
    // that clears 3:1 is the one to ask for. `outlineVariant` is M3's
    // decorative hairline and `contrast.dart` says so at length; recolouring it
    // to 3:1 to serve this call site is what turned thirteen cards across
    // twelve screens rose.
    AppCardVariant.outlined => (
      background: AppColors.surfaceLowest,
      border: AppColors.outline,
      borderWidth: 1,
    ),
    AppCardVariant.filled => (
      background: AppColors.surfaceContainer,
      border: Colors.transparent,
      borderWidth: 1,
    ),
    AppCardVariant.tonal => (
      background: AppColors.primaryContainer,
      border: Colors.transparent,
      borderWidth: 1,
    ),
    AppCardVariant.sage => (
      background: AppColors.tertiaryContainer,
      border: Colors.transparent,
      borderWidth: 1,
    ),
    AppCardVariant.amber => (
      background: AppColors.amberContainer,
      border: Colors.transparent,
      borderWidth: 1,
    ),
    AppCardVariant.error => (
      background: AppColors.errorContainer,
      border: Colors.transparent,
      borderWidth: 1,
    ),
    AppCardVariant.selected => (
      background: AppColors.surfaceLowest,
      border: AppColors.primary,
      borderWidth: 2,
    ),
  };
}

/// How a variant is drawn by hand. The colours come from [cardStyle].
///
/// The two voices of the app — tonal (its own) and sage (restful) — carry
/// their colour as pencil hatching over the paper rather than as a flat
/// tint: tone the way a pencil makes it, so a screen is never a stack of
/// coloured boxes. Amber keeps a precise outline and no tint; a caution is
/// stated, not shaded.
({
  Color? fill,
  Color? frame,
  double frameWidth,
  Color? offsetOutline,
  HandLevel level,
  Color? hatch,
})
handCardLook(AppCardVariant variant) {
  final style = cardStyle(variant);
  return switch (variant) {
    AppCardVariant.outlined => (
      fill: style.background,
      frame: AppColors.outline.withValues(alpha: 0.55),
      frameWidth: 1.05,
      offsetOutline: null,
      level: HandLevel.crafted,
      hatch: null,
    ),
    AppCardVariant.filled => (
      fill: style.background,
      frame: null,
      frameWidth: 1,
      offsetOutline: null,
      level: HandLevel.crafted,
      hatch: null,
    ),
    AppCardVariant.tonal => (
      fill: null,
      frame: null,
      frameWidth: 1.1,
      offsetOutline: AppColors.primary.withValues(alpha: 0.85),
      level: HandLevel.crafted,
      hatch: AppColors.primary,
    ),
    AppCardVariant.sage => (
      fill: null,
      frame: null,
      frameWidth: 1.1,
      offsetOutline: null,
      level: HandLevel.crafted,
      hatch: AppColors.tertiary,
    ),
    AppCardVariant.amber => (
      fill: null,
      frame: AppColors.amber.withValues(alpha: 0.6),
      frameWidth: 1.2,
      offsetOutline: null,
      level: HandLevel.structural,
      hatch: null,
    ),
    AppCardVariant.error => (
      fill: style.background,
      frame: AppColors.error.withValues(alpha: 0.45),
      frameWidth: 1,
      offsetOutline: null,
      level: HandLevel.structural,
      hatch: null,
    ),
    AppCardVariant.selected => (
      fill: style.background,
      frame: AppColors.primary,
      frameWidth: 2,
      offsetOutline: null,
      level: HandLevel.expressive,
      hatch: null,
    ),
  };
}

/// How dark a card's hatching is drawn: enough to read as a tone, light
/// enough that print over it keeps its contrast.
const double kCardHatchOpacity = 0.3;

/// Tight corners from the caller's radius: the old soft radii read as a
/// toolkit, and this page is cut, not moulded.
double handTightRadius(double r) => (r * 0.35).clamp(3.0, 8.0);

/// The one loose corner.
double handLooseRadius(double r) => (r * 0.9).clamp(10.0, 22.0);

/// A seed from what a card holds, so the same card is drawn the same way on
/// every visit and its neighbours are drawn differently.
///
/// Each child is named with [handSeedNameOf], never its `runtimeType`, which
/// an obfuscated release build renames.
int handSeedForChildren(
  BuildContext context,
  List<Widget> children,
  Object? salt,
) {
  final parts = <Object?>[ScreenScope.of(context), salt, children.length];
  for (final c in children.take(3)) {
    parts.add(handSeedNameOf(c));
    if (c is Text) parts.add(c.data);
  }
  return handSeed(parts);
}

/// A block of related content. `card()` in the prototype: 16px padding, 12px
/// between children, and the large radius rather than the medium one.
class AppCard extends StatelessWidget implements HandSeedName {
  const AppCard({
    super.key,
    required this.children,
    this.variant = AppCardVariant.outlined,
    this.padding = const EdgeInsets.all(16),
    this.gap = 12,
    this.borderRadius = AppRadius.lg,
    this.onTap,
    this.seed,
  });

  final List<Widget> children;
  final AppCardVariant variant;
  final EdgeInsets padding;
  final double gap;
  final double borderRadius;
  final VoidCallback? onTap;

  /// Which hand draws it. Usually left to the card's own contents.
  final int? seed;

  @override
  String get handSeedName => 'AppCard';

  @override
  Widget build(BuildContext context) {
    final look = handCardLook(variant);

    final surface = HandSurface(
      seed: seed ?? handSeedForChildren(context, children, variant.index),
      fill: look.fill,
      frame: look.frame,
      frameWidth: look.frameWidth,
      offsetOutline: look.offsetOutline,
      level: look.level,
      hatch: look.hatch,
      hatchOpacity: kCardHatchOpacity,
      radius: handTightRadius(borderRadius),
      looseCorner: handLooseRadius(borderRadius),
      onTap: onTap,
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) SizedBox(height: gap),
            children[i],
          ],
        ],
      ),
    );
    // A chosen card says so to a screen reader, not only with its ink ring.
    return variant == AppCardVariant.selected
        ? Semantics(selected: true, child: surface)
        : surface;
  }
}
