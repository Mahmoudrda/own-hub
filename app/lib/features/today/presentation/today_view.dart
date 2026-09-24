/// T01 — Today, and T06 — Today on day one.
///
/// Matches `6-v2/src/screens-today.mjs` → `T01` and
/// `6-v2/src/screens-firstrun.mjs` → `T06`.
///
/// **T06 is a state, not a route** (HANDOFF rule 16). It is this widget's other
/// branch, taken when `arc.hasAnyLog` is false, and `app_routes.dart` lists it
/// only because that table is generated from the screen inventory. Nothing
/// navigates to it: `firstRunStates` in `app_router.dart` keeps it out of
/// `appDestinations`, so "Home, empty" cannot be opened over a Home that is not
/// empty. The branch ends permanently at her first log of any kind.
///
/// Everything she might log today is already written on this screen — the walk
/// her phone counted, the session from her plan, the breakfast she has at this
/// hour — so the usual case is one tap. Every one of those taps goes through
/// [LogCommandBus] and offers five seconds of undo. None of them asks her to
/// confirm anything (§2 rule 9).
library;

import '../../../theme/app_art.dart';

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../domain/format/number_label.dart';
import '../../../domain/logging/log_command_bus.dart';
import '../../../l10n/app_l10n.dart';
import '../../../routing/app_router.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_empty_state.dart';
import '../../../ui/app_avatar.dart';
import '../../../ui/app_list_item.dart';
import '../../../ui/app_nav_bar.dart';
import '../../../ui/app_pill.dart';
import '../../../ui/app_sage_note.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/app_undo_snackbar.dart';
import '../../../ui/hand/hand.dart';
import '../../../ui/screen_scope.dart';
import '../../../theme/screen_art.dart';
import '../domain/today_day.dart';
import '../domain/today_repository.dart';
import 'today_cards.dart';

class TodayView extends StatefulWidget {
  const TodayView({
    super.key,
    this.repository,
    this.bus,
    this.now,
    this.level,
    this.onStartSession,
    this.onRecall,
    this.onOpenMeal,
    this.onOpenPlate,
    this.onLogPlate,
    this.onOpenWeek,
    this.onOpenCycle,
    this.onOpenProfile,
    this.onAsk,
    this.onNotifications,
    this.onOpenFirstWeek,
    this.onTellUsWhatYouEat,
    this.onOpenBeginnersGroup,
    this.onSelectTab,
  });

  /// Injectable so a test — and later Firestore — can supply the day.
  final TodayRepository? repository;

  /// Shared with Train and Eat in production, so rule 9 has one implementation
  /// rather than one per feature.
  final LogCommandBus? bus;

  /// The clock, injectable for the evening rendering below.
  final DateTime? now;

  /// Her level, for the pill beside the day name. Null renders no pill.
  ///
  /// Passed in rather than read here, so Today does not depend on the rewards
  /// domain — the same reasoning as [TodayDay.showCycleCard]. The router
  /// supplies it from the SAME derivation P01 uses, which is what keeps Home
  /// and Progress from disagreeing about the number.
  final int? level;

  final VoidCallback? onStartSession;
  final VoidCallback? onRecall;
  final VoidCallback? onOpenMeal;
  final VoidCallback? onOpenPlate;

  /// Logs the plate she tapped, then opens the logged day.
  ///
  /// Home's plates were a way into Eat and nothing more: tapping one opened E04
  /// showing whatever she had logged elsewhere, and the plate she actually
  /// pressed was never written. Supplied, this takes precedence over
  /// [onOpenPlate] and carries the plate, so one tap logs it with the same five
  /// seconds every other log in the product offers.
  final ValueChanged<PlateSuggestion>? onLogPlate;

  final VoidCallback? onOpenWeek;
  final VoidCallback? onOpenCycle;

  /// Where her profile picture goes.
  ///
  /// D11 makes the avatar the entry to her profile and, for a woman who chose
  /// both roles, the control that switches between the trainee and coach apps.
  final VoidCallback? onOpenProfile;

  final VoidCallback? onAsk;
  final VoidCallback? onNotifications;
  final VoidCallback? onOpenFirstWeek;
  final VoidCallback? onTellUsWhatYouEat;
  final VoidCallback? onOpenBeginnersGroup;
  final ValueChanged<String>? onSelectTab;

  @override
  State<TodayView> createState() => _TodayViewState();
}

class _TodayViewState extends State<TodayView> {
  late final TodayRepository _repo;
  late final LogCommandBus _bus;
  late final bool _ownsRepo;
  late final bool _ownsBus;
  StreamSubscription<TodayDay>? _sub;
  late TodayDay _day;

