/// E13: Check your meal.
///
/// What the photo showed, as cards she can correct, and **nothing is logged
/// until she taps "Log this meal"**. Every change here is to a draft
/// ([MealCheck]); the one write goes through `MealLogService.logChecked` and
/// the same five-second undo bus as every other meal, so E04 opens after it
/// with its undo bar exactly as it does after typing a meal.
///
/// On each card: the name, the weight with steps of 10 g, and energy,
/// protein, carbs, fat and fibre. Changing the weight recomputes them from the
/// values per 100 g, live. "Edit numbers" lets her type any of them, and a
/// figure she typed is marked as hers. A food nothing was found for says so
/// and counts for nothing until she fills it in or removes it. A known dish
/// says it was estimated from a standard recipe and can show its parts.
///
/// One small line says these are estimates. No figure is red and none is a
/// target: the totals are what is on the plate, nothing more.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app_state/guest_session.dart';
import '../../../app_state/haptics.dart';
import '../../../domain/clock/app_clock.dart';
import '../../../domain/format/number_label.dart';
import '../../../domain/logging/log_command_bus.dart';
import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_chip_row.dart';
import '../../../ui/app_list_item.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/app_undo_snackbar.dart';
import '../domain/allergy_guard.dart';
import '../domain/food_library.dart';
import '../domain/meal_check.dart';
import '../domain/meal_log_service.dart';
import '../domain/meal_repository.dart';
import '../domain/meal_scan.dart';
import 'eat_day_view_model.dart';
import 'eat_sample_library.dart';
import 'eat_widgets.dart';
import 'meal_log_session.dart';
import 'meal_labels.dart';

class MealCheckView extends StatefulWidget {
  const MealCheckView({
    super.key,
    required this.result,
    required this.constraints,
    this.repository,
    this.session,
    this.bus,
    this.library,
    this.now,
    this.onLogged,
    this.onBlocked,
    this.onCancel,
    this.onSnap,
  });

  /// What the scan found. Null when E13 is opened with nothing to check.
  final MealScanResult? result;

  /// See `EatView.constraints`: required, never defaulted.
  final DietaryConstraints constraints;

  final MealRepository? repository;

  /// The Eat tab's shared five seconds, so E04 draws this meal at once.
  final MealLogSession? session;
  final LogCommandBus? bus;

  /// The food list "Add something" searches. Defaults to the sample library.
  final FoodLibrary? library;
  final DateTime? now;

  /// Carries the five-second window to E04.
  final ValueChanged<LogHandle>? onLogged;
  final ValueChanged<MealLogRefused>? onBlocked;

  /// Leaves without logging anything.
  final VoidCallback? onCancel;

  /// E12, offered only when there is nothing to check.
  final VoidCallback? onSnap;

  @override
  State<MealCheckView> createState() => _MealCheckViewState();
}

class _MealCheckViewState extends State<MealCheckView> {
  late MealCheck _check;
  late MealSlot _slot;
  late final MealRepository _repo;
  late final LogCommandBus _bus;
  late final bool _ownsRepo;
  late final bool _ownsBus;

  /// Cards whose figures are open for typing, and dishes showing their parts.
  final Set<String> _editing = <String>{};
  final Set<String> _expanded = <String>{};

  final Map<String, TextEditingController> _grams =
      <String, TextEditingController>{};
  final Map<String, TextEditingController> _figures =
      <String, TextEditingController>{};

  bool _adding = false;
  bool _logged = false;
  int _added = 0;
  final TextEditingController _query = TextEditingController();
  final TextEditingController _ownName = TextEditingController();
  final TextEditingController _ownGrams = TextEditingController();
  final Map<MacroKind, TextEditingController> _ownFigures = {
    for (final macro in MacroKind.values) macro: TextEditingController(),
  };

  DateTime get _now => widget.now ?? AppClock.now();

  @override
  void initState() {
    super.initState();
    final result = widget.result;
    _check = result == null ? MealCheck.empty : MealCheck.fromScan(result);
    _slot = EatDayViewModel.slotAt(_now);
    _ownsRepo = widget.repository == null;
    _repo = widget.repository ?? InMemoryMealRepository();
    _ownsBus = widget.bus == null && widget.session == null;
    _bus = widget.bus ?? widget.session?.bus ?? LogCommandBus();
  }

