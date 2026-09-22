/// P01 — Your progress.
///
/// Matches `6-v2/src/screens-progress.mjs` → `P01`. The design note names the
/// three numbers and what each is for: *"the tier is how steady she is lately,
/// the level is everything she has ever done, and the week bar is what to do
/// now."*
///
/// ## Two of those three are hers. The tier is not yet anybody's.
///
/// The week bar and the level are computed from her own documents and render
/// her own figures. The tier does not render at all, and that is the point of
/// this screen rather than a hole in it.
///
/// `DECISIONS.md` D6 delegates the tier thresholds and says **"Until written
/// here, no tier number is authoritative."** They have not been written. G6 §3.2
/// infers a table and §9.2 immediately records that P01 and T05 contradict each
/// other about it. So [TierLadder.unauthored] is what the app supplies,
/// `standing.isKnown` is false, and every tier surface on this screen — the
/// name, the holding sentence, the "Next: Strong" card and both of its bars —
/// draws nothing.
///
/// `PHASE2-ACCEPTANCE.md` states the consequence plainly: *"P01 cannot ship an
/// authoritative tier number."* It does not.
///
/// ## Every other figure is checked against her before it is shown
///
/// The dictionary carried most of this screen's numbers as **fixed strings** —
/// `n14WeeksCountedBestRun9`, `level7`, `n1Saved`, `n4Of12`, `n8SoFar` — with no
/// placeholder form. Rendering those to everyone is the defect
/// `PHASE1-QA-VERDICT` calls blocking, and inventing English in the widget would
/// put untranslated text in front of an Arabic reader.
///
/// Three of them now have a parameterised form, and where one exists this screen
/// uses it rather than withholding the line: `levelN` replaces `level7`, and
/// `countOfTotal` replaces `n4Of12`, `n14Of20` and `n8Of10`. Those lines are now
/// stated to **every** woman, because they state her own figure.
///
/// The rest still go through [statedLine], which returns the sentence only when
/// the figure baked into it really is hers. A woman with nine counted weeks is
/// told nothing about her counted weeks rather than told she has fourteen. The
/// four remaining call sites — `n14WeeksCountedBestRun9`, `n8SoFar`, `n1Saved`,
/// `nextStrong` and the "Regular holds…" sentence — are the list of
/// parameterised keys still to be minted, and the build reports them.
///
/// The one figure that does render for everybody is the week line, because
/// `thisWeekDoneOfTarget` **is** parameterised — and it is fed from the same
/// object as the segments directly beneath it, so the sentence and the bar
/// cannot disagree (`PHASE1-FIXES.md` §13).
library;

import 'package:flutter/material.dart';

import '../../../domain/format/number_label.dart';
import '../../../domain/rewards/stated_figure.dart';
import '../../../domain/rewards/tier_policy.dart';
import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_list_item.dart';
import '../../../ui/app_nav_bar.dart';
import '../../../ui/app_pill.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/app_split_row.dart';
import '../../../ui/app_week_segments.dart';
import '../../../ui/hand/hand.dart';
import '../../today/presentation/today_cards.dart' show openScreen;
import 'progress_view_model.dart';
import 'progress_widgets.dart';

class ProgressView extends StatelessWidget {
  const ProgressView({
    super.key,
    required this.summary,
    this.onBack,
    this.onOpenMilestones,
    this.onOpenBests,
    this.onOpenBody,
    this.onOpenFirstWeek,
    this.onOpenRestWeek,
    this.onOpenTierSlip,
    this.onSelectTab,
  });

  /// Her progress, already computed. The screen does no arithmetic.
  final ProgressSummary summary;

  final VoidCallback? onBack;
  final VoidCallback? onOpenMilestones;
  final VoidCallback? onOpenBests;
  final VoidCallback? onOpenBody;
  final VoidCallback? onOpenFirstWeek;

  /// "What a rest week covers" → T04. This is T04's only inbound edge in the
  /// whole design, and leaving it unwired is what made T04 unreachable.
  final VoidCallback? onOpenRestWeek;

