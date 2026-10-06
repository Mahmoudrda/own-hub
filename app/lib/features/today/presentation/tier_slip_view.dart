/// T05 — When a tier slips.
///
/// Matches `6-v2/src/screens-today.mjs` → `T05`. Shown once, on the Monday it
/// happens, and then silent.
///
/// **Nothing earned is taken away, and nothing here is a failure state.** The
/// sheet names how close the way back is — one counted week, not the ten it took
/// to get there — and then lists everything she keeps: her counted weeks, her
/// level and every point, and everything the tier opened. There is no red, no
/// zero, and no list of what she missed.
///
/// That list is true by construction rather than by good intentions:
/// `UnlockPolicy.isUnlocked` reads `earnedTier`, which is monotonic, so a
/// slipped label closes nothing. Only the word on the pill moves.
///
/// She can also shrink this week's goal in one tap, because a goal she can meet
/// beats a goal she abandons. That write belongs to the rewards group
/// (`WeeklyGoalService.setTarget`), not to this screen — the spine forbids two
/// groups writing one field — so it leaves here as a callback.
///
/// "Shown once" is structural rather than remembered: the notice document's key
/// contains the ISO week, so an offline replay collides with itself instead of
/// re-raising the sheet.
///
/// ## The sheet does not open without a tier, and that is deliberate
///
/// Every sentence in this sheet names a tier or a threshold: *"You are Showing
/// up for now"*, *"Regular asks for four of your last eight weeks, and three
/// counted"*, *"Everything Regular opened"*. `DECISIONS.md` D6 says **"Until
/// written here, no tier number is authoritative"** and records that T05
/// *"contradicts D6 directly. It currently ships three."*
///
/// So the sheet is gated on [TierStanding.isKnown]. With the ladder unauthored —
/// which is what the app ships — there is no tier, the sheet does not open, and
/// Today stays exactly as it was. A tier-slip notice with no tier is not a
/// notice; rendering one with invented thresholds is the defect being fixed.
///
/// The two figures that *are* hers now resolve properly: [goal] carries her
/// counted weeks and [rewards] her points, so "Your 14 counted weeks" and
/// "Level 7 and every point" go through `statedLine` instead of being told to
/// everyone. `PHASE1-FIXES.md` §13 lists this screen as the fifth occurrence of
/// that defect class, unfixable at the time because **the view received no tier,
/// no level and no week count at all**. It receives all three now.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../domain/clock/app_clock.dart';
import '../../../domain/rewards/level_curve.dart';
import '../../../domain/rewards/rewards.dart';
import '../../../domain/rewards/stated_figure.dart';
import '../../../domain/rewards/tier_policy.dart';
import '../../../domain/rewards/weekly_goal.dart';
import '../../../domain/week/week_key.dart';
import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_nav_bar.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/app_sheet.dart';
import '../../../ui/hand/hand.dart';
import '../domain/today_repository.dart';
import 'today_cards.dart';

class TierSlipView extends StatefulWidget {
  const TierSlipView({
    super.key,
    this.repository,
    this.date,
    this.standing,
    this.goal,
    this.rewards,
    this.onStartShortSession,
    this.onShrinkGoal,
    this.onStartSession,
    this.onRecall,
    this.onSelectTab,
  });

  final TodayRepository? repository;
  final DateTime? date;

  /// Her tier on both axes, from `TierPolicy`.
  ///
  /// Null — or computed from an unauthored ladder — means there is no tier to
  /// report, and the sheet stays shut. See the library comment.
  final TierStanding? standing;

  /// Her counted weeks, for the first line of the kept list.
  final WeeklyGoal? goal;

  /// Her points, from which the level is computed by the same curve the server
  /// uses. Passing points rather than a level is deliberate: two places storing
  /// the level is two places for it to disagree.
  final Rewards? rewards;

  final VoidCallback? onStartShortSession;

  /// "Make this week 2 sessions" — the rewards group's write, never this one's.
  final VoidCallback? onShrinkGoal;

  final VoidCallback? onStartSession;
  final VoidCallback? onRecall;
  final ValueChanged<String>? onSelectTab;

  @override
  State<TierSlipView> createState() => _TierSlipViewState();
}

class _TierSlipViewState extends State<TierSlipView> {
  late final TodayRepository _repo;
  late final bool _ownsRepo;
  late final DateTime _date;
  late final bool _showSheet;

  /// She has closed the notice by tapping the scrim. Not persisted, because
  /// [initState] has already marked the notice seen for the week — this only
  /// decides whether it is still on screen for the rest of this visit.
  bool _dismissed = false;

  TierStanding get _standing => widget.standing ?? TierStanding.unknown;

  @override
  void initState() {
    super.initState();
    _ownsRepo = widget.repository == null;
    _repo = widget.repository ?? InMemoryTodayRepository();
    // Today, not the prototype's Monday. See the same fix in
    // `quiet_week_view.dart`: the router passes no `date`, so this screen
    // greeted every woman with 14 September 2026.
    _date = widget.date ?? AppClock.now();
    final week = WeekKey.of(_date);

    // Two conditions, and the order matters. There must be a tier to talk
    // about, and the notice must not already have been acknowledged this week.
    // Asked before it is marked: re-opening Today in the same ISO week finds the
    // notice already acknowledged and stays silent.
    _showSheet =
        _standing.isKnown && !_repo.noticeSeen(NoticeKind.tierSlip, week);

    if (_showSheet) {
      unawaited(_repo.markNoticeSeen(NoticeKind.tierSlip, week));
    }
  }

