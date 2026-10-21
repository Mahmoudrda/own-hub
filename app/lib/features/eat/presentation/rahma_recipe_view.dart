/// E06 — one of Rahma's cards.
///
/// The existing `RecipeView` still serves the four prototype rows, which are
/// built from the *food* pack because no recipe pack existed. This screen is
/// what a real recipe looks like, and the router picks between them by id.
///
/// ## Two tabs, and what the second one is for
///
/// **المكوّنات والخطوات** is the default: her ingredients lifted into a block,
/// then her steps, with a timer chip where she gave a time and a temperature
/// chip where she gave a temperature. Every one of those strings is hers,
/// verbatim; the only new writing on the screen is the app's own chrome.
///
/// **كما هي في الكتاب** is the card as the book prints it, unsplit, on the pink
/// paper. It exists because three things are lost in the split and none of them
/// is recoverable: the breath of a card that reads as one exhale, the join
/// between an ingredient and the moment it goes in, and the author's own
/// segmentation on the three cards she ran on without numbering. A woman who
/// was given this book should be able to see the book.
///
/// ## Warmth and warning do not look the same
///
/// This is the rule the screen is built around. Rahma's words are on pink paper
/// in her ink. Every safety line — what the dish contains, the pregnancy note,
/// the favism note, how to tell chicken is cooked, and the standing "read the
/// label yourself" — is in the app's voice, comes from the dictionary, and renders
/// in `HandInk.print` inside a `HandLevel.structural` surface on the app's own
/// ground. If a woman cannot tell at a glance whether a line is Rahma being
/// lovely or the app being careful, the careful line has failed.
///
/// **Nothing here ever says a dish is safe for her.** It says what the dish
/// contains and who has and has not checked. We can state contents; we cannot
/// certify a kitchen we do not control.
library;

import 'package:flutter/material.dart';

import '../../../domain/format/number_label.dart';
import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../theme/recipe_book_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_media.dart';
import '../../../ui/content_image.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/app_segmented.dart';
import '../../../ui/hand/hand.dart';
import '../../../ui/meal_image.dart';
import '../../account/presentation/allergen_labels.dart';
import '../domain/recipe.dart';
import 'recipe_labels.dart';

/// The sentence for a doneness token.
///
/// Tokens rather than free text on the recipe, so that the sentence a woman
/// reads about undercooked chicken is dictionary copy in one register, reviewed
/// once, instead of forty variations authored alongside forty recipes.
String? donenessLine(AppL10n l10n, String? token) => switch (token) {
  'poultry_cooked_through' => l10n.chickenIsDoneWhenNoPinkIs,
  'mince_cooked_through' => l10n.mincedMeatIsDoneWhenNoPink,
  'liver_cooked_through' => l10n.liverIsDoneWhenItIsFirm,
  'shrimp_opaque' => l10n.shrimpIsDoneWhenItTurnsOpaque,
  'fish_flakes' => l10n.fishIsDoneWhenItTurnsOpaque,
  'egg_set' => l10n.eggIsDoneWhenTheWhiteIs,
  'baked_egg_set' => l10n.eggIsDoneWhenTheWhiteIs,
  // A token this build does not know is shown as nothing rather than as the
  // token. The content may be newer than the binary.
  _ => null,
};

/// The sentence for an advisory token. Rendered as a note, never a filter:
/// an advisory is not something she ticked, so the app does not get to decide
/// anything about her body from it.
String? advisoryLine(AppL10n l10n, String token) => switch (token) {
  'pregnancy_liver' => l10n.liverIsVeryHighInVitaminA,
  'g6pd_fava' => l10n.thisDishContainsFavaBeansIfYou,
  _ => null,
};

class RahmaRecipeView extends StatefulWidget {
  const RahmaRecipeView({
    super.key,
    required this.recipe,
    this.onBack,
    this.onShare,
    this.onAddToWeek,
  });

  final Recipe recipe;
  final VoidCallback? onBack;

