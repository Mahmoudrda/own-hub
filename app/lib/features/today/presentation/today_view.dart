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

import '../../../app_state/custom_workout_state.dart';
import '../../../app_state/eat_state.dart';
import '../../../data/pending_answers.dart';
import '../../../domain/format/day_key.dart';
import '../../../domain/format/number_label.dart';
import '../../../domain/logging/log_command_bus.dart';
import '../../../l10n/app_l10n.dart';
import '../../eat/domain/meal_repository.dart';
import '../../events/domain/hub_event.dart';
import '../../events/presentation/upcoming_events_card.dart';
import '../../../routing/app_router.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_chevron.dart';
import '../../../ui/app_empty_state.dart';
import '../../../ui/app_list_item.dart';
import '../../../ui/app_nav_bar.dart';
import '../../../ui/app_pill.dart';
import '../../../ui/app_sage_note.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/app_sheet.dart';
import '../../../ui/sign_in_pill.dart';
import '../../../ui/app_undo_snackbar.dart';
import '../../../ui/hand/hand.dart';
import '../../../ui/screen_scope.dart';
import '../../../theme/screen_art.dart';
import '../../onboarding/domain/intake.dart';
import '../../train/domain/tier_facts.dart';
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
    this.onOpenWeek,
    this.onOpenCycle,
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
    this.onSignIn,
    this.tierTabs,
    this.tierFacts,
    this.onChangeTraining,
    this.trainingLine,
    this.planLinks,
    this.followUp,
    this.coachCard,
    this.onOpenCoach,
    this.onEditToday,
    this.onChangePlan,
    this.onShortVersion,
    this.onTenMinuteWalk,
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

  /// "Sign in or join", for a woman with no account. Supplied, a pill in the
  /// greeting opens it; null draws nothing.
  final VoidCallback? onSignIn;

  /// Kept so callers compile. The tier tabs live on the plan screen now, so
  /// Home never draws them.
  final Widget? tierTabs;

  /// The viewed tier's session facts. Home reads only the minutes from it.
  final TierFacts? tierFacts;

  /// Opens the "Your training" sheet. Supplied, a row in the Change sheet shows
  /// [trainingLine] and calls it; null draws no row.
  final VoidCallback? onChangeTraining;

  /// Her place, goal and level in one line, for the "Your training" row.
  final String? trainingLine;

  /// Kept so callers compile. Edit and Change plan are rows in the Change
  /// sheet now ([onEditToday], [onChangePlan]).
  final Widget? planLinks;

  /// "Edit today" in the Change sheet. Null opens R03 in edit mode.
  final VoidCallback? onEditToday;

  /// "Change plan" in the Change sheet. Null opens Train.
  final VoidCallback? onChangePlan;

  /// "Short version" in the Change sheet. No row when null.
  final VoidCallback? onShortVersion;

  /// "A 10-minute walk" in the Change sheet. No row when null.
  final VoidCallback? onTenMinuteWalk;

  /// The follow-up card (how she feels after a session, her week review),
  /// or null when there is nothing to ask.
  final Widget? followUp;

  /// Her coach's card while she is coached. It is the Today card: D11, her
  /// coach's workout, with its one Start.
  final Widget? coachCard;

  /// Opens My coach, from the Change sheet: the Today card's only tap is
  /// Start, so Home keeps to five controls.
  final VoidCallback? onOpenCoach;

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

  final VoidCallback? onOpenWeek;
  final VoidCallback? onOpenCycle;

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

  /// What is stored for today. The Eat card reads it together with the meals
  /// still inside their undo window, so a meal she has just logged shows at
  /// once.
  late MealDay _stored;

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
    _stored = MealDay(dayId: dayKey(widget.now ?? AppClock.now()));
    EatAppState.instance.session.addListener(_pendingMealsChanged);
    _sub = _repo.watch().listen((day) {
      if (mounted) setState(() => _day = day);
    });
    _watchMeals();
  }

  void _watchMeals() {
    final meals = widget.mealRepository ?? AppRouter.mealRepository;
    final id = dayKey(widget.now ?? AppClock.now());
    void adopt(MealDay day) {
      if (mounted) setState(() => _stored = day);
    }

    unawaited(meals.day(id).then(adopt, onError: (_) {}));
    _mealSub = meals.watchDay(id).listen(adopt, onError: (_) {});
  }

  void _pendingMealsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    EatAppState.instance.session.removeListener(_pendingMealsChanged);
    _sub?.cancel();
    _mealSub?.cancel();
    // A log still inside its undo window when she navigates away is committed,
    // never dropped.
    if (_ownsBus) unawaited(_bus.flushAll());
    if (_ownsRepo) unawaited(_repo.dispose());
    super.dispose();
  }

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

  /// "Sign in or join" for a woman with no account, on the weekday line of the
  /// header at the trailing edge. Null for everyone else.
  Widget? _signInPill() =>
      widget.onSignIn == null ? null : SignInPill(onTap: widget.onSignIn!);

  List<Widget> _today(BuildContext context, AppL10n l10n) {
    final art = ScreenArt.inlineFor(ScreenScope.of(context));
    final now = widget.now ?? AppClock.now();
    final done = _day.state == DayState.done || _day.state == DayState.recalled;
    final eat = EatAppState.instance;
    final targets = eat.targets();

    return [
      HomeGreeting(
        signIn: _signInPill(),
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
        ],
      ),
      if (widget.coachCard case final coach?)
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            coach,
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: _changeLink(l10n),
            ),
          ],
        )
      else
        _hero(l10n, art, done),
      HomeWeekStrip(
        today: _day.date,
        doneWeekdays: {...widget.weekDoneWeekdays, if (done) _day.date.weekday},
        caption: l10n.thisWeekDoneOfTarget(
          _day.week.sessionsLogged,
          _day.week.sessionsTarget,
        ),
        onTap: () => openScreen(context, 'P01', widget.onOpenWeek),
      ),
      HomeEatLine(
        totals: eat.totalsWithPending(_stored, against: targets),
        targets: targets,
        onTap: () => openScreen(context, 'E01', widget.onOpenMeal),
      ),
      ?_contextual(context, l10n),
    ];
  }

  Widget _hero(AppL10n l10n, List<String> art, bool done) {
    return TodayHero(
      // Today's session is logged: the card says so instead of offering the
      // same start again for the rest of the day.
      done: done,
      // What her plan calls today's session, or "Today's workout". Never a
      // programme name she did not choose.
      title: widget.sessionTitle,
      minutes: widget.tierFacts?.estimatedMinutes ?? widget.sessionMinutes,
      week: _day.programWeek,
      totalWeeks: _day.programTotalWeeks,
      art: AppArt.image(art.length > 1 ? art[1] : AppArt.running, size: 112),
      onStart: () => openScreen(context, 'R07', widget.onStartSession),
      onChange: _openChange,
    );
  }

  Widget _changeLink(AppL10n l10n) => AppButton(
    l10n.change,
    key: const ValueKey('today-change'),
    variant: AppButtonVariant.text,
    height: 44,
    fontSize: 15,
    onPressed: _openChange,
  );

  /// Everything that changes today, in one sheet: the quiet "Change" link on
  /// the Today card opens it.
  void _openChange() {
    final l10n = AppL10n.of(context);
    final coached = widget.coachCard != null;
    Widget row(
      Key key,
      IconData icon,
      String title,
      VoidCallback act, {
      String subtitle = '',
    }) {
      return Builder(
        builder: (sheet) => AppListItem(
          key: key,
          leading: Icon(icon, size: 22, color: AppColors.primaryDim),
          title: title,
          subtitle: subtitle,
          trailing: const AppChevron(),
          onTap: () {
            Navigator.of(sheet).pop();
            act();
          },
        ),
      );
    }

    final alreadyDid = AppRouter.screenIsOn('T02')
        ? row(
            const ValueKey('change-already-did-it'),
            Icons.check,
            l10n.iAlreadyDidIt,
            () => openScreen(context, 'T02', widget.onRecall),
          )
        : null;
    // After 20:00 an unlogged session has likelier already happened, so that
    // answer leads the sheet (it used to swap the Start button).
    final evening = (widget.now ?? AppClock.now()).hour >= 20;
    showAppSheet<void>(
      context: context,
      gap: 8,
      children: [
        if (evening) ?alreadyDid,
        if (coached) ...[
          row(
            const ValueKey('change-own-plan'),
            Icons.fitness_center,
            l10n.doMyOwnPlanInstead,
            () => openScreen(context, 'R07', widget.onStartSession),
          ),
          if (widget.onOpenCoach case final coach?)
            row(
              const ValueKey('change-my-coach'),
              Icons.sports_outlined,
              l10n.myCoach,
              coach,
            ),
        ] else ...[
          row(
            const ValueKey('change-edit-today'),
            Icons.edit_outlined,
            l10n.editToday,
            () {
              CustomWorkoutState.instance.editRequested = true;
              openScreen(context, 'R03', widget.onEditToday);
            },
          ),
          if (widget.onShortVersion case final short?)
            row(
              const ValueKey('change-short-version'),
              Icons.timer_outlined,
              l10n.shortVersion,
              short,
            ),
          row(
            const ValueKey('change-plan'),
            Icons.tune,
            l10n.changePlan,
            widget.onChangePlan ?? () => AppRouter.goToTab(context, 'R01'),
          ),
          if (widget.onChangeTraining case final training?)
            row(
              const ValueKey('change-training'),
              Icons.person_outline,
              l10n.yourTraining,
              training,
              subtitle: widget.trainingLine ?? '',
            ),
        ],
        if (!evening) ?alreadyDid,
        if (_day.walkToCount && !_walkClaimed)
          row(
            const ValueKey('change-count-walk'),
            Icons.directions_walk,
            _walkLine(l10n),
            widget.onCountWalk ?? _countWalk,
            subtitle: l10n.countIt,
          ),
        if (widget.onTenMinuteWalk case final walk?)
          row(
            const ValueKey('change-ten-minute-walk'),
            Icons.directions_walk,
            l10n.a10MinuteWalk,
            walk,
          ),
      ],
    );
  }

  /// The one card below the Eat line, by priority: a follow-up, the
  /// next event, her cycle, a reminder offer, then the lines about her first
  /// week and streak. Never two.
  Widget? _contextual(BuildContext context, AppL10n l10n) {
    // Her coach's card is the Today card, and the one card there is.
    if (widget.coachCard != null) return null;
    if (widget.followUp case final follow?) return follow;
    if (widget.nextEvent case final next? when AppRouter.screenIsOn('T09')) {
      return UpcomingEventsCard(
        next: next,
        onOpen: () => openScreen(context, 'T09', widget.onOpenEvents),
      );
    }
    if (_day.showCycleCard) {
      return AppListItem(
        leading: const Icon(
          Icons.self_improvement,
          size: 22,
          color: AppColors.primaryDim,
        ),
        title: l10n.myCycle,
        trailing: const AppChevron(),
        onTap: () => openScreen(context, 'Y03', widget.onOpenCycle),
      );
    }
    if (widget.offerReminders &&
        (_day.week.sessionsLogged > 0 ||
            _day.arc.completed.contains(FirstWeekStep.finishSession))) {
      return AppListItem(
        key: const ValueKey('today-reminder-offer'),
        leading: const Icon(Icons.alarm, size: 22, color: AppColors.primaryDim),
        title: l10n.aReminderOnYourTrainingDays,
        trailing: IconButton(
          key: const ValueKey('today-reminder-not-now'),
          tooltip: l10n.notNow,
          icon: const Icon(Icons.close, size: 20),
          color: AppColors.onSurfaceVariant,
          onPressed: widget.onDismissReminderOffer,
        ),
        onTap: widget.onChooseReminderDays,
      );
    }
    return _milestones(l10n);
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
        )
      // At day zero the line says what starts it, so she is never shown a
      // streak of nothing as though it were a failure.
      else if (streakStatus != null &&
          (streakStatus.enabled || streakStatus.pausedToday))
        _BlockLine(
          key: const ValueKey('todayTrainingStreak'),
          icon: Icons.local_florist_outlined,
          text: trainingStreakLine(l10n, streakStatus),
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
    TodayGreeting(day: weekdayLabel(l10n, _day.date)),
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
        signIn: _signInPill(),
        day: weekdayLabel(l10n, _day.date),
        greeting: homeGreeting(l10n, now, widget.firstName),
        actions: [
          AppPill(
            l10n.day1_4ehtd,
            background: AppColors.surfaceContainer,
            foreground: AppColors.onSurfaceVariant,
          ),
        ],
      ),
      HomeWeekStrip(today: _day.date),
      ?widget.coachCard,
      // The card says what the app is for, and the button in it is the one
      // obvious thing to do. It names no programme and promises no session:
      // she has answered no questions and has no plan. What is true of every
      // woman on her first day is what this product is: it counts weeks
      // rather than days, and it counts only what she logs.
      AppCard(
        gap: 12,
        children: [
          // On a small phone the poster gives way, so Start stays on screen.
          if (MediaQuery.sizeOf(context).height >= 700)
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
          AppButton(
            l10n.startDay1,
            height: 56,
            icon: Icons.play_arrow,
            // Her coach's workout is the one filled Start while she has one.
            variant: widget.coachCard == null
                ? AppButtonVariant.filled
                : AppButtonVariant.outlined,
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

/// One line under the week's marks: an icon, a word or two, a sentence. Not a
/// control: Home keeps to five, and these counts are opened from You.
class _BlockLine extends StatelessWidget {
  const _BlockLine({
    super.key,
    required this.icon,
    required this.text,
    this.label,
  });

  final IconData icon;
  final String text;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
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
        ],
      ),
    );
  }
}
