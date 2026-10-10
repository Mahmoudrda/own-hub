/// The Eat tab's session state — one log bus, her plates, and what she saved.
///
/// ## Why the five seconds had to move out of the screens
///
/// Every Eat screen built its own [LogCommandBus], so the write it was holding
/// belonged to that screen alone. E02 logged, pushed E04, and E04 opened on an
/// empty day — the day-one branch, with no undo bar — because the meal was still
/// sitting in E02's private bus five seconds from being written. When it landed,
/// E04's undo bar finally appeared and tapping it did nothing, because the
/// window had closed. One log, two screens, and neither could see the other.
///
/// [MealLogSession] is that one bus, plus the meals still inside their window,
/// so any Eat screen draws them the moment they are logged and any Eat screen
/// can take them back. Rule 9 is unchanged: the write is held and only reaches
/// [MealRepository] when the window closes, so an undone meal is never written.
///
/// ## What this adds on top of the session
///
///   * **Her plates.** A committed meal is folded into `eatPrefs` by the session
///     (that is what turns "logged twice" into E01's one-tap row) and recorded
///     here with the figure the item itself carries, so Home can list her plates
///     without resolving the food pack against a locale.
///   * **Home's meal card.** `recordMeal` is called when a meal is *written*,
///     never when it is merely pending — Home is not on screen during the undo
///     window, so a log she takes back never reaches it.
///   * **Recipes she saved.**
///
/// Her plates and her bookmarks are written to the phone with everything else
/// (`local_persistence.dart`); the log bus is not, because a meal still inside
/// its five seconds was never written.
///
/// Nothing here is seeded. A woman who has logged nothing has no plates, and
/// Home keeps whatever it opened with.
library;

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseFirestore;
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth;
import 'package:flutter/widgets.dart';

import '../domain/clock/app_clock.dart';
import '../features/eat/data/firestore_recipe_source.dart';
import '../features/eat/data/recipe_sync.dart';
import '../features/eat/data/seeded_recipe_library.dart';
import '../features/eat/domain/allergy_guard.dart';
import '../features/eat/domain/item_id.dart';
import '../features/eat/domain/meal_log_service.dart';
import '../features/eat/domain/meal_repository.dart';
import '../features/eat/domain/meal_sentence_parser.dart';
import '../features/eat/domain/meal_slot_state_machine.dart';
import '../features/eat/presentation/eat_day_view_model.dart';
import '../features/eat/presentation/eat_sample_library.dart';
import '../features/eat/presentation/meal_log_session.dart';
import '../features/today/domain/today_day.dart';
import '../domain/logging/log_command_bus.dart';
import '../l10n/app_l10n.dart';
import '../routing/app_router.dart';
import '../ui/app_undo_snackbar.dart';
import 'app_changes.dart';
import 'firebase_boot.dart';
import 'honest_notice.dart';

/// A plate she has actually eaten, with the figure her own log carried.
///
/// The kcal is **not** re-derived from the pack: [MealItem.kcal] is frozen onto
/// the item at log time with the pack version, so the number Home shows is the
/// number she logged even if the pack changes underneath it.
@immutable
class UsualPlate {
  const UsualPlate({
    required this.plateId,
    required this.items,
    required this.kcal,
    required this.timesEaten,
    required this.lastAt,
  });

  final String plateId;
  final List<PlateItem> items;
  final int kcal;
  final int timesEaten;
  final DateTime lastAt;

  /// What the plate is called on Home — the first food in it.
  String get foodId => items.first.foodId;

  PlateSuggestion get suggestion => PlateSuggestion(foodId: foodId, kcal: kcal);
}

class EatAppState {
  EatAppState._();

  static final EatAppState instance = EatAppState._();

  /// How many plates Home's meal card lists. Two, as the card is drawn.
  static const int kHomePlates = 2;

  MealLogSession? _session;

