/// A tappable row, matching `listItem()` in `6-v2/src/kit.mjs`.
///
/// Used everywhere in this product: choosing a language, picking a move, reading
/// a coach's offer. The card variants come from the prototype's `CARD_V` map and
/// are reproduced exactly, because they carry meaning — `selected` is a 2px
/// primary border rather than a fill, so a chosen row reads as chosen without
/// changing its weight on the page.
///
/// ## The default row is not a box
///
/// An `outlined` row is drawn as a line in a diary — open on the page, ruled
/// underneath in pencil — rather than as one more framed card. Stacked, they
/// read as a list someone keeps. Every other variant still carries meaning in
/// its colour, so those stay surfaces, drawn the way `app_card.dart` draws them.
///
/// A leading icon sits in a small pencil ring. The icon is the product's own;
/// the ring is only the hand acknowledging it.
library;

import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import 'app_card.dart';
import 'hand/hand.dart';

export 'app_card.dart' show AppCardVariant;

class AppListItem extends StatelessWidget {
  const AppListItem({
    super.key,
    this.title = '',
    this.subtitle = '',
    this.leading,
    this.trailing,
    this.onTap,
    this.variant = AppCardVariant.outlined,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    this.borderRadius = AppRadius.md,
  });

  final String title;
  final String subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final AppCardVariant variant;
  final EdgeInsets padding;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final seed = handSeed(['row', title, subtitle, variant.index]);
    final lead = leading;

    final row = Row(
      children: [
        if (lead != null) ...[
          lead is Icon ? HandIconRing(icon: lead, seed: seed) : lead,
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppText.titleM),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: AppText.bodyM.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 12),
          // Capped, so a long pill at the largest text size in Arabic
          // shortens itself rather than pushing the row off the screen.
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 168),
            child: trailing,
          ),
        ],
      ],
    );

    if (variant == AppCardVariant.outlined) {
      // A ruled line: the text keeps the caller's vertical rhythm and sits
      // nearly on the page's own margin, with the rule beneath it.
      final content = Padding(
        padding: EdgeInsets.fromLTRB(2, padding.top, 2, padding.bottom),
        child: row,
      );
      final ruled = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          content,
          HandRule(seed: seed, height: 3),
        ],
      );
      if (onTap == null) return ruled;
      return HandPressable(
        onTap: onTap,
        scale: 0.985,
        builder: (_, _) => ruled,
      );
    }

    final look = handCardLook(variant);
    final surface = HandSurface(
      seed: seed,
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
      child: row,
    );
    // A chosen row says so to a screen reader, not only with its ink ring.
    return variant == AppCardVariant.selected
        ? Semantics(selected: true, child: surface)
        : surface;
  }
}

/// An icon from the product's own set, ringed in pencil.
class HandIconRing extends StatelessWidget {
  const HandIconRing({
    super.key,
    required this.icon,
    this.seed = 0,
    this.size = 40,
    this.color,
  });

  final Icon icon;
  final int seed;
  final double size;

  /// The ring's colour. Pencil by default.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: LoopPainter(
          seed: seed ^ (icon.icon?.codePoint ?? 0),
          color: color ?? AppColors.outline.withValues(alpha: 0.7),
          width: 1.0,
          level: HandLevel.crafted,
          inflate: EdgeInsets.zero,
          textDirection: Directionality.of(context),
        ),
        child: Center(child: icon),
      ),
    );
  }
}
