/// E01 — Eat, the one place for food.
///
/// Logging a meal, finding a recipe and planning the week's dinners used to be
/// four screens (E01, E02, E05, E07) and a centre button. This is one page: a
/// search bar that never scrolls away (type it, say it, or snap it) over three
/// segments.
///
///  * **Log**: the day's ring and macros, the four meals each with a Log pill,
///    the meal-photo card, then Recent / Frequent / Favourites and her usual
///    picks. An undo bar for the meal she has just logged (E04's job).
///  * **Recipes**: search, filters, and the recipes grouped by meal.
///  * **Plan**: this week's dinners and the grocery list under them.
///
/// Typing in the bar searches foods right here: while there is text, the food
/// results replace the segment's content, and logging from them returns to the
/// day with the undo bar showing.
///
/// It reuses the screens that already did each job, in their `embedded` mode,
/// so every logging path (slots, the five seconds, undo, favourites, portions,
/// quick custom foods, allergy guard) is the same code as before. E05, E06,
/// E07 and E08 stay as pushed screens for deep links and notifications.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../domain/logging/log_command_bus.dart';
import '../../../app_state/guest_session.dart' show PendingAction;
import '../../../l10n/app_l10n.dart';
import '../../../routing/app_router.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_field.dart';
import '../../../ui/app_nav_bar.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/app_segmented.dart';
import '../../../ui/screen_art_strip.dart';
import '../../../ui/screen_scope.dart';
import '../../../ui/hand/hand.dart';
import '../../today/presentation/today_cards.dart' show openScreen;
import '../data/seeded_recipe_library.dart';
import '../domain/allergy_guard.dart';
import '../domain/daily_targets.dart';
import '../domain/food_library.dart';
import '../domain/meal_log_service.dart';
import '../domain/meal_repository.dart';
import '../domain/meal_sentence_parser.dart';
import '../domain/recipe.dart';
import 'eat_view.dart';
import 'eat_widgets.dart' show SnapMealButton;
import 'grocery_list_view.dart';
import 'meal_log_session.dart';
import 'recipes_view.dart';
import 'type_it_view.dart';
import 'week_plan_view.dart';

/// The three parts of the Eat tab.
enum EatHubSegment { log, recipes, plan }

class EatHubView extends StatefulWidget {
  const EatHubView({
    super.key,
    required this.constraints,
    this.repository,
    this.session,
    this.library,
    this.now,
    this.targets,
    this.history = const <ParsedItem>[],
    this.frequent = const <ParsedItem>[],
    this.historyOf,
    this.frequentOf,
    this.requireAccount,
    this.onBlocked,
    this.justLogged,
    this.foodPointsFor,
    this.initialText,
    this.initialSlot,
    this.initialSegment = EatHubSegment.log,
    this.book,
    this.asked = false,
    this.onOpenRecipe,
    this.onAnswerAllergies,
    this.onOpenLetter,
    this.onPickDinner,
    this.fillFrom = const <String>[],
    this.recipeTitle,
    this.recipeOf,
    this.onSpeak,
    this.onSnap,
    this.onSearch,
    this.onLogged,
    this.onSelectTab,
  });

  /// See `EatView.constraints`: required, never defaulted.
  final DietaryConstraints constraints;

  /// One store for the whole page. Absent, the hub keeps its own in memory.
  final MealRepository? repository;

  /// The Eat tab's shared five seconds. The hub attaches to it for as long as
  /// it is open, so switching segments never closes a meal's undo window.
  final MealLogSession? session;

  final FoodLibrary? library;
  final DateTime? now;
  final DailyTargets? targets;

  /// Plates she has eaten before, and the same foods most-eaten first, for the
  /// Recent and Frequent lists.
  final List<ParsedItem> history;
  final List<ParsedItem> frequent;

  /// The same lists, read afresh on every build. The hub stays open while she
  /// logs, so a list handed over once would never show the meal she has just
  /// had; given, these win over [history] and [frequent].
  final List<ParsedItem> Function(AppL10n l10n)? historyOf;
  final List<ParsedItem> Function(AppL10n l10n)? frequentOf;

  /// Asked before a meal is logged or a food starred; false means she is a
  /// guest and has been taken to sign in. Absent, everything is allowed.
  final bool Function(BuildContext context, PendingAction action)?
  requireAccount;

  final ValueChanged<MealLogRefused>? onBlocked;

