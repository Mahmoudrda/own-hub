/// E05 — Recipes.
///
/// Matches `6-v2/src/screens-eat.mjs` → `E05`. Filtered by protein, time and
/// cost, with the **price per serving in EGP on every card**. The design note is
/// the reason that price is not optional: "Food that costs more than her week
/// allows is not a recipe, it is an advert."
///
/// ## The recipe pack does not exist yet
///
/// G5 §1.2 specifies ~120 recipes inside the signed content pack. That pipeline
/// has not been built, so the four rows here are the ones the prototype names,
/// resolved from the dictionary — the same position `TrainRepository` takes on
/// the 124 exercise titles, and the same one `eat_sample_library.dart` takes on
/// foods. The photos do not exist either, so [AppMedia] renders its placeholder
/// rather than a broken image.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_chip_row.dart';
import '../../../ui/app_list_item.dart';
import '../../../ui/app_media.dart';
import '../../../ui/app_nav_bar.dart';
import '../../../ui/app_scaffold.dart';
import '../../today/presentation/today_cards.dart' show openScreen;

/// One row of the recipe list.
class RecipeRow {
  const RecipeRow({
    required this.recipeId,
    required this.title,
    required this.detail,
    this.minutes,
    this.proteinG,
    this.egp,
  });

  final String recipeId;
  final String title;

  /// "22 min · 540 kcal · 18 g protein · 14 EGP" — time, energy, protein and
  /// **cost**, which is the one the design insists on.
  final String detail;

  /// The three figures [detail] states, as numbers the filters can read.
  ///
  /// **Null means the row does not say**, and a row that does not say never
  /// matches a filter: "Under 20 min" must not offer a dish whose time nobody
  /// has written down. The four rows below carry the same values their own
  /// dictionary line states, so a card and the filter that selected it cannot
  /// disagree.
  final int? minutes;
  final int? proteinG;
  final int? egp;
}

/// The four filters E05 offers, in the order the chips are drawn.
enum RecipeFilter { highProtein, underTwentyMinutes, cheap, ramadan }

/// From how much protein a dish counts as a high-protein one.
///
/// Twenty grams: the figure `DayTotals` already treats as a meal's worth of the
/// day's target, rather than a number chosen to make the list look full.
const int kHighProteinG = 20;

/// What "cheap" means on a card whose cost is stated per serving, in EGP.
const int kCheapEgp = 15;

/// Whether [row] survives [filter].
bool matchesFilter(RecipeRow row, RecipeFilter filter) => switch (filter) {
  RecipeFilter.highProtein => (row.proteinG ?? 0) >= kHighProteinG,
  RecipeFilter.underTwentyMinutes => row.minutes != null && row.minutes! < 20,
  RecipeFilter.cheap => row.egp != null && row.egp! <= kCheapEgp,
  // No recipe carries a Ramadan tag: the recipe pack does not exist, and
  // deciding here which dishes suit Ramadan would be authoring content in a
  // switch statement. The chip selects and the list says so.
  RecipeFilter.ramadan => false,
};

/// The four the prototype draws.
List<RecipeRow> sampleRecipes(AppL10n l10n) => [
  RecipeRow(
    recipeId: 'koshari_portioned',
    title: l10n.koshariPortioned,
    detail: l10n.n22Min540Kcal18GProtein,
    minutes: 22,
    proteinG: 18,
    egp: 14,
  ),
  RecipeRow(
    recipeId: 'ful_with_egg_cumin',
    title: l10n.fulWithEggAndCumin,
    detail: l10n.n10Min310Kcal19GProtein,
    minutes: 10,
    proteinG: 19,
    egp: 8,
  ),
  RecipeRow(
    recipeId: 'molokhia_chicken',
    title: l10n.molokhiaWithChicken,
    detail: l10n.n45Min460Kcal34GProtein,
    minutes: 45,
    proteinG: 34,
    egp: 26,
  ),
  RecipeRow(
    recipeId: 'yoghurt_dates_nuts',
    title: l10n.yoghurtDatesAndNuts,
    detail: l10n.n3Min280Kcal14GProtein,
    minutes: 3,
    proteinG: 14,
    egp: 12,
  ),
];

