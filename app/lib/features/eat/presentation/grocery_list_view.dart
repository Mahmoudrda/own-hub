/// E08 — Grocery list.
///
/// Matches `6-v2/src/screens-eat.mjs` → `E08`. **One shop.** Grouped the way an
/// Egyptian market trip actually goes, and it survives being closed mid-shop.
///
/// ## Ticks are local-first
///
/// A tick updates the screen immediately and the flush to Firestore is
/// debounced. E08 is used standing in a market, often with no signal, and a tick
/// that waited for a round-trip would fail exactly where the screen is for. The
/// keys are deterministic (`sha1(ingredientId:unit)`), so a tick made on two
/// devices converges on one line rather than ticking two.
///
/// ## Ticked lines stay where they are
///
/// Struck through, in place. A list that reorders itself under her thumb while
/// she is shopping is harder to read than one that does not.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app_state/haptics.dart';
import '../../../domain/clock/app_clock.dart';
import '../../../domain/week/week_key.dart';
import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_nav_bar.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/hand/hand.dart';
import '../../today/presentation/today_cards.dart' show openScreen;
import '../../../ui/app_button.dart';
import '../domain/grocery_from_recipes.dart';
import '../domain/meal_repository.dart';
import '../domain/recipe.dart';
import 'eat_sample_library.dart';
import 'week_plan_view_model.dart';

class GroceryListView extends StatefulWidget {
  const GroceryListView({
    super.key,
    this.repository,
    this.now,
    this.onBack,
    this.onShare,
    this.onSelectTab,
    this.recipeOf,
    this.recipeTitle,
    this.onPlanWeek,
  });

  /// Finds one of Rahma's recipes by id. Given it, the list is made from the
  /// dinners on the week plan, in her own words; without it the screen draws
  /// the lines the plan already holds.
  final Recipe? Function(String recipeId)? recipeOf;

  /// The name a dinner's section is headed with.
  final String? Function(String recipeId)? recipeTitle;

  /// "Plan my week": E07, shown when there is nothing to shop for yet.
  final VoidCallback? onPlanWeek;

  final MealRepository? repository;
  final DateTime? now;
  final VoidCallback? onBack;

  /// G5 §9 Q8: an OS share sheet with generated text. Nothing leaves the device
  /// unless she chooses — no server, no link.
  final VoidCallback? onShare;

  final ValueChanged<String>? onSelectTab;

  @override
  State<GroceryListView> createState() => _GroceryListViewState();
}

class _GroceryListViewState extends State<GroceryListView> {
  late final MealRepository _repo;
  late final bool _ownsRepo;

  static const _model = WeekPlanViewModel();

  WeekPlanView? _view;

  /// The line she has just ticked, so only its tick is drawn on. The others
  /// are simply there.
  String? _justTicked;

  DateTime get _now => widget.now ?? AppClock.now();
  String get _weekId => WeekKey.of(_now).id;

  @override
  void initState() {
    super.initState();
    _ownsRepo = widget.repository == null;
    _repo = widget.repository ?? InMemoryMealRepository();
    unawaited(_load());
  }

  Future<void> _load() async {
    var plan = await _repo.mealPlan(_weekId);
    final recipeOf = widget.recipeOf;
    if (plan != null && recipeOf != null) {
      await _repo.syncGroceries(
        weekId: _weekId,
        lines: groceryLinesFor(plan, recipeOf),
      );
      plan = await _repo.mealPlan(_weekId);
    }
    if (!mounted) return;
    setState(() => _view = _model.build(weekId: _weekId, plan: plan));
  }

  @override
  void dispose() {
    if (_ownsRepo) unawaited(_repo.dispose());
    super.dispose();
  }

