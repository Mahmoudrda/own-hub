/// E07 — This week.
///
/// Matches `6-v2/src/screens-eat.mjs` → `E07`. **Swap, do not rebuild.** The
/// week plan is made of recipes she has already logged, so it is recognisable
/// rather than aspirational, and every row swaps in one tap.
///
/// E07 and E08 read the **same** `mealPlans/{yyyy-Www}` document, so opening the
/// grocery list from here costs zero additional reads (§2).
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../domain/week/week_key.dart';
import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_list_item.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/hand/hand.dart';
import '../../today/presentation/today_cards.dart' show openScreen;
import '../domain/meal_repository.dart';
import 'eat_sample_library.dart';
import 'week_plan_view_model.dart';

class WeekPlanView extends StatefulWidget {
  const WeekPlanView({
    super.key,
    this.repository,
    this.now,
    this.onBack,
    this.onRegenerate,
    this.onOpenRecipe,
    this.onOpenGroceryList,
  });

  final MealRepository? repository;
  final DateTime? now;
  final VoidCallback? onBack;

  /// An override for the rearrange control. Left null — which is what the
  /// router passes — the screen rearranges the week itself; see [_rearrange].
  final VoidCallback? onRegenerate;
  final ValueChanged<String>? onOpenRecipe;
  final VoidCallback? onOpenGroceryList;

  @override
  State<WeekPlanView> createState() => _WeekPlanViewState();
}

class _WeekPlanViewState extends State<WeekPlanView> {
  late final MealRepository _repo;
  late final bool _ownsRepo;

  MealPlan? _plan;

  DateTime get _now => widget.now ?? DateTime.now();

  /// The ISO week id, from the type that already refuses arithmetic on weeks.
  String get _weekId => WeekKey.of(_now).id;

  @override
  void initState() {
    super.initState();
    _ownsRepo = widget.repository == null;
    _repo = widget.repository ?? InMemoryMealRepository();
    unawaited(_load());
  }

  Future<void> _load() async {
    final plan = await _repo.mealPlan(_weekId);
    if (mounted) setState(() => _plan = plan);
  }

  /// Rearranges the week — the same five dinners, moved on by a day.
  ///
  /// The button was drawn as "regenerate" and wired to nothing. There is no
  /// generator to call: the recipe pack does not exist, and inventing five new
  /// dinners here would be authoring content in a tap handler. What this screen
  /// *can* honestly do is the design's own sentence — "swap, do not rebuild" —
  /// so the dinners she already has move on a day, through the repository's own
  /// [MealRepository.swapDinner], and the grocery list is untouched because the
  /// week still holds the same five meals.
  Future<void> _rearrange() async {
    final plan = _plan;
    if (plan == null || plan.dinners.length < 2) return;

    final days = plan.dinners.keys.toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    final recipes = [for (final day in days) plan.dinners[day]!];

    for (var i = 0; i < days.length; i++) {
      await _repo.swapDinner(
        weekId: _weekId,
        day: days[i],
        recipeId: recipes[(i + 1) % recipes.length],
      );
    }
    await _load();
  }

  @override
  void dispose() {
    if (_ownsRepo) unawaited(_repo.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final view = const WeekPlanViewModel().build(weekId: _weekId, plan: _plan);

    return AppScaffold(
      appBar: AppTopBar(
        title: l10n.thisWeek,
        onBack: widget.onBack,
        actions: [
          IconButton(
            onPressed: widget.onRegenerate ?? () => unawaited(_rearrange()),
            tooltip: l10n.rearrangeTheWeek,
            iconSize: 24,
            color: AppColors.onSurfaceVariant,
            icon: const Icon(Icons.autorenew),
          ),
        ],
      ),
      footer: [
        AppButton(
          l10n.seeTheGroceryList,
          onPressed: () => openScreen(context, 'E08', widget.onOpenGroceryList),
        ),
      ],
      children: [
        // "Five dinners, built from recipes you have logged before. Swap any
        // of them." — over five rows all reading "Need an idea for dinner?",
        // which is what a woman with no plan saw. There were no five dinners,
        // nothing had been built, and there was nothing to swap.
        //
        // The guard was already written and this screen was not using it:
        // `WeekPlanView.hasPlan` carries the doc "True once anything has been
        // planned. Before that E07 offers to build one rather than showing five
        // blank rows with no explanation."
        Text(
          view.hasPlan
              ? l10n.fiveDinnersBuiltFromRecipesYouHave
              : l10n.nothingIsPlannedForThisWeekYet,
          style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
        ),
        // A planner page: one ink rule heads the week, and each day below it
        // is a pencil-ruled line of its own.
        const HandRule(seed: 23, ink: true, height: 10),
        for (final row in view.dinners)
          AppListItem(
            title: row.recipeId == null
                ? l10n.needAnIdeaForDinner
                : recipeLabel(l10n, row.recipeId!),
            subtitle: weekdayLabelFor(l10n, row.day),
            // swap_horiz is directional and flips in Arabic.
            trailing: const Icon(
              Icons.swap_horiz,
              size: 22,
              color: AppColors.primaryDim,
            ),
            onTap: () {
              final open = widget.onOpenRecipe;
              if (open != null && row.recipeId != null) {
                open(row.recipeId!);
                return;
              }
              openScreen(context, 'E06');
            },
          ),
        AppCard(
          variant: AppCardVariant.tonal,
          onTap: () => openScreen(context, 'E08', widget.onOpenGroceryList),
          children: [
            Row(
              children: [
                const Icon(
                  Icons.shopping_cart,
                  size: 24,
                  color: AppColors.primaryDim,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(l10n.oneShopCoversIt, style: AppText.titleM),
                      // Withheld rather than stated.
                      //
                      // This read `n23ItemsAbout640Egp` — "23 items · about
                      // 640 EGP" — the prototype's list and the prototype's
                      // bill, shown to a woman whose plan holds four dinners
                      // and whose market is not Cairo's. The dictionary does
                      // carry `countItemsAboutEgpEgp` and `view.itemCount` is
                      // her real count, but NOTHING in this product costs a
                      // grocery line: `GroceryLine` has an ingredient, a group
                      // and a tick, and no price. Half of that sentence would
                      // have to be invented, so the sentence is not said. The
                      // dictionary gap is a price on the line, not a string.
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
