/// E05 — Recipes.
///
/// Matches `6-v2/src/screens-eat.mjs` → `E05`. Filtered by protein, time and
/// cost, with the **price per serving in EGP on every card**. The design note is
/// the reason that price is not optional: "Food that costs more than her week
/// allows is not a recipe, it is an advert."
///
/// ## Two libraries on one screen, and they do not look alike
///
/// The four rows at the top are the prototype's, resolved from the dictionary,
/// and they are the ones carrying the EGP figure the design note insists on.
/// Below them is **Rahma's book**: four sections, her English titles, her PS
/// lines, her cards on pink paper.
///
/// They are drawn differently on purpose. Her card is a piece of paper with
/// clips on it; the app's rows are rows. A woman has to be able to tell in a
/// glance whose words she is reading, and that is worth more than a consistent
/// list style.
///
/// ## The book is behind one question
///
/// [RecipesView] renders nothing of Rahma's until `DietaryProfile.asked` is
/// true. Not as an onboarding flourish: `AppRouter.eatConstraints` returns
/// `DietaryConstraints.none` for an unasked woman, `none` is a claim that she
/// was asked and named nothing, and `AllergyGuard` clears every dish
/// unconditionally against that claim. Shipping allergen-tagged recipes in front
/// of it would hand a sesame dish to a woman allergic to sesame with no warning
/// at all. `E10` is the question; this screen is what waits for it.
library;

import 'package:flutter/material.dart';

import '../../../domain/format/number_label.dart';
import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../theme/recipe_book_tokens.dart';
import '../../../ui/app_chip_row.dart';
import '../../../ui/app_field.dart';
import '../../../ui/app_list_item.dart';
import '../../../ui/app_media.dart';
import '../../../ui/app_nav_bar.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/hand/hand.dart';
import '../../today/presentation/today_cards.dart' show openScreen;
import '../data/seeded_recipe_library.dart';
import '../domain/allergy_guard.dart';
import '../domain/recipe.dart';

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

/// The filters E05 offers, in the order the chips are drawn.
///
/// The last three arrived with Rahma's book and each one answers a question her
/// cards can actually answer: whether a dish needs an oven she may not have,
/// whether it is something she can make the night before, and whether it is
/// clear of nuts. They apply to her recipes only; the four prototype rows carry
/// no tags to test, and a row that does not say never matches a filter.
enum RecipeFilter {
  highProtein,
  underTwentyMinutes,
  cheap,
  ramadan,
  noOven,
  readyInTheFridge,
  noNuts,
}

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
  // The three below read tags only Rahma's recipes carry, so a prototype row
  // never matches one. Same rule, stated once: a row that does not say never
  // matches a filter.
  RecipeFilter.noOven => false,
  RecipeFilter.readyInTheFridge => false,
  RecipeFilter.noNuts => false,
};