  /// Null draws no share button: there is nothing to share with yet, and a
  /// button that only says so is a dead end.
  final VoidCallback? onShare;

  /// Puts this dinner on her week. The next step after reading a recipe; the
  /// page had none but Back.
  final VoidCallback? onAddToWeek;

  @override
  State<RahmaRecipeView> createState() => _RahmaRecipeViewState();
}

class _RahmaRecipeViewState extends State<RahmaRecipeView> {
  /// 0 is her ingredients and steps, 1 is the card as printed.
  int _tab = 0;

  /// One step at a time, larger type, a big next control.
  ///
  /// A toggle rather than a route: the two-tap budget and the route count both
  /// say no, and cook mode is a *state* of this screen rather than a different
  /// place. The screen is not held awake, because that needs a new dependency;
  /// without it cook mode still works and the screen sleeps, which is honest.
  bool _cookMode = false;
  int _cookStep = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final recipe = widget.recipe;

    return PaperPage(
      color: BookInk.bg,
      child: AppScaffold(
        // The recipe's own picture, or the drawn mark: never the screen's stock
        // illustration, which would show a buddha bowl above a shakshoka.
        showArt: false,
        backgroundColor: Colors.transparent,
        appBar: AppTopBar(
          onBack: widget.onBack,
          actions: [
            if (widget.onShare != null)
              IconButton(
                onPressed: widget.onShare,
                iconSize: 24,
                color: BookInk.ink,
                icon: const Icon(Icons.share),
              ),
          ],
        ),
        footer: [
          if (widget.onAddToWeek != null)
            AppButton(
              l10n.addToMyWeek,
              key: const ValueKey('e06-add-to-my-week'),
              icon: Icons.calendar_month,
              onPressed: widget.onAddToWeek,
            ),
        ],
        children: [
          // A console recipe's photo, when one was uploaded. Her book's
          // recipes have none, and nothing is drawn for them.
          if (recipe.photoPath case final photo?)
            ContentImage(
              path: photo,
              height: 200,
              placeholder: const AppMedia(
                height: 200,
                kind: AppMediaKind.photo,
                showPlayButton: false,
              ),
            )
          else if (recipe.imageAsset case final painted?)
            Center(child: MealImage(asset: painted, size: 180)),
          BookCard(
            cardId: recipe.recipeId,
            markKey: recipe.markKey,
            markSize: 64,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (AppL10n.of(context).localeName.startsWith('ar') &&
                    recipe.titleAr != null) ...[
                  // The Arabic title leads in the Arabic UI; the Latin one is
                  // the book's spelling and comes second, smaller.
                  _Hers(
                    child: Text(
                      recipe.titleAr!,
                      style: EditorialType.section.copyWith(
                        color: BookInk.roseTitle,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: BookTitle(
                      titleEn: recipe.titleEn,
                      style: AppText.titleM.copyWith(color: BookInk.ink),
                    ),
                  ),
                ] else ...[
                  BookTitle(
                    titleEn: recipe.titleEn,
                    style: EditorialType.section.copyWith(color: BookInk.ink),
                  ),
                  if (recipe.titleAr != null) ...[
                    const SizedBox(height: 6),
                    _Hers(
                      child: Text(
                        recipe.titleAr!,
                        style: AppText.titleM.copyWith(
                          color: BookInk.roseTitle,
                        ),
                      ),
                    ),
                  ],
                ],
                // Whose recipe it is, said in the app's voice where the page
                // would otherwise read as hers.
                if (recipe.isOwnHub) ...[
                  const SizedBox(height: 6),
                  Text(
                    l10n.fromTheOwnHubKitchen,
                    key: const ValueKey('e06-own-hub-byline'),
                    style: AppText.label.copyWith(color: BookInk.inkSoft),
                  ),
                ],
                const SizedBox(height: 12),
                if (_tab == 0 || recipe.isOwnHub)
                  _Structured(
                    recipe: recipe,
                    cookMode: _cookMode,
                    cookStep: _cookStep,
                    onToggleCookMode: () => setState(() {
                      _cookMode = !_cookMode;
                      _cookStep = 0;
                    }),
                    onStep: (delta) => setState(() {
                      final steps = recipe.allSteps.length;
                      _cookStep = (_cookStep + delta).clamp(0, steps - 1);
                    }),
                  )
                else
                  // The page. One block, her line breaks, nothing extracted and
                  // nothing reordered.
                  _Hers(
                    child: Text(
                      recipe.bodyAr,
                      style: AppText.body.copyWith(color: BookInk.ink),
                    ),
                  ),
                if (recipe.closingAr != null && _tab == 0) ...[
                  const SizedBox(height: 14),
                  _Hers(
                    child: HandNote(
                      recipe.closingAr!,
                      size: 19,
                      color: BookInk.ink,
                    ),
                  ),
                ],
              ],
            ),
          ),
          // The card as printed exists only for a book card; Own Hub's own
          // recipes have no page to show.
          if (!recipe.isOwnHub)
            AppSegmented(
              items: [l10n.ingredientsAndSteps, l10n.asItIsInTheBook],
              selectedIndex: _tab,
              onChanged: (i) => setState(() => _tab = i),
            ),
          // ---------------------------------------------------- the careful half
          //
          // Everything below this line is the app speaking, not Rahma. It is on
          // the app's own surface, in its own ink, in its own Arabic,
          // and it is deliberately unlike the card above it.
          _SafetyNote(
            children: [
              Text(l10n.contains, style: AppText.titleS),
              const SizedBox(height: 6),
              if (!recipe.allergensReviewed)
                Text(
                  l10n.nobodyHasSignedOffWhatIsIn,
                  style: AppText.bodyM.copyWith(color: HandInk.print),
                )
              else if (recipe.allergensFinal.isEmpty)
                Text(
                  l10n.containsNoneOfTheSixteenWeCheck,
                  style: AppText.bodyM.copyWith(color: HandInk.print),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final wire in recipe.allergensFinal.toList()..sort())
                      if (allergenLabelForWire(l10n, wire) case final label?)
                        _ContentsChip(label: label),
                  ],
                ),
              for (final advisory in recipe.advisories)
                if (advisoryLine(l10n, advisory) case final line?) ...[
                  const SizedBox(height: 10),
                  Text(
                    line,
                    style: AppText.bodyM.copyWith(color: HandInk.print),
                  ),
                ],
              if (donenessLine(l10n, recipe.doneness) case final line?) ...[
                const SizedBox(height: 12),
                Text(l10n.howToTellItIsDone, style: AppText.titleS),
                const SizedBox(height: 4),
                Text(line, style: AppText.bodyM.copyWith(color: HandInk.print)),
              ],
              const SizedBox(height: 12),
              Text(
                recipe.isOwnHub
                    ? l10n.theIngredientsAreGenericReadTheLabel
                    : l10n.theIngredientsAreRahmasReadTheLabel,
                style: AppText.bodyM.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Rahma's own words, right to left whatever the app's language.
///
/// Her text is Egyptian Arabic with English words inside it, numbered as she
/// numbered it. In a left-to-right column the number landed on the wrong side
/// and mixed lines broke apart. Full width, so a short line still starts at
/// the right edge. Only the direction changes; her text is never touched.
class _Hers extends StatelessWidget {
  const _Hers({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: Directionality(textDirection: TextDirection.rtl, child: child),
  );
}

/// A line of a recipe in the direction it is written in.
///
/// Her cards are always right to left. A recipe Own Hub wrote reads in the
/// app's language, so its English is left to the surrounding direction.
class _Written extends StatelessWidget {
  const _Written({required this.arabic, required this.child});

  final bool arabic;
  final Widget child;

  @override
  Widget build(BuildContext context) => arabic
      ? _Hers(child: child)
      : SizedBox(width: double.infinity, child: child);
}

/// Whether the text of [recipe] is drawn in Arabic: always for a book card,
/// and for Own Hub's own recipes when the app is in Arabic.
bool _arabicText(BuildContext context, Recipe recipe) =>
    !recipe.isOwnHub || AppL10n.of(context).localeName.startsWith('ar');

/// Her ingredients and steps, lifted out of the card.
class _Structured extends StatelessWidget {
  const _Structured({
    required this.recipe,
    required this.cookMode,
    required this.cookStep,
    required this.onToggleCookMode,
    required this.onStep,
  });

  final Recipe recipe;
  final bool cookMode;
  final int cookStep;
  final VoidCallback onToggleCookMode;
  final void Function(int delta) onStep;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    // **Her own steps only.** Each component's steps are drawn further down
    // under the heading the book gives it, so taking `allSteps` here printed
    // every component step twice: once flat and unheaded, then again grouped.
    // `Fattah` keeps all eleven of its steps in components, so it read as
    // twenty-two; `Makrona Bashmel` eleven for six, `Kebda Meal` nine for six,
    // `Crepe` eight for five.
    final arabic = _arabicText(context, recipe);
    final steps = recipe.steps;
    // Cook mode is the other case, and it is why `allSteps` still exists: one
    // step at a time has to walk the whole dish in the order the card prints
    // it, headings and all, or a woman following `Fattah` would be shown
    // nothing at all.
    final cookSteps = recipe.allSteps;
    final sides = [
      for (final i in recipe.ingredients)
        if (i.servingSideOnly) i,
    ];
    final main = [
      for (final i in recipe.ingredients)
        if (!i.servingSideOnly) i,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _facts(l10n),
        const SizedBox(height: 12),
        // The heading and the rows are drawn only where the page has an
        // ingredient list to draw. `Lahma bel basl` is written as twelve
        // numbered steps and nothing else, so eight bare nouns were lifted out
        // of the method and printed here — "the meat", "the oil", "the onion" —
        // under a heading that made the book look as though it had lost the
        // amounts. Saying what the page does give is honest; that list was not.
        // Her Arabic sits in an English page: say whose words they are.
        if (!recipe.isOwnHub && !l10n.localeName.startsWith('ar')) ...[
          Text(
            l10n.inRahmasWordsAsWrittenInHer,
            key: const ValueKey('e06-in-her-words'),
            style: AppText.label.copyWith(color: BookInk.inkSoft),
          ),
          const SizedBox(height: 8),
        ],
        if (recipe.ingredientsBasis != IngredientsBasis.none) ...[
          Text(
            l10n.ingredients,
            style: AppText.titleM.copyWith(color: BookInk.ink),
          ),
          const SizedBox(height: 6),
          for (final ingredient in main)
            _IngredientRow(ingredient: ingredient, arabic: arabic),
        ],
        if (recipe.ingredientsBasis != IngredientsBasis.measures) ...[
          const SizedBox(height: 4),
          Text(switch (recipe.ingredientsBasis) {
            IngredientsBasis.none => l10n.theBookWritesThisOneAsA,
            _ => l10n.theBookNamesWhatGoesInAnd,
          }, style: AppText.bodyM.copyWith(color: BookInk.inkSoft)),
        ],
        if (!recipe.isOwnHub &&
            main.any((i) => i.gramsBasis == GramsBasis.estimated)) ...[
          const SizedBox(height: 4),
          Text(
            l10n.theWeightsAreEstimatesExceptWhereThe,
            style: AppText.bodyM.copyWith(color: BookInk.inkSoft),
          ),
        ],
        if (sides.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            l10n.servedWith,
            style: AppText.titleS.copyWith(color: BookInk.ink),
          ),
          for (final side in sides)
            _IngredientRow(ingredient: side, arabic: arabic),
        ],
        const SizedBox(height: 16),
        // A card the book prints as a list and nothing more has no method to
        // head: it says so instead of showing a heading over nothing.
        if (cookSteps.isEmpty)
          Text(
            l10n.theBookGivesThisOneAsA,
            key: const ValueKey('e06-list-only'),
            style: AppText.bodyM.copyWith(color: BookInk.inkSoft),
          )
        else
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.steps,
                  style: AppText.titleM.copyWith(color: BookInk.ink),
                ),
              ),
              if (cookSteps.length > 1)
                TextButton(
                  onPressed: onToggleCookMode,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    foregroundColor: BookInk.roseTitle,
                  ),
                  child: Text(l10n.cookMode, style: AppText.label),
                ),
            ],
          ),
        if (cookMode && cookSteps.isNotEmpty)
          _CookMode(
            steps: cookSteps,
            index: cookStep,
            onStep: onStep,
            arabic: arabic,
          )
        else ...[
          for (final step in steps) _StepRow(step: step, arabic: arabic),
          for (final component in recipe.components) ...[
            const SizedBox(height: 14),
            _Hers(
              child: Text(
                component.headingAr,
                style: AppText.titleS.copyWith(color: BookInk.ink),
              ),
            ),
            for (final step in component.steps)
              _StepRow(step: step, arabic: arabic),
          ],
          for (final variant in recipe.variants) ...[
            const SizedBox(height: 14),
            _Hers(
              child: Text(
                variant.labelAr,
                style: AppText.titleS.copyWith(color: BookInk.ink),
              ),
            ),
            for (final step in variant.steps)
              _StepRow(step: step, arabic: arabic),
          ],
        ],
      ],
    );
  }

  /// Time, protein, energy and cost, each drawn **only when it is known**.
  ///
  /// Never a zero and never a dash. A macro figure that was never computed has
  /// nothing to say, and saying "0 g protein" about a recipe nobody has costed
  /// is worse than silence.
  Widget _facts(AppL10n l10n) {
    // Both times, and labelled. One number here read "1,445 min" for a bowl of
    // oats that takes five minutes of work, because the screen drew the total
    // and never the hands-on figure. Where the two agree, only one is drawn:
    // repeating "12 min hands on · 12 min in all" says nothing twice.
    final handsOn = handsOnLabel(l10n, recipe.activeMinutes);
    final total = handsOn != null && recipe.activeMinutes == recipe.totalMinutes
        ? null
        : totalTimeLabel(l10n, recipe.totalMinutes);
    final parts = <String>[
      ?handsOn,
      ?total,
      if (recipe.serves != null) l10n.servesN(countLabel(recipe.serves!)),
      if (recipe.proteinG != null) l10n.nGProtein(countLabel(recipe.proteinG!)),
      if (recipe.kcal != null) l10n.nKcalAServing(countLabel(recipe.kcal!)),
      if (recipe.egpPerServing != null)
        l10n.nEgpAServing(countLabel(recipe.egpPerServing!)),
    ];
    if (parts.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 10,
      runSpacing: 6,
      children: [
        for (final part in parts)
          Text(part, style: AppText.label.copyWith(color: BookInk.inkSoft)),
      ],
    );
  }
}