  /// "If a tier slips" → T05, likewise.
  final VoidCallback? onOpenTierSlip;

  final ValueChanged<String>? onSelectTab;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppTopBar(title: l10n.yourProgress, onBack: onBack),
      bottomNavigationBar: AppNavBar(
        activeScreenId: 'T01',
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
          ..._tierCard(l10n),
          ..._nextTierCard(l10n),
          _weekCard(l10n),
          // Below her week, quieter: a rule, then the rest of the record.
          const HandRule(seed: 37, height: 18),
          _tiles(context, l10n),
          AppListItem(
            leading: const Icon(
              Icons.checklist,
              size: 22,
              color: AppColors.primaryDim,
            ),
            title: l10n.yourFirstWeek,
            subtitle: l10n.allFiveDone,
            trailing: const Icon(
              Icons.chevron_right,
              size: 22,
              color: AppColors.onSurfaceVariant,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            onTap: () => openScreen(context, 'T07', onOpenFirstWeek),
          ),
          AppListItem(
            leading: const Icon(Icons.spa, size: 22, color: AppColors.tertiary),
            title: l10n.whatARestWeekCovers,
            subtitle: l10n.aMissedWeekRepairedWithoutAsking,
            trailing: const Icon(
              Icons.chevron_right,
              size: 22,
              color: AppColors.onSurfaceVariant,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            onTap: () => openScreen(context, 'T04', onOpenRestWeek),
          ),
          AppListItem(
            leading: const Icon(
              Icons.info_outline,
              size: 22,
              color: AppColors.primaryDim,
            ),
            title: l10n.ifATierSlips,
            subtitle: l10n.oneCountedWeekBringsItBack,
            trailing: const Icon(
              Icons.chevron_right,
              size: 22,
              color: AppColors.onSurfaceVariant,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            onTap: () => openScreen(context, 'T05', onOpenTierSlip),
          ),
        ],
      ),
    );
  }

  /// Her tier, her counted weeks and her level.
  ///
  /// Drawn only where something true can be said. With no authored ladder the
  /// tier name and the holding sentence are absent; with figures that are not
  /// the prototype's, the counted-week line and the level pill are absent too.
  /// If none of the four has anything to say, the card itself does not appear —
  /// an empty card is a hole, not a design.
  List<Widget> _tierCard(AppL10n l10n) {
    final tierName = _tierLabel(l10n);

    // 'Regular holds while four of your last eight weeks count. Six did.' —
    // names a tier AND two thresholds, so it needs the ladder D6 has not
    // authored. Dictionary gap: a parameterised holding sentence.
    final holds = summary.tierIsKnown ? _holdingSentence(l10n) : null;

    // '14 weeks counted · best run 9'.
    final counted = statedLine<(int, int)>(
      l10n.n14WeeksCountedBestRun9,
      states: (14, 9),
      hers: (summary.countedWeeks, summary.bestRun),
    );

    // 'Level {n}' — hers, in Western digits.
    //
    // This replaces `level7`, a fixed string that announced the mockup's level
    // seven to a woman on level one. Because the parameterised form exists, the
    // pill no longer has to be withheld from everybody whose level is not 7:
    // every woman has a level, so this always draws.
    final level = l10n.levelN(countLabel(summary.level));

    // A masthead rather than a card, the shape Today opens with: her
    // standing set small on the page, her level highlighted at the edge, and
    // a pencil rule under both. The week below is the page's subject.
    return [
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          AppSplitRow(
            start: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (tierName != null) Text(tierName, style: AppText.headline),
                if (counted != null) ...[
                  if (tierName != null) const SizedBox(height: 2),
                  Text(
                    counted,
                    style: AppText.bodyM.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
            end: AppPill(level, icon: Icons.workspace_premium),
          ),
          if (holds != null) ...[
            const SizedBox(height: 8),
            Text(
              holds,
              style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
            ),
          ],
          const HandRule(seed: 19, height: 10),
        ],
      ),
    ];
  }