  /// The one bus every Eat screen logs through.
  ///
  /// Built lazily so `AppRouter.mealRepository` is read at first use rather than
  /// at class-load time, which is what keeps this file and the router free of an
  /// initialisation order between them.
  MealLogSession get session => _session ??= MealLogSession(
    repository: AppRouter.mealRepository,
    onCommitted: _committed,
  );

  final Map<String, UsualPlate> _plates = <String, UsualPlate>{};
  final Set<String> _saved = <String>{};

  /// Which recipe row she tapped, recorded inline at the tap.
  ///
  /// `goTo` pushes a route **name** and nothing else, so an id cannot ride along
  /// as an argument the way a `LogHandle` does — the same arrangement the
  /// community ids use. Without it E06 opened on koshari whichever row she
  /// pressed, over a Log button that wrote koshari.
  String? openRecipeId;

  // ------------------------------------------------------- Rahma's book ----

  /// Her thirty-nine cards, once the seed asset has been read.
  ///
  /// [RecipeBook.empty] until then, and every screen that draws it treats empty
  /// as "there is no book" rather than as "the book is missing" — E05 falls back
  /// to the four prototype rows, E06 to the food-backed page, and neither shows
  /// a spinner. A spinner on a library that is already on the handset would be
  /// a lie about where the data lives.
  RecipeBook recipeBook = RecipeBook.empty;

  Future<void>? _bookLoad;

  /// Starts the one read of the seed, and tells the open screens when it lands.
  ///
  /// Called from the Eat screens rather than from `main()` so that a build which
  /// never opens Eat never pays for it, and idempotent because three screens
  /// call it. The failure path is deliberately silent: a bundle read that fails
  /// leaves [recipeBook] empty, which every caller already handles, and there is
  /// nothing a woman could do about it.
  ///
  /// With no [library] given it reads [recipeSync]: the seed, or the last
  /// complete remote set cached on the phone, and then asks
  /// [refreshRecipes] whether the server has a newer one. That check is
  /// rate-limited inside [RecipeSync], so calling this from a build costs
  /// nothing after the first time.
  void ensureRecipeBook({RecipeLibrary? library}) {
    _bookLoad ??= (library ?? recipeSync).load().then(
      _adopt,
      onError: (_) {},
    );
    if (library == null) unawaited(refreshRecipes());
  }

  /// The bundled seed with the Firestore library laid over it.
  RecipeSync get recipeSync => _recipeSync ??= RecipeSync(
    seed: SeededRecipeLibrary(),
    source: _liveRecipeSource,
  );
  RecipeSync? _recipeSync;

  /// Swaps a newer library in for the open screens. Never throws.
  ///
  /// Called at start-up and on Eat open. When Eat has not been opened yet the
  /// new set is only cached, and the first open reads it from there.
  Future<void> refreshRecipes() async {
    try {
      final book = (await recipeSync.refresh()).book;
      if (book != null && _bookLoad != null) _adopt(book);
    } catch (_) {
      // The seed is already the answer.
    }
  }

  /// One reference swap of a finished book, so no screen can see half of one.
  /// An older book never replaces a newer one, whichever read lands last.
  void _adopt(RecipeBook book) {
    if (recipeBook.recipes.isNotEmpty &&
        book.contentVersion < recipeBook.contentVersion) {
      return;
    }
    recipeBook = book;
    AppChanges.bump();
  }

  /// Firestore, only when a read could succeed: Firebase is up and a verified
  /// account is signed in (the rules read `isVerified()`). Otherwise null, and
  /// nothing is read or billed.
  static RecipeRemoteSource? _liveRecipeSource() {
    try {
      if (!FirebaseBoot.isReady) return null;
      if (FirebaseAuth.instance.currentUser == null) return null;
      if (!AppRouter.isVerified) return null;
      return FirestoreRecipeSource(FirebaseFirestore.instance);
    } catch (_) {
      return null;
    }
  }