  @override
  void dispose() {
    for (final controller in [
      ..._grams.values,
      ..._figures.values,
      ..._ownFigures.values,
      _query,
      _ownName,
      _ownGrams,
    ]) {
      controller.dispose();
    }
    if (_ownsBus) unawaited(_bus.flushAll());
    if (_ownsRepo) unawaited(_repo.dispose());
    super.dispose();
  }

  FoodLibrary _library(AppL10n l10n) =>
      widget.library ?? eatSampleLibrary(l10n);

  String get _language => Localizations.localeOf(context).languageCode;

  // ------------------------------------------------------------- editing --

  int _indexOf(String key) => _check.items.indexWhere((i) => i.key == key);

  void _update(String key, CheckItem Function(CheckItem item) change) {
    final index = _indexOf(key);
    if (index < 0) return;
    setState(() => _check = _check.replace(index, change(_check.items[index])));
  }

  TextEditingController _gramsField(CheckItem item) => _grams.putIfAbsent(
    item.key,
    () => TextEditingController(text: _gramsText(item.grams)),
  );

  TextEditingController _figureField(CheckItem item, MacroKind macro) =>
      _figures.putIfAbsent(
        '${item.key}|${macro.name}',
        () => TextEditingController(text: item.value(macro)?.toString() ?? ''),
      );

  static String _gramsText(double? grams) =>
      grams == null ? '' : grams.round().toString();

  /// After a change of weight: the typed-in fields that are not hers follow
  /// the new figures, so an open "Edit numbers" never shows a stale one.
  void _followWeight(String key) {
    final index = _indexOf(key);
    if (index < 0) return;
    final item = _check.items[index];
    for (final macro in MacroKind.values) {
      if (item.isEdited(macro)) continue;
      final field = _figures['${item.key}|${macro.name}'];
      if (field == null) continue;
      field.text = item.value(macro)?.toString() ?? '';
    }
  }

  void _step(CheckItem item, int steps) {
    _update(item.key, (i) => i.stepGrams(steps));
    final index = _indexOf(item.key);
    if (index >= 0) {
      _gramsField(item).text = _gramsText(_check.items[index].grams);
    }
    _followWeight(item.key);
  }

  void _typedGrams(CheckItem item, String text) {
    final grams = parseWholeNumber(text);
    _update(item.key, (i) => i.withGrams((grams ?? 0).toDouble()));
    _followWeight(item.key);
  }

  void _typedFigure(CheckItem item, MacroKind macro, String text) {
    _update(item.key, (i) => i.withEdit(macro, parseWholeNumber(text)));
  }

  void _remove(CheckItem item) {
    final index = _indexOf(item.key);
    if (index < 0) return;
    setState(() {
      _check = _check.removeAt(index);
      _editing.remove(item.key);
      _expanded.remove(item.key);
    });
  }

  void _addFood(Food food) {
    setState(() {
      _check = _check.add(
        CheckItem.library('add-${_added++}', food, food.defaultSize),
      );
      _query.clear();
      _adding = false;
    });
  }

  bool get _ownReady =>
      _ownName.text.trim().isNotEmpty &&
      (parseWholeNumber(_ownGrams.text) ?? 0) > 0 &&
      parseWholeNumber(_ownFigures[MacroKind.kcal]!.text) != null &&
      parseWholeNumber(_ownFigures[MacroKind.protein]!.text) != null;

  void _addOwn() {
    if (!_ownReady) return;
    int? figure(MacroKind macro) => parseWholeNumber(_ownFigures[macro]!.text);
    setState(() {
      _check = _check.add(
        CheckItem.own(
          'add-${_added++}',
          name: _ownName.text.trim(),
          grams: parseWholeNumber(_ownGrams.text)!.toDouble(),
          kcal: figure(MacroKind.kcal),
          proteinG: figure(MacroKind.protein),
          carbsG: figure(MacroKind.carbs),
          fatG: figure(MacroKind.fat),
          fiberG: figure(MacroKind.fiber),
        ),
      );
      for (final field in [_ownName, _ownGrams, ..._ownFigures.values]) {
        field.clear();
      }
      _adding = false;
    });
  }

  // ------------------------------------------------------------- logging --

