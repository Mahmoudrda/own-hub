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

import '../../../domain/clock/app_clock.dart';
import '../../../theme/app_art.dart';

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../data/pending_answers.dart';
import '../../../domain/format/day_key.dart';
import '../../../domain/format/number_label.dart';
import '../../../domain/logging/log_command_bus.dart';
import '../../../l10n/app_l10n.dart';
import '../../eat/domain/day_totals.dart';
import '../../eat/domain/meal_day_reader.dart';
import '../../eat/domain/meal_repository.dart';
import '../../events/domain/hub_event.dart';
import '../../events/presentation/upcoming_events_card.dart';
import '../../../routing/app_router.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_chevron.dart';
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
import '../../onboarding/domain/intake.dart';
import '../../onboarding/presentation/her_answers.dart';
import '../../../domain/flags/feature_flags.dart';
import '../../../domain/rewards/training_streak.dart';
import '../domain/today_day.dart';
import '../domain/today_repository.dart';
import 'streak_sheet.dart' show trainingStreakLine;
import 'today_cards.dart';

class TodayView extends StatefulWidget {
  const TodayView({
    super.key,
    this.repository,
    this.bus,
    this.now,
    this.sessionTitle,
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
    this.intake,
    this.intakePlaceAnswered = false,
    this.onOpenWeekPlan,
    this.offerCycleSetup = false,
    this.onTrackCycle,
    this.onNotNowCycle,
    this.onCountWalk,
    this.nextEvent,
    this.onOpenEvents,
    this.trainingStreak,
    this.onOpenStreak,
    this.challengeLine,
    this.offerReminders = false,
    this.onChooseReminderDays,
    this.onDismissReminderOffer,
    this.firstName,
    this.sessionMinutes,
    this.weekDoneWeekdays = const <int>{},
    this.mealRepository,
  });

  /// Her first name, for the greeting and the avatar. Null greets without it.
  final String? firstName;

  /// How long today's session takes, for the Today card. Null says nothing.
  final int? sessionMinutes;

  /// The `DateTime.weekday` numbers of the days this week she trained, for the
  /// ticks on the week strip. Today is ticked by the day's own state.
  final Set<int> weekDoneWeekdays;

  /// Where today's meal totals are read from. Null reads the app's own.
  final MealRepository? mealRepository;

  /// Her training streak (D37), or null when it is off — by the build or by
  /// her. Null draws nothing at all.
  final StreakStatus? trainingStreak;

  /// The streak sheet: the rule, the pauses, the switch.
  final VoidCallback? onOpenStreak;

  /// This week's challenge against her own last week (D38), as one sentence,
  /// or null when there is none to set.
  final String? challengeLine;

  /// The one-time offer of training reminders, as a single dismissible line
  /// after she has finished a session. It used to be a card on `R10`.
  final bool offerReminders;

  /// Opens the reminders sheet.
  final VoidCallback? onChooseReminderDays;

  /// "Not now": an answer, so the offer is not made again.
  final VoidCallback? onDismissReminderOffer;

  /// Her setup answers. On day one they are read back above "Start day 1",
  /// so the week she just saw built is the week Home names.
  final Intake? intake;

  /// Whether she was asked where she trains. False after the one-screen
  /// "Your week", which never asks: the line then names no place.
  final bool intakePlaceAnswered;

  /// "Plan this week's dinners": `E07`, the week plan and its shopping list.
  final VoidCallback? onOpenWeekPlan;

  /// Whether day one offers "Track my cycle". The router turns it off once
  /// My cycle is set up or she has said "Not now".
  final bool offerCycleSetup;

  /// "Track my cycle": `Y01`.
  final VoidCallback? onTrackCycle;

  /// "Not now" on the cycle row. Hides it for good.
  final VoidCallback? onNotNowCycle;

  /// "Count it" on the walk row. Supplied, it replaces counting the walk:
  /// the row stays on screen and nothing is written.
  final VoidCallback? onCountWalk;

