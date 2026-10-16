/// P02 — Milestones.
///
/// Matches `6-v2/src/screens-progress.mjs` → `P02`. The design note is the rule:
/// *"Twelve milestones, every one tied to training, eating or coming back.
/// Unearned ones show plain progress instead of a locked badge, because a
/// padlock reads as 'you are not allowed'."*
///
/// So there is no lock icon anywhere in this file and no `locked` state in
/// [MilestoneStanding]. An unearned milestone is a bar that is part-way along.
///
/// ## Eight, not twelve — and the screen does not claim otherwise
///
/// G6 §9.14: *"P02 names eight; I inferred four (first meal logged, 10 personal
/// bests, first rest week banked, 100 sessions). Sign-off needed on the list and
/// on 25 points each."* Inferring four and shipping them would be the same
/// defect as shipping an inferred tier ladder, so [authoredMilestones] holds
/// only the ones P02 actually names — **eight**.
///
/// It held seven until the dictionary gained `cameBack`. "Came back" was named
/// in the note at the foot of the screen but had no standalone label, so it
/// could not be a row. It has one now, and the catalogue is the full eight P02
/// names. The remaining four are still unauthored and still absent: a label
/// was what blocked the eighth, and nothing blocks the other four but a
/// decision nobody has taken.
///
/// The heading *"Twelve in all"* is therefore checked rather than stated: it is
/// rendered through [statedLine] against the real catalogue size, and with eight
/// milestones it does not draw. When the remaining four are authored and
/// labelled it starts drawing by itself, with no code change.
library;

import 'package:flutter/material.dart';

import '../../../domain/format/number_label.dart';
import '../../../domain/rewards/stated_figure.dart';
import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_nav_bar.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/hand/hand.dart';
import '../../today/presentation/today_cards.dart' show openScreen;
import '../domain/milestone.dart';
import 'progress_view_model.dart';
import 'progress_widgets.dart';

/// The milestones this product ships today.
///
/// Eight, because eight is how many P02 names and the dictionary can now label.
/// See the library comment — the other four are a content obligation, not a
/// coding task, and guessing them is the thing this file exists not to do.
const MilestoneCatalogue authoredMilestones = MilestoneCatalogue(<Milestone>[
  Milestone(id: 'first_session', measure: MilestoneMeasure.sessions, target: 1),
  Milestone(
    id: 'first_counted_week',
    measure: MilestoneMeasure.countedWeeks,
    target: 1,
  ),
  Milestone(
    id: 'first_personal_best',
    measure: MilestoneMeasure.personalBests,
    target: 1,
  ),
  Milestone(id: 'ten_sessions', measure: MilestoneMeasure.sessions, target: 10),
  Milestone(
    id: 'twenty_counted_weeks',
    measure: MilestoneMeasure.countedWeeks,
    target: 20,
  ),
  Milestone(
    id: 'first_program_finished',
    measure: MilestoneMeasure.programDays,
    target: 18,
  ),
  Milestone(
    id: 'fifty_sessions',
    measure: MilestoneMeasure.sessions,
    target: 50,
  ),
  // The eighth, and the one P02 says it most wants her to have. It was the
  // only one of the eight P02 names that had no standalone label — the screen
  // could describe it in the note at the foot and not as a row. `cameBack`
  // exists now, so it is a row.
  //
  // Its measure counts nothing: coming back is an event the ledger records, so
  // `MilestoneCounts.of` returns 0 for it and it is earned because
  // `rewards.milestones` says so. That is the same rule every other milestone
  // follows, and it is why no counter here can un-earn it.
  Milestone(id: 'came_back', measure: MilestoneMeasure.cameBack, target: 1),
]);

class MilestonesView extends StatelessWidget {
  const MilestonesView({
    super.key,
    required this.summary,
    this.onBack,
    this.onSelectTab,
  });

  final MilestonesSummary summary;
  final VoidCallback? onBack;
  final ValueChanged<String>? onSelectTab;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    // 'Twelve in all. None are secret, and none are for filling in a profile.'
    // The second half is true of any catalogue; the first names a size. Both
    // travel in one dictionary value, so the whole sentence waits for the list.
    final heading = statedLine<int>(
      l10n.twelveInAllNoneAreSecretAnd,
      states: 12,
      hers: summary.catalogueCount,
    );