  /// The one write, and only from her tap.
  void _log() {
    if (_logged || !_check.canLog) return;
    // A checked photo meal is not replayed after sign-up (its figures were
    // read from the picture); she is asked to sign in first and logs it again.
    if (!GuestSession.require(context, const PendingAction(PendingKind.logMeal))) {
      return;
    }
    final l10n = AppL10n.of(context);
    final now = _now;
    final service = MealLogService(
      repository: _repo,
      library: _library(l10n),
      guard: AllergyGuard(widget.constraints),
    );
    final outcome = service.logChecked(
      day: MealDay(dayId: _dayIdOf(now)),
      slot: _slot,
      entries: _check.entries(_language),
      at: now,
    );
    if (outcome is MealLogRefused) {
      widget.onBlocked?.call(outcome);
      return;
    }
    final prepared = outcome as MealLogPrepared;
    _logged = true;
    unawaited(AppHaptics.play(HapticMoment.actionDone));

    final session = widget.session;
    final LogHandle handle;
    if (session != null) {
      handle = session.submit(
        prepared,
        slot: _slot,
        describe: mealAddedLabel(
          l10n,
          mealFoodNames(_library(l10n), prepared.items),
          _slot,
        ),
      );
    } else {
      handle = _bus.submit(
        UndoableLog(
          describe: mealAddedLabel(
            l10n,
            mealFoodNames(_library(l10n), prepared.items),
            _slot,
          ),
          commit: () => service.commit(prepared.write),
        ),
      );
    }
    final onLogged = widget.onLogged;
    if (onLogged != null) {
      onLogged(handle);
    } else {
      showUndoSnackBar(
        context,
        handle: handle,
        undoLabel: l10n.undo,
        onUndo: session?.settle,
      );
    }
  }

  static String _dayIdOf(DateTime at) =>
      '${at.year.toString().padLeft(4, '0')}-'
      '${at.month.toString().padLeft(2, '0')}-'
      '${at.day.toString().padLeft(2, '0')}';