/// One of her quantity phrases, with the grams beside it when they are known.
///
/// Her words first, at full size; the gram figure muted and smaller. Neither is
/// ever hidden: `علبة زبادي` is what she wrote and what a woman standing at a
/// fridge recognises, and `105 جم` is what a scale can act on.
class _IngredientRow extends StatelessWidget {
  const _IngredientRow({required this.ingredient, required this.arabic});

  final RecipeIngredient ingredient;
  final bool arabic;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final app = Directionality.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: _Written(
        arabic: arabic,
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          children: [
            // `qtyLine`, not `qtyTextAr`: her phrase may cross one of the
            // book's line breaks, and a row that wrapped where the page wrapped
            // read as two ingredients.
            Text(
              ingredient.qtyLineFor(arabic: arabic),
              style: AppText.body.copyWith(color: BookInk.ink),
            ),
            // The app's labels, in the app's direction.
            if (ingredient.grams != null)
              Text(
                l10n.nG(countLabel(ingredient.grams!)),
                textDirection: app,
                style: AppText.bodyM.copyWith(color: BookInk.inkSoft),
              ),
            if (ingredient.optional)
              Text(
                l10n.optional,
                textDirection: app,
                style: AppText.bodyM.copyWith(color: BookInk.inkSoft),
              ),
            if (ingredient.brandHint != null)
              Text(
                ingredient.brandHint!,
                style: AppText.bodyM.copyWith(color: BookInk.inkSoft),
              ),
          ],
        ),
      ),
    );
  }
}