  /// "Next: Strong · Counted weeks 14 of 20 · Personal bests 8 of 10".
  ///
  /// Never drawn today: [ProgressSummary.nextRung] is null while the ladder is
  /// unauthored. The card is written rather than omitted so that authoring the
  /// ladder is the only change needed to make it appear — and so the bars, when
  /// they do appear, are her real ratios rather than the prototype's 70% and 80%.
  List<Widget> _nextTierCard(AppL10n l10n) {
    final rung = summary.nextRung;
    if (rung == null) return const <Widget>[];

    // 'Next: Strong' — a fixed string naming one specific tier, so it heads
    // the card only for a woman whose next tier IS Strong. Absent otherwise,
    // rather than an empty line.
    final title = statedLine<String>(
      l10n.nextStrong,
      states: 'strong',
      hers: rung.tier.name,
    );
    // '{count} of {total}', so the figure beside each bar is the same ratio
    // the bar draws. `n14Of20` and `n8Of10` stated the mockup's thresholds and
    // were withheld from everyone else; the parameterised form states hers.
    //
    // A threshold of none gets no row: there is nothing to fill, and a bar
    // beside "0 of 0" can only read as done.
    final rows = <Widget>[
      if (rung.countedWeeks > 0)
        MiniStat(
          label: l10n.countedWeeks,
          percent: summary.percentToCountedWeeks(rung),
          value: l10n.countOfTotal(
            countLabel(summary.countedWeeks),
            countLabel(rung.countedWeeks),
          ),
        ),
      if (rung.bestsCount > 0)
        MiniStat(
          label: l10n.personalBests,
          percent: summary.percentToBests(rung),
          value: l10n.countOfTotal(
            countLabel(summary.bestsCount),
            countLabel(rung.bestsCount),
          ),
        ),
    ];
    if (title == null && rows.isEmpty) return const <Widget>[];

    return [
      AppCard(
        variant: AppCardVariant.amber,
        gap: 8,
        children: [
          if (title != null) Text(title, style: AppText.titleM),
          ...rows,
        ],
      ),
    ];
  }

  /// The week, which is the only unit this product counts in.
  ///
  /// Everything here is hers. The heading is the parameterised
  /// `thisWeekDoneOfTarget` and the segments below it are built from the same
  /// two numbers, so — unlike the defect this replaces — the sentence and the
  /// bar cannot disagree.
  Widget _weekCard(AppL10n l10n) {
    // 'Last eight weeks · the pale one was a rest week' describes a pale bar.
    // With no repaired week on the chart there is no pale bar to describe.
    final legend = summary.hasRepairedWeekInWindow
        ? l10n.lastEightWeeksThePaleOneWas
        : null;

    // '1 saved' — rest weeks banked.
    final saved = statedLine<int>(
      l10n.n1Saved,
      states: 1,
      hers: summary.restWeeksBanked,
    );

    // Her week is the page's subject, so it is set on the page itself: the
    // line at section size, and the sessions as marks she keeps by hand — a
    // sage tick in each one logged, the next circled in rose. The marks are
    // the only signature here; the chart and its legend below stay print.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 6),
        Text(
          l10n.thisWeekDoneOfTarget(
            summary.sessionsThisWeek,
            summary.sessionsTarget,
          ),
          style: EditorialType.section,
        ),
        const SizedBox(height: 14),
        AppWeekSegments(
          total: summary.sessionsTarget,
          filled: summary.sessionsThisWeek,
          style: WeekStyle.marks,
        ),
        const SizedBox(height: 18),
        WeekBarsChart(weeks: summary.recentWeeks),
        if (legend != null || saved != null) ...[
          const SizedBox(height: 8),
          AppSplitRow(
            start: legend == null
                ? const SizedBox.shrink()
                : Text(
                    legend,
                    style: AppText.bodyM.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
            end: saved == null
                ? const SizedBox.shrink()
                : Text(
                    saved,
                    style: AppText.bodyM.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
          ),
        ],
      ],
    );
  }

