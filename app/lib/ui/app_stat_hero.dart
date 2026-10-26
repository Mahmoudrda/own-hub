/// One big figure and up to three small ones: the most a hero area carries.
library;

import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

class AppStat {
  const AppStat({required this.value, required this.label});

  final String value;
  final String label;
}

class AppStatHero extends StatelessWidget {
  const AppStatHero({
    super.key,
    required this.hero,
    this.others = const [],
    this.heroBuilder,
  }) : assert(others.length <= 3, 'a hero area carries at most 3 more figures');

  final AppStat hero;
  final List<AppStat> others;

  /// Draws the big figure itself, in the style the hero gives it, for a screen
  /// that animates it. Null draws [hero]'s value as plain text.
  final Widget Function(TextStyle style)? heroBuilder;

  static const _tabular = [FontFeature.tabularFigures()];

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          () {
            final style = AppText.display.copyWith(
              fontSize: 48,
              height: 1.1,
              color: AppColors.onSurface,
              fontFeatures: _tabular,
            );
            return heroBuilder?.call(style) ?? Text(hero.value, style: style);
          }(),
          Text(
            hero.label,
            style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
          ),
          if (others.isNotEmpty) ...[
            const SizedBox(height: 16),
            // A wrap, so at the largest text size the figures stack instead of
            // overflowing.
            Wrap(
              spacing: 24,
              runSpacing: 12,
              children: [
                for (final s in others)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        s.value,
                        style: AppText.titleL.copyWith(
                          color: AppColors.onSurface,
                          fontFeatures: _tabular,
                        ),
                      ),
                      Text(
                        s.label,
                        style: AppText.bodyM.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
