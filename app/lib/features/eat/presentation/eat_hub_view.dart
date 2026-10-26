/// E01 and E02 — Eat, the one place for food.
///
/// One page with two states, which the router names E01 and E02.
///
///  * **E01, "What I ate today"**: the day's hero, the four meals each with one
///    "+", and a search field with the camera inside it. Recipes and the week's
///    plan are two quiet rows under the meals and open in this page, with a
///    back arrow.
///  * **E02, "Find and add"**: the same field, focused, over Recent, Frequent
///    and Favourites, Quick custom and the pack. Typing searches foods right
///    here; logging returns to the day with the undo bar showing.
///
/// She is in E02 when the router names it, when she taps the field, when text
/// is in it, or when she taps a "+" that has no usual plate to log. The page
/// reuses the screens that already did each job, in their `embedded` mode, so
/// every logging path (slots, the five seconds, undo, favourites, portions,
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
import '../../../ui/app_list_item.dart';
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
    this.coachSection,
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

  /// "From your coach", at the top of the plan. Null without a coach.
  final Widget? coachSection;

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

  /// E02: the page is for finding and adding. Sticky, so a tap on a tab or a
  /// row inside it cannot drop her back to the day.
  bool _finding = false;
  bool _isE02 = false;
  bool _scopeRead = false;
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
    _focus.addListener(_focusChanged);
    _finding = _slot != null || _text.text.trim().isNotEmpty;
    _justLogged = widget.justLogged;
    _points = widget.foodPointsFor?.call(_justLogged) ?? 0;
    _visited.add(_segment);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_scopeRead) return;
    _scopeRead = true;
    _isE02 = ScreenScope.of(context) == 'E02';
    if (_isE02) _finding = true;
  }

  void _focusChanged() {
    if (_focus.hasFocus && !_finding && mounted) {
      setState(() => _finding = true);
    }
  }

  /// Leaves E02 for the day: from the close icon, or back. On the routed E02
  /// this closes the page instead.
  void _leaveFinding() {
    if (_isE02 && Navigator.of(context).canPop()) {
      Navigator.of(context).maybePop();
      return;
    }
    _focus.unfocus();
    _text.clear();
    setState(() {
      _finding = false;
      _slot = null;
    });
  }

  @override
  void dispose() {
    _focus.removeListener(_focusChanged);
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
      _finding = false;
      _text.clear();
    });
    widget.onLogged?.call(handle);
    _focus.unfocus();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToTop());
  }

  /// A "+" on a meal row with no usual plate: aim the next food at that meal
  /// and start typing.
  void _logInto(MealSlot slot) {
    setState(() {
      _slot = slot;
      _finding = true;
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
    final inLog = segment == EatHubSegment.log;

    final header = inLog ? _header(l10n) : _subHeader(l10n, segment);
    // At the largest text sizes the header would leave the lists a sliver, so it
    // scrolls with them instead of staying pinned.
    final pinned = MediaQuery.textScalerOf(context).scale(1) <= 1.5;

    return PopScope(
      // Back from Recipes or Plan returns to the day; back from the search on
      // E01 returns to the day. The routed E02 closes like any pushed page.
      canPop: inLog && (!_finding || _isE02),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (!inLog) {
          _select(EatHubSegment.log);
        } else {
          _leaveFinding();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.surface,
        bottomNavigationBar: AppNavBar(
          // The screen it was opened as. The bar marks a tab active only on the
          // screen that tab owns, so on E02 or E04 the Eat tab is a way back to
          // E01 rather than a claim about a page she is not on. Outside the
          // router there is no scope, and E01 is the right answer there.
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
                        ..._content(l10n, segment),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The search field with the camera inside it, and the meal it is aimed at.
  Widget _header(AppL10n l10n) {
    final voice = widget.onSpeak != null && AppRouter.screenIsOn('E03');
    final slot = _slot;
    return Column(
      key: const ValueKey('eat-hub-header'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        AppField(
          key: const ValueKey('eat-hub-search'),
          controller: _text,
          focusNode: _focus,
          hint: _finding && voice
              ? l10n.sayOrTypeWhatYouAte
              : l10n.typeWhatYouAte,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_finding)
                IconButton(
                  key: const ValueKey('eat-hub-clear'),
                  onPressed: _leaveFinding,
                  tooltip: l10n.clear,
                  iconSize: 22,
                  color: AppColors.onSurfaceVariant,
                  icon: const Icon(Icons.close),
                ),
              if (widget.onSnap case final snap?)
                IconButton(
                  key: const ValueKey('eat-snap-meal'),
                  onPressed: snap,
                  tooltip: l10n.snapYourMeal,
                  iconSize: 22,
                  color: AppColors.primaryDim,
                  icon: const Icon(Icons.photo_camera_outlined),
                ),
            ],
          ),
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

  /// Recipes and Plan open in this page, with a way back to the day.
  Widget _subHeader(AppL10n l10n, EatHubSegment segment) {
    return Row(
      key: const ValueKey('eat-hub-subheader'),
      children: [
        IconButton(
          key: const ValueKey('eat-hub-back'),
          onPressed: () => _select(EatHubSegment.log),
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          icon: const BackButtonIcon(),
        ),
        Expanded(
          child: Text(_segmentLabel(l10n, segment), style: AppText.titleL),
        ),
      ],
    );
  }

  /// Recipes and Plan, as two quiet rows under the day.
  Widget _moreRows(AppL10n l10n) {
    final recipes = AppRouter.screenIsOn('E05');
    final plan = AppRouter.screenIsOn('E07');
    if (!recipes && !plan) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      spacing: 8,
      children: [
        if (recipes)
          AppListItem(
            key: const ValueKey('eat-hub-open-recipes'),
            leading: const Icon(
              Icons.menu_book,
              size: 23,
              color: AppColors.primaryDim,
            ),
            title: l10n.recipes,
            subtitle: l10n.egyptianDishesWithPortionsAndCostPer,
            trailing: const Icon(
              Icons.chevron_right,
              size: 22,
              color: AppColors.onSurfaceVariant,
            ),
            onTap: () => _select(EatHubSegment.recipes),
          ),
        if (plan)
          AppListItem(
            key: const ValueKey('eat-hub-open-plan'),
            leading: const Icon(
              Icons.calendar_view_week,
              size: 23,
              color: AppColors.primaryDim,
            ),
            title: l10n.plan,
            subtitle: l10n.fiveEgyptianDinnersAndOneShoppingList,
            trailing: const Icon(
              Icons.chevron_right,
              size: 22,
              color: AppColors.onSurfaceVariant,
            ),
            onTap: () => _select(EatHubSegment.plan),
          ),
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

  List<Widget> _content(AppL10n l10n, EatHubSegment segment) {
    final inLog = segment == EatHubSegment.log;
    final finding = inLog && _finding;

    return [
      _kept(
        const ValueKey('eat-hub-day'),
        inLog && !finding,
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
          onLogged: _logged,
          onBlocked: widget.onBlocked,
          requireAccount: widget.requireAccount,
          below: _moreRows(l10n),
        ),
      ),
      if (finding)
        Padding(
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
        ),
      // The microphone sits under the list, not in the field, so the field
      // keeps its X and the camera.
      if (finding &&
          _text.text.trim().isEmpty &&
          widget.onSpeak != null &&
          AppRouter.screenIsOn('E03'))
        Padding(
          padding: const EdgeInsets.only(top: kStackGap),
          child: AppListItem(
            key: const ValueKey('eat-hub-mic'),
            leading: const Icon(
              Icons.mic,
              size: 23,
              color: AppColors.primaryDim,
            ),
            title: l10n.sayOrTypeWhatYouAte,
            onTap: widget.onSpeak,
          ),
        ),
      if (_visited.contains(EatHubSegment.recipes) &&
          AppRouter.screenIsOn('E05'))
        _kept(
          const ValueKey('eat-hub-recipes'),
          segment == EatHubSegment.recipes,
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
          segment == EatHubSegment.plan,
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
        ?widget.coachSection,
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
