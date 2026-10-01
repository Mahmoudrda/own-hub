/// E01 — Eat, and E09 — Eat on day one.
///
/// Matches `6-v2/src/screens-eat.mjs` → `E01` and
/// `6-v2/src/screens-firstrun.mjs` → `E09`.
///
/// **E09 is a state, not a route** (HANDOFF rule 16). It is this widget's other
/// branch, taken when nothing has ever been logged, and `app_routes.dart` lists
/// it only because that table is generated from the screen inventory.
/// `firstRunStates` in `app_router.dart` keeps it out of `appDestinations`, and
/// `routing_test.dart` pins that — so "Eat, empty" cannot be opened over an Eat
/// screen that is not empty. Exactly the arrangement `TodayView` uses for T06.
///
/// ## One tap logs, and five seconds take it back
///
/// Every log on this screen goes through [LogCommandBus] and nothing else. The
/// row appears immediately with its real numbers, the write is held locally for
/// five seconds, and an undo inside that window means **no write was ever
/// issued** (§4.2) — so there is nothing queued to resurface on reconnect and
/// G6's once-a-day points hook never fires for a meal she cancelled.
///
/// There is no dialog on this path and no parameter on this screen that could
/// produce one.
///
/// ## Two numbers on this screen are the mockup's, not hers
///
/// "22 of 95 g" and "About 410 kcal so far today" are **fixed dictionary
/// strings with no placeholder form** — `app_en.arb` carries five parameterised
/// messages and all five are Phase 1's. `PHASE2-ACCEPTANCE.md` §1 records this
/// for fourteen Phase 2 rows and asks for `{soFar} of {target} g`.
///
/// So the sentences are selected by state, the way `TodayView` selects between
/// "This week, 0 of 3" and "This week, 1 of 3", and **the protein bar is the one
/// element that tracks her real data** — it is a percentage, not copy. The
/// numbers in those two sentences cannot be made to follow her logs without a
/// dictionary change, and inventing the string here would put untranslated
/// English in front of an Arabic reader.
///
/// The protein target itself is unowned — G5 §9 Q1, see
/// [kProvisionalProteinTargetG].
library;

import '../../../theme/app_art.dart';

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../domain/flags/feature_flags.dart';
import '../../../data/pending_answers.dart';
import '../../../domain/format/number_label.dart';
import '../../../domain/logging/log_command_bus.dart';
import '../../../l10n/app_l10n.dart';
import '../../../app_state/eat_state.dart';
import '../../../routing/app_router.dart';
import '../../../theme/app_tokens.dart';
import '../../../theme/recipe_book_tokens.dart';
import '../../../ui/app_empty_state.dart';
import '../../../ui/app_list_item.dart';
import '../../../ui/app_nav_bar.dart';
import '../../../ui/app_pill.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/screen_scope.dart';
import '../../../ui/app_split_row.dart';
import '../../../ui/app_undo_bar.dart';
import '../../../ui/app_undo_snackbar.dart';
import '../../../ui/hand/hand.dart';
import '../../../ui/screen_art_strip.dart';
import '../../today/presentation/today_cards.dart' show mealSlotName, openScreen;
import '../domain/allergy_guard.dart';
import '../domain/day_totals.dart';
import '../domain/food_library.dart';
import '../domain/meal_log_service.dart';
import '../domain/meal_repository.dart';
import '../domain/meal_sentence_parser.dart';
import 'eat_day_view_model.dart';
import 'eat_sample_library.dart';
import 'eat_widgets.dart';
import 'meal_log_session.dart';

/// A meal the plan prescribes for a slot.
///
/// **Null for every woman in the MVP.** G2 publishes `assignment.meal == null`
/// for the whole cut — there is no coach to plan meals — so the "Lunch, from
/// your plan / From Sara" block the prototype draws is not rendered to a woman
/// who has no coach. Drawing it anyway would name a coach she does not have, the
/// same class of untruth as C13's invented "74 seconds".
class PlannedMeal {
  const PlannedMeal({
    required this.slot,
    required this.title,
    required this.meta,
    required this.planRef,
    required this.entry,
    this.coachName,
  });

  final MealSlot slot;
  final String title;
  final String meta;
  final PlanRef planRef;
  final ParsedItem entry;
  final String? coachName;
}

