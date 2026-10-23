/// W06/W07: a coach builds a meal plan for one client and publishes it.
///
/// One to seven days; breakfast, lunch, dinner and snack. An item is a recipe
/// from the app's recipe book, a food from the food pack with grams, or a short
/// line of her choice. The client's declared allergies, from her intake, mark
/// the items that clash or that nobody has checked. Figures are worked out from
/// the app's own tables and are never typed or sent.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app_state/app_changes.dart';
import '../../../../app_state/honest_notice.dart';
import '../../../../domain/format/number_label.dart';
import '../../../../l10n/app_l10n.dart';
import '../../../../theme/app_tokens.dart';
import '../../../../ui/app_button.dart';
import '../../../../ui/app_card.dart';
import '../../../../ui/app_chip_row.dart';
import '../../../../ui/app_field.dart';
import '../../../../ui/app_list_item.dart';
import '../../../../ui/app_scaffold.dart';
import '../../../../ui/app_sheet.dart';
import '../../../eat/domain/allergy_guard.dart';
import '../../data/coaching_repository.dart';
import '../member/coach_labels.dart' show allergenNames;
import '../../domain/coach_plan.dart';
import '../../domain/coaching_contract.dart';
import '../../domain/coaching_failure.dart';
import '../../domain/subscription.dart';
import '../client/coach_plan_view.dart';
import '../coach/coach_text.dart';
import 'coach_plan_logic.dart';
import 'plan_labels.dart';

const int _itemNoteMax = 120;
const int _freeTextMax = 80;

class ShareMealPlanView extends StatefulWidget {
  const ShareMealPlanView({
    super.key,
    required this.repository,
    required this.subscription,
    required this.catalog,
    this.clientName = '',
    this.templates = const <CoachDraft>[],
    this.existing,
    this.onBack,
    this.onPublished,
  });

  final CoachingRepository repository;
  final Subscription subscription;

  /// The recipe book and the food pack.
  final MealCatalog catalog;
  final String clientName;
  final List<CoachDraft> templates;

  /// A meal plan already published to this client, sent again as a new version.
  final CoachPlan? existing;
  final VoidCallback? onBack;
  final void Function(String planId, int revision)? onPublished;

  @override
  State<ShareMealPlanView> createState() => _ShareMealPlanViewState();
}

class _ShareMealPlanViewState extends State<ShareMealPlanView> {
  late MealPlanBody _body = widget.existing?.meal ?? const MealPlanBody();
  late final TextEditingController _name = TextEditingController(
    text: widget.existing?.name ?? '',
  );
  int _day = 0;
  bool _busy = false;
  bool _published = false;
  bool _templateSaved = false;
  String _error = '';

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  MealPlanBody _withDays(int n) {
    // The labels are the coach's own language: she is who reads them first.
    final l10n = AppL10n.of(context);
    return mealPlanWithDays(_body, n, (i) => l10n.dayNumber(countLabel(i)));
  }

  /// Her allergies, or null when the intake did not come with any answer.
  DietaryConstraints get _constraints {
    final intake = widget.subscription.intake;
    if (intake == null) return DietaryConstraints.unknown;
    return DietaryConstraints(
      allergies: {for (final a in intake.allergies) a.trim().toLowerCase()},
    );
  }