  /// The soonest published event still to come, for the Upcoming card. The
  /// card is drawn only while `T09` is switched on ([Feature.events]) and
  /// there is one.
  final HubEvent? nextEvent;
  final VoidCallback? onOpenEvents;

  /// Injectable so a test — and later Firestore — can supply the day.
  final TodayRepository? repository;

  /// Shared with Train and Eat in production, so rule 9 has one implementation
  /// rather than one per feature.
  final LogCommandBus? bus;

  /// The clock, injectable for the evening rendering below.
  final DateTime? now;

  /// What her plan calls today's session, when there is a plan.
  ///
  /// Passed in so Home does not read the Train domain. Null renders "Today's workout" rather than the fixed
  /// "Legs and glutes" this screen used to set as its cover for every woman on
  /// earth. See [WorkoutCard.title].
  final String? sessionTitle;

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
  StreamSubscription<MealDay>? _mealSub;
  late TodayDay _day;

  /// What she has eaten so far today, for the Eat card's ring and macros.
  DayTotals _totals = DayTotals.empty;

  /// The walk row updates the moment she taps, before the write is committed —
  /// the log is hers immediately, and undo puts it back.
  bool _walkClaimed = false;

  /// Day one's optional rows, folded behind "More you can do" until she asks.
  bool _moreOpen = false;

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
    _watchMeals();
  }

  void _watchMeals() {
    final meals = widget.mealRepository ?? AppRouter.mealRepository;
    final id = dayKey(widget.now ?? AppClock.now());
    void adopt(MealDay day) {
      if (mounted) setState(() => _totals = const MealDayReader().totals(day));
    }

    unawaited(meals.day(id).then(adopt, onError: (_) {}));
    _mealSub = meals.watchDay(id).listen(adopt, onError: (_) {});
  }

  @override
  void dispose() {
    _sub?.cancel();
    _mealSub?.cancel();
    // A log still inside its undo window when she navigates away is committed,
    // never dropped.
    if (_ownsBus) unawaited(_bus.flushAll());
    if (_ownsRepo) unawaited(_repo.dispose());
    super.dispose();
  }

  /// After 20:00 an unlogged session is likelier to have happened than to be
  /// about to, so the two buttons swap weight. This is a rendering of the same
  /// day state, not a sixth state (plan G3 §3.1).
  bool get _isEvening => (widget.now ?? AppClock.now()).hour >= 20;

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

  /// What is left of her week, said in the week's own units.
  ///
  /// Never a fixed "Two more": a week she has finished says so, and a week she
  /// has not counts down from her own target rather than from the prototype's.
  String _weekLine(AppL10n l10n) {
    final left = _day.week.sessionsTarget - _day.week.sessionsLogged;
    if (left <= 0) return l10n.thisWeekCounts;
    return l10n.countPluralOne1MoreAndThe(left);
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
        staggerGroup: 'T01',
        // Three branches where there were two. `_dayOne` says "Day one" on a
        // masthead and offers her the first session, which is the right screen
        // for a woman who has never logged anything and a confident lie to a
        // woman whose year of training has not been pulled down yet.
        children: switch ((_day.isDayOne, _repo.dataState)) {
          (true, DataState.unknown) => _stillLooking(context, l10n),
          (true, _) => _dayOne(context, l10n),
          (false, _) => _today(context, l10n),
        },
      ),
    );
  }

  // ---------------------------------------------------------------- T01 ----

  List<Widget> _today(BuildContext context, AppL10n l10n) {
    final art = ScreenArt.inlineFor(ScreenScope.of(context));
    final now = widget.now ?? AppClock.now();
    final done = _day.state == DayState.done || _day.state == DayState.recalled;

    return [
      HomeGreeting(
        day: weekdayLabel(l10n, _day.date),
        greeting: homeGreeting(l10n, now, widget.firstName),
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
          // D11's role switch, and the way into My profile. 44 points: My
          // cycle, Language, notification settings, Privacy, the Safety Centre
          // and "delete everything" are all behind this one control.
          AppAvatar(
            size: 44,
            firstName: widget.firstName,
            onOpenProfile: () =>
                openScreen(context, 'A02', widget.onOpenProfile),
          ),
        ],
      ),
      HomeWeekStrip(
        today: _day.date,
        doneWeekdays: {...widget.weekDoneWeekdays, if (done) _day.date.weekday},
      ),
      // One column with the card, so the walk can leave by easing out and
      // the gap above the card stays the scaffold's own.
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          HandSwap(
            child: _day.walkToCount && !_walkClaimed
                ? Padding(
                    key: const ValueKey('today-walk'),
                    padding: const EdgeInsets.only(bottom: kStackGap),
                    child: _walkCard(l10n),
                  )
                : const SizedBox.shrink(key: ValueKey('today-no-walk')),
          ),
          _hero(l10n, art, done),
        ],
      ),
      _weekCard(l10n),
      HomeEatCard(
        totals: _totals,
        loggedAt: _day.mealLoggedAt,
        // The heading follows the hour: the meal she logged, or the meal she
        // is likely to be having now.
        now: widget.now,
        plates: _day.plates,
        onTap: () => openScreen(context, 'E02', widget.onOpenMeal),
        onPlateTap: () => openScreen(context, 'E04', widget.onOpenPlate),
        onPlateLog: widget.onLogPlate,
      ),
      ..._extras(context, l10n),
      ?_milestones(l10n),
    ];
  }

  Widget _hero(AppL10n l10n, List<String> art, bool done) {
    return TodayHero(
      // Today's session is logged: the card says so instead of offering the
      // same start again for the rest of the day.
      done: done,
      evening: _isEvening,
      // What her plan calls today's session, or "Today's workout". Never a
      // programme name she did not choose.
      title: widget.sessionTitle,
      minutes: widget.sessionMinutes,
      week: _day.programWeek,
      totalWeeks: _day.programTotalWeeks,
      art: AppArt.image(art.length > 1 ? art[1] : AppArt.running, size: 112),
      onStart: () => openScreen(context, 'R07', widget.onStartSession),
      onRecall: AppRouter.screenIsOn('T02')
          ? () => openScreen(context, 'T02', widget.onRecall)
          : null,
    );
  }

  /// Her real count against her real target.
  Widget _weekCard(AppL10n l10n) {
    return WeekCard(
      open: true,
      title: l10n.thisWeekDoneOfTarget(
        _day.week.sessionsLogged,
        _day.week.sessionsTarget,
      ),
      // While her first week is open, that arc is the one progress line, so
      // the week's own count is not said twice.
      line: _firstWeekOpen ? '' : _weekLine(l10n),
      total: _day.week.sessionsTarget,
      filled: _day.week.sessionsLogged,
      onTap: () => openScreen(context, 'P01', widget.onOpenWeek),
    );
  }

  List<Widget> _extras(BuildContext context, AppL10n l10n) {
    return [
      // Only for a woman who actually uses My cycle: skipping it costs
      // nothing, and a card for the feature she declined is a cost. The title
      // is `myCycle`, not a string with a sample day baked in.
      if (_day.showCycleCard)
        AppListItem(
          leading: const Icon(
            Icons.self_improvement,
            size: 22,
            color: AppColors.primaryDim,
          ),
          title: l10n.myCycle,
          trailing: const AppChevron(),
          onTap: () => openScreen(context, 'Y03', widget.onOpenCycle),
        ),
      // The owner's next event. Off with Feature.events, and absent when
      // nothing is planned: an empty card would promise events nobody made.
      if (widget.nextEvent case final next? when AppRouter.screenIsOn('T09'))
        UpcomingEventsCard(
          next: next,
          onOpen: () => openScreen(context, 'T09', widget.onOpenEvents),
        ),
      // Asked once, after a session she finished, as one line she can send
      // away. Her own days and time, and nothing until she taps.
      if (widget.offerReminders &&
          (_day.week.sessionsLogged > 0 ||
              _day.arc.completed.contains(FirstWeekStep.finishSession)))
        AppListItem(
          key: const ValueKey('today-reminder-offer'),
          leading: const Icon(
            Icons.alarm,
            size: 22,
            color: AppColors.primaryDim,
          ),
          title: l10n.aReminderOnYourTrainingDays,
          trailing: IconButton(
            key: const ValueKey('today-reminder-not-now'),
            tooltip: l10n.notNow,
            icon: const Icon(Icons.close, size: 20),
            color: AppColors.onSurfaceVariant,
            onPressed: widget.onDismissReminderOffer,
          ),
          onTap: widget.onChooseReminderDays,
        ),
    ];
  }

  /// Whether her first week is still open. While it is, that arc is the one
  /// milestone line; her training streak takes over after it.
  bool get _firstWeekOpen =>
      !firstWeekIsComplete(_day.arc) && AppRouter.screenIsOn('T07');

  /// The lines that close the page: this week's challenge, and one of her
  /// first week or her training streak. Each is one line, each only when it
  /// has something true to say. Choice overload (§15): more rows down the page
  /// would have been more things to decide about.
  Widget? _milestones(AppL10n l10n) {
    final quiet = AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant);
    final streakStatus = widget.trainingStreak;
    final challenge = widget.challengeLine;
    final lines = <Widget>[
      if (challenge != null)
        _BlockLine(
          key: const ValueKey('today-challenge'),
          icon: Icons.flag_outlined,
          label: l10n.thisWeeksChallenge,
          text: challenge,
        ),
      // They count different things, so the first week says "steps" and is
      // never read against "This week, 0 of 3".
      if (_firstWeekOpen)
        _BlockLine(
          key: const ValueKey('today-first-week'),
          icon: Icons.checklist,
          text: l10n.yourFirstWeekDoneOfTotalSteps(
            countLabel(firstWeekDone(_day.arc)),
            countLabel(offeredFirstWeekSteps().length),
          ),
          onTap: () => openScreen(context, 'T07', widget.onOpenFirstWeek),
        )
      // At day zero the line says what starts it, so she is never shown a
      // streak of nothing as though it were a failure.
      else if (streakStatus != null &&
          (streakStatus.enabled || streakStatus.pausedToday))
        _BlockLine(
          key: const ValueKey('todayTrainingStreak'),
          icon: Icons.local_florist_outlined,
          text: trainingStreakLine(l10n, streakStatus),
          onTap: widget.onOpenStreak,
        ),
    ];
    if (lines.isEmpty) return null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final line in lines)
          DefaultTextStyle.merge(style: quiet, child: line),
      ],
    );
  }

  /// Day one's optional rows — her cycle, the beginners group. Two or more
  /// fold behind one "More you can do" row until she opens it; one is shown
  /// as it is. The first screen she sees leads with one thing to do (§15).
  List<Widget> _optionalDayOneRows(AppL10n l10n, Widget chevron) {
    final rows = <Widget>[
      // My cycle was four taps deep behind her avatar. Optional, and said so;
      // gone once it is set up or she says not now.
      if (widget.offerCycleSetup && AppRouter.screenIsOn('Y01'))
        AppListItem(
          key: const ValueKey('day-one-track-cycle'),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          leading: const Icon(
            Icons.water_drop_outlined,
            size: 22,
            color: AppColors.primaryDim,
          ),
          title: l10n.trackMyCycle,
          subtitle: l10n.optionalAndItStaysOnThisPhone,
          trailing: TextButton(
            onPressed: widget.onNotNowCycle,
            child: Text(
              l10n.notNow,
              style: AppText.label.copyWith(color: AppColors.primaryDim),
            ),
          ),
          onTap: () => openScreen(context, 'Y01', widget.onTrackCycle),
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
    ];
    if (rows.length < 2) return rows;
    return [
      // One block, so the fold opens by easing out rather than the page
      // jumping; the gaps inside it are the scaffold's own.
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _moreRow(l10n, chevron),
          HandSwap(
            child: _moreOpen
                ? Column(
                    key: const ValueKey('day-one-more-rows'),
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final row in rows) ...[
                        const SizedBox(height: kStackGap),
                        row,
                      ],
                    ],
                  )
                : const SizedBox.shrink(key: ValueKey('day-one-less')),
          ),
        ],
      ),
    ];
  }

  Widget _moreRow(AppL10n l10n, Widget chevron) {
    return AppListItem(
      key: const ValueKey('day-one-more'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      leading: const Icon(
        Icons.more_horiz,
        size: 22,
        color: AppColors.primaryDim,
      ),
      title: l10n.moreYouCanDo,
      trailing: AnimatedRotation(
        turns: _moreOpen ? 0.25 : 0,
        duration: handMotionOff(context) ? Duration.zero : HandTiming.short,
        child: chevron,
      ),
      onTap: () => setState(() => _moreOpen = !_moreOpen),
    );
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
        onPressed: widget.onCountWalk ?? _countWalk,
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

  // ------------------------------------------------------- T06, unanswered ----

  /// Home while nothing has yet said whether she has a history.
  ///
  /// Deliberately not a spinner: there was none here before, and the honest
  /// thing to put on a screen that does not know is a sentence rather than an
  /// animation implying the app is doing work she should wait for. It keeps the
  /// masthead, because the weekday and her profile are true whatever the pull
  /// says, and drops the "Day 1" pill, the cover, the button and the empty
  /// state, because every one of them is a claim about a history nothing has
  /// read yet.
  List<Widget> _stillLooking(BuildContext context, AppL10n l10n) => [
    TodayGreeting(
      day: weekdayLabel(l10n, _day.date),
      actions: [
        AppAvatar(
          size: 44,
          onOpenProfile: () => openScreen(context, 'A02', widget.onOpenProfile),
        ),
      ],
    ),
    Text(
      l10n.lookingForWhatYouHaveAdded,
      style: AppText.body.copyWith(color: AppColors.onSurfaceVariant),
    ),
  ];

  // ---------------------------------------------------------------- T06 ----

  List<Widget> _dayOne(BuildContext context, AppL10n l10n) {
    const chevron = AppChevron(size: 21);
    final now = widget.now ?? AppClock.now();

    return [
      // The same masthead as every other day, with "Day 1" where her level
      // will be.
      HomeGreeting(
        day: weekdayLabel(l10n, _day.date),
        greeting: homeGreeting(l10n, now, widget.firstName),
        actions: [
          AppPill(
            l10n.day1_4ehtd,
            background: AppColors.surfaceContainer,
            foreground: AppColors.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          // Day one needs the profile as much as any other day: a woman who
          // chose both roles would first look here for the coach side.
          AppAvatar(
            size: 44,
            firstName: widget.firstName,
            onOpenProfile: () =>
                openScreen(context, 'A02', widget.onOpenProfile),
          ),
        ],
      ),
      HomeWeekStrip(today: _day.date),
      // The card says what the app is for, and the button in it is the one
      // obvious thing to do. It names no programme and promises no session:
      // she has answered no questions and has no plan. What is true of every
      // woman on her first day is what this product is: it counts weeks
      // rather than days, and it counts only what she logs.
      AppCard(
        gap: 12,
        children: [
          Container(
            height: 128,
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            alignment: Alignment.center,
            child: AppArt.image(AppArt.trainers, size: 112),
          ),
          Text(
            l10n.yourTrainingWeekByWeek,
            style: EditorialType.section.copyWith(fontSize: 26),
          ),
          Text(
            // With the training streak on (D37) the product counts days too, so
            // the sentence that said it never did would no longer be true.
            AppRouter.featureFlags.isOn(Feature.trainingStreak)
                ? l10n.yourWeeksCountAndSoDoThe
                : l10n.thisAppCountsWeeksNotDaysAnd,
            style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
          ),
          // Her week, as she set it. The same line O05 showed her, so what she
          // saved and what Home says cannot disagree.
          if (widget.intake case final intake?)
            Text(
              herAnswersLine(
                l10n,
                intake,
                placeAnswered: widget.intakePlaceAnswered,
              ),
              key: const ValueKey('day-one-her-week'),
              style: AppText.titleM.copyWith(
                color: AppColors.onPrimaryContainer,
              ),
            ),
          // Day one only: the kitten shows where to start. It goes with the
          // day-one state, the moment she logs anything.
          const Align(
            alignment: AlignmentDirectional.centerStart,
            child: Kitten(
              pose: KittenPose.point,
              size: 48,
              moment: 'T06',
              sessionBudget: true,
            ),
          ),
          AppButton(
            l10n.startDay1,
            height: 56,
            icon: Icons.play_arrow,
            onPressed: () => openScreen(context, 'R03', widget.onStartSession),
          ),
        ],
      ),
      // The one other thing to do: say what she ate.
      AppListItem(
        key: const ValueKey('day-one-log-meal'),
        leading: const Icon(
          Icons.restaurant_outlined,
          size: 22,
          color: AppColors.primaryDim,
        ),
        title: l10n.logAMeal,
        trailing: chevron,
        onTap: () => openScreen(context, 'E01', widget.onTellUsWhatYouEat),
      ),
      // Rule 17: the empty state states what will appear and why it is empty,
      // and each row around it is one of the "log one thing" it names.
      AppEmptyState(
        icon: Icons.history,
        art: AppArt.gymBag,
        title: l10n.nothingAddedYet,
        body: l10n.todaysSessionAndTheMealYouUsually,
      ),
      if (AppRouter.screenIsOn('T07'))
        AppListItem(
          variant: AppCardVariant.tonal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          leading: const Icon(
            Icons.checklist,
            size: 22,
            color: AppColors.primaryDim,
          ),
          title: l10n.yourFirstWeek,
          // Counted over the steps this build offers, the same list T07 draws:
          // `arc.stepCount` is always five, so with Community dark Home said
          // "0 of 5" about an arc of three.
          subtitle: l10n.countOfTotal(
            countLabel(firstWeekDone(_day.arc)),
            countLabel(offeredFirstWeekSteps().length),
          ),
          trailing: chevron,
          onTap: () => openScreen(context, 'T07', widget.onOpenFirstWeek),
        ),
      // Planning her food is a reason she installed the app, and on day one
      // the week plan had no door from Home or Eat.
      if (AppRouter.screenIsOn('E07'))
        AppListItem(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          leading: const Icon(
            Icons.calendar_view_week,
            size: 22,
            color: AppColors.primaryDim,
          ),
          title: l10n.planThisWeeksDinners,
          subtitle: l10n.fiveEgyptianDinnersAndOneShoppingList,
          trailing: chevron,
          onTap: () => openScreen(context, 'E07', widget.onOpenWeekPlan),
        ),
      ..._optionalDayOneRows(l10n, chevron),
      // The weekly rule, said once, before she can fail it. It states the
      // rule and never the number: she sets her own target in setup.
      AppSageNote(l10n.hitYourGoalAndTheWeekCounts),
    ];
  }
}

/// One line under the week's marks: an icon, a word or two, a sentence. A tap
/// target of at least 48 points when it leads somewhere.
class _BlockLine extends StatelessWidget {
  const _BlockLine({
    super.key,
    required this.icon,
    required this.text,
    this.label,
    this.onTap,
  });

  final IconData icon;
  final String text;
  final String? label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.tertiary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (label != null)
                  Text(
                    label!,
                    style: AppText.label.copyWith(color: AppColors.tertiary),
                  ),
                Text(text),
              ],
            ),
          ),
          if (onTap != null) const AppChevron(),
        ],
      ),
    );
    if (onTap == null) return row;
    return Semantics(
      button: true,
      child: InkWell(onTap: onTap, child: row),
    );
  }
}