class EatView extends StatefulWidget {
  const EatView({
    super.key,
    required this.constraints,
    this.repository,
    this.bus,
    this.session,
    this.library,
    this.now,
    this.justLogged,
    this.plannedMeal,
    this.yesterdaysLunch,
    this.onOpenRecipes,
    this.onType,
    this.onSpeak,
    this.onLogged,
    this.onBlocked,
    this.onSelectTab,
  });

  /// What she can and cannot eat.
  ///
  /// **Required, never defaulted.** Whether her allergies are known is a fact
  /// about the product's state, and both possible defaults are wrong in a
  /// different way — `unknown` fails closed on every log, `none` claims she was
  /// asked and named nothing. The caller has to say which it is, out loud. See
  /// `app_router.dart`, which is the one place in the app that decides.
  final DietaryConstraints constraints;

  final MealRepository? repository;

  /// Shared with Train and Today in production, so rule 9 has one
  /// implementation rather than one per feature.
  final LogCommandBus? bus;

  /// The Eat tab's shared five seconds.
  ///
  /// When supplied, this screen logs into it rather than into a bus of its own,
  /// and draws every meal still inside its window — including one logged on
  /// another screen a moment ago, which is what makes E04 show the meal E02 just
  /// took. Absent, the screen keeps its own bus and its own pending list, which
  /// is how the widget tests drive it.
  final MealLogSession? session;

  /// The food pack. Defaults to the sample library resolved from the dictionary.
  final FoodLibrary? library;

  /// The clock, injectable so "which slot is now" is testable.
  final DateTime? now;

  /// The log she just made — **this is what makes this screen E04.**
  ///
  /// E01 and E04 are the same screen either side of a log: the prototype draws
  /// them separately because it is a static mockup, and building two widgets
  /// would mean two logging paths, two slot cards and two chances for them to
  /// drift. E04 is still a real route (`appDestinations` holds it); its builder
  /// simply constructs this widget with the handle.
  ///
  /// When set, the screen grows the undo bar, the "+5 points" pill and the
  /// protein delta, exactly as `screens-eat.mjs` → `E04` draws them.
  final LogHandle? justLogged;

  /// Null for every woman in the MVP — see [PlannedMeal].
  final PlannedMeal? plannedMeal;

  /// "Yesterday's lunch again", read cache-only. Absent ⇒ the row is omitted
  /// rather than rendered empty (§2).
  final SuggestionView? yesterdaysLunch;

  final VoidCallback? onOpenRecipes;
  final VoidCallback? onType;
  final VoidCallback? onSpeak;

  /// Carries the five-second window to whatever renders the undo.
  final ValueChanged<LogHandle>? onLogged;

  /// A log the domain refused. Unwired today: the allergen sheet's three
  /// strings ("This has sesame — you told us sesame", "Not this", "Log it
  /// anyway") are absent from the dictionary, so there is nothing to render.
  final ValueChanged<MealLogRefused>? onBlocked;

  final ValueChanged<String>? onSelectTab;

  @override
  State<EatView> createState() => _EatViewState();
}

class _EatViewState extends State<EatView> {
  late final MealRepository _repo;
  late final LogCommandBus _bus;
  late final bool _ownsRepo;
  late final bool _ownsBus;

  StreamSubscription<MealDay>? _sub;
  MealDay? _day;
  EatPrefs _prefs = const EatPrefs();

  /// Items logged in the last five seconds, shown before the write is issued.
  ///
  /// §4.3: "The logged row appears immediately, with its real numbers, and the
  /// day total moves." Undo removes them again, because nothing was written.
  final List<MealItem> _pending = <MealItem>[];

  DateTime get _now => widget.now ?? DateTime.now();
  String get _dayId => _dayIdOf(_now);

  static String _dayIdOf(DateTime at) =>
      '${at.year.toString().padLeft(4, '0')}-'
      '${at.month.toString().padLeft(2, '0')}-'
      '${at.day.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    _ownsRepo = widget.repository == null;
    _repo = widget.repository ?? InMemoryMealRepository();
    final session = widget.session;
    _ownsBus = widget.bus == null && session == null;
    _bus = widget.bus ?? session?.bus ?? LogCommandBus();

    // While this screen is open the session keeps its meals pending, so the
    // undo stays real. When the last such screen closes it writes them.
    session?.attach();
    session?.addListener(_sessionChanged);

