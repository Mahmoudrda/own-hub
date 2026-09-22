/// The shapes P01–P03 are built from.
///
/// These live in the feature rather than in `lib/ui/` for the same reason
/// `today_cards.dart` does: they are Progress's content, not reusable shapes.
/// The reusable parts they are built from — [AppCard], [AppProgressBar],
/// [AppListItem] — are in the kit.
library;

import 'package:flutter/material.dart';

import '../../../domain/rewards/week_rollup.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_progress.dart';
import '../../../ui/hand/hand.dart';

/// P01's eight-week chart, matching `weekBars()` in `6-v2/src/kit.mjs`.
///
/// Three bar heights and three colours, one per [WeekBarKind]: a full green bar
/// for a week she earned, a shorter pale one for a week a rest week covered, and
/// a low neutral one for a week that did not count.
///
/// **The low bar is never red**, and there is no fourth kind for a "missed"
/// styling to use. D5 puts the consequence of a quiet week at the week level and
/// never as a failure mark, so the chart shows a week that is shorter rather
/// than a week that is wrong.
///
/// Draws nothing at all when there are no closed weeks yet. A new woman gets an
/// absent chart rather than eight grey stubs implying eight weeks of failure.
class WeekBarsChart extends StatelessWidget {
  const WeekBarsChart({super.key, required this.weeks});

  /// Oldest first, at most [kRecentWeekWindow] of them.
  final List<WeekBar> weeks;

  @override
  Widget build(BuildContext context) {
    if (weeks.isEmpty) return const SizedBox.shrink();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < weeks.length; i++) ...[
          if (i > 0) const SizedBox(width: 5),
          Expanded(
            // The bars are data, so they stay exact. The one hand in them is
            // pencil tone on the pale week, so "the pale one" is told apart by
            // texture as well as by colour.
            child: CustomPaint(
              foregroundPainter: weeks[i].kind == WeekBarKind.repaired
                  ? HatchPainter(
                      seed: i + 1,
                      color: AppColors.tertiary,
                      gap: 4,
                      opacity: 0.45,
                      radius: 5,
                    )
                  : null,
              child: Container(
                height: _height(weeks[i].kind),
                decoration: BoxDecoration(
                  color: _colour(weeks[i].kind),
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  static double _height(WeekBarKind kind) => switch (kind) {
    WeekBarKind.counted => 34,
    WeekBarKind.repaired => 28,
    WeekBarKind.missed => 16,
  };

  static Color _colour(WeekBarKind kind) => switch (kind) {
    WeekBarKind.counted => AppColors.tertiary,
    WeekBarKind.repaired => AppColors.tertiarySoft,
    WeekBarKind.missed => AppColors.outlineVariant,
  };
}

/// A label, a figure and a bar — the `mini()` helper on P01's next-tier card and
/// P02's "Next" list.
///
/// [value] is nullable, and null draws the label and the bar without a figure.
/// That is the case where the dictionary holds only a fixed string ("14 of 20")
/// and the woman's own number is different: the bar still shows her real
/// progress, and no sentence states a number that is not hers.
class MiniStat extends StatelessWidget {
  const MiniStat({
    super.key,
    required this.label,
    required this.percent,
    this.value,
    this.barHeight = 8,
  });

  final String label;
  final String? value;

  /// 0–100, her real progress.
  final double percent;

  final double barHeight;

  @override
  Widget build(BuildContext context) {
    final figure = value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: AppText.titleS)),
            if (figure != null)
              Text(
                figure,
                style: AppText.bodyM.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        AppProgressBar(percent: percent, height: barHeight),
      ],
    );
  }
}

/// An earned milestone — P02's `msDone()`.
///
/// [when] is nullable. The dictionary carries the prototype's dates as fixed
/// strings ("3 Jun") and there is no month vocabulary to build another from, so
/// a woman who earned it on a different day sees the milestone and its tick
/// without a date rather than somebody else's.
class MilestoneDoneRow extends StatelessWidget {
  const MilestoneDoneRow({super.key, required this.name, this.when});

  final String name;
  final String? when;

  @override
  Widget build(BuildContext context) {
    final earnedOn = when;

    return Row(
      children: [
        const Icon(Icons.check_circle, size: 24, color: AppColors.tertiary),
        const SizedBox(width: 10),
        Expanded(child: Text(name, style: AppText.body)),
        if (earnedOn != null)
          Text(
            earnedOn,
            style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
          ),
      ],
    );
  }
}