/// One of her steps. Her words are shown as written; the number in front is
/// drawn here from the step's position.
class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.step,
    required this.arabic,
    this.large = false,
  });

  final RecipeStep step;
  final bool arabic;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final body = large
        ? AppText.body.copyWith(fontSize: 21, height: 1.5, color: BookInk.ink)
        : AppText.body.copyWith(color: BookInk.ink);
    final app = Directionality.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: _Written(
        arabic: arabic,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  countLabel(step.index),
                  style: body.copyWith(
                    color: BookInk.inkSoft,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(step.textFor(arabic: arabic), style: body),
                ),
              ],
            ),
            if (step.minutes != null || step.tempC != null)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 26, top: 5),
                child: Wrap(
                  spacing: 8,
                  children: [
                    if (step.minutes != null)
                      _Chip(
                        label: l10n.nMin(countLabel(step.minutes!)),
                        direction: app,
                      ),
                    if (step.tempC != null)
                      _Chip(
                        label: l10n.tempDegrees(countLabel(step.tempC!)),
                        direction: app,
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

/// One step at a time, larger, with a big control either side.
class _CookMode extends StatelessWidget {
  const _CookMode({
    required this.steps,
    required this.index,
    required this.onStep,
    required this.arabic,
  });

  final bool arabic;
  final List<RecipeStep> steps;
  final int index;
  final void Function(int delta) onStep;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final at = index.clamp(0, steps.length - 1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.stepNOfTotal(countLabel(at + 1), countLabel(steps.length)),
          style: AppText.label.copyWith(color: BookInk.inkSoft),
        ),
        _StepRow(step: steps[at], arabic: arabic, large: true),
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: at == 0 ? null : () => onStep(-1),
                style: TextButton.styleFrom(
                  minimumSize: const Size(48, 56),
                  foregroundColor: BookInk.roseTitle,
                ),
                child: Text(l10n.previousStep, style: AppText.label),
              ),
            ),
            Expanded(
              child: TextButton(
                onPressed: at >= steps.length - 1 ? null : () => onStep(1),
                style: TextButton.styleFrom(
                  minimumSize: const Size(48, 56),
                  foregroundColor: BookInk.roseTitle,
                ),
                child: Text(l10n.nextStep, style: AppText.label),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// A timer or temperature chip on a step. Her ink on her paper, hairline edge.
class _Chip extends StatelessWidget {
  const _Chip({required this.label, this.direction});

  final String label;

  /// The app's direction, kept when the chip sits inside her text.
  final TextDirection? direction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        border: Border.all(color: BookInk.hairline),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        label,
        textDirection: direction,
        style: AppText.label.copyWith(color: BookInk.inkSoft),
      ),
    );
  }
}

/// One allergen the dish contains. Not a filter and not a tap target: a label.
class _ContentsChip extends StatelessWidget {
  const _ContentsChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surfaceLowest,
        border: Border.all(color: AppColors.outline),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(label, style: AppText.label.copyWith(color: HandInk.print)),
    );
  }
}

/// The app being careful, drawn so it cannot be mistaken for Rahma being lovely.
///
/// Square, structural, on the app's own paper, in printed ink. The card above it
/// is pink, wobbly and handwritten. That difference is the feature.
class _SafetyNote extends StatelessWidget {
  const _SafetyNote({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return HandSurface(
      seed: handSeed(const ['recipe-safety']),
      fill: AppColors.surface,
      frame: AppColors.outline,
      level: HandLevel.structural,
      radius: AppRadius.sm,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}