  @override
  void dispose() {
    if (_ownsRepo) unawaited(_repo.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    final raised = _showSheet && !_dismissed;

    return Scaffold(
      backgroundColor: AppColors.surface,
      // THE BAR IS THE TOP LAYER, AND THE SCRIM STOPS ABOVE IT.
      //
      // The rule `already_did_it_view.dart` (T02) states, applied here. The
      // scrim and the sheet used to be siblings of this Column and were drawn
      // AFTER it, so all three tabs were painted at the foot of T05 and every
      // pointer aimed at them was taken by the coloured box on top — and the
      // box carried no gesture at all, so it was a barrier that barred and did
      // not dismiss. Between them that left exactly two ways off this screen,
      // both of them buttons inside a notice she did not ask for.
      //
      // `tabs_live_journey_test.dart` names T02, T05 and R05 as the three
      // screens that did this. All three are fixed now, and `r1_49d` (a real
      // finger at the painted pixel) is the instrument that can see it —
      // `tester.semantics.tap` does not hit-test, so the semantics sweeps pass
      // either way. It cannot see this one on a fresh phone, because the
      // notice only appears when there is a tier to talk about; that is a gap
      // in the sweep, not evidence the screen was sound.
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                AppScaffold(
                  children: [
                    TodayGreeting(day: weekdayLabel(l10n, _date)),
                    WorkoutCard(
                      onStart: () =>
                          openScreen(context, 'R07', widget.onStartSession),
                      onRecall: () =>
                          openScreen(context, 'T02', widget.onRecall),
                    ),
                  ],
                ),
                if (raised) ...[
                  Positioned.fill(
                    child: Semantics(
                      button: true,
                      label: l10n.close,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => setState(() => _dismissed = true),
                        child: ColoredBox(
                          color: AppColors.ink.withValues(alpha: 0.45),
                        ),
                      ),
                    ),
                  ),
                  // Capped against this Stack's own constraints rather than the
                  // window — see the same note in T02.
                  LayoutBuilder(
                    builder: (context, constraints) => Align(
                      alignment: Alignment.bottomCenter,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: constraints.maxHeight * 0.92,
                        ),
                        child: SingleChildScrollView(
                          child: _sheet(context, l10n),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          AppNavBar(
            // T05, not T01: see the note in `already_did_it_view.dart`.
            activeScreenId: 'T05',
            onSelect: (id) {
              final onTab = widget.onSelectTab;
              if (onTab != null) {
                onTab(id);
                return;
              }
              openScreen(context, id);
            },
          ),
        ],
      ),
    );
  }

  Widget _sheet(BuildContext context, AppL10n l10n) {
    final level = const LevelCurve().levelFor(widget.rewards?.points ?? 0);

    // 'You are Showing up for now' names the tier she has slipped TO.
    final headline = _standing.display == Tier.showingUp
        ? l10n.youAreShowingUpForNow
        : null;

    // 'Regular asks for four of your last eight weeks, and three counted.'
    // Names the tier AND two thresholds — and G6 §9.2 records that this sentence
    // contradicts P01's version of the same rule, so it needs an edit before it
    // can be shown to anyone. Gated on the tier it names.
    final asks = _standing.earned == Tier.regular
        ? l10n.regularAsksForFourOfYourLast
        : null;

    // 'Your 14 counted weeks'.
    final counted = statedLine<int>(
      l10n.your14CountedWeeks,
      states: 14,
      hers: widget.goal?.countedWeeks ?? -1,
    );

    // 'Level 7 and every point'.
    final kept = statedLine<int>(
      l10n.level7AndEveryPoint,
      states: 7,
      hers: level,
    );

    // 'Everything Regular opened'. True only of the tier it names, and true by
    // construction once it is: unlocks read earnedTier, which has not moved.
    final opened = _standing.earned == Tier.regular
        ? l10n.everythingRegularOpened
        : null;

    return AppSheet(
      gap: 12,
      children: [
        if (headline != null) Text(headline, style: AppText.titleL),
        if (asks != null)
          Text(
            asks,
            style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
          ),
        AppCard(
          variant: AppCardVariant.sage,
          gap: 8,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          children: [
            // Written on the slip in sage, as a note to herself: the one
            // hand on this sheet, on the one line it most needs to say.
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: HandNote(
                l10n.keptAllOfIt,
                size: 18,
                color: AppColors.tertiary,
              ),
            ),
            if (counted != null) _kept(Icons.calendar_month, counted),
            if (kept != null) _kept(Icons.workspace_premium, kept),
            if (opened != null) _kept(Icons.lock, opened),
          ],
        ),
        AppButton(
          l10n.start10Minutes,
          height: 56,
          icon: Icons.play_arrow,
          onPressed: () =>
              openScreen(context, 'R07', widget.onStartShortSession),
        ),
        AppButton(
          l10n.makeThisWeek2Sessions,
          variant: AppButtonVariant.outlined,
          height: 48,
          fontSize: 15,
          onPressed: () => openScreen(context, 'T01', widget.onShrinkGoal),
        ),
      ],
    );
  }

  Widget _kept(IconData icon, String label) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.tertiary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: AppText.label.copyWith(
              fontSize: 15,
              color: AppColors.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}