    unawaited(_load());
    _sub = _repo.watchDay(_dayId).listen((day) {
      if (mounted) setState(() => _day = day);
    });
  }

  /// A meal was logged, taken back, or written somewhere else.
  ///
  /// Her plates move on a write, so the whole day is read again rather than
  /// only the pending list — that is what puts a meal logged twice into "your
  /// usual" without her leaving the screen.
  void _sessionChanged() {
    if (!mounted) return;
    setState(() {});
    unawaited(_load());
  }

  Future<void> _load() async {
    final day = await _repo.day(_dayId);
    final prefs = await _repo.prefs();
    if (!mounted) return;
    setState(() {
      _day = day;
      _prefs = prefs;
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    widget.session?.removeListener(_sessionChanged);
    // A log still inside its window when she navigates away is committed, never
    // dropped. The session does the same when its last screen leaves.
    widget.session?.detach();
    if (_ownsBus) unawaited(_bus.flushAll());
    if (_ownsRepo) unawaited(_repo.dispose());
    super.dispose();
  }

  /// The day as she sees it: what is stored, plus what is still inside its undo
  /// window.
  MealDay get _projected {
    final base = _day ?? MealDay(dayId: _dayId);
    final session = widget.session;
    if (session != null) return session.project(base);
    if (_pending.isEmpty) return base;

    final slots = <MealSlot, List<MealItem>>{...base.slots};
    for (final item in _pending) {
      final slot = _pendingSlots[item.itemId] ?? MealSlot.snack;
      slots[slot] = [...?slots[slot], item];
    }
    return base.copyWith(slots: slots);
  }

  final Map<String, MealSlot> _pendingSlots = <String, MealSlot>{};

  FoodLibrary _library(AppL10n l10n) =>
      widget.library ?? eatSampleLibrary(l10n);

  MealLogService _service(AppL10n l10n) => MealLogService(
    repository: _repo,
    library: _library(l10n),
    guard: AllergyGuard(widget.constraints),
  );

  /// The **one** undo offer for one log (§2 rule 9).
  ///
  /// When [EatView.onLogged] is wired the handle travels on to E04, which draws
  /// the in-page [AppUndoBar] for it. Raising a floating snackbar here as well
  /// put two offers for the same meal on screen at once, reading the same
  /// sentence and closing half a second apart — and a woman who reached the one
  /// that had already expired got nothing at all. The in-page bar is the one
  /// that stays: it sits where the prototype draws it, it does not cover the
  /// slot card it is announcing, and it degrades honestly, dropping its button
  /// the moment the five seconds close instead of leaving one that lies.
  ///
  /// With no handler to carry the handle onward nothing else would offer the
  /// window, so the snackbar stands in.
  void _offerUndo(LogHandle handle, {VoidCallback? onUndo}) {
    if (widget.onLogged != null) return;
    showUndoSnackBar(
      context,
      handle: handle,
      undoLabel: AppL10n.of(context).undo,
      onUndo: onUndo,
    );
  }

  /// One tap. Saves immediately, offers five seconds, asks nothing.
  void _log(
    List<ParsedItem> entries,
    MealSlot slot, {
    MealOrigin origin = MealOrigin.suggestion,
  }) {
    final l10n = AppL10n.of(context);
    final outcome = _service(l10n).logNew(
      day: _projected,
      slot: slot,
      entries: entries,
      source: MealSource.search,
      origin: origin,
      at: _now,
    );

    if (outcome is MealLogRefused) {
      // Surfaced, never swallowed. See `onBlocked` — there is no sheet to show.
      widget.onBlocked?.call(outcome);
      return;
    }

    final prepared = outcome as MealLogPrepared;
    final session = widget.session;
    if (session != null) {
      // The session holds the write and the row, so every open Eat screen draws
      // this meal now and can take it back for the next five seconds.
      final handle = session.submit(
        prepared,
        slot: slot,
        describe: l10n.foodLogged,
      );
      _offerUndo(
        handle,
        onUndo: () {
          session.settle();
          if (mounted) setState(() {});
        },
      );
      widget.onLogged?.call(handle);
      return;
    }

    setState(() {
      for (final item in prepared.items) {
        _pending.add(item);
        _pendingSlots[item.itemId] = slot;
      }
    });

    final handle = _bus.submit(
      UndoableLog(
        // The dictionary's "Lunch logged · 696 kcal" is a FIXED string with no
        // placeholder, so using it would announce 696 kcal whatever she logged —
        // the exact defect PHASE1-FIXES §8 records on R07's button. Until a
        // parameterised key exists, the honest sentence is the one that states
        // less.
        describe: l10n.foodLogged,
        commit: () => _service(l10n).commit(prepared.write),
      ),
    );

    _offerUndo(
      handle,
      onUndo: () {
        if (!mounted) return;
        setState(() {
          for (final item in prepared.items) {
            _pending.removeWhere((p) => p.itemId == item.itemId);
            _pendingSlots.remove(item.itemId);
          }
        });
      },
    );

    widget.onLogged?.call(handle);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final library = _library(l10n);

    final view = EatDayViewModel(
      library: library,
      guard: AllergyGuard(widget.constraints),
    ).build(day: _projected, prefs: _prefs, now: _now);

    return Scaffold(
      backgroundColor: AppColors.surface,
      bottomNavigationBar: AppNavBar(
        // This one widget is both E01 and E04, so it cannot name its own id the
        // way every other screen does. Hardcoding 'E01' marked the Eat tab
        // active while she was standing on E04, and `AppNavBar` gives the active
        // tab no `onTap` — so on E04 the Eat tab was drawn as the current page
        // and did nothing at all when she pressed it. Outside the router there
        // is no scope, and E01 is the right answer there.
        activeScreenId: ScreenScope.of(context) ?? 'E01',
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
        // Three branches where there were two. `_dayOne` is a confident
        // sentence about a woman who has never logged a meal, and it is a lie
        // to one whose meals are still being pulled down. See
        // `lib/data/pending_answers.dart`.
        children: switch ((view.isDayOne, _repo.dataState)) {
          (true, DataState.unknown) => _stillLooking(l10n),
          (true, _) => _dayOne(context, l10n, view),
          (false, _) => _today(context, l10n, view),
        },
      ),
    );
  }

  // ---------------------------------------------------------------- E01 ----

  /// Whether the log E04 was opened for can still be taken back.
  ///
  /// E04 drew a live Undo for as long as it was on screen, so a woman who sat
  /// there for ten seconds was offered a button that reported false and changed
  /// nothing — the same defect `_goCarryingHandle` records for R09, one flow
  /// across. [AppUndoBar] already has the honest rendering for a closed window:
  /// the bar stays, saying what was saved, and the button goes.
  bool get _canStillUndo {
    final handle = widget.justLogged;
    if (handle == null) return false;
    final session = widget.session;
    if (session == null) return true;
    return !session.issued(handle) || session.isOpen(handle);
  }

  /// Whether the log E04 was opened for was taken back.
  ///
  /// The bar used to stay after she undid it, still reading "Food logged" over
  /// a day that no longer holds the meal, with the five points beside it.
  bool get _wasUndone {
    final handle = widget.justLogged;
    final session = widget.session;
    if (handle == null || session == null) return false;
    return session.wasUndone(handle);
  }

  List<Widget> _today(BuildContext context, AppL10n l10n, EatDayView view) {
    final justLogged = _wasUndone ? null : widget.justLogged;

    return [
      // E04's undo bar, and the ONLY undo this screen shows. Drawn **in the
      // page** rather than raised as a floating snackbar, exactly as R13 does —
      // a floating bar would sit over the slot card it is announcing, and two
      // bars for one meal is what `_offerUndo` exists to prevent.
      if (justLogged != null)
        AppUndoBar(
          message: justLogged.describe,
          undoLabel: l10n.undo,
          onUndo: _canStillUndo
              ? () {
                  justLogged.undo();
                  widget.session?.settle();
                  if (mounted) setState(() {});
                }
              : null,
        ),
      AppSplitRow(
        start: _masthead(l10n),
        end: justLogged == null
            ? AppPill(
                l10n.ramadanModeOff,
                background: AppColors.surfaceContainer,
                foreground: AppColors.onSurfaceVariant,
              )
            // Five points land once a day for logging anything — never per
            // item, so there is no reason for her to split a plate. G6 awards
            // them on the day document, which is what makes that structural.
            : AppPill(
                l10n.n5Points,
                background: AppColors.tertiaryContainer,
                foreground: AppColors.tertiary,
                icon: Icons.add,
              ),
      ),
      DayCard(
        slots: _slotColumns(l10n, view),
        proteinTitle: l10n.protein,
        // The card derives its own sentences from these totals now. It used to
        // take them as fixed strings chosen by `justLogged == null` — so the
        // numbers changed when she logged *anything* and never reflected what
        // she ate. `proteinDelta` is omitted because nothing computes it: a
        // LogHandle carries a description and an undo, not a delta.
        totals: view.totals,
      ),
      // Rendered only for a woman who actually has a coach — null for everyone
      // in the MVP.
      if (widget.plannedMeal != null) ..._plannedBlock(l10n),
      // The slot she is actually in, and no claim about a pattern.
      //
      // This was "Dinner, your usual" beside "Tuesdays": the slot fixed
      // whatever the hour, and a weekly habit asserted to a woman who had
      // logged one meal in her life. `slotAt` is the same hour-to-slot rule
      // Home heads its meal row with, so the two screens agree. "Your usual"
      // is the guess form and stays, because that is what this row is: the
      // thing she tends to eat at this hour.
      if (justLogged != null)
        // The meal, named plainly. It read "Lunch, your usual" the moment after
        // she logged her first meal ever, which is one meal and not a usual.
        // Home takes the same line once something is logged, for the same
        // reason: the time is already printed beside it.
        Text(
          mealSlotName(l10n, EatDayViewModel.slotAt(DateTime.now())),
          style: AppText.titleM,
        ),
      for (final suggestion in view.suggestions)
        MealRow(
          title: _titleOf(suggestion),
          meta: _metaOf(l10n, suggestion),
          logLabel: l10n.log,
          primary: suggestion.primary,
          onLog: () => _log(suggestion.entries, view.activeSlot),
        ),
      if (widget.yesterdaysLunch != null)
        MealRow(
          title: l10n.yesterdaysLunchAgain,
          // Yesterday's own figure, through the same [_metaOf] the rows above
          // use. `taameyaSaladBaladi520Kcal` — "Ta'ameya, salad, baladi ·
          // 520 kcal" — named the prototype's lunch and its calories whatever
          // she had actually eaten yesterday, on the row whose whole promise is
          // that it repeats HER meal.
          meta: _metaOf(l10n, widget.yesterdaysLunch!),
          logLabel: l10n.log,
          onLog: () => _log(widget.yesterdaysLunch!.entries, view.activeSlot),
        ),
      if (_screenedToNothing(view.suggestions)) _guardNote(l10n),
      _recipesRow(l10n),
      _rahmaShelf(l10n),
      _box(l10n),
    ];
  }

  List<Widget> _plannedBlock(AppL10n l10n) {
    final planned = widget.plannedMeal!;
    // The pill credits whoever wrote the plan. `fromSara` is the prototype's
    // coach, and in a build with no coaching nobody wrote it, so the row names
    // the plan and credits nobody rather than naming a woman who is not there.
    final credit =
        planned.coachName ??
        (AppRouter.featureFlags.isOn(Feature.coachedLife) ? l10n.fromSara : '');
    return [
      AppSplitRow(
        start: Text(l10n.lunchFromYourPlan, style: AppText.titleM),
        end: credit.isEmpty
            ? const SizedBox.shrink()
            : AppPill(credit, icon: Icons.sports),
      ),
      MealRow(
        title: planned.title,
        meta: planned.meta,
        logLabel: l10n.log,
        primary: true,
        // A planned meal CORRECTS on a re-log — a different method entirely
        // from the free log above. HANDOFF rule 3.
        onLog: () => _logPlanned(planned),
      ),
    ];
  }

  void _logPlanned(PlannedMeal planned) {
    final l10n = AppL10n.of(context);
    final outcome = _service(l10n).correctPlannedLog(
      day: _projected,
      planRef: planned.planRef,
      entry: planned.entry,
      at: _now,
    );

    if (outcome is MealLogRefused) {
      widget.onBlocked?.call(outcome);
      return;
    }

    final prepared = outcome as MealLogPrepared;
    final handle = _bus.submit(
      UndoableLog(
        describe: l10n.foodLogged,
        commit: () => _service(l10n).commit(prepared.write),
      ),
    );
    _offerUndo(handle);
    widget.onLogged?.call(handle);
  }

  // ------------------------------------------------------- E09, unanswered ----

  /// Eat while nothing has yet said whether she has eaten here before.
  ///
  /// The masthead stays, because the name of the section is true whatever a
  /// pull says. The "Day 1" pill, the empty state and the starters go, because
  /// each of them states that she is beginning.
  ///
  /// No spinner: this screen never had one, and a sentence is the honest way to
  /// say "we do not know yet" without implying she should sit and wait.
  List<Widget> _stillLooking(AppL10n l10n) => [
    _masthead(l10n),
    Text(
      l10n.lookingForWhatYouHaveLogged,
      style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
    ),
  ];

  // ---------------------------------------------------------------- E09 ----

  List<Widget> _dayOne(BuildContext context, AppL10n l10n, EatDayView view) {
    return [
      AppSplitRow(
        start: _masthead(l10n),
        end: AppPill(
          l10n.day1_4ehtd,
          background: AppColors.surfaceContainer,
          foreground: AppColors.onSurfaceVariant,
        ),
      ),
      // Rule 17: the empty state IS the onboarding. It says what will appear
      // here, why it is empty, and offers one action — no tour, no overlay.
      AppEmptyState(
        icon: Icons.restaurant,
        art: AppArt.bowlSalad,
        title: l10n.noPlatesYet,
        body: l10n.logSomethingTwiceAndItBecomesA,
      ),
      _box(l10n),
      if (_screenedToNothing(view.starters))
        _guardNote(l10n)
      else ...[
        Text(l10n.orStartFromOneOfThese, style: AppText.titleS),
        for (final starter in view.starters)
          MealRow(
            title: _titleOf(starter),
            meta: _starterMeta(l10n, view.activeSlot, starter),
            logLabel: l10n.log,
            primary: starter.primary,
            onLog: () => _log(starter.entries, view.activeSlot),
          ),
      ],
      Text(
        l10n.noCountdownNoRedNumbersProteinIs,
        style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
      ),
    ];
  }

  // -------------------------------------------------------------- shared ----

  /// True when the guard emptied a list that would otherwise have rows in it.
  ///
  /// She told us what she avoids and no dish in the pack lists what is in it,
  /// so [AllergyGuard.screen] removes all of them — "unknown, therefore unsafe".
  /// An empty list with no sentence under it reads as a broken screen, which is
  /// how a safety filter gets "fixed" by being switched off.
  bool _screenedToNothing(List<SuggestionView> rows) =>
      rows.isEmpty && widget.constraints.hasAllergies;

  Widget _guardNote(AppL10n l10n) => Text(
    l10n.weCannotCheckTheseDishesForWhat,
    style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
  );

  /// The section's name, set large and ringed once in rose ink — the one mark
  /// on this page. Each section's home is marked its own way (Today is
  /// underlined, Train highlighted), so the hand never repeats a gesture
  /// from tab to tab.
  Widget _masthead(AppL10n l10n) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Padding(
        padding: const EdgeInsetsDirectional.only(start: 10, top: 6, bottom: 6),
        child: HandCircled(
          drawOn: true,
          level: HandLevel.signature,
          width: HandStroke.felt,
          inflate: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Text(l10n.eat, style: EditorialType.section),
        ),
      ),
      // Clear of the loop, which reaches 14 past the word on each side.
      const SizedBox(width: 26),
      // The drawing sits beside the name, as on a cover, not above it.
      const Flexible(child: ScreenArtInline()),
    ],
  );

  List<SlotColumn> _slotColumns(AppL10n l10n, EatDayView view) {
    return [
      for (final slot in view.slots)
        SlotColumn(
          name: _slotName(l10n, slot.slot),
          value: _slotValue(l10n, slot),
          status: slot.status,
        ),
    ];
  }

  String _slotName(AppL10n l10n, MealSlot slot) => switch (slot) {
    MealSlot.breakfast => l10n.breakfast,
    MealSlot.lunch => l10n.lunch,
    MealSlot.dinner => l10n.dinner,
    MealSlot.snack => l10n.snack,
  };

  /// What is in the slot, or where it sits in the day.
  String _slotValue(AppL10n l10n, SlotView slot) {
    if (slot.items.isEmpty) {
      return slot.status == SlotStatus.now ? l10n.now_65hr : l10n.later;
    }
    final names = slot.items
        .map((item) => _foodName(l10n, item.foodId))
        .where((name) => name.isNotEmpty)
        .toList();
    return names.isEmpty ? l10n.later : names.join(', ');
  }

  String _foodName(AppL10n l10n, String foodId) {
    final food = _library(l10n).byId(foodId);
    return food?.names.first ?? '';
  }

  String _titleOf(SuggestionView suggestion) =>
      suggestion.entries.map((e) => e.food.names.first).join(', ');

  /// "460 kcal · 34 g protein" — computed from the food she is looking at.
  ///
  /// The old doc comment claimed the macros were "picked from the dictionary by
  /// the row it describes, so the row and its macros cannot disagree". They
  /// disagreed for every food outside a six-case switch, because the default
  /// arm was `n540Kcal18GProtein`: two boiled eggs — 156 kcal and 13 g — showed
  /// koshari's 540 and 18. The dictionary even held `n156Kcal13GProtein`, the
  /// correct figure, unused.
  ///
  /// Summed across entries, because one suggestion can hold several foods;
  /// `_titleOf` already joins their names. `countLabel` keeps the digits
  /// Western under `ar`, which `NumberFormat` would not.
  String _metaOf(AppL10n l10n, SuggestionView suggestion) {
    final kcal = suggestion.entries.fold<int>(0, (sum, e) => sum + e.kcal);
    final protein = suggestion.entries.fold<int>(
      0,
      (sum, e) => sum + e.proteinG,
    );
    return l10n.kcalKcalProteinGProtein(countLabel(kcal), countLabel(protein));
  }

  /// The same defect as [_metaOf], one screen earlier and with the slot in it.
  ///
  /// Three hardcoded cases and `_ => lunch540Kcal18GProtein`, so E01's starter
  /// list told a woman that boiled eggs were a 540 kcal lunch. The slot now
  /// comes from the slot she is actually logging into — the one tapping Log
  /// writes to — rather than a guess baked into the string about when a food
  /// is usually eaten.
  String _starterMeta(AppL10n l10n, MealSlot slot, SuggestionView starter) {
    final kcal = starter.entries.fold<int>(0, (sum, e) => sum + e.kcal);
    final protein = starter.entries.fold<int>(0, (sum, e) => sum + e.proteinG);
    return l10n.slotKcalKcalProteinGProtein(
      _slotName(l10n, slot),
      countLabel(kcal),
      countLabel(protein),
    );
  }

  Widget _recipesRow(AppL10n l10n) => AppListItem(
    leading: const Icon(Icons.menu_book, size: 23, color: AppColors.primaryDim),
    title: l10n.recipes,
    subtitle: l10n.egyptianDishesWithPortionsAndCostPer,
    trailing: const Icon(
      Icons.chevron_right,
      size: 22,
      color: AppColors.onSurfaceVariant,
    ),
    onTap: () => openScreen(context, 'E05', widget.onOpenRecipes),
  );

  /// A shelf of her four sections, one small card each.
  ///
  /// **The rest of E01 is not restyled.** This is the logging screen: the day
  /// totals, the suggestions, the say-or-type box and the guard note all stay
  /// exactly as they are. Turning the whole tab pink would mean turning the day
  /// totals pink, and the day totals are not a recipe book.
  ///
  /// Empty until the seed has been read, and empty is drawn as nothing at all
  /// rather than as four grey placeholders: a shelf of loading cards on a screen
  /// whose main job is logging a meal is noise.
  Widget _rahmaShelf(AppL10n l10n) {
    final book = (EatAppState.instance..ensureRecipeBook()).recipeBook;
    if (book.sections.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.rahmasRecipes, style: AppText.titleM),
        const SizedBox(height: 8),
        SizedBox(
          height: 108,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.zero,
            itemCount: book.sections.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final section = book.sections[index];
              return SizedBox(
                width: 168,
                child: HandSurface(
                  seed: handSeed(['eat-shelf', section.sectionId]),
                  fill: BookInk.paper,
                  level: HandLevel.crafted,
                  radius: 8,
                  looseCorner: 16,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  onTap: () => openScreen(context, 'E05', widget.onOpenRecipes),
                  semanticsButton: true,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: BookTitle(
                          titleEn: section.titleEn,
                          style: AppText.titleS.copyWith(color: BookInk.ink),
                        ),
                      ),
                      FoodMark(
                        markKey: section.markKey,
                        size: 30,
                        ink: BookInk.ink,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _box(AppL10n l10n) => SayOrTypeBox(
    label: l10n.sayOrTypeWhatYouAte,
    micTooltip: l10n.weNeedTheMicrophoneToHearWhat,
    onType: () => openScreen(context, 'E02', widget.onType),
    onSpeak: () => openScreen(context, 'E03', widget.onSpeak),
  );
}
