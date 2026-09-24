/// Y10 — Your patterns.
///
/// Matches `screens-cycle.mjs` → `Y10`. One chart of her own reported energy
/// around period starts.
///
/// ## The caption, and the sentence still missing
///
/// The design draws "You logged low energy on 4 of 6 logged days in the first 3
/// days of your last 2 periods" and "6 logged days · 2 cycles". Both existed in
/// the dictionary **only as fixed strings with the mockup's numbers in them**,
/// so both were withheld: rendering one would have told every woman she logged
/// low energy on four of six days regardless of what she logged, the defect
/// `PHASE1-FIXES.md` #13 records on four screens and #3 on C13.
///
/// `loggedOfTotalLoggedDays` is now the placeholder form for the first, so the
/// caption renders **her** two numbers — the low-energy days she logged, out of
/// the days in the window she logged at all. Both come from the one
/// [CyclePatternsSnapshot] the chart is drawn from, so the sentence and the bars
/// beside it cannot disagree.
///
/// The second sentence, "6 logged days · 2 cycles", has no placeholder form yet
/// and is still absent.
///
/// ## What the caption deliberately is not
///
/// It counts low-energy days against **logged** days, never against the days
/// the window asked for. "2 of 6 days logged" is an adherence score about how
/// often she opens the app, and plan §12 bans one: "No daily streak, no
/// adherence score, no 'readiness'." This screen describes symptoms, not
/// diligence.
///
/// ## Missing days stay missing
///
/// A day with no check-in renders as an absent bar, never as a low-energy one.
library;

import 'package:flutter/material.dart';

import '../../../domain/format/number_label.dart';
import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/app_toggle.dart';
import '../../../ui/hand/hand.dart';
import '../domain/today_check_in.dart';
import 'cycle_patterns_view_model.dart';
import 'cycle_widgets.dart';

class CyclePatternsView extends StatelessWidget {
  const CyclePatternsView({
    super.key,
    this.recentStarts = const <String>[],
    this.checkIns = const <String, TodayCheckIn>{},
    this.easierWhenLowEnergy = false,
    this.showCalendarTab = true,
    this.viewModel = const CyclePatternsViewModel(),
    this.onBack,
    this.onSettings,
    this.onToggleEasier,
    this.onSelectTab,
    this.onSelectCycleTab,
  });

  final List<String> recentStarts;
  final Map<String, TodayCheckIn> checkIns;
  final bool easierWhenLowEnergy;
  final bool showCalendarTab;
  final CyclePatternsViewModel viewModel;

  final VoidCallback? onBack;
  final VoidCallback? onSettings;
  final ValueChanged<bool>? onToggleEasier;
  final ValueChanged<String>? onSelectTab;
  final ValueChanged<CycleTab>? onSelectCycleTab;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final snapshot = viewModel.build(
      recentStarts: recentStarts,
      checkIns: checkIns,
      easierWhenLowEnergy: easierWhenLowEnergy,
    );

    return Scaffold(
      backgroundColor: AppColors.surface,
      bottomNavigationBar: CycleNavBar(
        screenId: 'Y10',
        onSelectTab: onSelectTab,
      ),
      appBar: AppTopBar(
        title: l10n.myCycle,
        onBack: onBack,
        actions: [
          IconButton(
            tooltip: l10n.cycleSettings,
            color: AppColors.onSurfaceVariant,
            icon: const Icon(Icons.settings),
            onPressed: onSettings,
          ),
        ],
      ),
      body: AppScaffold(
        children: [
          CycleTabs(
            active: CycleTab.patterns,
            showCalendar: showCalendarTab,
            onSelect: onSelectCycleTab,
          ),
          Text(l10n.yourPatterns, style: AppText.titleL),
          AppCard(
            children: [
              Text(
                l10n.energyOnTheFirstThreeDaysOf,
                style: AppText.bodyM.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              if (snapshot.isEmpty)
                // Says so, rather than drawing an empty chart that reads as
                // "no symptoms".
                Text(
                  l10n.noDatesNoEstimates,
                  style: AppText.bodyM.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                )
              else ...[
                _Chart(bars: snapshot.bars, l10n: l10n),
                // Her two numbers, from the same snapshot the bars are drawn
                // from. `countLabel`, never `NumberFormat` — Western digits in
                // both locales (`P0-A11Y-01`).
                Text(
                  l10n.loggedOfTotalLoggedDays(
                    countLabel(snapshot.lowEnergyDays),
                    countLabel(snapshot.counts.logged),
                  ),
                  style: AppText.bodyM.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
              Text(l10n.thisDescribesYourLogsItDoesNot, style: AppText.bodyM),
            ],
          ),
          // A setting, not a finding: a flat tint rather than a second sheet
          // the same as the chart's.
          AppCard(
            variant: AppCardVariant.filled,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            children: [
              CycleSwitchRow(
                title: l10n.offerAnEasierWorkoutWhenILog,
                subtitle: l10n.changesWhatWeSuggestNeverYourPlan,
                trailing: AppToggle(
                  value: snapshot.easierWhenLowEnergy,
                  semanticLabel: l10n.offerAnEasierWorkoutWhenILog,
                  onChanged: onToggleEasier,
                ),
              ),
            ],
          ),
          // The counts sentence is deliberately absent. See the library note.
        ],
      ),
    );
  }
}

class _Chart extends StatelessWidget {
  const _Chart({required this.bars, required this.l10n});

  final List<PatternBar> bars;
  final AppL10n l10n;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      // 92 for the tallest bar, 6 for the gap, and room for the word under it.
      // At 110 this overflowed by 4 pixels the first time a test rendered a
      // high-energy day — the chart had never been drawn at its own maximum.
      height: 128,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final bar in bars) ...[
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _Bar(energy: bar.energy),
                  const SizedBox(height: 6),
                  Text(
                    switch (bar.energy) {
                      Energy.low => l10n.low,
                      Energy.ok => l10n.okay,
                      Energy.high => l10n.high,
                      null => '',
                    },
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.nav.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
          ],
        ],
      ),
    );
  }
}

/// One day's bar. Heights are the chart's three fixed steps and are drawn
/// exactly; only the finish is the page's.
///
/// A low-energy day is shaded in pencil over its blush, so the difference
/// from an okay or high day is a texture as well as a colour.
class _Bar extends StatelessWidget {
  const _Bar({required this.energy});

  final Energy? energy;

  @override
  Widget build(BuildContext context) {
    final height = switch (energy) {
      Energy.low => 30.0,
      Energy.ok => 66.0,
      Energy.high => 92.0,
      // A day she did not log has no bar at all.
      null => 0.0,
    };
    if (height == 0) return const SizedBox.shrink();

    final low = energy == Energy.low;
    return HandSurface(
      seed: handSeed(['pattern-bar', energy?.index]),
      fill: low ? AppColors.primaryContainer : AppColors.tertiaryContainer,
      hatch: low ? AppColors.primaryDim : null,
      level: HandLevel.structural,
      radius: 2,
      looseCorner: 6,
      child: SizedBox(width: double.infinity, height: height),
    );
  }
}