/// Whether one of Rahma's recipes survives [filter].
///
/// Read off her own steps rather than off a tag somebody typed: a recipe uses
/// the oven when one of her steps says so, which cannot drift from the card the
/// way a hand-maintained tag can.
bool recipeMatchesFilter(Recipe recipe, RecipeFilter filter) => switch (filter) {
  RecipeFilter.highProtein => recipe.dietTags.contains('high_protein'),
  RecipeFilter.underTwentyMinutes =>
    recipe.totalMinutes != null && recipe.totalMinutes! < 20,
  // Nobody has priced a recipe in the book, and `egpPerServing` is null on all
  // of them. Null means the row does not say, so none of them is "cheap".
  RecipeFilter.cheap =>
    recipe.egpPerServing != null && recipe.egpPerServing! <= kCheapEgp,
  RecipeFilter.ramadan => recipe.dietTags.contains('ramadan'),
  RecipeFilter.noOven => !recipe.allSteps.any(
    (s) => s.tool == 'oven' || s.tool == 'air_fryer',
  ),
  RecipeFilter.readyInTheFridge => recipe.allSteps.any(
    (s) => s.tool == 'fridge' || s.tool == 'freezer',
  ),
  // Reads the contents set, and only for a recipe somebody has signed. An
  // unsigned recipe is not "nut free", it is unchecked, and offering it under a
  // "no nuts" chip would be the app making exactly the claim it refuses to make.
  RecipeFilter.noNuts =>
    recipe.allergensReviewed &&
    !recipe.allergensFinal.contains('tree_nuts') &&
    !recipe.allergensFinal.contains('peanuts'),
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
    this.book,
    this.constraints = DietaryConstraints.unknown,
    this.asked = false,
    this.onBack,
    this.onSearch,
    this.onOpenRecipe,
    this.onOpenWeekPlan,
    this.onOpenLetter,
    this.onAnswerAllergies,
    this.onSelectTab,
  });

  final List<RecipeRow>? recipes;

  /// Rahma's book, already loaded. Null draws the four prototype rows and
  /// nothing else, which is what every test of this screen written before the
  /// book existed sees.
  final RecipeBook? book;

  /// What she told us she cannot eat. Used to remove her recipes before they
  /// are drawn, never to grey them out: a list that shows a dish and refuses it
  /// is a list that has already shown it to her.
  final DietaryConstraints constraints;

  /// Whether the allergy question has actually been put to her.
  ///
  /// False hides the whole book behind a prompt to answer it. That is not an
  /// onboarding preference: see the file note.
  final bool asked;

  final VoidCallback? onBack;
  final VoidCallback? onSearch;
  final ValueChanged<String>? onOpenRecipe;
  final VoidCallback? onOpenWeekPlan;
  final VoidCallback? onOpenLetter;

  /// Opens E10. Wired to the prompt that stands in front of the book.
  final VoidCallback? onAnswerAllergies;

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

  /// Her search text. Local, over a list already in memory, so it is instant
  /// and works with no network — which is the whole reason the index is one
  /// document and the seed is in the binary.
  ///
  /// The screen has had a search icon since the prototype and the router never
  /// wired it, so the button did nothing at all. It opens this field now.
  String _query = '';
  bool _searching = false;

  /// The three filters only her recipes can answer: whether a dish needs an
  /// oven, whether it can be made the night before, and whether it is clear of
  /// nuts. Held separately from [_filter] because they sit under her heading and
  /// apply to her half of the screen; a chip drawn beside the book that emptied
  /// the app's own rows above it would be a filter acting outside its own
  /// section.
  RecipeFilter? _bookFilter;

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
            onPressed: () {
              // The router passes no `onSearch`, so this button has been inert
              // since the prototype. It opens the field below now, and still
              // calls anything a caller did wire.
              setState(() {
                _searching = !_searching;
                if (!_searching) _query = '';
              });
              widget.onSearch?.call();
            },
            iconSize: 24,
            tooltip: l10n.searchRecipes,
            color: AppColors.onSurfaceVariant,
            icon: const Icon(Icons.search),
          ),
        ],
      ),
      bottomNavigationBar: AppNavBar(
        // E05, which is what this screen is. Claiming 'E01' marked the Eat tab
        // active, and `AppNavBar` gives the active tab no `onTap` — so the Eat
        // tab rendered as the current page and did nothing when she pressed it.
        activeScreenId: 'E05',
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
          if (_searching)
            AppField(
              label: l10n.searchRecipes,
              hint: l10n.searchRecipes,
              autofocus: true,
              onChanged: (value) => setState(() => _query = value),
            ),
          // The four general filters, which apply to both libraries. The three
          // that only Rahma's recipes can answer live with her book further
          // down, because `grow: false` wraps and seven chips take two lines,
          // which pushed the app's own rows under the bottom bar.
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
          ..._book(l10n, filter),
        ],
      ),
    );
  }

  /// Rahma's half of the screen.
  ///
  /// Returns an empty list when there is no book, which is what keeps every
  /// test written against the prototype rows unaffected by this feature.
  List<Widget> _book(AppL10n l10n, RecipeFilter? filter) {
    final book = widget.book;
    if (book == null || book.recipes.isEmpty) return const [];

    // The question comes first, always. See the file note: `none` is a claim,
    // and showing her an allergen-tagged library against a claim nobody made is
    // the failure this whole ordering exists to prevent.
    if (!widget.asked) {
      return [
        _BookHeading(title: l10n.rahmasRecipes),
        AppListItem(
          variant: AppCardVariant.filled,
          leading: const Icon(
            Icons.help_outline,
            size: 24,
            color: AppColors.primaryDim,
          ),
          title: l10n.isThereAnythingYouCannotEat,
          subtitle: l10n.tickAnythingYouAvoidDishesThatContain,
          trailing: const Icon(
            Icons.chevron_right,
            size: 22,
            color: AppColors.onSurfaceVariant,
          ),
          onTap: () => openScreen(context, 'E10', widget.onAnswerAllergies),
        ),
      ];
    }

    final guard = AllergyGuard(widget.constraints);
    var hidden = 0;
    final bySection = <String, List<Recipe>>{};
    for (final section in book.sections) {
      final all = book.inSection(section.sectionId);
      final allowed = guard.screenRecipes(all);
      hidden += all.length - allowed.length;
      bySection[section.sectionId] = [
        for (final recipe in allowed)
          if ((filter == null || recipeMatchesFilter(recipe, filter)) &&
              (_bookFilter == null ||
                  recipeMatchesFilter(recipe, _bookFilter!)) &&
              recipe.matches(_query))
            recipe,
      ];
    }
    final anyShown = bySection.values.any((rows) => rows.isNotEmpty);

    return [
      _BookHeading(title: l10n.rahmasRecipes),
      AppChipRow(
        grow: false,
        items: [l10n.noOven, l10n.readyInTheFridge, l10n.noNuts],
        selected: {
          if (_bookFilter != null)
            _bookFilter!.index - RecipeFilter.noOven.index,
        },
        onTap: (index) => setState(() {
          final tapped = RecipeFilter.values[RecipeFilter.noOven.index + index];
          _bookFilter = _bookFilter == tapped ? null : tapped;
        }),
      ),
      for (final section in book.sections)
        if (bySection[section.sectionId]!.isNotEmpty) ...[
          _SectionDivider(section: section),
          for (final recipe in bySection[section.sectionId]!)
            _RahmaCard(
              recipe: recipe,
              onTap: () {
                final open = widget.onOpenRecipe;
                if (open != null) {
                  open(recipe.recipeId);
                  return;
                }
                openScreen(context, 'E06');
              },
            ),
        ],
      if (!anyShown)
        Text(
          l10n.nothingMatchesThat,
          style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
        ),
      // Hiding silently is worse than hiding visibly. A woman who declared a nut
      // allergy and then found six recipes missing has no way to tell a filter
      // from a fault, so the screen says how many and offers the way back.
      if (hidden > 0)
        AppListItem(
          variant: AppCardVariant.filled,
          leading: const Icon(
            Icons.shield_outlined,
            size: 24,
            color: AppColors.primaryDim,
          ),
          title: l10n.countDishesAreHiddenBecauseOfWhat(countLabel(hidden)),
          subtitle: l10n.changeWhatYouAvoid,
          trailing: const Icon(
            Icons.chevron_right,
            size: 22,
            color: AppColors.onSurfaceVariant,
          ),
          onTap: () => openScreen(context, 'E10', widget.onAnswerAllergies),
        ),
      // Assemblies: named combinations of verified foods, in the app's own
      // language and never on her card. None exist yet, because every one of
      // them needs a `foods` row with verified per-100 g macros and `foods` has
      // none. Said out loud rather than left as an empty heading.
      if (book.assemblies.isEmpty)
        AppListItem(
          variant: AppCardVariant.filled,
          leading: const Icon(
            Icons.dashboard_customize_outlined,
            size: 24,
            color: AppColors.primaryDim,
          ),
          title: l10n.quickCombinations,
          subtitle: l10n.noCombinationsAreBuiltYetEachOne,
        ),
      if (book.letterAr.isNotEmpty)
        AppListItem(
          variant: AppCardVariant.filled,
          leading: const Icon(
            Icons.favorite_border,
            size: 24,
            color: AppColors.primaryDim,
          ),
          title: l10n.aMessageFromRahma,
          trailing: const Icon(
            Icons.chevron_right,
            size: 22,
            color: AppColors.onSurfaceVariant,
          ),
          onTap: () => openScreen(context, 'E11', widget.onOpenLetter),
        ),
    ];
  }
}

