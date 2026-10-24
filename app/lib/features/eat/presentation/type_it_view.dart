/// E02 — Type it.
///
/// Matches `6-v2/src/screens-eat.mjs` → `E02`. **Search and describing a meal
/// are the same box.** She types a sentence; it becomes rows with the sizes
/// already picked, and the sizes are chips *on* the row so she never opens a
/// food to fix one.
///
/// Everything here resolves against the local pack, so it works with the radio
/// off — E02 issues **zero** reads and zero network calls (§2).
///
/// ## What an unmatched fragment does
///
/// It becomes a visible chip and nothing else. §2 rule 10: the parser can only
/// emit a `foodId` that exists in the pack and a quantity from that food's own
/// `sizes[]`. A wrong guess in a food log is silent — she would see a plausible
/// dish, tap Log, and never find out her day was wrong — so the product says it
/// did not understand instead.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app_state/eat_state.dart' show EatAppState;
import '../../../app_state/guest_session.dart';
import '../../../app_state/haptics.dart';
import '../../../domain/clock/app_clock.dart';
import '../../../domain/format/number_label.dart';
import '../../../domain/logging/log_command_bus.dart';
import '../../../l10n/app_l10n.dart';
import '../../../routing/app_router.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_field.dart';
import '../../../ui/app_list_item.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/app_segmented.dart';
import '../../../ui/app_undo_snackbar.dart';
import '../../../ui/hand/hand.dart';
import '../domain/allergy_guard.dart';
import '../domain/daily_targets.dart';
import '../domain/food_library.dart';
import '../domain/meal_log_service.dart';
import '../domain/meal_repository.dart';
import '../domain/meal_sentence_parser.dart';
import 'eat_day_view_model.dart';
import 'eat_sample_library.dart';
import 'eat_widgets.dart';
import 'food_portion_sheet.dart';
import 'meal_log_session.dart';
import 'meal_result_card.dart';
import 'quick_custom_sheet.dart';
import 'slot_picks.dart';
import 'type_it_view_model.dart';
import 'meal_labels.dart';

class TypeItView extends StatefulWidget {
  const TypeItView({
    super.key,
    required this.constraints,
    this.repository,
    this.bus,
    this.session,
    this.library,
    this.now,
    this.initialText,
    this.slot,
    this.targets,
    this.history = const <ParsedItem>[],
    this.frequent = const <ParsedItem>[],
    this.onClose,
    this.onSpeak,
    this.onSnap,
    this.onLogged,
    this.onBlocked,
    this.requireAccount,
    this.embedded = false,
    this.controller,
    this.fieldFocus,
  });

  /// Drawn inside the Eat hub, under its search bar: only the results and the
  /// rows, with no scaffold, text field or footer. The hub owns the text
  /// ([controller]) and the focus ([fieldFocus]); this reads them.
  final bool embedded;

  /// The hub's search text. Used only when [embedded]; this screen listens to it
  /// and never disposes it.
  final TextEditingController? controller;

  /// The hub's search field focus, so "Edit" on the result card returns to it.
  final FocusNode? fieldFocus;

  /// See `EatView.constraints` — required, never defaulted.
  final DietaryConstraints constraints;

  final MealRepository? repository;
  final LogCommandBus? bus;

  /// The Eat tab's shared five seconds — see `EatView.session`. Supplied, the
  /// meal this screen logs is visible on the screen she lands on next, which is
  /// the whole of E02 → E04.
  final MealLogSession? session;

  final FoodLibrary? library;
  final DateTime? now;

  /// The prototype draws the box already holding "koshari and 2 eggs". Null
  /// leaves it empty, which is what a woman actually opens.
  final String? initialText;

  /// The meal she is logging into. Null follows the session's preset (the Log
  /// pill on E01), else the hour.
  final MealSlot? slot;

  /// Her day's targets, for the "Impact on today" rings on the portion sheet.
  /// Null hides the rings.
  final DailyTargets? targets;