  // --------------------------------------------------------------- build --

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final cold = widget.result == null;
    return PopScope(
      canPop: widget.onCancel == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) widget.onCancel?.call();
      },
      child: AppScaffold(
        appBar: AppTopBar(
          title: l10n.checkYourMeal,
          onBack: widget.onCancel,
          leadingIcon: Icons.close,
        ),
        footerScrollsWhenLarge: true,
        footer: cold ? _coldFooter(l10n) : _footer(l10n),
        children: cold ? _coldBody(l10n) : _body(l10n),
      ),
    );
  }

  List<Widget> _coldBody(AppL10n l10n) => [
    Text(l10n.nothingToCheckYetSnapYourMeal, style: AppText.body),
  ];

  List<Widget> _coldFooter(AppL10n l10n) => [
    if (widget.onSnap != null)
      AppButton(
        l10n.snapYourMeal,
        icon: Icons.photo_camera_outlined,
        onPressed: widget.onSnap,
      ),
    AppButton(
      l10n.cancel,
      variant: AppButtonVariant.text,
      height: 48,
      fontSize: 16,
      onPressed: widget.onCancel,
    ),
  ];

  List<Widget> _body(AppL10n l10n) => [
    // Said once, small, at the top.
    Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsetsDirectional.only(top: 2, end: 8),
          child: Icon(
            Icons.info_outline,
            size: 18,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        Expanded(
          child: Text(
            l10n.theseAreEstimatesCheckTheGrams,
            key: const ValueKey('meal-check-estimate'),
            style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
          ),
        ),
      ],
    ),
    // Why "Log this meal" is waiting, said where she can act on it.
    if (_check.incomplete > 0)
      Text(
        l10n.enterTheNumbersForEachItemOr,
        key: const ValueKey('meal-check-incomplete'),
        style: AppText.bodyM.copyWith(color: AppColors.onSurface),
      ),
    for (final item in _check.items) _card(l10n, item),
    if (_check.isEmpty)
      Text(l10n.nothingOnThisPlateYetAddSomething, style: AppText.body),
    ..._addSection(l10n),
    Text(l10n.whichMealIsIt, style: AppText.titleS),
    AppChipRow(
      items: [
        for (final slot in MealSlot.values) _slotName(l10n, slot),
      ],
      selected: {MealSlot.values.indexOf(_slot)},
      onTap: (index) => setState(() => _slot = MealSlot.values[index]),
    ),
  ];

  List<Widget> _footer(AppL10n l10n) {
    final totals = _check.totals;
    final more = moreMacrosLine(
      l10n,
      carbsG: totals.carbsG,
      fatG: totals.fatG,
      fiberG: totals.fiberG,
    );
    return [
      Semantics(
        container: true,
        liveRegion: true,
        child: Column(
          key: const ValueKey('meal-check-totals'),
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // One line for the meal, one for the rest, so the cards above
            // keep most of the page.
            Text(
              '${l10n.thisMeal} · '
              '${l10n.kcalKcal(countLabel(totals.kcal))} · '
              '${l10n.proteinGramsG(countLabel(totals.proteinG))}',
              style: AppText.titleS,
            ),
            if (more != null)
              Text(
                more,
                style: AppText.bodyM.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
      AppButton(
        l10n.logThisMeal,
        key: const ValueKey('meal-check-log'),
        onPressed: _check.canLog && !_logged ? _log : null,
      ),
      AppButton(
        l10n.cancel,
        key: const ValueKey('meal-check-cancel'),
        variant: AppButtonVariant.text,
        height: 48,
        fontSize: 16,
        onPressed: widget.onCancel,
      ),
    ];
  }

  // ---------------------------------------------------------------- card --

  Widget _card(AppL10n l10n, CheckItem item) {
    final name = item.nameFor(_language);
    final editing = _editing.contains(item.key);
    final note = switch (item.kind) {
      CheckItemKind.own => l10n.addedByYou,
      CheckItemKind.scanned when item.scanned!.isDish =>
        l10n.estimatedFromAStandardRecipe,
      _ => null,
    };
    return AppCard(
      key: ValueKey('meal-check-item-${item.key}'),
      gap: 10,
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 12),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(name, style: AppText.titleM),
                    if (note != null)
                      Text(
                        note,
                        style: AppText.bodyM.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            IconButton(
              key: ValueKey('meal-check-remove-${item.key}'),
              tooltip: l10n.removeName(name),
              onPressed: () => _remove(item),
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              icon: const Icon(
                Icons.close,
                size: 22,
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsetsDirectional.only(end: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: _cardBody(l10n, item, editing),
          ),
        ),
      ],
    );
  }

  List<Widget> _cardBody(AppL10n l10n, CheckItem item, bool editing) {
    final out = <Widget>[];
    if (item.hasGrams) {
      out.add(_gramsRow(l10n, item));
    } else {
      final food = item.food!;
      out.add(
        AppChipRow(
          items: [for (final size in food.sizes) size.label],
          selected: {food.sizes.indexWhere((s) => s.id == item.size!.id)},
          onTap: (index) =>
              _update(item.key, (i) => i.withSize(food.sizes[index])),
        ),
      );
    }
    if (item.needsNumbers) {
      out.add(
        Text(
          l10n.weCouldntFindTheNutritionForThis,
          key: ValueKey('meal-check-unmatched-${item.key}'),
          style: AppText.bodyM.copyWith(color: AppColors.onSurface),
        ),
      );
    } else {
      out.add(_figuresLine(l10n, item));
      if (item.partlyFound) {
        out.add(
          Text(
            l10n.weFoundOnlyPartOfThisSo,
            key: ValueKey('meal-check-partly-${item.key}'),
            style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
          ),
        );
      }
    }
    if (item.edited.isNotEmpty) {
      out.add(
        Row(
          children: [
            const Icon(Icons.edit, size: 14, color: AppColors.tertiary),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                l10n.editedByYou,
                style: AppText.label.copyWith(
                  fontSize: 13,
                  color: AppColors.tertiary,
                ),
              ),
            ),
          ],
        ),
      );
    }
    if (editing) out.add(_figureFields(l10n, item));
    final parts = item.parts;
    out.add(
      Wrap(
        spacing: 4,
        children: [
          TextButton(
            key: ValueKey('meal-check-edit-${item.key}'),
            onPressed: () => setState(() {
              if (!_editing.remove(item.key)) _editing.add(item.key);
            }),
            child: Text(editing ? l10n.done_54ca1 : l10n.editNumbers),
          ),
          if (parts.isNotEmpty)
            TextButton(
              key: ValueKey('meal-check-parts-${item.key}'),
              onPressed: () => setState(() {
                if (!_expanded.remove(item.key)) _expanded.add(item.key);
              }),
              child: Text(
                _expanded.contains(item.key)
                    ? l10n.hideWhatsInIt
                    : l10n.seeWhatsInIt,
              ),
            ),
        ],
      ),
    );
    if (parts.isNotEmpty && _expanded.contains(item.key)) {
      out.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final part in parts)
              Text(
                '${part.name} · '
                '${l10n.gramsG_1usqy(countLabel(part.grams.round()))}',
                style: AppText.bodyM.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
          ],
        ),
      );
    }
    return out;
  }

  Widget _gramsRow(AppL10n l10n, CheckItem item) {
    final field = _gramsField(item);
    return Row(
      children: [
        IconButton(
          key: ValueKey('meal-check-less-${item.key}'),
          tooltip: l10n.n10GLess,
          onPressed: (item.grams ?? 0) <= 0 ? null : () => _step(item, -1),
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          icon: const Icon(Icons.remove_circle_outline, size: 26),
          color: AppColors.primaryDim,
        ),
        SizedBox(
          width: 150,
          child: TextField(
            key: ValueKey('meal-check-grams-${item.key}'),
            controller: field,
            onChanged: (text) => _typedGrams(item, text),
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            inputFormatters: [wholeNumberFormatter],
            style: AppText.titleM,
            decoration: InputDecoration(
              isDense: true,
              labelText: l10n.weightInGrams,
              suffixText: l10n.gramsG_1usqy('').trim(),
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        IconButton(
          key: ValueKey('meal-check-more-${item.key}'),
          tooltip: l10n.n10GMore,
          onPressed: (item.grams ?? 0) >= kMaxItemGrams
              ? null
              : () => _step(item, 1),
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          icon: const Icon(Icons.add_circle_outline, size: 26),
          color: AppColors.primaryDim,
        ),
      ],
    );
  }

  /// "540 kcal · Protein 18 g · Carbs 80 g · Fat 12 g · Fibre 9 g", with the
  /// figures that are known. A figure she typed is underlined as hers.
  Widget _figuresLine(AppL10n l10n, CheckItem item) {
    String? label(MacroKind macro) {
      final value = item.value(macro);
      if (value == null) return null;
      final text = countLabel(value);
      return switch (macro) {
        MacroKind.kcal => l10n.kcalKcal(text),
        MacroKind.protein => l10n.proteinGramsG(text),
        MacroKind.carbs => l10n.carbsGramsG(text),
        MacroKind.fat => l10n.fatGramsG(text),
        MacroKind.fiber => l10n.fibreGramsG(text),
      };
    }

    final shown = [
      for (final macro in MacroKind.values)
        if (label(macro) case final text?) (macro: macro, text: text),
    ];
    return Wrap(
      key: ValueKey('meal-check-figures-${item.key}'),
      spacing: 10,
      runSpacing: 2,
      children: [
        for (final figure in shown)
          Text(
            figure.text,
            style: AppText.bodyM.copyWith(
              color: AppColors.onSurface,
              fontWeight: figure.macro == MacroKind.kcal
                  ? FontWeight.w600
                  : FontWeight.w400,
              decoration: item.isEdited(figure.macro)
                  ? TextDecoration.underline
                  : null,
              decorationColor: AppColors.tertiary,
            ),
          ),
      ],
    );
  }

  Widget _figureFields(AppL10n l10n, CheckItem item) {
    String labelOf(MacroKind macro) => switch (macro) {
      MacroKind.kcal => l10n.energyKcal,
      MacroKind.protein => l10n.proteinG_xt7ig,
      MacroKind.carbs => l10n.carbsG_5nlte,
      MacroKind.fat => l10n.fatG_1xdz2,
      MacroKind.fiber => l10n.fibreG,
    };
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final macro in MacroKind.values)
          SizedBox(
            width: 140,
            child: TextField(
              key: ValueKey('meal-check-figure-${item.key}-${macro.name}'),
              controller: _figureField(item, macro),
              onChanged: (text) => _typedFigure(item, macro, text),
              keyboardType: TextInputType.number,
              inputFormatters: [wholeNumberFormatter],
              decoration: InputDecoration(
                isDense: true,
                labelText: labelOf(macro),
                border: const OutlineInputBorder(),
              ),
            ),
          ),
      ],
    );
  }

  // ----------------------------------------------------------- add item --

  List<Widget> _addSection(AppL10n l10n) {
    if (!_adding) {
      return [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            key: const ValueKey('meal-check-add'),
            onPressed: () => setState(() => _adding = true),
            icon: const Icon(Icons.add),
            label: Text(l10n.addSomething),
          ),
        ),
      ];
    }
    final library = _library(l10n);
    final guard = AllergyGuard(widget.constraints);
    final query = _query.text.trim();
    final found = query.isEmpty
        ? const <Food>[]
        : guard.screenSuggestions(library.resolve(query)).take(5).toList();
    return [
      Text(l10n.addSomething, style: AppText.titleS),
      TextField(
        key: const ValueKey('meal-check-search'),
        controller: _query,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          isDense: true,
          labelText: l10n.searchTheFoodList,
          prefixIcon: const Icon(Icons.search),
          border: const OutlineInputBorder(),
        ),
      ),
      for (final food in found)
        AppListItem(
          key: ValueKey('meal-check-found-${food.foodId}'),
          title: food.names.first,
          subtitle: l10n.kcalKcalProteinGProtein(
            countLabel(food.defaultSize.kcal),
            countLabel(food.defaultSize.proteinG),
          ),
          trailing: const Icon(Icons.add, color: AppColors.primaryDim),
          onTap: () => _addFood(food),
        ),
      Text(l10n.orTypeItIn, style: AppText.titleS),
      TextField(
        key: const ValueKey('meal-check-own-name'),
        controller: _ownName,
        onChanged: (_) => setState(() {}),
        maxLength: 80,
        decoration: InputDecoration(
          isDense: true,
          labelText: l10n.whatIsIt,
          counterText: '',
          border: const OutlineInputBorder(),
        ),
      ),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _ownField(
            const ValueKey('meal-check-own-grams'),
            _ownGrams,
            l10n.weightInGrams,
          ),
          _ownField(
            const ValueKey('meal-check-own-kcal'),
            _ownFigures[MacroKind.kcal]!,
            l10n.energyKcal,
          ),
          _ownField(
            const ValueKey('meal-check-own-protein'),
            _ownFigures[MacroKind.protein]!,
            l10n.proteinG_xt7ig,
          ),
          _ownField(
            const ValueKey('meal-check-own-carbs'),
            _ownFigures[MacroKind.carbs]!,
            l10n.carbsG_5nlte,
          ),
          _ownField(
            const ValueKey('meal-check-own-fat'),
            _ownFigures[MacroKind.fat]!,
            l10n.fatG_1xdz2,
          ),
          _ownField(
            const ValueKey('meal-check-own-fiber'),
            _ownFigures[MacroKind.fiber]!,
            l10n.fibreG,
          ),
        ],
      ),
      AppButton(
        l10n.addIt,
        key: const ValueKey('meal-check-own-add'),
        variant: AppButtonVariant.tonal,
        height: 48,
        fontSize: 16,
        onPressed: _ownReady ? _addOwn : null,
      ),
    ];
  }

  Widget _ownField(
    Key key,
    TextEditingController controller,
    String label,
  ) => SizedBox(
    width: 140,
    child: TextField(
      key: key,
      controller: controller,
      onChanged: (_) => setState(() {}),
      keyboardType: TextInputType.number,
      inputFormatters: [wholeNumberFormatter],
      decoration: InputDecoration(
        isDense: true,
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    ),
  );

  static String _slotName(AppL10n l10n, MealSlot slot) => switch (slot) {
    MealSlot.breakfast => l10n.breakfast,
    MealSlot.lunch => l10n.lunch,
    MealSlot.dinner => l10n.dinner,
    MealSlot.snack => l10n.snack,
  };
}

/// Digits only, in either script: an Egyptian keyboard types Arabic-Indic
/// digits as readily as Western ones, and both are a number she meant.
final TextInputFormatter wholeNumberFormatter =
    FilteringTextInputFormatter.allow(
      RegExp(r'[0-9\u0660-\u0669\u06F0-\u06F9]'),
    );

/// A whole number typed in Western, Arabic-Indic or Persian digits, or null
/// when there is none. Capped at five digits: no figure on a plate is longer.
int? parseWholeNumber(String text) {
  final digits = StringBuffer();
  for (final unit in text.trim().codeUnits) {
    if (unit >= 0x30 && unit <= 0x39) {
      digits.writeCharCode(unit);
    } else if (unit >= 0x0660 && unit <= 0x0669) {
      digits.writeCharCode(0x30 + unit - 0x0660);
    } else if (unit >= 0x06F0 && unit <= 0x06F9) {
      digits.writeCharCode(0x30 + unit - 0x06F0);
    }
  }
  final value = digits.toString();
  if (value.isEmpty) return null;
  return int.tryParse(value.length > 5 ? value.substring(0, 5) : value);
}
