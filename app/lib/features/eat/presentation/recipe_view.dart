/// E06 — Recipe.
///
/// Matches `6-v2/src/screens-eat.mjs` → `E06`. **The recipe page ends where
/// logging starts**: cooked it, log my bowl, in her usual size.
///
/// Portions are the objects she serves — a bowl in three sizes — not grams.
/// That is why the size control is S/M/L rather than a number field, and why
/// what gets logged is a [FoodSize] from the pack rather than a weight she had
/// to estimate.
///
/// "Cooked it, log my bowl" is a **logging action**, so it goes through
/// [LogCommandBus] like every other one: it saves immediately, offers five
/// seconds to undo, and asks nothing.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../domain/format/number_label.dart';
import '../../../domain/logging/log_command_bus.dart';
import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_chip_row.dart';
import '../../../ui/app_media.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/app_split_row.dart';
import '../../../ui/app_undo_snackbar.dart';
import '../../../ui/hand/hand.dart';
import '../domain/allergy_guard.dart';
import '../domain/food_library.dart';
import '../domain/meal_log_service.dart';
import '../domain/meal_repository.dart';
import '../domain/meal_sentence_parser.dart';
import 'eat_day_view_model.dart';
import 'eat_sample_library.dart';
import 'meal_log_session.dart';

class RecipeView extends StatefulWidget {
  const RecipeView({
    super.key,
    required this.constraints,
    this.repository,
    this.bus,
    this.session,
    this.library,
    this.now,
    this.foodId = 'koshari_bowl',
    this.title,
    this.saved = false,
    this.onBack,
    this.onBookmark,
    this.onShare,
    this.onSeeSteps,
    this.onLogged,
    this.onBlocked,
  });

  /// See `EatView.constraints` — required, never defaulted.
  final DietaryConstraints constraints;

  final MealRepository? repository;
  final LogCommandBus? bus;

  /// The Eat tab's shared five seconds — see `EatView.session`.
  final MealLogSession? session;

  final FoodLibrary? library;
  final DateTime? now;

  /// Which dish this page is about. The recipe pack does not exist, so the page
  /// is built from the food it logs.
  final String foodId;

  /// What to call the dish when [foodId] is not in the pack.
  ///
  /// The recipe ids and the food ids are two separately authored sample sets,
  /// so a few recipes name a dish the food pack does not carry. The page is
  /// headed with the recipe she tapped and says it cannot log it — rather than
  /// falling back to koshari's name over a button that would write koshari.
  final String? title;

  /// Whether she has saved this recipe. The bookmark is filled when she has, so
  /// the control says what it did rather than looking identical either way.
  final bool saved;

  final VoidCallback? onBack;
  final VoidCallback? onBookmark;
  final VoidCallback? onShare;
  final VoidCallback? onSeeSteps;
  final ValueChanged<LogHandle>? onLogged;
  final ValueChanged<MealLogRefused>? onBlocked;

  @override
  State<RecipeView> createState() => _RecipeViewState();
}

class _RecipeViewState extends State<RecipeView> {
  late final MealRepository _repo;
  late final LogCommandBus _bus;
  late final bool _ownsRepo;
  late final bool _ownsBus;

  /// Her usual portion — the middle size, which is what she actually serves.
  int? _sizeIndex;