  /// The walk row updates the moment she taps, before the write is committed —
  /// the log is hers immediately, and undo puts it back.
  bool _walkClaimed = false;

  @override
  void initState() {
    super.initState();
    _ownsRepo = widget.repository == null;
    _repo = widget.repository ?? InMemoryTodayRepository();
    _ownsBus = widget.bus == null;
    _bus = widget.bus ?? LogCommandBus();
    _day = _repo.day;
    _sub = _repo.watch().listen((day) {
      if (mounted) setState(() => _day = day);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    // A log still inside its undo window when she navigates away is committed,
    // never dropped.
    if (_ownsBus) unawaited(_bus.flushAll());
    if (_ownsRepo) unawaited(_repo.dispose());
    super.dispose();
  }

  /// After 20:00 an unlogged session is likelier to have happened than to be
  /// about to, so the two buttons swap weight. This is a rendering of the same
  /// day state, not a sixth state (plan G3 §3.1).
  bool get _isEvening => (widget.now ?? DateTime.now()).hour >= 20;

  /// The walk row's sentence, carrying the duration only when there is one.
  ///
  /// This was the fixed `walkThisMorning32Min` in both places — on the card and
  /// again in the undo bar — so a woman whose phone had counted eleven minutes
  /// was told thirty-two, twice. `walkThisMorningMinutesMin` is the
  /// parameterised form; with no duration the card names the walk and says
  /// nothing about its length.
  String _walkLine(AppL10n l10n) {
    final minutes = _day.walkMinutes;
    return minutes == null
        ? l10n.walkThisMorning
        : l10n.walkThisMorningMinutesMin(countLabel(minutes));
  }

  void _countWalk() {
    final l10n = AppL10n.of(context);
    setState(() => _walkClaimed = true);
    final handle = _bus.submit(
      UndoableLog(describe: _walkLine(l10n), commit: _repo.countWalk),
    );
    showUndoSnackBar(
      context,
      handle: handle,
      undoLabel: l10n.undo,
      onUndo: () {
        if (mounted) setState(() => _walkClaimed = false);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return Scaffold(
      backgroundColor: AppColors.surface,
      bottomNavigationBar: AppNavBar(
        activeScreenId: 'T01',
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
        children: _day.isDayOne
            ? _dayOne(context, l10n)
            : _today(context, l10n),
      ),
    );
  }

  // ---------------------------------------------------------------- T01 ----

  List<Widget> _today(BuildContext context, AppL10n l10n) {
    // This screen sets its illustrations inside the cover rather than in a
    // strip over it: the woman training beside her week, the plate beside
    // the meal. Same two drawings, placed where they mean something.
    final art = ScreenArt.inlineFor(ScreenScope.of(context));
    Widget? artAt(int i, double size) =>
        i < art.length ? AppArt.image(art[i], size: size) : null;

    return [
      TodayGreeting(
        day: weekdayLabel(l10n, _day.date),
        level: widget.level,
        actions: [
          // The assistant ships dark in the first release, and an icon in the
          // greeting is the most prominent control on the app's landing
          // screen. Drawn only where there is something behind it.
          if (AppRouter.screenIsOn('X01'))
            IconButton(
              tooltip: l10n.askSomething,
              color: AppColors.onSurfaceVariant,
              icon: const Icon(Icons.psychology),
              onPressed: () => openScreen(context, 'X01', widget.onAsk),
            ),
          IconButton(
            tooltip: l10n.notifications,
            color: AppColors.onSurfaceVariant,
            icon: const Icon(Icons.notifications_none),
            onPressed: () => openScreen(context, 'A01', widget.onNotifications),
          ),
          // D11's role switch, and the way into My profile. Built as a
          // component, tested on its own, and until now rendered on no screen
          // in the running app — so a woman who chose BOTH roles had no way to
          // reach the coach side at all, which is the whole point of the choice.
          AppAvatar(
            size: 32,
            onOpenProfile: () =>
                openScreen(context, 'A02', widget.onOpenProfile),
          ),
        ],
      ),
      if (_day.walkToCount && !_walkClaimed) _walkCard(l10n),
      WorkoutCard(
        evening: _isEvening,
        // Her week, or no badge. `summary` is deliberately not passed: the
        // line it would carry is a claim about a session this screen is handed
        // nothing about. See WorkoutCard.
        week: _day.programWeek,
        totalWeeks: _day.programTotalWeeks,
        onStart: () => openScreen(context, 'R07', widget.onStartSession),
        onRecall: () => openScreen(context, 'T02', widget.onRecall),
        // The week sits on the cover, between the session and the action.
        weekBlock: WeekCard(
          open: true,
          // Her real count against her real target.
          //
          // This was two finished sentences — "This week, 0 of 3" and "This
          // week, 1 of 3" — chosen by `sessionsLogged == 0`. So the sentence
          // changed when she logged *anything* and never counted past one, and
          // a woman whose goal is four sessions read "This week, 0 of 3" while
          // the ring immediately below it drew four segments from the same
          // object. Third occurrence of the class this codebase has now fixed
          // four times: see PHASE1-FIXES.md #3 and #8, and DayCard in the Eat
          // flow.
          title: l10n.thisWeekDoneOfTarget(
            _day.week.sessionsLogged,
            _day.week.sessionsTarget,
          ),
          line: l10n.twoMoreAndTheWeekCounts,
          total: _day.week.sessionsTarget,
          filled: _day.week.sessionsLogged,
          onTap: () => openScreen(context, 'P01', widget.onOpenWeek),
          art: artAt(1, 76),
        ),
      ),
      // Below the cover, quieter: a rule, then the rest of the day.
      const HandRule(seed: 29, height: 22),
      MealCard(
        loggedAt: _day.mealLoggedAt,
        plates: _day.plates,
        onTap: () => openScreen(context, 'E02', widget.onOpenMeal),
        onPlateTap: () => openScreen(context, 'E04', widget.onOpenPlate),
        onPlateLog: widget.onLogPlate,
        art: artAt(0, 56),
      ),
      // Only for a woman who actually uses My cycle.
      //
      // This row rendered unconditionally, so someone who skipped cycle setup
      // — or never saw it — still got a cycle card on Home. P0-CYC-03 is that
      // skipping costs nothing, and a card for the feature she declined is a
      // cost. Found by the Cycle agent in a folder it was not allowed to edit.
      //
      // The title is `myCycle`, not `myCyclePeriodDay2`. That string has the
      // mockup's sample baked into it, so it announced "period day 2" to every
      // woman who saw it regardless of her actual day, and the parameterised
      // form does not exist yet. The neutral half is the true half.
      if (_day.showCycleCard)
        AppListItem(
          leading: const Icon(
            Icons.self_improvement,
            size: 22,
            color: AppColors.primaryDim,
          ),
          title: l10n.myCycle,
          trailing: const Icon(
            Icons.chevron_right,
            size: 22,
            color: AppColors.onSurfaceVariant,
          ),
          onTap: () => openScreen(context, 'Y03', widget.onOpenCycle),
        ),
    ];
  }

  /// The walk her phone already counted. One tap claims it.
  Widget _walkCard(AppL10n l10n) {
    final line = Text(
      _walkLine(l10n),
      style: AppText.titleS.copyWith(color: AppColors.onTertiaryContainer),
    );
    // A word, not a second button: the cover has one action, and this is a
    // note beside it. Underlined in pen, like every text action.
    final count = IntrinsicWidth(
      child: AppButton(
        l10n.countIt,
        variant: AppButtonVariant.text,
        height: 44,
        fontSize: 15,
        onPressed: _countWalk,
      ),
    );
    final icon = HandIconRing(
      icon: const Icon(
        Icons.directions_walk,
        size: 20,
        color: AppColors.tertiary,
      ),
      seed: 13,
      size: 34,
      color: AppColors.tertiary.withValues(alpha: 0.6),
    );
    // Side by side at ordinary sizes; at a large text size the action goes
    // under the words, which would otherwise be squeezed until a word breaks.
    final stacked = MediaQuery.textScalerOf(context).scale(1) > 1.3;

    // The walk her phone already counted, as one line at the top of the
    // page — ringed in sage, ruled under in pencil — with one word to keep it.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (stacked) ...[
          Row(
            children: [
              icon,
              const SizedBox(width: 10),
              Expanded(child: line),
            ],
          ),
          Align(alignment: AlignmentDirectional.centerEnd, child: count),
        ] else
          Row(
            children: [
              icon,
              const SizedBox(width: 10),
              Expanded(child: line),
              const SizedBox(width: 8),
              count,
            ],
          ),
        const HandRule(seed: 37, height: 6),
      ],
    );
  }

  // ---------------------------------------------------------------- T06 ----

  List<Widget> _dayOne(BuildContext context, AppL10n l10n) {
    const chevron = Icon(
      Icons.chevron_right,
      size: 21,
      color: AppColors.onSurfaceVariant,
    );

    return [
      // The same masthead as every other day, with "Day 1" where her level
      // will be.
      TodayGreeting(
        day: weekdayLabel(l10n, _day.date),
        actions: [
          AppPill(
            l10n.day1_4ehtd,
            background: AppColors.surfaceContainer,
            foreground: AppColors.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          // Day one needs it as much as any other day: this is the first
          // screen after sign-up, and it is where a woman who chose both
          // roles would first look for the coach side.
          AppAvatar(
            size: 32,
            onOpenProfile: () =>
                openScreen(context, 'A02', widget.onOpenProfile),
          ),
        ],
      ),
      // The programme she just chose is the cover: its name set large and
      // underlined once, its promise, and the one thing to do.
      //
      // "Monday, Tuesday, Thursday · 15 min" is not said. It names three
      // weekdays and a session length, and T06 is handed neither — she picks
      // her days in O04 and this screen never receives them. A woman who chose
      // Saturday and Sunday read the prototype's three days under the
      // programme she had just chosen. The programme's name and its promise
      // are true of it for everyone.
      const SizedBox(height: 4),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: HandUnderline(
                level: HandLevel.signature,
                width: HandStroke.felt,
                drawOn: true,
                gap: 4,
                child: Text(
                  l10n.beginnerFoundations,
                  style: EditorialType.cover,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Icon(
              Icons.workspace_premium,
              size: 28,
              color: AppColors.primaryDim,
            ),
          ),
        ],
      ),
      Text(
        l10n.fourMovesOnTheFloorNothingJumps,
        style: AppText.body.copyWith(color: AppColors.onSurfaceVariant),
      ),
      const SizedBox(height: 4),
      AppButton(
        l10n.startDay1,
        height: 56,
        icon: Icons.play_arrow,
        onPressed: () => openScreen(context, 'R03', widget.onStartSession),
      ),
      const HandRule(seed: 31, height: 18),
      AppListItem(
        variant: AppCardVariant.tonal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        leading: const Icon(
          Icons.checklist,
          size: 22,
          color: AppColors.primaryDim,
        ),
        title: l10n.yourFirstWeek,
        // Her arc, counted from the arc itself.
        //
        // This was the fixed `n2Of5DoneNothingExpires` — "2 of 5 done ·
        // nothing expires" — on the ONE screen where nothing is done yet:
        // T06 renders only when `arc.hasAnyLog` is false, so it told a woman
        // with an empty arc that two of it were finished.
        // Counted over the steps this build offers, the same list T07 draws.
        // `arc.stepCount` is always five, so with Community dark Home said
        // "0 of 5" about an arc of three.
        subtitle: l10n.countOfTotal(
          countLabel(firstWeekDone(_day.arc)),
          countLabel(offeredFirstWeekSteps().length),
        ),
        trailing: chevron,
        onTap: () => openScreen(context, 'T07', widget.onOpenFirstWeek),
      ),
      // Rule 17: the empty state states what will appear and why it is empty.
      AppEmptyState(
        icon: Icons.history,
        art: AppArt.trainers,
        title: l10n.nothingLoggedYet,
        body: l10n.todaysSessionAndTheMealYouUsually,
      ),
      AppListItem(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        leading: const Icon(
          Icons.restaurant,
          size: 22,
          color: AppColors.primaryDim,
        ),
        title: l10n.tellUsOneThingYouEat,
        subtitle: l10n.oneMealIsEnoughToStartThe,
        trailing: chevron,
        // The prototype points this at E09, which is Eat's own day-one state and
        // therefore not a destination either (rule 16). Eat is opened; Eat
        // decides to render E09 for exactly the same reason this screen renders
        // T06.
        onTap: () => openScreen(context, 'E01', widget.onTellUsWhatYouEat),
      ),
      // The community is dark in the first release, so on day one this row
      // named a group she cannot join and opened the "switched off" panel.
      // Not drawn rather than drawn and disabled: the rest of day one is three
      // things she can actually do.
      if (AppRouter.screenIsOn('M01'))
        AppListItem(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          leading: const Icon(
            Icons.groups,
            size: 22,
            color: AppColors.primaryDim,
          ),
          // `n4210WomenInTheBeginnersGroup` — "4,210 women in the beginners
          // group" — is a membership figure nothing in this app counts, frozen
          // into the dictionary on the screen a woman sees on her first day.
          // The group has a name; the size is not claimed.
          title: l10n.beginnersGroup,
          subtitle: l10n.nobodyThereHasBeenTrainingOverA,
          trailing: chevron,
          // Same reasoning as above: M17 is Community's day-one state.
          onTap: () => openScreen(context, 'M01', widget.onOpenBeginnersGroup),
        ),
      // The weekly rule, said once, before she can fail it.
      AppSageNote(l10n.threeSessionsMakesTheWeekCountAnd),
    ];
  }
}