  /// Puts a book in place without touching the bundle. Tests only.
  @visibleForTesting
  void seedRecipeBook(RecipeBook book) {
    recipeBook = book;
    _bookLoad = Future<void>.value();
  }

  /// Her plates, most-eaten first and most-recent as the tie-break.
  ///
  /// Deliberately not [PlateRollup.rank]: that answers "what should E01 offer",
  /// and it holds a plate back until she has eaten it twice so a one-off meal is
  /// not suggested forever. Home's card is a different question — "the plate you
  /// had" — and a woman who logged one breakfast should see that breakfast.
  List<UsualPlate> get usualPlates {
    final plates = _plates.values.toList();
    plates.sort((a, b) {
      final byCount = b.timesEaten.compareTo(a.timesEaten);
      if (byCount != 0) return byCount;
      return b.lastAt.compareTo(a.lastAt);
    });
    return plates;
  }

  /// What Home's meal card lists.
  List<PlateSuggestion> get homePlates => [
    for (final plate in usualPlates.take(kHomePlates)) plate.suggestion,
  ];

  // ------------------------------------------------------------- recipes ----

  /// The dish in the food pack a recipe is *about*, or null when the pack has
  /// no such dish.
  ///
  /// E06 is built from the food it logs, because the recipe pack (G5 §1.2, ~120
  /// recipes) has not been built. The two sample sets were authored separately,
  /// so three of the seven recipe ids name a dish the food pack does not carry.
  /// Those map to null and E06 says so, rather than being pointed at the
  /// nearest-looking food — which would head the page with one dish and log
  /// another, the exact defect `recipe_view.dart` records for its old fixed
  /// koshari title.
  static String? foodForRecipe(String? recipeId) => switch (recipeId) {
    'koshari_portioned' => 'koshari_bowl',
    'molokhia_chicken' => 'molokhia_chicken',
    'lentil_soup_eggs' => 'lentil_soup_eggs',
    _ => null,
  };

  /// What E06 should open on: the dish behind the row she tapped, or the one
  /// the screen defaults to when it is opened cold (the All-screens index).
  ///
  /// The koshari fallback applies **only** to a cold open. It used to apply to
  /// every row [foodForRecipe] could not resolve, which is how tapping
  /// "Yoghurt, dates and nuts" produced a page headed "Koshari bowl" over a Log
  /// button that would have written koshari: `RecipeView` reads the food's own
  /// name first and only falls through to `title` when the id resolves to
  /// nothing. Handing back the recipe id instead resolves to nothing in the
  /// food pack, which is the truth, and the page then heads itself with the row
  /// she actually pressed and says the dish cannot be logged from here.
  String get openFoodId =>
      foodForRecipe(openRecipeId) ?? openRecipeId ?? 'koshari_bowl';

  /// The title E06 carries when the pack cannot name the dish for it.
  String? recipeTitle(AppL10n l10n) {
    final recipeId = openRecipeId;
    if (recipeId == null || foodForRecipe(recipeId) != null) return null;
    return recipeLabel(l10n, recipeId);
  }

  bool isSaved(String recipeId) => _saved.contains(recipeId);

  /// Saves or unsaves a recipe, and says which it did.
  ///
  /// Nothing is sent anywhere: there is no library to publish to and no account
  /// behind this build, so the bookmark is the icon on the page and this note.
  void toggleSaved(BuildContext context, String recipeId) {
    final l10n = AppL10n.of(context);
    final added = _saved.add(recipeId);
    if (!added) _saved.remove(recipeId);
    showHonestNotice(context, added ? l10n.saved : l10n.removedFromSaved);
    AppChanges.bump();
  }

  // ------------------------------------------------------------- logging ----