  /// Local first: the row changes now, the document catches up.
  void _tick(String itemKey, bool ticked) {
    final current = _view;
    if (current == null) return;
    setState(() {
      _view = _model.tick(current, itemKey, ticked);
      _justTicked = ticked ? itemKey : null;
    });
    if (ticked) unawaited(AppHaptics.play(HapticMoment.actionDone));
    unawaited(
      _repo.tickGrocery(weekId: _weekId, itemKey: itemKey, ticked: ticked),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final view = _view ?? _model.build(weekId: _weekId);
    final nothingToShopFor = _view != null && view.itemCount == 0;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppTopBar(
        title: l10n.groceryList,
        onBack: widget.onBack,
        actions: [
          // Nothing to share while the list is empty.
          if (!nothingToShopFor && view.itemCount > 0)
            IconButton(
              onPressed: widget.onShare,
              // Named. It was an icon with no tooltip, no label and no hint, so
              // E08 shipped a tappable a screen reader announces as nothing at
              // all — the only unnamed control on the screen.
              tooltip: l10n.share,
              iconSize: 24,
              color: AppColors.onSurfaceVariant,
              icon: const Icon(Icons.share),
            ),
        ],
      ),
      bottomNavigationBar: AppNavBar(
        // E08, which is what this screen is. Claiming 'E01' marked the Eat tab
        // active, and the active tab is not a link to itself — so the Eat tab
        // was dead from the grocery list.
        activeScreenId: 'E08',
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
        children: [
          if (nothingToShopFor) ...[
            Text(l10n.planYourWeekFirst, style: AppText.titleL),
            Text(
              l10n.pickYourDinnersForTheWeekAnd,
              style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
            ),
            AppButton(
              l10n.planMyWeek,
              key: const ValueKey('e08-plan-week'),
              onPressed: () => openScreen(context, 'E07', widget.onPlanWeek),
            ),
          ] else ...[
            Text(
              l10n.groupedTheWayYouShopTickAs,
              style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
            ),
            // A list she keeps, not a stack of cards: each dinner or market
            // stop is an open section on the page, and a pencil rule separates
            // one from the next.
            for (var i = 0; i < view.groups.length; i++) ...[
              if (i > 0) HandRule(seed: 50 + i, height: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    view.groups[i].recipeId == null
                        ? groceryGroupLabel(l10n, view.groups[i].group)
                        : (widget.recipeTitle?.call(view.groups[i].recipeId!) ??
                              recipeLabel(l10n, view.groups[i].recipeId!)),
                    style: AppText.titleS.copyWith(color: AppColors.primaryDim),
                  ),
                  const SizedBox(height: 4),
                  for (final line in view.groups[i].lines)
                    _GroceryTick(
                      label: line.text ?? groceryLabel(l10n, line.ingredientId),
                      ticked: line.ticked,
                      drawOn: line.itemKey == _justTicked,
                      onTap: () => _tick(line.itemKey, !line.ticked),
                    ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// One line. A filled tick or an empty pencil ring — shape, not colour alone.
class _GroceryTick extends StatelessWidget {
  const _GroceryTick({
    required this.label,
    required this.ticked,
    required this.onTap,
    this.drawOn = false,
  });

  final String label;
  final bool ticked;
  final bool drawOn;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: ticked,
      button: true,
      child: HandPressable(
        onTap: onTap,
        builder: (_, _) => ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                if (ticked)
                  HandTick(
                    size: 22,
                    color: AppColors.tertiary,
                    seed: handSeed(['grocery-tick', label]),
                    drawOn: drawOn,
                  )
                else
                  // The box she has not ticked yet, drawn in pencil the way a
                  // shopping list is ruled by hand.
                  SizedBox.square(
                    dimension: 22,
                    child: CustomPaint(
                      painter: LoopPainter(
                        seed: handSeed(['grocery', label]),
                        color: AppColors.outline,
                        width: 1.4,
                        level: HandLevel.crafted,
                        inflate: EdgeInsets.zero,
                        textDirection: Directionality.of(context),
                      ),
                    ),
                  ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: AppText.body.copyWith(
                      color: ticked
                          ? AppColors.onSurfaceVariant
                          : AppColors.onSurface,
                      decoration: ticked ? TextDecoration.lineThrough : null,
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
}