  DateTime get _now => widget.now ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _ownsRepo = widget.repository == null;
    _repo = widget.repository ?? InMemoryMealRepository();
    _ownsBus = widget.bus == null && widget.session == null;
    _bus = widget.bus ?? widget.session?.bus ?? LogCommandBus();
  }

  @override
  void dispose() {
    if (_ownsBus) unawaited(_bus.flushAll());
    if (_ownsRepo) unawaited(_repo.dispose());
    super.dispose();
  }

  FoodLibrary _library(AppL10n l10n) =>
      widget.library ?? eatSampleLibrary(l10n);

  /// The **one** undo offer for one log (§2 rule 9).
  ///
  /// When [RecipeView.onLogged] is wired the handle travels on to E04, which
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

  void _log(Food food, FoodSize size) {
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
      entries: [
        ParsedItem(
          food: food,
          size: size,
          servings: 1,
          sourceText: food.names.first,
        ),
      ],
      source: MealSource.search,
      origin: MealOrigin.recipe,
      at: _now,
    );

    if (outcome is MealLogRefused) {
      widget.onBlocked?.call(outcome);
      return;
    }

    final prepared = outcome as MealLogPrepared;
    final session = widget.session;
    if (session != null) {
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
    final library = _library(l10n);
    final food = library.byId(widget.foodId);

    final sizes = food?.sizes ?? const <FoodSize>[];
    final selected = _sizeIndex ?? (sizes.isEmpty ? 0 : sizes.length ~/ 2);

    return AppScaffold(
      appBar: AppTopBar(
        onBack: widget.onBack,
        actions: [
          IconButton(
            onPressed: widget.onBookmark,
            iconSize: 24,
            tooltip: widget.saved ? l10n.saved : l10n.save,
            color: widget.saved
                ? AppColors.primaryDim
                : AppColors.onSurfaceVariant,
            icon: Icon(widget.saved ? Icons.bookmark : Icons.bookmark_border),
          ),
          IconButton(
            onPressed: widget.onShare,
            iconSize: 24,
            color: AppColors.onSurfaceVariant,
            icon: const Icon(Icons.share),
          ),
        ],
      ),
      footer: [
        AppButton(
          l10n.cookedItLogMyBowl,
          icon: Icons.check,
          onPressed: food == null || sizes.isEmpty
              ? null
              : () => _log(food, sizes[selected]),
        ),
        AppButton(
          l10n.seeTheSteps,
          variant: AppButtonVariant.outlined,
          height: 48,
          fontSize: 15,
          onPressed: widget.onSeeSteps,
        ),
      ],
      children: [
        const AppMedia(
          height: 160,
          kind: AppMediaKind.photo,
          showPlayButton: false,
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The dish this page was opened for.
            //
            // Title, macros and the line under them were all fixed to koshari:
            // `koshariPortioned`, `n540Kcal` and `n18GProtein`. E06 takes a
            // `foodId` and the router opens it from any recipe row, so tapping
            // "Molokhia with chicken" produced a page headed "Koshari,
            // portioned · 540 kcal · 18 g protein" — over a portion picker and
            // a Log button that wrote molokhia.
            //
            // Swiped with marker, the way she would mark the dish she means
            // to cook. The page's only mark.
            MarkerHighlight(
              drawOn: true,
              child: Text(
                food?.names.first ?? widget.title ?? l10n.koshariPortioned,
                textWidthBasis: TextWidthBasis.longestLine,
                style: AppText.headline,
              ),
            ),
            // `n22Min4Servings14EgpA` — "22 min · 4 servings · 14 EGP a
            // serving" — is recipe-pack content: a cooking time, a yield and a
            // cost per serving. No recipe pack exists (see [foodId]), and the
            // food pack carries none of the three, so the line is withheld
            // rather than repeated from the prototype's koshari for every dish.
          ],
        ),
        // Energy and protein for the portion she has selected, and the diet
        // tag. The tag is copy on this page, NOT a `dietTags[]` claim from the
        // pack — that content does not exist, and AllergyGuard reads its
        // absence rather than this.
        // The dish she tapped is not in the food pack, so the portion picker
        // and the Log button below have nothing to act on. Said, rather than
        // left as a page of disabled controls.
        if (food == null)
          Text(
            l10n.thisDishIsNotInTheFood,
            style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
          ),
        AppChipRow(
          grow: false,
          selected: const <int>{},
          items: [
            if (sizes.isNotEmpty)
              l10n.kcalKcalProteinGProtein(
                countLabel(sizes[selected].kcal),
                countLabel(sizes[selected].proteinG),
              ),
            l10n.vegetarian,
          ],
        ),
        AppCard(
          variant: AppCardVariant.filled,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          children: [
            AppSplitRow(
              start: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.yourPortion, style: AppText.titleM),
                  const SizedBox(height: 3),
                  Text(
                    l10n.mediumBowlTheOneYouUsuallyServe,
                    style: AppText.bodyM.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              end: SizedBox(
                width: 160,
                child: AppChipRow(
                  items: [l10n.s, l10n.m, l10n.l],
                  selected: {selected},
                  onTap: (index) => setState(() => _sizeIndex = index),
                ),
              ),
            ),
          ],
        ),
        Text(
          l10n.riceLentilsAndPastaCookedTogetherWith,
          style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
        ),
      ],
    );
  }
}