  /// Logs a plate from Home's meal card.
  ///
  /// Home carries a `foodId` and a figure, not a size, so the plate she actually
  /// ate is looked up here and logged at the size she ate it. A card still
  /// showing the plates the day opened with has no such record, and those fall
  /// back to the food's usual size — the middle one, which is the portion E06
  /// calls "the one you usually serve".
  LogHandle? logPlate(BuildContext context, String foodId) {
    final library = eatSampleLibrary(AppL10n.of(context));
    final plate = _plateFor(foodId);

    final entries = <ParsedItem>[];
    if (plate != null) {
      for (final item in plate.items) {
        final resolved = entryFor(library, item.foodId, sizeId: item.size);
        if (resolved == null) continue;
        entries.add(
          ParsedItem(
            food: resolved.food,
            size: resolved.size,
            servings: item.servings.toInt(),
            sourceText: resolved.sourceText,
          ),
        );
      }
    } else {
      final resolved = entryFor(library, foodId);
      if (resolved != null) entries.add(resolved);
    }

    return log(context, entries: entries, origin: MealOrigin.suggestion);
  }

  /// One tap. Saves immediately, offers five seconds, asks nothing.
  ///
  /// Returns the handle so the caller can carry it to the screen that draws the
  /// undo bar, or null when the domain refused — in which case the reason has
  /// already been said out loud.
  LogHandle? log(
    BuildContext context, {
    required List<ParsedItem> entries,
    required MealOrigin origin,
    DateTime? at,
  }) {
    if (entries.isEmpty) return null;
    final l10n = AppL10n.of(context);
    final now = at ?? AppClock.now();
    final slot = EatDayViewModel.slotAt(now);

    final outcome =
        MealLogService(
          repository: AppRouter.mealRepository,
          library: eatSampleLibrary(l10n),
          guard: AllergyGuard(AppRouter.eatConstraints),
        ).logNew(
          day: MealDay(dayId: dayIdOf(now)),
          slot: slot,
          entries: entries,
          source: MealSource.search,
          origin: origin,
          at: now,
        );

    if (outcome is MealLogRefused) {
      explainRefusal(context, outcome);
      return null;
    }

    final handle = session.submit(
      outcome as MealLogPrepared,
      slot: slot,
      describe: l10n.mealAdded,
    );
    // **No snackbar here.** This used to raise one and then hand the handle
    // back, and its only caller — Home's plate — carries that handle straight
    // to E04, which draws the in-page undo bar for it. Two offers for one meal
    // were on screen at once, reading the same sentence and closing half a
    // second apart, and the one she reached second reported false and changed
    // nothing. One log, one undo: carry the handle to the screen that draws the
    // bar, or call [showUndo] if you are staying put.
    return handle;
  }

  /// The five-second offer for a caller that does not carry the handle onward,
  /// wired so every screen showing the meal drops it the moment she takes it
  /// back. A caller that navigates to E04 must not also call this.
  void showUndo(BuildContext context, LogHandle handle) {
    showUndoSnackBar(
      context,
      handle: handle,
      undoLabel: AppL10n.of(context).undo,
      onUndo: settle,
    );
  }

  /// Call after something outside the session undid a handle — the snackbar and
  /// E04's undo bar both do — so every open screen redraws without it.
  void settle() {
    session.settle();
    AppChanges.bump();
  }