    final earned = summary.earned;
    final ahead = summary.ahead;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppTopBar(title: l10n.milestones, onBack: onBack),
      bottomNavigationBar: AppNavBar(
        activeScreenId: 'P02',
        onSelect: (id) {
          final onTab = onSelectTab;
          if (onTab != null) {
            onTab(id);
            return;
          }
          openScreen(context, id);
        },
      ),
      body: AppScaffold(
        children: [
          if (heading != null)
            Text(
              heading,
              style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
            ),
          // What she has is set open on the page, its heading swiped in sage
          // marker — sage is done here, never won. What is still ahead sits
          // below a rule, on its own pencil-framed sheet.
          if (earned.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: MarkerHighlight(
                    color: AppColors.tertiaryContainer,
                    child: Text(
                      l10n.earned,
                      style: AppText.titleS.copyWith(
                        color: AppColors.onTertiaryContainer,
                      ),
                    ),
                  ),
                ),
                for (final standing in earned) ...[
                  const SizedBox(height: 12),
                  MilestoneDoneRow(
                    name: _label(l10n, standing.milestone.id) ?? '',
                    when: _earnedOn(l10n, standing),
                  ),
                ],
              ],
            ),
          if (earned.isNotEmpty && ahead.isNotEmpty)
            const HandRule(seed: 43, height: 14),
          if (ahead.isNotEmpty)
            AppCard(
              gap: 14,
              children: [
                Text(
                  l10n.next,
                  style: AppText.titleS.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                for (final standing in ahead)
                  MiniStat(
                    label: _label(l10n, standing.milestone.id) ?? '',
                    percent: standing.percent,
                    value: _aheadFigure(l10n, standing),
                    barHeight: 6,
                  ),
              ],
            ),
          // "Came back" is a row now, and it still has the last word on the
          // screen, which is where the design puts it. The note says why it
          // exists; the row says where she stands on it.
          AppCard(
            variant: AppCardVariant.tonal,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.favorite,
                    size: 22,
                    color: AppColors.primaryDim,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.cameBackIsEarnedByReturningAfter,
                      style: AppText.bodyM,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// The milestone's name, from the dictionary.
  ///
  /// Null for an id the dictionary cannot name, which is how an unauthored
  /// milestone stays off the screen instead of appearing as a blank row.
  String? _label(AppL10n l10n, String id) => milestoneTitle(l10n, id);

  /// When she earned it.
  ///
  /// The dictionary carries the prototype's four dates as fixed strings — "3
  /// Jun", "9 Jun" — and there is no month vocabulary to build any other date
  /// from, in either language. `MaterialLocalizations` would supply one, but
  /// under `ar` it formats with Eastern Arabic digits and breaks `P0-A11Y-01`,
  /// which is the same trap `weightLabel` and `countLabel` exist to avoid.
  ///
  /// So a woman who earned a milestone on a different day sees the milestone and
  /// its tick without a date, rather than somebody else's date. A parameterised
  /// date message is a reported dictionary gap.
  String? _earnedOn(AppL10n l10n, MilestoneStanding standing) {
    final at = standing.earnedAt;
    if (at == null) return null;
    return switch (standing.milestone.id) {
      'first_session' => _on(at, 2026, 6, 3) ? l10n.n3Jun : null,
      'first_counted_week' => _on(at, 2026, 6, 9) ? l10n.n9Jun : null,
      'first_personal_best' => _on(at, 2026, 6, 17) ? l10n.n17Jun : null,
      'ten_sessions' => _on(at, 2026, 7, 1) ? l10n.n1Jul : null,
      _ => null,
    };
  }

  /// Her own count against the target — "14 of 20", "31 of 50".
  ///
  /// This replaces three fixed strings (`n14Of20`, `day11Of18`, `n23Of50`) that
  /// each stated the mockup's pair of numbers, so a woman whose figures did not
  /// happen to match saw a bar with no figure beside it. `countOfTotal` states
  /// hers, on every milestone that is a count to climb.
  ///
  /// Null for a "first ever" milestone. [Milestone.isFirstOfItsKind] is a single
  /// event rather than a count, so "0 of 1" would be a number where there is
  /// nothing to be part-way through — the bar alone says it better.
  ///
  /// The one thing lost is the word "day" in "day 11 of 18": the progress
  /// milestone now reads "11 of 18". A `day {n} of {total}` key is a reported
  /// gap.
  String? _aheadFigure(AppL10n l10n, MilestoneStanding standing) {
    if (standing.milestone.isFirstOfItsKind) return null;
    return l10n.countOfTotal(
      countLabel(standing.shown),
      countLabel(standing.milestone.target),
    );
  }

  static bool _on(DateTime at, int year, int month, int day) =>
      at.year == year && at.month == month && at.day == day;
}

/// A milestone's name, from the dictionary. Shared with P01's "next
/// milestone", so the two screens cannot name one milestone two ways.
///
/// Null for an id the dictionary cannot name, which is how an unauthored
/// milestone stays off the screen instead of appearing as a blank row.
String? milestoneTitle(AppL10n l10n, String id) => switch (id) {
  'first_session' => l10n.firstSession,
  'first_counted_week' => l10n.firstCountedWeek,
  'first_personal_best' => l10n.firstPersonalBest,
  'ten_sessions' => l10n.n10Sessions,
  'twenty_counted_weeks' => l10n.n20CountedWeeks,
  'first_program_finished' => l10n.firstProgramFinished,
  'fifty_sessions' => l10n.n50Sessions,
  'came_back' => l10n.cameBack,
  _ => null,
};