/// The one Modern Standard line above her book. Everything below it is hers.
class _BookHeading extends StatelessWidget {
  const _BookHeading({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Text(title, style: AppText.titleL),
  );
}

/// A compressed version of the book's full-page section divider.
///
/// The title is stacked and large, as she set it, but in [BookInk.roseTitle]
/// rather than the book's own `#D3737E`: that colour measures 1.68:1 on this
/// ground and fails AA at any size. See `recipe_book_tokens.dart`.
class _SectionDivider extends StatelessWidget {
  const _SectionDivider({required this.section});

  final RecipeSection section;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 2),
      child: HandSurface(
        seed: handSeed(['book-section', section.sectionId]),
        fill: BookInk.bg,
        level: HandLevel.expressive,
        radius: 10,
        looseCorner: 20,
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        // Mark first, so it sits at the start of the reading direction: right
        // in Arabic, as the divider prints it, and left in English. The same
        // arrangement `BookCard` uses, and for the same reason.
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FoodMark(markKey: section.markKey, size: 48, ink: BookInk.roseTitle),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BookTitle(
                    titleEn: section.titleEn,
                    style: EditorialType.cover.copyWith(
                      color: BookInk.roseTitle,
                    ),
                  ),
                  const SizedBox(height: 8),
                  BookTitle(
                    titleEn: section.psLineEn,
                    style: AppText.bodyM.copyWith(color: BookInk.inkSoft),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One of her cards in the list.
///
/// Time and protein under the title where she states them, and nothing at all
/// where she does not. An unsigned recipe carries one Modern Standard line
/// saying so, in the app's printed ink rather than hers: it is the app
/// speaking, and it must not read as part of the card.
class _RahmaCard extends StatelessWidget {
  const _RahmaCard({required this.recipe, required this.onTap});

  final Recipe recipe;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final facts = <String>[
      if (recipe.totalMinutes != null) l10n.nMin(countLabel(recipe.totalMinutes!)),
      if (recipe.proteinG != null) l10n.nGProtein(countLabel(recipe.proteinG!)),
      if (recipe.egpPerServing != null)
        l10n.nEgpAServing(countLabel(recipe.egpPerServing!)),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: BookMetrics.cardGap),
      child: BookCard(
        cardId: recipe.recipeId,
        markKey: recipe.markKey,
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BookTitle(
              titleEn: recipe.titleEn,
              style: EditorialType.section.copyWith(color: BookInk.ink),
            ),
            if (recipe.titleAr != null) ...[
              const SizedBox(height: 4),
              Text(
                recipe.titleAr!,
                style: AppText.titleS.copyWith(color: BookInk.roseTitle),
              ),
            ],
            if (facts.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                facts.join(' · '),
                style: AppText.bodyM.copyWith(color: BookInk.inkSoft),
              ),
            ],
            if (!recipe.allergensReviewed) ...[
              const SizedBox(height: 8),
              Text(
                l10n.nobodyHasSignedOffWhatIsIn,
                style: AppText.bodyM.copyWith(color: HandInk.print),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