  /// Says why a log was refused, in the terms the refusal actually knows.
  ///
  /// The allergen sheet ("Not this" / "Log it anyway") is deliberately not
  /// raised here: it belongs to [AllergyBlockReason.namedAllergen], and that
  /// case needs `foods.allergens[]`, which is unauthored — so every refusal this
  /// build can reach is the *unknown* one, where there is no allergen to name
  /// and nothing for her to acknowledge. Offering an override on a dish nobody
  /// has listed would be asking her to accept a risk the product cannot state.
  void explainRefusal(BuildContext context, MealLogRefused refused) {
    final l10n = AppL10n.of(context);
    final assessment = refused.assessment;
    final dish = refused.dish;
    // `foodNotInPack` and `noDayContext` are structurally unreachable from the
    // screens — every row is built from the pack, and every log carries a day —
    // so there is no sentence for them rather than an invented one.
    if (refused.reason != LogRefusalReason.allergenOutstanding ||
        assessment == null) {
      return;
    }

    showHonestNotice(context, switch (assessment.reason) {
      AllergyBlockReason.namedAllergen => l10n.thisDishHasAllergenYouToldUs(
        assessment.allergens.map((a) => allergenLabel(l10n, a)).join(', '),
      ),
      // Her own words for the dish when the refusal named one, and the sentence
      // that states less when it did not.
      AllergyBlockReason.unknownAllergenData =>
        dish == null
            ? l10n.weCannotCheckTheseDishesForWhat
            : l10n.nobodyHasListedWhatIsInDish(dish),
      AllergyBlockReason.constraintsUnavailable => l10n.weDoNotKnowWhatYouAvoid,
      null => l10n.weDoNotKnowWhatYouAvoid,
    });
  }

  /// An allergen in her language. The four `A02` offers, and no others.
  static String allergenLabel(AppL10n l10n, String wireName) =>
      switch (wireName.trim().toLowerCase()) {
        'nuts' => l10n.nuts,
        'dairy' => l10n.dairy,
        'gluten' => l10n.gluten,
        'shellfish' => l10n.shellfish,
        _ => wireName,
      };

  /// `yyyy-MM-dd`, the key every meal document is filed under.
  static String dayIdOf(DateTime at) =>
      '${at.year.toString().padLeft(4, '0')}-'
      '${at.month.toString().padLeft(2, '0')}-'
      '${at.day.toString().padLeft(2, '0')}';

  /// Her plates, keyed the way they are stored, as the snapshot keeps them.
  ///
  /// [usualPlates] is the ordered view a screen wants; this is the map the
  /// storage layer writes. See `lib/app_state/local_persistence.dart`.
  Map<String, UsualPlate> get platesByIdentity =>
      Map<String, UsualPlate>.unmodifiable(_plates);

  /// The recipes she bookmarked.
  Set<String> get savedRecipes => Set<String>.unmodifiable(_saved);

  /// Puts back her plates and her bookmarks. The mirror of [reset].
  ///
  /// The log bus is deliberately not restored: a meal still inside its five
  /// seconds when the app closed was never written, and resurrecting it would
  /// be logging a meal she can no longer take back.
  void restore({
    Map<String, UsualPlate> plates = const <String, UsualPlate>{},
    Iterable<String> savedRecipes = const <String>[],
  }) {
    _plates
      ..clear()
      ..addAll(plates);
    _saved
      ..clear()
      ..addAll(savedRecipes);
  }

  /// Drops everything without writing it. For tests and sign-out.
  void reset() {
    _session?.reset();
    _session = null;
    _plates.clear();
    _saved.clear();
    openRecipeId = null;
  }

  // -------------------------------------------------------------- private ---

  UsualPlate? _plateFor(String foodId) {
    for (final plate in usualPlates) {
      if (plate.foodId == foodId) return plate;
    }
    return null;
  }

  /// A meal that has been **written** — never one still inside its window.
  void _committed(PendingMeal meal) {
    if (meal.items.isEmpty) return;

    final plateId = plateIdOf([
      for (final item in meal.items) (foodId: item.foodId, size: item.size),
    ]);
    final existing = _plates[plateId];
    _plates[plateId] = UsualPlate(
      plateId: plateId,
      items: [
        for (final item in meal.items)
          PlateItem(
            foodId: item.foodId,
            size: item.size,
            servings: item.servings,
          ),
      ],
      kcal: meal.items.fold(0, (sum, item) => sum + item.kcal),
      timesEaten: (existing?.timesEaten ?? 0) + 1,
      lastAt: meal.at,
    );

    AppRouter.todayRepository.recordMeal(at: meal.at, plates: homePlates);
    AppChanges.bump();
  }
}
