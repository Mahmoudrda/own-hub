/// T04 — After a quiet week.
///
/// Matches `6-v2/src/screens-today.mjs` → `T04`. Monday is a fresh start, so
/// this is when the app speaks.
///
/// **This screen has no failure state, and that is the whole design.**
/// `DECISIONS.md` D5: a banked rest week protects her completely and must never
/// reduce a reward; D5a: rest the app itself advised is planned rest, not a
/// skip. So what was protected is said before anything else — her counted weeks
/// are *safe* — and then the ask shrinks to the shortest session and an even
/// smaller meal log.
///
/// There is deliberately no red, no error variant, and **no count of what was
/// missed** anywhere in this file. The week card shows sessions logged against
/// the goal, which is a total that moves, never a deficit that accuses.
///
/// The notice is marked seen on first render. Because the document key contains
/// the ISO week (plan G3 §1.2), acknowledging it is idempotent under offline
/// replay — she cannot be shown the same Monday's notice twice.
///
/// ## What changed when the rewards engine landed
///
/// This screen used to state the prototype's numbers as facts about her. The
/// week card read *"This week, 0 of 3"* from a fixed dictionary string while
/// being handed the literal `total: 3, filled: 0`, and the headline read *"Your
/// 14 weeks are safe"* to every woman — `PHASE1-FIXES.md` §13 records it as the
/// fourth occurrence of a class this codebase has now fixed five times, and
/// `DECISIONS.md` records why it could not be fixed then: **the view received no
/// week count of any kind.**
///
/// It does now. [goal] carries her real counters and the repository already
/// carried her real week, so:
///
///   * the week line is the **parameterised** `thisWeekDoneOfTarget`, fed from
///     the same object as the segments beneath it, so the sentence and the bar
///     cannot disagree;
///   * the headline goes through `statedLine`, because the dictionary's only
///     form of it has "14" inside it. A woman with nine counted weeks is told
///     that a rest week covered her week and is not told she has fourteen. A
///     parameterised headline is a reported dictionary gap;
///   * and the card that carries both is drawn only when [WeeklyGoal
///     .lastRepairedWeek] names a week. That sentence was unconditional and
///     T04 has a route: P01 links to it, so a phone switched on that morning
///     was two taps from being told a rest week had covered a week she was not
///     here for.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../domain/clock/app_clock.dart';
import '../../../domain/rewards/stated_figure.dart';
import '../../../domain/rewards/weekly_goal.dart';
import '../../../domain/week/week_key.dart';
import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_nav_bar.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/app_split_row.dart';
import '../../../ui/hand/hand.dart';
import '../domain/today_repository.dart';
import 'today_cards.dart';

class QuietWeekView extends StatefulWidget {
  const QuietWeekView({
    super.key,
    this.repository,
    this.date,
    this.goal,
    this.onStartShortSession,
    this.onOpenMeal,
    this.onOpenWeek,
    this.onSelectTab,
  });

  final TodayRepository? repository;

  /// The Monday this is shown on.
  final DateTime? date;

  /// Her counted weeks, her rest-week bank, her run.
  ///
  /// Optional because the Today repository does not carry it — `weeklyGoal` is
  /// G6's document, published to G3 precisely so T04 can report a repair without
  /// paying a fifth Monday read. Null means the caller has not wired it yet, and
  /// the screen then says nothing about her counted weeks rather than guessing.
  final WeeklyGoal? goal;

  final VoidCallback? onStartShortSession;
  final VoidCallback? onOpenMeal;
  final VoidCallback? onOpenWeek;
  final ValueChanged<String>? onSelectTab;

  @override
  State<QuietWeekView> createState() => _QuietWeekViewState();
}

class _QuietWeekViewState extends State<QuietWeekView> {
  late final TodayRepository _repo;
  late final bool _ownsRepo;
  late final DateTime _date;

  @override
  void initState() {
    super.initState();
    _ownsRepo = widget.repository == null;
    _repo = widget.repository ?? InMemoryTodayRepository();
    // Today, not the prototype's Monday. `DateTime(2026, 9, 14)` was the
    // mockup's date and the router passes no `date`, so T04 greeted every woman
    // with "Monday 14 September" for ever while Home, T02 and R10 beside it all
    // said the real day.
    _date = widget.date ?? AppClock.now();
    // Shown once, never again that week.
    unawaited(_repo.markNoticeSeen(NoticeKind.quietWeek, WeekKey.of(_date)));
  }

