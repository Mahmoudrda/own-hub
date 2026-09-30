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
import 'recipe_labels.dart';

/// One row of the recipe list.
class RecipeRow {
  const RecipeRow({
    required this.recipeId,
    required this.title,
    required this.detail,
    this.minutes,
    this.proteinG,
    this.egp,
    this.allergens,
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

  /// What the dish contains, as allergen wire tokens.
  ///
  /// **Null means nobody has written it down**, the same convention
  /// `Food.allergens` uses and the same one `AllergyGuard` fails closed on. An
  /// empty set here would be a claim that the dish contains none of what she
  /// named, and nobody has checked these four, so all four carry null.
  ///
  /// The field exists because without it the guard could not see these rows at
  /// all: E10 promises "dishes that contain it are hidden from your recipes",
  /// and "Yoghurt, dates and nuts" stayed on screen, tappable, for a woman who
  /// had just declared tree nuts.
  final Set<String>? allergens;
}

/// The filters E05 offers, in the order the chips are drawn.
///
/// The last three arrived with Rahma's book and each one answers a question her
/// cards can actually answer: whether a dish needs an oven she may not have,
/// whether it is something she can make the night before, and whether it is
/// clear of nuts. The first two apply to her recipes only; the four prototype
/// rows carry no tags to test, and a row that does not say never matches a
/// filter.
///
/// [noNuts] is the exception and applies to both halves of the screen. It is a
/// safety claim rather than a convenience, and a claim that holds over half a
/// list is not a claim: the chip used to leave "Yoghurt, dates and nuts" on
/// screen above the book it had just emptied.
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
  // Hands-on time where the recipe states one, because that is what the chip
  // means. It read `totalMinutes`, which counts a night in the fridge, so
  // overnight oats — five minutes of work — was excluded at 1,445 and so were
  // chia pudding, ice cream and banana pudding. A row that does not say still
  // never matches: the fallback is the total, not a zero.
  RecipeFilter.underTwentyMinutes => switch (recipe.activeMinutes ??
      recipe.totalMinutes) {
    final int minutes => minutes < 20,
    null => false,
  },
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
///
/// Every one of them leaves [RecipeRow.allergens] null, which means **nobody
/// has checked**, exactly as `eat_sample_library.dart` records for the food
/// pack: `foods.allergens[]` is unauthored, and writing a set here would be the
/// app inventing a safety guarantee for a woman with a food allergy. Null is
/// the fail-closed value, so a declared allergy takes all four off the screen
/// and `_topEmptyLine` says why.
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

    // The guard runs on the app's own rows too, and it runs **before** any
    // chip. E10 promises her, verbatim, "dishes that contain it are hidden from
    // your recipes"; this list is the one directly under that promise, and it
    // used to be exempt from it because a `RecipeRow` carried no allergen field
    // for the guard to read. A woman who declared tree nuts was still offered
    // "Yoghurt, dates and nuts", tappable, with no interstitial.
    //
    // Nothing here is tagged, so for a woman with any declared allergy every
    // row goes and the line below says why. That is stricter than the promise
    // rather than looser than it, which is the only direction this is allowed
    // to be wrong in.
    final guard = AllergyGuard(widget.constraints);
    final safe = [
      for (final recipe in all)
        if (guard.allowsAllergens(recipe.allergens)) recipe,
    ];
    final hiddenUnchecked = all.length - safe.length;

    final recipes = [
      for (final recipe in safe)
        if ((filter == null || matchesFilter(recipe, filter)) &&
            // "No nuts" is drawn beside Rahma's book and every other chip there
            // stays in her half of the screen. This one cannot: it is a safety
            // claim, and a claim that holds for half a list is not a claim. It
            // selects none of these rows, because none of them has been checked.
            (_bookFilter != RecipeFilter.noNuts ||
                matchesFilter(recipe, RecipeFilter.noNuts)))
          recipe,
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
          // An empty list has to name its own cause, and the causes are not one
          // sentence. The guard's reason comes first because the guard ran
          // first: a chip cannot be blamed for rows that were already gone.
          if (recipes.isEmpty)
            Text(
              _topEmptyLine(l10n, hiddenUnchecked, filter),
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

  /// Why the app's own four rows are not on screen.
  ///
  /// Same discipline as [_emptyLine] below, ordered by cause rather than by
  /// severity. [hiddenUnchecked] is the guard's removal and it comes first,
  /// because it happened first.
  String _topEmptyLine(AppL10n l10n, int hiddenUnchecked, RecipeFilter? filter) {
    // Says whose check is missing, because it is not hers.
    //
    // This read "None of these dishes has been checked FOR WHAT YOU AVOID, so
    // none of them is shown", and three rows further down the same screen the
    // book answers the identical fact with "This is not about what you avoid:
    // nobody has signed off what is in these dishes". One screen, one cause,
    // two sentences, and the first one put the cause in her body. Every one of
    // the recipes is unsigned today, so a woman who declares molluscs — a tag
    // that fires on none of them — emptied the list and was told it was what
    // she avoids.
    //
    // It stays a different sentence from the book's, for the reason the
    // `noNuts` branch below already gives: the same words printed twice on one
    // screen read as the app repeating itself rather than as two libraries each
    // answering for themselves.
    if (hiddenUnchecked > 0) return l10n.nobodyHasSignedOffWhatIsIn_127cj;
    // Its own sentence, not the book's. The book says "No recipe can be called
    // nut free yet", and printing that twice on one screen reads as the app
    // repeating itself rather than as two libraries each answering for
    // themselves.
    if (_bookFilter == RecipeFilter.noNuts) {
      return l10n.noneOfTheseDishesHasBeenChecked_9ic16;
    }
    if (filter == RecipeFilter.ramadan) {
      return l10n.noRecipeCarriesARamadanTagYet;
    }
    return l10n.nothingMatchesThat;
  }

  /// Why her half of the screen is empty, in the woman's own terms.
  ///
  /// Order matters and it is the order of causes, not of severity. Anything
  /// removed by the guard was removed **before** a filter was applied, so the
  /// guard's reason is the true one: a chip cannot be blamed for a book that
  /// was already gone.
  ///
  /// The two guard reasons are separate sentences because they are separate
  /// facts, and conflating them is the defect this method exists for. Every one
  /// of the thirty-nine recipes is unsigned today, so declaring molluscs — a
  /// tag that fires on none of them — emptied the book and the screen said "39
  /// dishes are hidden because of what you avoid". Nothing she avoids was in
  /// any of them.
  ///
  /// The last two are the filters that can only ever select nothing in this
  /// build. They each get their own line for the same reason Ramadan already
  /// had one: a chip that falls through to "Nothing matches that" reads as a
  /// fault in the app rather than as an absence in the content.
  String _emptyLine(AppL10n l10n, HiddenRecipes hidden, RecipeFilter? filter) {
    if (hidden.unsigned > 0) return l10n.noDishHereHasBeenCheckedYet;
    if (hidden.namedAllergen > 0) {
      return l10n.everythingHereContainsSomethingYouToldUs;
    }
    // Nobody has priced a recipe in the book, so "Cheap" selects none of them.
    if (filter == RecipeFilter.cheap) return l10n.noRecipeHasBeenPricedYet;
    if (filter == RecipeFilter.ramadan) {
      return l10n.noRecipeCarriesARamadanTagYet;
    }
    // "No nuts" fails closed on `allergensReviewed`, and nothing is signed, so
    // it correctly selects none. Saying which of those two facts is doing the
    // work is the difference between an honest gap and a broken chip.
    if (_bookFilter == RecipeFilter.noNuts) {
      return l10n.noRecipeCanBeCalledNutFree;
    }
    return l10n.nothingMatchesThat;
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
    var hidden = HiddenRecipes.none;
    final bySection = <String, List<Recipe>>{};
    for (final section in book.sections) {
      final all = book.inSection(section.sectionId);
      final allowed = guard.screenRecipes(all);
      hidden = hidden.plus(guard.hiddenByReason(all));
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

    // Said once, at the head of the book, instead of three lines on each of
    // thirty-nine cards. It is also the only place the **consequence** is
    // stated: the marker on a card says the dish is unchecked, and says nothing
    // at all about the book disappearing the moment she names an allergy, which
    // is the part that actually bites.
    //
    // Only while there is something to caveat. When the book is empty the empty
    // state below already says this and says it in the past tense, and two
    // sentences about the same fact read as the screen repeating itself.
    final anyUnsigned =
        anyShown && book.recipes.any((r) => !r.allergensReviewed);

    return [
      _BookHeading(title: l10n.rahmasRecipes),
      if (anyUnsigned)
        Text(
          l10n.nothingInTheBookHasBeenChecked,
          style: AppText.bodyM.copyWith(color: HandInk.print),
        ),
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
      // The empty state has to name the reason it is empty, and the two reasons
      // are not the same sentence.
      //
      // Every one of the thirty-nine recipes is unsigned today, so a woman who
      // declares an allergy loses the whole book whatever she declared. The
      // screen used to answer that with "Nothing matches that." followed by
      // "39 dishes are hidden because of what you avoid" — while she may avoid
      // something that appears in none of them. That sentence takes the app's
      // own caution and tells her it came out of her body.
      if (!anyShown)
        Text(
          _emptyLine(l10n, hidden, filter),
          style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
        ),
      // Hiding silently is worse than hiding visibly. A woman who declared a nut
      // allergy and then found six recipes missing has no way to tell a filter
      // from a fault, so the screen says how many, **why**, and offers the way
      // back. Two rows rather than one total, because "nobody has checked
      // these yet" is not "this one contains sesame".
      if (hidden.unsigned > 0)
        _HiddenRow(
          title: dishesHiddenUnchecked(l10n, hidden.unsigned),
          onTap: () => openScreen(context, 'E10', widget.onAnswerAllergies),
        ),
      if (hidden.namedAllergen > 0)
        _HiddenRow(
          title: dishesHiddenByAllergen(l10n, hidden.namedAllergen),
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

/// One reason some of her cards are not on screen, and the way back.
///
/// Drawn once per reason rather than once per total: "nobody has checked these
/// yet" is a fact about the library and "this one contains sesame" is a fact
/// about her, and one row stating their sum tells her the wrong one.
class _HiddenRow extends StatelessWidget {
  const _HiddenRow({required this.title, required this.onTap});

  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return AppListItem(
      variant: AppCardVariant.filled,
      leading: const Icon(
        Icons.shield_outlined,
        size: 24,
        color: AppColors.primaryDim,
      ),
      title: title,
      subtitle: l10n.changeWhatYouAvoid,
      trailing: const Icon(
        Icons.chevron_right,
        size: 22,
        color: AppColors.onSurfaceVariant,
      ),
      onTap: onTap,
    );
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
    // The hands-on figure, not the total. Overnight oats is five minutes of
    // work and a day in the fridge, and this card said "1,445 min" — a number
    // that is true, unusable, and reads as a bug. The total still has its say
    // on E06, where there is room for both.
    final time = handsOnLabel(l10n, recipe.activeMinutes) ??
        totalTimeLabel(l10n, recipe.totalMinutes);
    final facts = <String>[
      ?time,
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
            // Three words, not three lines. The full sentence — "Nobody has
            // signed off what is in this dish. Read the label on each product
            // yourself." — is right, and it is still on E06 beside the contents
            // list where she is about to cook. Repeated under every one of
            // thirty-nine cards it stopped being read, and it never mentioned
            // the consequence that matters anyway. That is now said once, at
            // the head of the book, where it is about the book rather than
            // about this dish.
            if (!recipe.allergensReviewed) ...[
              const SizedBox(height: 8),
              Text(
                l10n.notCheckedYet,
                style: AppText.label.copyWith(color: HandInk.print),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