  /// Plates she has eaten before, listed first in the results as "You've had".
  final List<ParsedItem> history;

  /// The same foods, most eaten first, for the Frequent tab. Each at the
  /// portion she last had.
  final List<ParsedItem> frequent;

  final VoidCallback? onClose;
  final VoidCallback? onSpeak;

  /// E12, a photo of her plate instead of typing it. Null hides the camera;
  /// the router passes it only while E12 is on and she is verified.
  final VoidCallback? onSnap;
  final ValueChanged<LogHandle>? onLogged;

  /// A log the domain refused. Unwired today — the allergen sheet's three
  /// strings are absent from the dictionary, so there is nothing to render.
  final ValueChanged<MealLogRefused>? onBlocked;

  /// Asked before a meal is logged or a food starred: false means she is a
  /// guest and has been taken to sign in, so nothing is saved. The router
  /// passes the guest gate; absent, everything is allowed.
  final bool Function(BuildContext context, PendingAction action)?
  requireAccount;

  @override
  State<TypeItView> createState() => _TypeItViewState();
}

class _TypeItViewState extends State<TypeItView> {
  late final TextEditingController _controller;
  late final bool _ownsController;
  String _heardText = '';
  late final MealRepository _repo;
  late final LogCommandBus _bus;
  late final bool _ownsRepo;
  late final bool _ownsBus;

  /// The parse for what is currently in the box.
  ///
  /// Held separately from the controller because it has to be able to diverge
  /// from it: removing a row must not re-parse the sentence and bring that row
  /// straight back.
  TypeItState? _state;

  /// Her starred foods and the foods she typed in, read when the screen opens
  /// and again after each change.
  EatPrefs _prefs = const EatPrefs();

  /// The tab under the empty box: 0 Recent, 1 Frequent, 2 Favourites.
  int _tab = 0;

  /// The shelf she narrowed the list to, or null for All. It combines with what
  /// she has typed: the words search inside the shelf.
  FoodCategory? _category;

  late final bool _ownsFocus = !widget.embedded || widget.fieldFocus == null;
  late final FocusNode _fieldFocus = _ownsFocus
      ? FocusNode()
      : widget.fieldFocus!;

  /// The meal a Log pill on E01 named, read once when the screen opens.
  MealSlot? _preset;

  DateTime get _now => widget.now ?? AppClock.now();

  MealSlot get _slot => _preset ?? EatDayViewModel.slotAt(_now);

  /// Whether saying a meal is on in this build (`E03`).
  bool get _voice => widget.onSpeak != null && AppRouter.screenIsOn('E03');

  @override
  void initState() {
    super.initState();
    _ownsController = !widget.embedded || widget.controller == null;
    _controller = _ownsController
        ? TextEditingController(text: widget.initialText ?? '')
        : widget.controller!;
    _heardText = _controller.text;
    if (!_ownsController) _controller.addListener(_heard);
    if (widget.embedded) widget.session?.addListener(_sessionChanged);
    _preset = widget.slot;
    _ownsRepo = widget.repository == null;
    _repo = widget.repository ?? InMemoryMealRepository();
    _ownsBus = widget.bus == null && widget.session == null;
    _bus = widget.bus ?? widget.session?.bus ?? LogCommandBus();
    // The hub chooses the meal itself; the session's preset belongs to E02.
    if (!widget.embedded) _preset ??= widget.session?.takeLogSlot();
    unawaited(_loadPrefs());
  }

  /// Inside the hub the page stays open while she logs, so her usual picks are
  /// read again whenever a meal is written or taken back.
  void _sessionChanged() {
    if (mounted) unawaited(_loadPrefs());
  }

  /// The hub's box changed: parse what is in it. Selection moves alone do not.
  void _heard() {
    final text = _controller.text;
    if (text == _heardText || !mounted) return;
    _heardText = text;
    _onChanged(text);
  }

