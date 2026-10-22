/// The sections of the Insights page (P01) that read from stores other than
/// her week: the body map, her personal bests and her last seven days of
/// food. Each one says what will appear when it has nothing yet, and none of
/// them counts anything down or shows a loss.
library;

import 'package:flutter/material.dart';

import '../../../domain/format/number_label.dart';
import '../../../domain/rewards/personal_best_detector.dart';
import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../theme/hand_tokens.dart' show EditorialType;
import '../../../ui/app_list_item.dart';
import '../../../ui/app_split_row.dart';
import '../../today/presentation/today_cards.dart' show weekdayLabel;
import '../../train/presentation/exercise_labels.dart' show muscleLabel;
import '../../train/domain/exercise_library.dart' show Muscle, MuscleSection;
import '../domain/muscle_report.dart';
import '../domain/nutrition_insights.dart';
import 'muscle_figure.dart';
import 'personal_bests_view.dart' show PersonalBestRow, personalBestRow;

/// Her body from the front and the back with the week's sets on it. A tap on
/// the figure opens P06 for the detail.
class InsightsBodyMap extends StatelessWidget {
  const InsightsBodyMap({super.key, required this.report, this.onOpen});

  final MuscleReport report;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    const window = MuscleWindow.week;
    final scores = {
      for (final m in Muscle.values)
        if (report.muscleScore(window, m) > 0) m: report.muscleScore(window, m),
    };
    final worked = report.rankedMuscles(window);
    final sets = MuscleSection.values.fold<double>(
      0,
      (sum, s) => sum + report.setsIn(window, s),
    );
    final quiet = AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant);

    return Column(
      key: const ValueKey('insights-body-map'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(l10n.yourBodyMapAndSets, style: EditorialType.section),
        const SizedBox(height: 8),
        MuscleFigure(
          scores: scores,
          onSelect: (_) => onOpen?.call(),
          semanticsLabel: l10n.bodyMapInSetsList(
            worked.isEmpty
                ? l10n.notTrainedYet
                : [
                    for (final w in worked)
                      '${muscleLabel(l10n, w.muscle)} ${setsLabel(w.sets)}',
                  ].join(', '),
          ),
          frontLabel: l10n.frontView,
          backLabel: l10n.backView,
        ),
        const SizedBox(height: 8),
        if (report.hasSetsIn(window))
          Text(
            l10n.daysPluralOneSetsIn1Day(window.days, setsLabel(sets)),
            key: const ValueKey('insights-week-sets'),
            textAlign: TextAlign.center,
            style: AppText.titleS,
          )
        else
          Text(
            report.hasAnyLog
                ? l10n.daysPluralOneNoSetsLoggedToday(window.days)
                : l10n.trainOnceAndYourBodyMapRecords,
            key: const ValueKey('insights-body-empty'),
            textAlign: TextAlign.center,
            style: quiet,
          ),
      ],
    );
  }
}

/// Up to three of her personal bests, newest first, and the way to the rest.
class InsightsBests extends StatelessWidget {
  const InsightsBests({super.key, required this.bests, this.onOpen});

  final List<PersonalBest> bests;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final rows = <PersonalBestRow>[
      for (final best in bests) ?personalBestRow(l10n, best),
    ].take(3).toList();

    return Column(
      key: const ValueKey('insights-bests'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        AppListItem(
          leading: const Icon(
            Icons.emoji_events,
            size: 22,
            color: AppColors.amber,
          ),
          title: l10n.personalBests,
          subtitle: rows.isEmpty
              ? l10n.measuredAgainstYourOwnHistoryOnlyMore
              : '',
          trailing: const Icon(
            Icons.chevron_right,
            size: 22,
            color: AppColors.onSurfaceVariant,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          onTap: onOpen,
        ),
        for (final row in rows)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 12, top: 6),
            child: AppSplitRow(
              start: Text(row.title, style: AppText.titleS),
              end: Text(
                row.delta ?? '',
                style: AppText.bodyM.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Protein as seven bars against her target, with the averages of the days
/// she logged. A day with nothing written down is a short dash, not a zero.
class InsightsFood extends StatelessWidget {
  const InsightsFood({super.key, required this.week});

  final NutritionWeek week;

  static const double _barMax = 56;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final quiet = AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant);
    final avgProtein = week.averageProteinG;
    final avgKcal = week.averageKcal;

    return Column(
      key: const ValueKey('insights-food'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.foodLastDaysDays(countLabel(week.days.length)),
          style: AppText.titleM,
        ),
        const SizedBox(height: 8),
        if (!week.hasAny)
          Text(l10n.logAMealAndYourProteinAnd, style: quiet)
        else ...[
          SizedBox(
            height: _barMax,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < week.days.length; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(child: _bar(l10n, week.days[i], i)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            l10n.youLoggedFoodOnLoggedOf7(countLabel(week.loggedDays)),
            key: const ValueKey('insights-food-logged'),
            style: quiet,
          ),
          const SizedBox(height: 6),
          _line(
            l10n.proteinAverageOfTheDaysYouLogged,
            l10n.nGProtein(countLabel(avgProtein ?? 0)),
          ),
          _line(
            l10n.proteinTarget,
            l10n.nGProtein(countLabel(week.proteinTargetG)),
          ),
          _line(
            l10n.caloriesAverageOfTheDaysYouLogged,
            l10n.kcalKcal(countLabel(avgKcal ?? 0)),
          ),
        ],
      ],
    );
  }

  Widget _line(String label, String value) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: AppSplitRow(
      start: Text(label, style: AppText.bodyM),
      end: Text(value, style: AppText.titleS),
    ),
  );

  Widget _bar(AppL10n l10n, NutritionDay day, int index) {
    final target = week.proteinTargetG;
    final ratio = !day.logged || target <= 0
        ? 0.0
        : (day.proteinG / target).clamp(0.0, 1.0);
    final today = index == week.days.length - 1;
    final height = day.logged ? 8 + (_barMax - 8) * ratio : 3.0;
    final label = day.logged
        ? '${weekdayLabel(l10n, day.date)}, ${l10n.nGProtein(countLabel(day.proteinG))}'
        : weekdayLabel(l10n, day.date);
    return Semantics(
      label: label,
      child: ExcludeSemantics(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            height: height.toDouble(),
            decoration: BoxDecoration(
              color: day.logged
                  ? (today ? AppColors.primary : AppColors.primaryDim)
                  : AppColors.outline.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ),
    );
  }
}