  @override
  void dispose() {
    if (_ownsRepo) unawaited(_repo.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final week = _repo.day.week;

    // The week a rest week covered, or null if none did. See the card below.
    final repairedWeek = widget.goal?.lastRepairedWeek;

    // 'Your 14 weeks are safe' — a fixed string with her count inside it.
    final safe = statedLine<int>(
      l10n.your14WeeksAreSafe,
      states: 14,
      hers: widget.goal?.countedWeeks ?? -1,
    );

    return Scaffold(
      backgroundColor: AppColors.surface,
      bottomNavigationBar: AppNavBar(
        // T04, not T01: see the note in `already_did_it_view.dart`. Claiming
        // Home here killed the Home tab on the one screen a woman opens after
        // a week she missed.
        activeScreenId: 'T04',
        onSelect: (id) {
          final onTab = widget.onSelectTab;
          if (onTab != null) {
            onTab(id);
            return;
          }
          openScreen(context, id);
        },
      ),
      body: AppScaffold(
        children: [
          TodayGreeting(day: weekdayLabel(l10n, _date)),
          // What was protected, before anything else on the screen.
          //
          // **Only when a rest week actually covered one.** The sentence says
          // "A rest week covered last week, so nothing changed" and it was
          // printed unconditionally, to a phone that had been switched on that
          // morning: P01 draws a row to T04, so two taps from Progress on day
          // one told a brand-new woman that a rest week had covered a week she
          // was not here for, at `restWeeksBanked = 0, countedWeeks = 0`. Same
          // class as the headline three lines above, which already goes through
          // `statedLine` for stating "14".
          //
          // [WeeklyGoal.lastRepairedWeek] is the field G6 publishes for exactly
          // this — "so T04 can report a repair from the user document it
          // already read" — so a repair it does not name is a repair that did
          // not happen. Null also covers the caller that has wired no goal at
          // all, which is the same answer: say nothing about her weeks rather
          // than guess.
          if (repairedWeek != null)
            AppCard(
              variant: AppCardVariant.sage,
              gap: 8,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.spa, size: 24, color: AppColors.tertiary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: safe == null
                          ? Text(
                              l10n.aRestWeekCoveredLastWeekSo,
                              style: AppText.body,
                            )
                          : Text(safe, style: AppText.titleM),
                    ),
                  ],
                ),
                if (safe != null)
                  Text(l10n.aRestWeekCoveredLastWeekSo, style: AppText.body),
              ],
            ),
          // Then the ask, shrunk to the smallest thing that still counts.
          //
          // Set on the page as the cover, the way Today sets its session, with
          // the one figure that makes it small — ten minutes — circled by hand.
          // That circle is this page's mark; everything under the rule is
          // Today's usual furniture.
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 6),
              AppSplitRow(
                start: Text(
                  l10n.theShortestOneWeHave,
                  style: EditorialType.section,
                ),
                end: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  child: HandCircled(
                    level: HandLevel.signature,
                    drawOn: true,
                    delay: const Duration(milliseconds: 200),
                    child: Text(
                      l10n.n10Min,
                      style: AppText.label.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.onSurface,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                l10n.fourMovesFloorOnlyNothingToCarry,
                style: AppText.bodyM.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 14),
              AppButton(
                l10n.startThe10Minutes,
                height: 54,
                icon: Icons.play_arrow,
                onPressed: () =>
                    openScreen(context, 'R07', widget.onStartShortSession),
              ),
            ],
          ),
          const HandRule(seed: 53, height: 18),
          MealCard(
            title: l10n.orJustLogBreakfast,
            loggedAt: DateTime(_date.year, _date.month, _date.day, 8, 40),
            onTap: () => openScreen(context, 'E02', widget.onOpenMeal),
          ),
          WeekCard(
            // Her real count against her real target, from the same object the
            // segments are built from.
            title: l10n.thisWeekDoneOfTarget(
              week.sessionsLogged,
              week.sessionsTarget,
            ),
            line: l10n.nothingIsLostOneSessionStartsIt,
            total: week.sessionsTarget,
            filled: week.sessionsLogged,
            onTap: () => openScreen(context, 'P01', widget.onOpenWeek),
          ),
        ],
      ),
    );
  }
}
