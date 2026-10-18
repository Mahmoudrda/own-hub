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

import '../../../app_state/haptics.dart';
import '../../../domain/clock/app_clock.dart';
import '../../../domain/format/number_label.dart';
import '../../../domain/logging/log_command_bus.dart';
import '../../../l10n/app_l10n.dart';
import '../../../routing/app_router.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_field.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/app_undo_snackbar.dart';
import '../../../ui/hand/hand.dart';
import '../domain/allergy_guard.dart';
import '../domain/food_library.dart';
import '../domain/meal_log_service.dart';
import '../domain/meal_repository.dart';
import '../domain/meal_sentence_parser.dart';
import 'eat_day_view_model.dart';
import 'eat_sample_library.dart';
import 'eat_widgets.dart';
import 'food_portion_sheet.dart';
import 'meal_log_session.dart';
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
    this.history = const <ParsedItem>[],
    this.onClose,
    this.onSpeak,
    this.onSnap,
    this.onLogged,
    this.onBlocked,
  });

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

  /// Plates she has eaten before, listed first in the results as "You've had".
  final List<ParsedItem> history;

  final VoidCallback? onClose;
  final VoidCallback? onSpeak;

  /// E12, a photo of her plate instead of typing it. Null hides the camera;
  /// the router passes it only while E12 is on and she is verified.
  final VoidCallback? onSnap;
  final ValueChanged<LogHandle>? onLogged;

  /// A log the domain refused. Unwired today — the allergen sheet's three
  /// strings are absent from the dictionary, so there is nothing to render.
  final ValueChanged<MealLogRefused>? onBlocked;

  @override
  State<TypeItView> createState() => _TypeItViewState();
}

class _TypeItViewState extends State<TypeItView> {
  late final TextEditingController _controller;
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

  DateTime get _now => widget.now ?? AppClock.now();

  /// Whether saying a meal is on in this build (`E03`).
  bool get _voice => widget.onSpeak != null && AppRouter.screenIsOn('E03');

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText ?? '');
    _ownsRepo = widget.repository == null;
    _repo = widget.repository ?? InMemoryMealRepository();
    _ownsBus = widget.bus == null && widget.session == null;
    _bus = widget.bus ?? widget.session?.bus ?? LogCommandBus();
  }

  @override
  void dispose() {
    _controller.dispose();
    if (_ownsBus) unawaited(_bus.flushAll());
    if (_ownsRepo) unawaited(_repo.dispose());
    super.dispose();
  }

  FoodLibrary _library(AppL10n l10n) =>
      widget.library ?? eatSampleLibrary(l10n);

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
    final l10n = AppL10n.of(context);
    final service = MealLogService(
      repository: _repo,
      library: _library(l10n),
      guard: AllergyGuard(widget.constraints),
    );

    final slot = EatDayViewModel.slotAt(_now);
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

    return AppScaffold(
      // E02 sits over Eat rather than after it, so it closes rather than
      // going back.
      appBar: AppTopBar(onBack: widget.onClose, leadingIcon: Icons.close),
      footer: [
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
          onChanged: _onChanged,
          // No microphone while saying a meal is off in this build
          // (`Feature.voiceLogging`): there is nothing to hear her with.
          hint: _voice ? l10n.sayOrTypeWhatYouAte : l10n.typeWhatYouAte,
          trailing: _voice || widget.onSnap != null
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.onSnap case final snap?)
                      IconButton(
                        key: const ValueKey('type-it-snap-meal'),
                        onPressed: snap,
                        tooltip: l10n.snapYourMeal,
                        iconSize: 22,
                        color: AppColors.primaryDim,
                        icon: const Icon(Icons.photo_camera_outlined),
                      ),
                    if (_voice)
                      IconButton(
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
        if (_isSentence(state))
          Text(
            l10n.wellAdd,
            style: AppText.titleS.copyWith(color: AppColors.tertiary),
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
              onPickSize: (index) =>
                  _resize(i, state.items[i].food.sizes[index]),
              onRemove: () => _remove(i),
              removeTooltip: l10n.edit,
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
      ],
    );
  }

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
    );
    if (item == null || !mounted) return;
    _log([item]);
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

    final had = <ParsedItem>[
      for (final entry in state.history)
        if (needle.isEmpty ||
            entry.food.names.any((n) => n.toLowerCase().contains(needle)))
          if (shown.add('had:${entry.food.foodId}:${entry.size.id}')) entry,
    ].take(5).toList();

    final foods = <Food>[
      for (final food
          in query.isEmpty
              ? guard.screenSuggestions(library.mostPopular(24)).take(8)
              : library.resolve(query))
        if (!listed.any((i) => i.food.foodId == food.foodId) &&
            !had.any((h) => h.food.foodId == food.foodId))
          food,
    ].take(12).toList();

    return [
      if (had.isNotEmpty) ...[
        Text(
          l10n.youveHad,
          style: AppText.titleS.copyWith(color: AppColors.onSurfaceVariant),
        ),
        for (final entry in had)
          FoodResultRow(
            key: ValueKey('had-${entry.food.foodId}-${entry.size.id}'),
            title: entry.food.names.first,
            meta: _metaFor(l10n, entry),
            addLabel: l10n.addName(entry.food.names.first),
            note: containsNoteFor(l10n, guard, entry.food),
            onTap: () =>
                _pick(entry.food, size: entry.size, servings: entry.servings),
            onAdd: () => _log([entry]),
          ),
      ],
      if (foods.isNotEmpty) ...[
        if (query.isEmpty)
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
      ],
    ];
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