  Widget _tiles(BuildContext context, AppL10n l10n) {
    // The section's contents, set as one ruled line of three entries with
    // pencil strokes between them — the way a magazine lists what is inside —
    // rather than three matching cards. At a large text size they stack.
    final entries = [
      _IndexEntry(
        icon: Icons.military_tech,
        label: l10n.milestones,
        // Her earned count against the catalogue size, from the
        // parameterised form rather than the mockup's '4 of 12'.
        //
        // Withheld when the catalogue is empty: "2 of 0" is not a fact
        // about anybody. That is the state P01 is wired in today — see the
        // build report on `app_router.dart`.
        meta: summary.milestoneCount <= 0
            ? null
            : l10n.countOfTotal(
                countLabel(summary.milestonesEarned),
                countLabel(summary.milestoneCount),
              ),
        onTap: () => openScreen(context, 'P02', onOpenMilestones),
      ),
      _IndexEntry(
        icon: Icons.emoji_events,
        label: l10n.bests,
        // '8 so far'.
        meta: statedLine<int>(
          l10n.n8SoFar,
          states: 8,
          hers: summary.bestsCount,
        ),
        onTap: () => openScreen(context, 'P03', onOpenBests),
      ),
      _IndexEntry(
        icon: Icons.monitor_weight,
        label: l10n.body,
        // True for every woman: nobody else can read it.
        meta: l10n.private,
        onTap: () => openScreen(context, 'P04', onOpenBody),
      ),
    ];
    final stacked = MediaQuery.textScalerOf(context).scale(1) > 1.3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (stacked)
          ...entries
        else
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < entries.length; i++) ...[
                  if (i > 0)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: SizedBox(
                        width: 1,
                        child: ColoredBox(color: Color(0x669C838A)),
                      ),
                    ),
                  Expanded(child: entries[i]),
                ],
              ],
            ),
          ),
        const HandRule(seed: 62, height: 6),
      ],
    );
  }

  /// The tier's own name.
  ///
  /// All five are now in the dictionary — "First steps", "Strong" and
  /// "Unshakeable" joined `regular` and `showingUp` — so naming a tier is no
  /// longer what blocks this. **The ladder still is.** `TierLadder.unauthored`
  /// is what the app supplies, so `display` is null and this returns null for
  /// every woman today. Minting the names means P01 can name her tier the day
  /// D6 writes the thresholds down, with no further code change; it does not
  /// mean the product knows what her tier is.
  String? _tierLabel(AppL10n l10n) {
    final display = summary.standing.display;
    if (display == null) return null;
    return switch (display) {
      Tier.firstSteps => l10n.firstSteps,
      Tier.showingUp => l10n.showingUp,
      Tier.regular => l10n.regular,
      Tier.strong => l10n.strong,
      Tier.unshakeable => l10n.unshakeable,
    };
  }

  /// "Regular holds while four of your last eight weeks count. Six did."
  ///
  /// States a tier, a threshold and a count. Rendered only for the tier it
  /// names, and only when her recent window really does hold six counted weeks.
  String? _holdingSentence(AppL10n l10n) {
    if (summary.standing.display != Tier.regular) return null;
    return statedLine<int>(
      l10n.regularHoldsWhileFourOfYourLast,
      states: 6,
      hers: summary.goal.countedInRecentWindow,
    );
  }
}

/// One entry in P01's contents line: the product's own icon, a name, and her
/// figure under it when there is one. A tap target of at least 44.
class _IndexEntry extends StatelessWidget {
  const _IndexEntry({
    required this.icon,
    required this.label,
    required this.onTap,
    this.meta,
  });

  final IconData icon;
  final String label;
  final String? meta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return HandPressable(
      onTap: onTap,
      builder: (context, _) => ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          // The icon sits above the name rather than beside it, so a third of
          // the column is enough for "Milestones" without breaking the word.
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: AppColors.primaryDim),
              const SizedBox(height: 4),
              Text(label, style: AppText.titleS),
              if (meta != null) ...[
                const SizedBox(height: 2),
                Text(
                  meta!,
                  style: AppText.bodyM.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