  void _back() {
    final back = widget.onBack;
    if (back != null) {
      back();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  Future<void> _add(String slot) async {
    final item = await showAppSheet<MealItem>(
      context: context,
      children: [
        _AddItemSheet(
          catalog: widget.catalog,
          slot: slot,
          language: Localizations.localeOf(context).languageCode,
        ),
      ],
    );
    if (item == null || !mounted) return;
    setState(() {
      _body = mealPlanWithItem(_body, _day, slot, item);
      _error = '';
    });
  }

  List<PlanProblem> _problems() => mealProblems(_body, _name.text);

  Future<void> _publish() async {
    final l10n = AppL10n.of(context);
    final problems = _problems();
    if (problems.isNotEmpty) {
      setState(
        () => _error = problems.contains(PlanProblem.noName)
            ? l10n.giveThePlanANameFirst
            : problems.contains(PlanProblem.noDays)
            ? l10n.addAtLeastOneItemFirst
            : problemText(l10n, problems.first),
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      final sent = await widget.repository.publishCoachPlan(
        subId: widget.subscription.id,
        name: _name.text.trim(),
        meal: _body,
        planId: widget.existing?.id,
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _published = true;
      });
      widget.onPublished?.call(sent.planId, sent.revision);
    } on CoachingFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = coachFailureText(l10n, failure);
      });
      // The line under the form can be out of sight on a long plan.
      showHonestNotice(context, _error);
    }
  }

  Future<void> _saveTemplate() async {
    final l10n = AppL10n.of(context);
    final problems = _problems();
    if (problems.isNotEmpty) {
      setState(
        () => _error = problems.contains(PlanProblem.noName)
            ? l10n.giveThePlanANameFirst
            : l10n.addAtLeastOneItemFirst,
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      await widget.repository.saveDraft(
        CoachDraft(
          id: '',
          kind: PlanKind.meal,
          name: _name.text.trim(),
          body: _body.toJson(),
        ),
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _templateSaved = true;
      });
    } on CoachingFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = coachFailureText(l10n, failure);
      });
      // The line under the form can be out of sight on a long plan.
      showHonestNotice(context, _error);
    }
  }

  void _preview() {
    unawaited(
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (route) => CoachPlanView(
            plan: CoachPlan(
              id: 'preview',
              kind: PlanKind.meal,
              name: _name.text.trim(),
              revision: (widget.existing?.revision ?? 0) + 1,
              meal: _body,
            ),
            catalog: widget.catalog,
            constraints: _constraints,
            preview: true,
            onBack: () => Navigator.of(route).maybePop(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    if (_body.days.isEmpty) _body = _withDays(1);
    final first = widget.clientName.trim();
    final constraints = _constraints;
    final allergies = widget.subscription.intake?.allergies ?? const <String>[];
    final flags = flagMealPlan(_body, constraints, widget.catalog);
    final day = _body.days[_day.clamp(0, _body.days.length - 1)];
    final dayIndex = _day.clamp(0, _body.days.length - 1);
    final total = dayNutrition(day, widget.catalog);
    return ListenableBuilder(
      listenable: AppChanges.instance,
      builder: (context, _) => AppScaffold(
        appBar: AppTopBar(title: l10n.shareAMealPlan, onBack: _back),
        footer: _published
            ? const []
            : [
                AppButton(
                  widget.existing == null
                      ? l10n.publishToName(first)
                      : l10n.publishAsANewVersion,
                  key: const ValueKey('meal-publish'),
                  onPressed: _busy ? null : _publish,
                ),
              ],
        children: [
          if (first.isNotEmpty)
            Text(
              l10n.planForName(first),
              style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
            ),
          if (_published)
            AppCard(
              variant: AppCardVariant.sage,
              children: [
                Semantics(
                  liveRegion: true,
                  child: Text(
                    l10n.publishedNameCanSeeItNow(first),
                    key: const ValueKey('meal-published'),
                    style: AppText.titleS,
                  ),
                ),
                AppButton(
                  l10n.back,
                  variant: AppButtonVariant.outlined,
                  onPressed: _back,
                ),
              ],
            )
          else ...[
            AppField(
              key: const ValueKey('meal-name'),
              controller: _name,
              label: l10n.planName,
              inputFormatters: [
                LengthLimitingTextInputFormatter(CoachingLimits.planNameMax),
              ],
              onChanged: (_) => setState(() => _error = ''),
            ),
            if (widget.existing != null)
              Text(
                l10n.versionN(countLabel(widget.existing!.revision + 1)),
                style: AppText.bodyM.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            if (widget.templates.any((t) => t.kind == PlanKind.meal) &&
                !_hasItems)
              ..._templatesList(l10n),
            Text(l10n.howManyDays, style: AppText.titleS),
            AppChipRow(
              key: const ValueKey('meal-day-count'),
              items: [
                for (var i = 1; i <= CoachingLimits.planMaxDays; i++)
                  countLabel(i),
              ],
              selected: {_body.days.length - 1},
              onTap: (i) => setState(() {
                _body = _withDays(i + 1);
                _day = _day.clamp(0, i);
              }),
            ),
            if (_body.days.length > 1)
              AppChipRow(
                key: const ValueKey('meal-day-pick'),
                grow: false,
                items: [
                  for (final d in _body.days) mealDayLabel(l10n, d.label),
                ],
                selected: {dayIndex},
                onTap: (i) => setState(() => _day = i),
              ),
            Semantics(
              liveRegion: true,
              child: Text(
                allergies.isEmpty
                    ? l10n.noAllergiesOnHerIntake
                    : l10n.nameAvoidsList(
                        first.isEmpty ? l10n.coach : first,
                        allergenNames(l10n, allergies),
                      ),
                key: const ValueKey('meal-allergies'),
                style: AppText.bodyM.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ),
            if (flags.isNotEmpty)
              AppCard(
                variant: AppCardVariant.amber,
                children: [
                  Text(
                    l10n.checkTheMarkedItemsBeforeYouPublish,
                    key: const ValueKey('meal-flag-banner'),
                    style: AppText.titleS,
                  ),
                ],
              ),
            AppCard(
              key: ValueKey('meal-day-$dayIndex'),
              variant: AppCardVariant.outlined,
              borderRadius: AppRadius.md,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    mealDayLabel(l10n, day.label),
                    style: AppText.titleM,
                  ),
                ),
                for (final slot in CoachingEnums.mealSlots)
                  ..._slot(l10n, lang, slot, day, dayIndex, flags),
                if (!total.isEmpty)
                  Text(
                    [
                      dayNutritionLine(l10n, total),
                      if (total.partial) l10n.someItemsHaveNoFigures,
                    ].join(' · '),
                    key: const ValueKey('meal-figures'),
                    style: AppText.bodyM.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            if (!total.isEmpty)
              Text(
                l10n.figuresComeFromOwnHubsFoodTables,
                style: AppText.bodyM.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            AppButton(
              l10n.seeItFirst,
              key: const ValueKey('meal-preview'),
              variant: AppButtonVariant.outlined,
              onPressed: _hasItems ? _preview : null,
            ),
            if (_templateSaved)
              Semantics(
                liveRegion: true,
                child: Text(
                  l10n.templateSaved,
                  key: const ValueKey('meal-template-saved'),
                  style: AppText.bodyM,
                ),
              )
            else
              AppButton(
                l10n.saveAsATemplate,
                key: const ValueKey('meal-save-template'),
                variant: AppButtonVariant.text,
                height: 48,
                fontSize: 15,
                onPressed: _busy ? null : _saveTemplate,
              ),
          ],
          if (_error.isNotEmpty)
            Semantics(
              liveRegion: true,
              child: Text(
                _error,
                key: const ValueKey('meal-error'),
                style: AppText.bodyM.copyWith(color: AppColors.error),
              ),
            ),
        ],
      ),
    );
  }

  bool get _hasItems =>
      _body.days.any((d) => d.slots.values.any((items) => items.isNotEmpty));

  List<Widget> _templatesList(AppL10n l10n) {
    final mine = [
      for (final t in widget.templates)
        if (t.kind == PlanKind.meal) t,
    ];
    return [
      Text(l10n.yourTemplates, style: AppText.titleS),
      for (var i = 0; i < mine.length; i++)
        AppListItem(
          key: ValueKey('meal-template-$i'),
          title: mine[i].name,
          onTap: () {
            final parsed = MealPlanBody.tryParse(mine[i].body);
            if (parsed == null || parsed.days.isEmpty) return;
            setState(() {
              _body = parsed;
              _day = 0;
              if (_name.text.trim().isEmpty) _name.text = mine[i].name;
            });
          },
        ),
    ];
  }

  List<Widget> _slot(
    AppL10n l10n,
    String lang,
    String slot,
    MealDay day,
    int dayIndex,
    List<MealFlag> flags,
  ) {
    final items = day.itemsIn(slot);
    return [
      Text(
        slotLabel(l10n, slot),
        style: AppText.titleS.copyWith(color: AppColors.onSurfaceVariant),
      ),
      if (items.isEmpty)
        Text(
          l10n.nothingPlannedYet,
          style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
        ),
      for (var i = 0; i < items.length; i++)
        _itemRow(l10n, lang, items[i], slot, dayIndex, i, flags),
      TextButton.icon(
        key: ValueKey('meal-add-$slot'),
        style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
        onPressed: items.length >= 12 ? null : () => unawaited(_add(slot)),
        icon: const Icon(Icons.add, size: 20),
        label: Text(l10n.addToSlot(slotLabel(l10n, slot))),
      ),
    ];
  }

  Widget _itemRow(
    AppL10n l10n,
    String lang,
    MealItem item,
    String slot,
    int dayIndex,
    int index,
    List<MealFlag> flags,
  ) {
    MealFlag? flag;
    for (final f in flags) {
      if (f.day == dayIndex && f.slot == slot && f.index == index) flag = f;
    }
    final amount = itemAmount(l10n, item);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Row(
        children: [
          Expanded(
            child: Column(
              key: ValueKey('meal-item-$dayIndex-$slot-$index'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.catalog.title(item, lang), style: AppText.titleS),
                if (amount.isNotEmpty)
                  Text(
                    amount,
                    style: AppText.bodyM.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                if (flag != null)
                  Text(
                    flag.kind == MealFlagKind.contains
                        ? l10n.containsAllergensWhichSheAvoids(
                            allergenNames(l10n, flag.allergens),
                          )
                        : l10n.allergensNotCheckedForThisOne,
                    key: ValueKey('meal-flag-$dayIndex-$slot-$index'),
                    style: AppText.bodyM.copyWith(color: AppColors.error),
                  ),
              ],
            ),
          ),
          IconButton(
            key: ValueKey('meal-remove-$dayIndex-$slot-$index'),
            tooltip: l10n.remove,
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            onPressed: () => setState(
              () => _body = mealPlanWithoutItem(_body, dayIndex, slot, index),
            ),
            icon: const Icon(Icons.delete_outline, size: 22),
          ),
        ],
      ),
    );
  }
}

enum _Tab { recipe, food, free }

/// Picks one item for a slot and answers it as a [MealItem].
class _AddItemSheet extends StatefulWidget {
  const _AddItemSheet({
    required this.catalog,
    required this.slot,
    required this.language,
  });

  final MealCatalog catalog;
  final String slot;
  final String language;

  @override
  State<_AddItemSheet> createState() => _AddItemSheetState();
}

class _AddItemSheetState extends State<_AddItemSheet> {
  _Tab _tab = _Tab.recipe;
  final TextEditingController _search = TextEditingController();
  final TextEditingController _grams = TextEditingController(text: '100');
  final TextEditingController _free = TextEditingController();
  final TextEditingController _note = TextEditingController();
  double _servings = 1;

  @override
  void dispose() {
    _search.dispose();
    _grams.dispose();
    _free.dispose();
    _note.dispose();
    super.dispose();
  }

  int get _gramsValue => int.tryParse(_grams.text.trim()) ?? 0;

  String? get _noteOrNull =>
      _note.text.trim().isEmpty ? null : _note.text.trim();

  MealItem? get _freeItem {
    final t = _free.text.trim();
    return t.isEmpty ? null : MealItem.free(t, note: _noteOrNull);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final query = _search.text.trim().toLowerCase();
    final recipes = [
      for (final r in widget.catalog.recipes)
        if (query.isEmpty ||
            r.titleEn.toLowerCase().contains(query) ||
            (r.titleAr ?? '').contains(query))
          r,
    ].take(30).toList();
    final foods = query.isEmpty
        ? widget.catalog.foods.mostPopular(30)
        : widget.catalog.foods.resolve(query).take(30).toList();
    final item = _freeItem;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.addToSlot(slotLabel(l10n, widget.slot)),
          style: AppText.titleL,
        ),
        const SizedBox(height: 10),
        AppChipRow(
          key: const ValueKey('add-tabs'),
          items: [l10n.recipes, l10n.foods, l10n.herChoice],
          selected: {_tab.index},
          onTap: (i) => setState(() => _tab = _Tab.values[i]),
        ),
        const SizedBox(height: 10),
        if (_tab != _Tab.free)
          AppField(
            key: const ValueKey('add-search'),
            controller: _search,
            label: l10n.search,
            onChanged: (_) => setState(() {}),
          ),
        if (_tab == _Tab.recipe)
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.servingsN(
                    _servings == _servings.roundToDouble()
                        ? _servings.round().toString()
                        : _servings.toString(),
                  ),
                ),
              ),
              IconButton(
                key: const ValueKey('add-servings-minus'),
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                onPressed: _servings <= 0.5
                    ? null
                    : () => setState(() => _servings -= 0.5),
                icon: const Icon(Icons.remove),
              ),
              IconButton(
                key: const ValueKey('add-servings-plus'),
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                onPressed: _servings >= 6
                    ? null
                    : () => setState(() => _servings += 0.5),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        if (_tab == _Tab.food)
          AppField(
            key: const ValueKey('add-grams'),
            controller: _grams,
            label: l10n.grams,
            keyboardType: TextInputType.number,
            textDirection: TextDirection.ltr,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4),
            ],
            onChanged: (_) => setState(() {}),
          ),
        if (_tab == _Tab.free)
          AppField(
            key: const ValueKey('add-free'),
            controller: _free,
            label: l10n.herChoice,
            hint: l10n.aShortLineLikeFruitOfHer,
            inputFormatters: [LengthLimitingTextInputFormatter(_freeTextMax)],
            onChanged: (_) => setState(() {}),
          ),
        AppField(
          key: const ValueKey('add-note'),
          controller: _note,
          label: l10n.noteForHerIfYouLike,
          inputFormatters: [LengthLimitingTextInputFormatter(_itemNoteMax)],
          onChanged: (_) => setState(() {}),
        ),
        // Tapping a recipe or food adds it at once with the amount above.
        if (_tab == _Tab.recipe) ...[
          if (recipes.isEmpty)
            Text(
              l10n.noRecipesToPickFromYet,
              key: const ValueKey('add-no-recipes'),
            ),
          for (final r in recipes)
            AppListItem(
              key: ValueKey('add-recipe-${r.recipeId}'),
              title: widget.language == 'ar' && (r.titleAr ?? '').isNotEmpty
                  ? r.titleAr!
                  : r.titleEn,
              variant: AppCardVariant.outlined,
              onTap: () => Navigator.of(
                context,
              ).pop(MealItem.recipe(r.recipeId, _servings, note: _noteOrNull)),
            ),
        ],
        if (_tab == _Tab.food)
          for (final f in foods)
            AppListItem(
              key: ValueKey('add-food-${f.foodId}'),
              title: f.names.first,
              variant: AppCardVariant.outlined,
              onTap: () {
                final g = _gramsValue;
                if (g < 1 || g > 2000) return;
                Navigator.of(context)
                    .pop(MealItem.food(f.foodId, g, note: _noteOrNull));
              },
            ),
        if (_tab == _Tab.free)
          AppButton(
            l10n.add,
            key: const ValueKey('add-confirm'),
            onPressed: item == null
                ? null
                : () => Navigator.of(context).pop(item),
          ),
        const SizedBox(height: 12),
      ],
    );
  }
}