class RecipesView extends StatefulWidget {
  const RecipesView({
    super.key,
    this.recipes,
    this.onBack,
    this.onSearch,
    this.onOpenRecipe,
    this.onOpenWeekPlan,
    this.onSelectTab,
  });

  final List<RecipeRow>? recipes;
  final VoidCallback? onBack;
  final VoidCallback? onSearch;
  final ValueChanged<String>? onOpenRecipe;
  final VoidCallback? onOpenWeekPlan;
  final ValueChanged<String>? onSelectTab;

  @override
  State<RecipesView> createState() => _RecipesViewState();
}

class _RecipesViewState extends State<RecipesView> {
  /// The filters she thinks in. Selection is this screen's, never a chip's.
  ///
  /// **Null is the opening state**, and it means every recipe. A chip that was
  /// selected before she touched anything claimed the list was already filtered
  /// while showing all four rows — so the first tap she made appeared to do
  /// nothing at all. Tapping the selected chip again clears it.
  RecipeFilter? _filter;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final all = widget.recipes ?? sampleRecipes(l10n);
    final filter = _filter;
    final recipes = filter == null
        ? all
        : [
            for (final recipe in all)
              if (matchesFilter(recipe, filter)) recipe,
          ];

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppTopBar(
        title: l10n.recipes,
        onBack: widget.onBack,
        actions: [
          IconButton(
            onPressed: widget.onSearch,
            iconSize: 24,
            color: AppColors.onSurfaceVariant,
            icon: const Icon(Icons.search),
          ),
        ],
      ),
      bottomNavigationBar: AppNavBar(
        activeScreenId: 'E01',
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
          AppChipRow(
            grow: false,
            items: [
              l10n.highProtein,
              l10n.under20Min,
              l10n.cheap,
              l10n.ramadan,
            ],
            selected: {if (filter != null) filter.index},
            onTap: (index) => setState(() {
              final tapped = RecipeFilter.values[index];
              _filter = _filter == tapped ? null : tapped;
            }),
          ),
          // Said only for the filter it is true of. The other three read real
          // figures off the rows, so an empty list there would mean her pack
          // holds nothing that matches — a different sentence, which nothing
          // in this build can reach.
          if (recipes.isEmpty && filter == RecipeFilter.ramadan)
            Text(
              l10n.noRecipeCarriesARamadanTagYet,
              style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
            ),
          for (final recipe in recipes)
            AppListItem(
              // The 64×64 thumbnail. No photography exists, so this is the
              // placeholder rather than a broken image.
              leading: const AppMedia(
                width: 64,
                height: 64,
                kind: AppMediaKind.photo,
                showPlayButton: false,
                borderRadius: AppRadius.sm,
              ),
              title: recipe.title,
              subtitle: recipe.detail,
              trailing: const Icon(
                Icons.chevron_right,
                size: 22,
                color: AppColors.onSurfaceVariant,
              ),
              onTap: () {
                final open = widget.onOpenRecipe;
                if (open != null) {
                  open(recipe.recipeId);
                  return;
                }
                openScreen(context, 'E06');
              },
            ),
          // The week is a different kind of thing from a recipe, so it sits
          // on a flat tint below the ruled list rather than as one more line.
          AppListItem(
            variant: AppCardVariant.filled,
            leading: const Icon(
              Icons.shopping_cart,
              size: 24,
              color: AppColors.primaryDim,
            ),
            title: l10n.thisWeeksPlanAndList,
            subtitle: l10n.n5DinnersOneShop,
            trailing: const Icon(
              Icons.chevron_right,
              size: 22,
              color: AppColors.onSurfaceVariant,
            ),
            onTap: () => openScreen(context, 'E07', widget.onOpenWeekPlan),
          ),
        ],
      ),
    );
  }
}
