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

import '../../../domain/format/number_label.dart';
import '../../../domain/logging/log_command_bus.dart';
import '../../../l10n/app_l10n.dart';
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
import 'meal_log_session.dart';
import 'type_it_view_model.dart';

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
    this.onAllFoods,
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

  /// "Or one you've had before".
  final List<ParsedItem> history;

  final VoidCallback? onClose;
  final VoidCallback? onSpeak;
  final VoidCallback? onAllFoods;
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

  DateTime get _now => widget.now ?? DateTime.now();

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
        describe: l10n.foodLogged,
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
        describe: l10n.foodLogged,
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
          l10n.logIt,
          onPressed: state.canLog ? () => _log(state.items) : null,
        ),
      ],
      children: [
        AppField(
          controller: _controller,
          onChanged: _onChanged,
          hint: l10n.sayOrTypeWhatYouAte,
          trailing: IconButton(
            onPressed: widget.onSpeak,
            tooltip: l10n.weNeedTheMicrophoneToHearWhat,
            iconSize: 22,
            color: AppColors.primaryDim,
            icon: const Icon(Icons.mic),
          ),
        ),
        if (state.items.isNotEmpty)
          Text(
            l10n.wellLog,
            style: AppText.titleS.copyWith(color: AppColors.tertiary),
          ),
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
        if (state.history.isNotEmpty) ...[
          // What she typed above the rule, what she has eaten before below it.
          const HandRule(seed: 17, height: 8),
          Text(
            l10n.orOneYouveHadBefore,
            style: AppText.titleS.copyWith(color: AppColors.onSurfaceVariant),
          ),
          for (final entry in state.history)
            MealRow(
              title: entry.food.names.first,
              // Her plate's own figure. `yourPlate600Kcal` — "Your plate ·
              // 600 kcal" — read 600 for every row in the list, whatever she
              // had eaten before.
              meta: l10n.kcalKcal(countLabel(entry.kcal)),
              logLabel: l10n.log,
              onLog: () => _log([entry]),
            ),
        ],
        AppButton(
          l10n.allFoods4100InTheList,
          variant: AppButtonVariant.text,
          height: 40,
          fontSize: 15,
          onPressed: widget.onAllFoods,
        ),
      ],
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