  /// A log she has just made, to open on its undo bar (E04).
  final LogHandle? justLogged;

  /// What a log will pay in points when its window closes. The pill is drawn
  /// only above zero. Absent, no pill.
  final int Function(LogHandle? handle)? foodPointsFor;

  /// Opens with this in the search bar (E02's "edit" from the voice screen).
  final String? initialText;

  /// The meal the next food goes to, when she arrives from a Log pill.
  final MealSlot? initialSlot;

  final EatHubSegment initialSegment;

  /// Rahma's book and the Own Hub kitchen, already loaded.
  final RecipeBook? book;

  /// Whether the allergy question has been put to her.
  final bool asked;

  /// A recipe was tapped (E06).
  final ValueChanged<String>? onOpenRecipe;
  final VoidCallback? onAnswerAllergies;
  final VoidCallback? onOpenLetter;

  /// Choose a dinner for a day (E05 in pick mode). Completes when she is back.
  final Future<void> Function(PlanDay day)? onPickDinner;

  /// Recipes "Fill my week" may use, in order. Empty draws no button.
  final List<String> fillFrom;

  /// The name of a recipe the sample library does not know.
  final String? Function(String recipeId)? recipeTitle;

  /// Finds a recipe by id, to make the grocery list from the week's dinners.
  final Recipe? Function(String recipeId)? recipeOf;

  /// The microphone: the voice screen (E03). Null, or E03 off, hides it.
  final VoidCallback? onSpeak;

  /// The camera: a photo of her plate (E12). Null hides it; the router passes
  /// it only while E12 is on and she is verified.
  final VoidCallback? onSnap;

  /// She typed in the search bar. Called with the text as it stands.
  final ValueChanged<String>? onSearch;

  /// A meal was logged from anywhere on the page. The hub shows the undo bar
  /// itself; this is for the caller's bookkeeping (analytics).
  final ValueChanged<LogHandle>? onLogged;

  final ValueChanged<String>? onSelectTab;

  @override
  State<EatHubView> createState() => _EatHubViewState();
}

class _EatHubViewState extends State<EatHubView> {
  late final MealRepository _repo;
  late final bool _ownsRepo;
  final TextEditingController _text = TextEditingController();
  final FocusNode _focus = FocusNode();
  final ScrollController _scroll = ScrollController();

  late EatHubSegment _segment = widget.initialSegment;
  final Set<EatHubSegment> _visited = <EatHubSegment>{};
  MealSlot? _slot;
  LogHandle? _justLogged;
  int _points = 0;

  /// Bumped when the week changes, so the grocery list reads the plan again.
  int _planRevision = 0;

  @override
  void initState() {
    super.initState();
    _ownsRepo = widget.repository == null;
    _repo = widget.repository ?? InMemoryMealRepository();
    widget.session?.attach();
    widget.session?.addListener(_sessionChanged);
    _slot = widget.initialSlot;
    _text.text = widget.initialText ?? '';
    _text.addListener(_typed);
    _justLogged = widget.justLogged;
    _points = widget.foodPointsFor?.call(_justLogged) ?? 0;
    _visited.add(_segment);
  }

  @override
  void dispose() {
    _text.removeListener(_typed);
    _text.dispose();
    _focus.dispose();
    _scroll.dispose();
    widget.session?.removeListener(_sessionChanged);
    widget.session?.detach();
    if (_ownsRepo) unawaited(_repo.dispose());
    super.dispose();
  }

  /// A meal was logged, taken back or written: her plates and recents moved.
  void _sessionChanged() {
    if (mounted) setState(() {});
  }

  String _lastHeard = '';

  void _typed() {
    if (_text.text == _lastHeard) return;
    _lastHeard = _text.text;
    widget.onSearch?.call(_text.text);
    if (mounted) setState(() {});
  }

  bool get _searching => _text.text.trim().isNotEmpty;

  /// The segments this build has switched on. Log is always there.
  List<EatHubSegment> get _segments => [
    EatHubSegment.log,
    if (AppRouter.screenIsOn('E05')) EatHubSegment.recipes,
    if (AppRouter.screenIsOn('E07')) EatHubSegment.plan,
  ];

  void _select(EatHubSegment next) {
    if (next == _segment) return;
    setState(() {
      _segment = next;
      _visited.add(next);
    });
  }