  @override
  void didUpdateWidget(TypeItView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.embedded && widget.slot != oldWidget.slot) {
      _preset = widget.slot;
    }
    // The held parse carries the plates she has had. With nothing typed there
    // is nothing of hers to keep, so a changed list is simply read again.
    if (_state != null &&
        _controller.text.trim().isEmpty &&
        !_sameEntries(widget.history, oldWidget.history)) {
      _state = null;
    }
  }

  Future<void> _loadPrefs() async {
    final prefs = await _repo.prefs();
    if (mounted) setState(() => _prefs = prefs);
  }

  static bool _sameEntries(List<ParsedItem> a, List<ParsedItem> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].food.foodId != b[i].food.foodId ||
          a[i].size.id != b[i].size.id ||
          a[i].servings != b[i].servings) {
        return false;
      }
    }
    return true;
  }

  @override
  void dispose() {
    if (widget.embedded) widget.session?.removeListener(_sessionChanged);
    if (_ownsController) {
      _controller.dispose();
    } else {
      _controller.removeListener(_heard);
    }
    if (_ownsFocus) _fieldFocus.dispose();
    if (_ownsBus) unawaited(_bus.flushAll());
    if (_ownsRepo) unawaited(_repo.dispose());
    super.dispose();
  }

  FoodLibrary _library(AppL10n l10n) => withCustomFoods(
    widget.library ?? eatSampleLibrary(l10n),
    _prefs.customFoods,
  );

  TypeItViewModel _model(AppL10n l10n) => TypeItViewModel(
    parser: MealSentenceParser(_library(l10n)),
    guard: AllergyGuard(widget.constraints),
    history: widget.history,
  );

  TypeItState _current(AppL10n l10n) {
    final held = _state;
    if (held != null) return held;
    return _model(l10n).build(_controller.text);
  }

  void _onChanged(String text) {
    final l10n = AppL10n.of(context);
    setState(() => _state = _model(l10n).build(text));
  }

  void _resize(int index, FoodSize size) {
    final l10n = AppL10n.of(context);
    setState(() => _state = _model(l10n).resize(_current(l10n), index, size));
  }

  void _remove(int index) {
    final l10n = AppL10n.of(context);
    setState(() => _state = _model(l10n).remove(_current(l10n), index));
  }

  /// The **one** undo offer for one log (§2 rule 9).
  ///
  /// When [TypeItView.onLogged] is wired the handle travels on to E04, which
  /// draws the in-page `AppUndoBar` for it. Raising a floating snackbar here as
  /// well put two offers for the same meal on screen, and the one she reached
  /// second had already expired. Without that handler nothing downstream would
  /// offer the five seconds, so the snackbar stands in.
  void _offerUndo(LogHandle handle, {VoidCallback? onUndo}) {
    unawaited(AppHaptics.play(HapticMoment.actionDone));
    if (widget.onLogged != null) return;
    showUndoSnackBar(
      context,
      handle: handle,
      undoLabel: AppL10n.of(context).undo,
      onUndo: onUndo,
    );
  }

  void _log(List<ParsedItem> entries) {
    final gate = widget.requireAccount;
    if (gate != null &&
        !gate(
          context,
          PendingAction.logMeal(entries, origin: MealOrigin.search),
        )) {
      return;
    }
    final l10n = AppL10n.of(context);
    final service = MealLogService(
      repository: _repo,
      library: _library(l10n),
      guard: AllergyGuard(widget.constraints),
    );

    final slot = _slot;
    final outcome = service.logNew(
      day: MealDay(dayId: _dayIdOf(_now)),
      slot: slot,
      entries: entries,
      source: MealSource.search,
      origin: MealOrigin.search,
      at: _now,
    );

    if (outcome is MealLogRefused) {
      widget.onBlocked?.call(outcome);
      return;
    }

    final prepared = outcome as MealLogPrepared;
    final session = widget.session;
    if (session != null) {
      // Into the tab's own five seconds, so E04 draws this meal the moment it
      // opens rather than five seconds later.
      final handle = session.submit(
        prepared,
        slot: slot,
        describe: mealAddedLabel(
          l10n,
          mealFoodNames(_library(l10n), prepared.items),
          slot,
        ),
      );
      _offerUndo(handle, onUndo: session.settle);
      widget.onLogged?.call(handle);
      return;
    }

    final handle = _bus.submit(
      UndoableLog(
        // The dictionary's "Lunch logged · 696 kcal" is a FIXED string with no
        // placeholder, so using it would announce 696 kcal whatever she logged —
        // the defect PHASE1-FIXES §8 records on R07's button. Until a
        // parameterised key exists, the sentence that says less is the honest
        // one.
        describe: mealAddedLabel(
          l10n,
          mealFoodNames(_library(l10n), prepared.items),
          slot,
        ),
        commit: () => service.commit(prepared.write),
      ),
    );
    _offerUndo(handle);
    widget.onLogged?.call(handle);
  }

  static String _dayIdOf(DateTime at) =>
      '${at.year.toString().padLeft(4, '0')}-'
      '${at.month.toString().padLeft(2, '0')}-'
      '${at.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final state = _current(l10n);

    final single = !_isSentence(state) || state.items.isEmpty || !state.canLog;
    final body = <Widget>[
      if (widget.embedded)
        // The footer's job, at the head of the list where the hub's tall
        // header and the keyboard cannot cover it.
        if (state.canLog && single && _controller.text.trim().isNotEmpty)
          AppButton(
            key: const ValueKey('type-it-add'),
            l10n.addIt,
            onPressed: () => _log(state.items),
          ),
      // Browsing one shelf keeps its chips at the head so she can leave it; the
      // rest of the time they close the list, below the rows she came for.
      if (_category != null) _categoryChips(),
      if (_isSentence(state))
        Text(
          l10n.wellAdd,
          style: AppText.titleS.copyWith(color: AppColors.tertiary),
        ),
      if (_isSentence(state) && state.items.isNotEmpty)
        MealResultCard(
          items: state.items,
          onYes: state.canLog ? () => _log(state.items) : null,
          onEdit: _fieldFocus.requestFocus,
        ),
      if (_isSentence(state))
        for (var i = 0; i < state.items.length; i++)
          ParsedRow(
            name: state.items[i].food.names.first,
            meta: _metaFor(l10n, state.items[i]),
            sizeLabels: [
              for (final size in state.items[i].food.sizes) size.label,
            ],
            selectedSize: state.items[i].food.sizes.indexWhere(
              (s) => s.id == state.items[i].size.id,
            ),
            onPickSize: (index) => _resize(i, state.items[i].food.sizes[index]),
            onRemove: () => _remove(i),
            removeTooltip: l10n.edit,
            imageAsset: state.items[i].food.imageAsset,
          ),
      // An unmatched fragment stays visible. Never dropped, never guessed.
      if (state.hasUnresolved)
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            // Her words in a dashed pencil box: space still waiting for a
            // food, which is exactly what an unmatched fragment is.
            for (final fragment in state.unresolved)
              HandSurface(
                seed: handSeed(['unresolved', fragment.text]),
                frame: AppColors.outline,
                dashed: true,
                radius: 4,
                looseCorner: 12,
                child: Chip(
                  label: Text(fragment.text, style: AppText.bodyM),
                  backgroundColor: Colors.transparent,
                  side: BorderSide.none,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
          ],
        ),
      ..._results(l10n, state),
    ];

    if (widget.embedded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        spacing: kStackGap,
        children: body,
      );
    }

    return AppScaffold(
      // E02 sits over Eat rather than after it, so it closes rather than
      // going back.
      appBar: AppTopBar(onBack: widget.onClose, leadingIcon: Icons.close),
      footer: [
        // The result card's Yes is the one save action for a sentence.
        if (!(_isSentence(state) && state.items.isNotEmpty && state.canLog))
          AppButton(
            // Names the action and nothing else.
            //
            // This was `logBoth696Kcal` — "Log both · 696 kcal" — which is the
            // total of the prototype's koshari-and-two-eggs sentence. It stated
            // that total to a woman logging one apple, and it said "both" when
            // there was one row or five. The rows above state the numbers, each
            // from its own selected size.
            l10n.addIt,
            onPressed: state.canLog ? () => _log(state.items) : null,
          ),
      ],
      children: [
        AppField(
          controller: _controller,
          focusNode: _fieldFocus,
          onChanged: _onChanged,
          // No microphone while saying a meal is off in this build
          // (`Feature.voiceLogging`): there is nothing to hear her with.
          hint: _voice ? l10n.sayOrTypeWhatYouAte : l10n.typeWhatYouAte,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_voice)
                IconButton(
                  onPressed: widget.onSpeak,
                  tooltip: l10n.weNeedTheMicrophoneToHearWhat,
                  iconSize: 22,
                  color: AppColors.primaryDim,
                  icon: const Icon(Icons.mic),
                ),
              if (widget.onSnap case final snap?)
                IconButton(
                  key: const ValueKey('type-it-snap-meal'),
                  onPressed: snap,
                  tooltip: l10n.snapYourMeal,
                  iconSize: 22,
                  color: AppColors.primaryDim,
                  icon: const Icon(Icons.photo_camera_outlined),
                ),
            ],
          ),
        ),
        ...body,
      ],
    );
  }

  Widget _categoryChips() => FoodCategoryChips(
    key: const ValueKey('type-it-categories'),
    selected: _category,
    onChanged: (category) => setState(() => _category = category),
  );

  /// Opens the portion sheet for a food and logs what she picked.
  Future<void> _pick(Food food, {FoodSize? size, int servings = 1}) async {
    final l10n = AppL10n.of(context);
    final item = await showFoodPortionSheet(
      context: context,
      food: food,
      containsNote: containsNoteFor(
        l10n,
        AllergyGuard(widget.constraints),
        food,
      ),
      initialSize: size,
      initialServings: servings,
      targets: widget.targets,
      isFavourite: _prefs.favourites.contains(food.foodId),
      onToggleFavourite: () async {
        final gate = widget.requireAccount;
        if (gate != null &&
            !gate(context, PendingAction.favourite(food.foodId))) {
          return _prefs.favourites.contains(food.foodId);
        }
        final now = await EatAppState.instance.toggleFavourite(
          _repo,
          food.foodId,
        );
        await _loadPrefs();
        return now;
      },
    );
    if (item == null || !mounted) return;
    _log([item]);
  }

  /// Quick custom: keeps the food and logs one serving of it.
  Future<void> _quickCustom({String name = ''}) async {
    final entry = await showQuickCustomSheet(
      context: context,
      initialName: name,
    );
    if (entry == null || !mounted) return;
    final food = await EatAppState.instance.addCustomFood(
      _repo,
      name: entry.name,
      kcal: entry.kcal,
      proteinG: entry.proteinG,
      carbsG: entry.carbsG,
      fatG: entry.fatG,
      fiberG: entry.fiberG,
    );
    await _loadPrefs();
    if (!mounted) return;
    final served = food.toFood();
    _log([
      ParsedItem(
        food: served,
        size: served.defaultSize,
        servings: 1,
        sourceText: served.names.first,
      ),
    ]);
  }

  /// A sentence naming several foods, or one with a part nothing matched, is
  /// shown as rows with their sizes. One food is shown as a result to tap; the
  /// footer's Add it still logs it at its usual size.
  bool _isSentence(TypeItState state) =>
      state.items.length > 1 || (state.items.isNotEmpty && state.hasUnresolved);

  /// Live results under the box: what she has eaten before, then the pack.
  ///
  /// A sentence naming several foods is already rows above, so it gets no
  /// results of its own. Foods she typed are shown whatever they hold, with a
  /// note where an allergen is known, because logging never blocks on one.
  List<Widget> _results(AppL10n l10n, TypeItState state) {
    final query = _controller.text.trim();
    if (state.items.length > 1) return const <Widget>[];
    final listed = _isSentence(state) ? state.items : const <ParsedItem>[];

    final library = _library(l10n);
    final needle = query.toLowerCase();
    final guard = AllergyGuard(widget.constraints);
    final shown = <String>{for (final item in listed) item.food.foodId};

    final shelf = _category;
    final had = query.isEmpty || shelf != null
        ? const <ParsedItem>[]
        : <ParsedItem>[
            for (final entry in state.history)
              if (entry.food.names.any((n) => n.toLowerCase().contains(needle)))
                if (shown.add('had:${entry.food.foodId}:${entry.size.id}'))
                  entry,
          ].take(5).toList();

    final Iterable<Food> candidates;
    if (shelf != null) {
      candidates = query.isEmpty
          ? guard.screenSuggestions([
              for (final food in library.foods)
                if (food.category == shelf) food,
            ])
          : library.resolve(query).where((food) => food.category == shelf);
    } else {
      candidates = query.isEmpty
          ? guard.screenSuggestions(library.mostPopular(24)).take(8)
          : library.resolve(query);
    }
    final unlisted = <Food>[
      for (final food in candidates)
        if (!listed.any((i) => i.food.foodId == food.foodId) &&
            !had.any((h) => h.food.foodId == food.foodId))
          food,
    ];
    // Browsing a shelf lists all of it; typing, or the opening picks, stop short.
    final foods = shelf != null && query.isEmpty
        ? unlisted
        : unlisted.take(12).toList();

    // The Recent tab sits right below the picks; a food listed there is not
    // offered twice.
    final recentIds = _tab == 0
        ? {for (final e in state.history.take(10)) e.food.foodId}
        : const <String>{};
    final picks = query.isEmpty && shelf == null
        ? [
            for (final pick in slotPicks(
              prefs: _prefs,
              library: library,
              guard: guard,
              slot: _slot,
            ))
              if (!recentIds.contains(pick.food.foodId)) pick,
          ]
        : const <ParsedItem>[];

    return [
      if (query.isEmpty && shelf == null)
        ..._emptyBox(l10n, state, guard, library),
      if (picks.isNotEmpty)
        SlotPicksRow(slot: _slot, picks: picks, onAdd: (pick) => _log([pick])),
      if (had.isNotEmpty) ...[
        Text(
          l10n.youveHad,
          style: AppText.titleS.copyWith(color: AppColors.onSurfaceVariant),
        ),
        for (final entry in had) _entryRow(l10n, guard, entry, 'had'),
      ],
      if (foods.isNotEmpty) ...[
        if (query.isEmpty && shelf == null)
          Text(
            l10n.popularDishes,
            style: AppText.titleS.copyWith(color: AppColors.onSurfaceVariant),
          ),
        for (final food in foods)
          FoodResultRow(
            key: ValueKey('result-${food.foodId}'),
            title: food.names.first,
            meta: _metaFor(
              l10n,
              ParsedItem(
                food: food,
                size: food.defaultSize,
                servings: 1,
                sourceText: food.names.first,
              ),
            ),
            addLabel: l10n.addName(food.names.first),
            note: containsNoteFor(l10n, guard, food),
            onTap: () => _pick(food),
          ),
        if (query.isEmpty && shelf == null)
          AppButton(
            key: const ValueKey('type-it-show-egyptian'),
            l10n.showAllEgyptianDishes,
            variant: AppButtonVariant.outlined,
            height: 48,
            fontSize: 16,
            onPressed: () =>
                setState(() => _category = FoodCategory.egyptianDishes),
          ),
      ],
      if (_category == null) _categoryChips(),
    ];
  }

  /// One food at a portion, with a "+" that logs exactly that portion.
  Widget _entryRow(
    AppL10n l10n,
    AllergyGuard guard,
    ParsedItem entry,
    String keyPrefix,
  ) {
    return FoodResultRow(
      key: ValueKey('$keyPrefix-${entry.food.foodId}-${entry.size.id}'),
      title: entry.food.names.first,
      meta: _metaFor(l10n, entry),
      addLabel: l10n.addName(entry.food.names.first),
      note: containsNoteFor(l10n, guard, entry.food),
      onTap: () =>
          _pick(entry.food, size: entry.size, servings: entry.servings),
      onAdd: () => _log([entry]),
    );
  }

  /// What the empty box offers: Recent, Frequent and Favourites, each row a
  /// food at the portion she last had it, and Quick custom above them.
  List<Widget> _emptyBox(
    AppL10n l10n,
    TypeItState state,
    AllergyGuard guard,
    FoodLibrary library,
  ) {
    final history = state.history;
    final allowed = guard
        .screenSuggestions([
          for (final entry in widget.frequent) entry.food,
          for (final id in _prefs.favourites) ?library.byId(id),
        ])
        .map((food) => food.foodId)
        .toSet();

    final rows = switch (_tab) {
      0 => history.take(10).toList(),
      1 => [
        for (final entry in widget.frequent)
          if (allowed.contains(entry.food.foodId)) entry,
      ].take(10).toList(),
      _ => [
        for (final id in _prefs.favourites)
          if (library.byId(id) case final food?)
            if (allowed.contains(food.foodId)) _lastPortion(history, food),
      ],
    };
    final prefix = const ['had', 'frequent', 'favourite'][_tab];

    return [
      AppSegmented(
        key: const ValueKey('eat-quick-tabs'),
        items: [l10n.recent, l10n.frequent, l10n.favourites],
        selectedIndex: _tab,
        onChanged: (index) => setState(() => _tab = index),
      ),
      AppListItem(
        key: const ValueKey('quick-custom-row'),
        leading: const Icon(
          Icons.edit_note,
          size: 23,
          color: AppColors.primaryDim,
        ),
        title: l10n.quickCustom,
        subtitle: l10n.typeANameAndTheNumbersOff,
        onTap: _quickCustom,
      ),
      if (rows.isEmpty)
        Text(
          _tab == 2 ? l10n.tapTheStarOnAFoodTo : l10n.foodsYouLogShowUpHere,
          key: const ValueKey('eat-quick-empty'),
          style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
        )
      else
        for (final entry in rows) _entryRow(l10n, guard, entry, prefix),
    ];
  }

  /// [food] at the portion she last logged it in, else its usual one.
  ParsedItem _lastPortion(List<ParsedItem> history, Food food) {
    for (final entry in history) {
      if (entry.food.foodId == food.foodId) return entry;
    }
    return ParsedItem(
      food: food,
      size: food.defaultSize,
      servings: 1,
      sourceText: food.names.first,
    );
  }

  /// The row's macros, computed from the size and servings she has selected.
  ///
  /// This was a four-case switch on `foodId` with `_ => n540Kcal18GProtein`, so
  /// it had the same defect `EatView._metaOf` records one screen earlier: two
  /// boiled eggs — 156 kcal and 13 g — were reported as koshari's 540 and 18,
  /// and so was every food outside the switch. It was also blind to the size
  /// chips sitting on the very row it describes: tapping "Large" moved what got
  /// written and left this line saying Medium's figures.
  ///
  /// [ParsedItem.kcal] and [ParsedItem.proteinG] already multiply the selected
  /// size by the servings, so the line and the write cannot disagree.
  /// `countLabel` keeps the digits Western under `ar`.
  String _metaFor(AppL10n l10n, ParsedItem item) =>
      l10n.kcalKcalProteinGProtein(
        countLabel(item.kcal),
        countLabel(item.proteinG),
      );
}