  void _scrollToTop() {
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  /// A meal was logged from the day, the search results or the voice screen's
  /// result. The page goes back to the day, where the meal now sits with its
  /// undo bar.
  void _logged(LogHandle handle) {
    setState(() {
      _justLogged = handle;
      _points = widget.foodPointsFor?.call(handle) ?? 0;
      _segment = EatHubSegment.log;
      _slot = null;
      _text.clear();
    });
    widget.onLogged?.call(handle);
    _focus.unfocus();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToTop());
  }

  /// A Log pill on a meal row: aim the next food at that meal and start typing.
  void _logInto(MealSlot slot) {
    setState(() {
      _slot = slot;
      _segment = EatHubSegment.log;
    });
    _scrollToTop();
    _focus.requestFocus();
  }

  String _slotName(AppL10n l10n, MealSlot slot) => switch (slot) {
    MealSlot.breakfast => l10n.breakfast,
    MealSlot.lunch => l10n.lunch,
    MealSlot.dinner => l10n.dinner,
    MealSlot.snack => l10n.snacks,
  };

  String _segmentLabel(AppL10n l10n, EatHubSegment segment) =>
      switch (segment) {
        EatHubSegment.log => l10n.log,
        EatHubSegment.recipes => l10n.recipes,
        EatHubSegment.plan => l10n.plan,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final segments = _segments;
    final segment = segments.contains(_segment) ? _segment : segments.first;
    final searching = _searching;

    final header = _header(l10n, segments, segment);
    // At the largest text sizes the header would leave the lists a sliver, so it
    // scrolls with them instead of staying pinned.
    final pinned = MediaQuery.textScalerOf(context).scale(1) <= 1.5;

    return Scaffold(
      backgroundColor: AppColors.surface,
      bottomNavigationBar: AppNavBar(
        // The screen it was opened as. The bar marks a tab active only on the
        // screen that tab owns, so on E02 or E04 the Eat tab is a way back to
        // E01 rather than a claim about a page she is not on. Outside the router
        // there is no scope, and E01 is the right answer there.
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
      body: PaperPage(
        color: AppColors.surface,
        child: SafeArea(
          child: Column(
            children: [
              if (pinned)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: header,
                ),
              Expanded(
                child: SingleChildScrollView(
                  key: const ValueKey('eat-hub-scroll'),
                  controller: _scroll,
                  padding: EdgeInsets.fromLTRB(16, pinned ? 0 : 8, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!pinned) header,
                      ..._content(l10n, segment, searching),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The search bar, the meal it is aimed at, and the segments.
  Widget _header(
    AppL10n l10n,
    List<EatHubSegment> segments,
    EatHubSegment segment,
  ) {
    final voice = widget.onSpeak != null && AppRouter.screenIsOn('E03');
    final slot = _slot;
    return Column(
      key: const ValueKey('eat-hub-header'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: AppField(
                key: const ValueKey('eat-hub-search'),
                controller: _text,
                focusNode: _focus,
                hint: voice ? l10n.sayOrTypeWhatYouAte : l10n.typeWhatYouAte,
                trailing: (voice || _searching)
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_searching)
                            IconButton(
                              key: const ValueKey('eat-hub-clear'),
                              onPressed: _text.clear,
                              tooltip: l10n.clear,
                              iconSize: 22,
                              color: AppColors.onSurfaceVariant,
                              icon: const Icon(Icons.close),
                            ),
                          if (voice)
                            IconButton(
                              key: const ValueKey('eat-hub-mic'),
                              onPressed: widget.onSpeak,
                              tooltip: l10n.weNeedTheMicrophoneToHearWhat,
                              iconSize: 22,
                              color: AppColors.primaryDim,
                              icon: const Icon(Icons.mic),
                            ),
                        ],
                      )
                    : null,
              ),
            ),
            if (widget.onSnap case final snap?) ...[
              const SizedBox(width: 10),
              SnapMealButton(label: l10n.snapYourMeal, onPressed: snap),
            ],
          ],
        ),
        if (slot != null)
          Padding(
            key: const ValueKey('eat-hub-adding-to'),
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.addingToMeal(_slotName(l10n, slot)),
                    style: AppText.label.copyWith(
                      color: AppColors.primaryDim,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => _slot = null),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    foregroundColor: AppColors.primaryDim,
                  ),
                  child: Text(l10n.clear),
                ),
              ],
            ),
          ),
        if (segments.length > 1) ...[
          const SizedBox(height: 10),
          AppSegmented(
            key: const ValueKey('eat-hub-segments'),
            items: [for (final s in segments) _segmentLabel(l10n, s)],
            selectedIndex: segments.indexOf(segment),
            onChanged: (index) => _select(segments[index]),
          ),
        ],
        // Each of these draws only for the screens it serves: E01 sets its
        // drawing inline, E02 and E04 take the strip.
        const Padding(
          padding: EdgeInsets.only(top: 6),
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: ScreenArtInline(size: 36),
          ),
        ),
        const ScreenArtStrip(size: 40),
        const SizedBox(height: 4),
      ],
    );
  }

  /// A part of the page that keeps its state while it is out of view, takes no
  /// room, and leaves no gap, so a segment she has been to comes back as she
  /// left it.
  Widget _kept(Key key, bool visible, Widget child) => Visibility(
    key: key,
    visible: visible,
    maintainState: true,
    child: Padding(
      padding: const EdgeInsets.only(top: kStackGap),
      child: child,
    ),
  );

  List<Widget> _content(AppL10n l10n, EatHubSegment segment, bool searching) {
    final inLog = segment == EatHubSegment.log;
    final typeIt = Padding(
      key: const ValueKey('eat-hub-food'),
      padding: const EdgeInsets.only(top: kStackGap),
      child: TypeItView(
        constraints: widget.constraints,
        repository: _repo,
        session: widget.session,
        library: widget.library,
        now: widget.now,
        slot: _slot,
        targets: widget.targets,
        history: widget.historyOf?.call(l10n) ?? widget.history,
        frequent: widget.frequentOf?.call(l10n) ?? widget.frequent,
        embedded: true,
        controller: _text,
        fieldFocus: _focus,
        onLogged: _logged,
        onBlocked: widget.onBlocked,
        requireAccount: widget.requireAccount,
      ),
    );

    return [
      _kept(
        const ValueKey('eat-hub-day'),
        inLog && !searching,
        EatView(
          constraints: widget.constraints,
          repository: _repo,
          session: widget.session,
          library: widget.library,
          now: widget.now,
          targets: widget.targets,
          justLogged: _justLogged,
          foodPointsPreview: _points,
          embedded: true,
          slot: _slot,
          onLogInto: _logInto,
          onSnap: widget.onSnap,
          onLogged: _logged,
          onBlocked: widget.onBlocked,
          requireAccount: widget.requireAccount,
        ),
      ),
      if (searching || inLog) typeIt,
      if (_visited.contains(EatHubSegment.recipes) &&
          AppRouter.screenIsOn('E05'))
        _kept(
          const ValueKey('eat-hub-recipes'),
          segment == EatHubSegment.recipes && !searching,
          RecipesPanel(
            book: widget.book,
            constraints: widget.constraints,
            asked: widget.asked,
            onOpenRecipe: widget.onOpenRecipe,
            onAnswerAllergies: widget.onAnswerAllergies,
            onOpenLetter: widget.onOpenLetter,
          ),
        ),
      if (_visited.contains(EatHubSegment.plan) && AppRouter.screenIsOn('E07'))
        _kept(
          const ValueKey('eat-hub-plan'),
          segment == EatHubSegment.plan && !searching,
          _plan(l10n),
        ),
    ];
  }

  /// This week's dinners with the grocery list under them.
  Widget _plan(AppL10n l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      spacing: kStackGap,
      children: [
        Text(l10n.thisWeek, style: AppText.titleL),
        WeekPlanView(
          repository: _repo,
          now: widget.now,
          embedded: true,
          onPickDinner: widget.onPickDinner,
          fillFrom: widget.fillFrom,
          recipeTitle: widget.recipeTitle,
          onOpenRecipe: widget.onOpenRecipe,
          onChanged: () => setState(() => _planRevision++),
        ),
        if (AppRouter.screenIsOn('E08')) ...[
          const HandRule(seed: 51, height: 12),
          Text(l10n.groceryList, style: AppText.titleL),
          GroceryListView(
            key: ValueKey('eat-hub-grocery-$_planRevision'),
            repository: _repo,
            now: widget.now,
            embedded: true,
            recipeOf: widget.recipeOf,
            recipeTitle: widget.recipeTitle,
          ),
        ],
      ],
    );
  }
}
