/// What the router needs from private coaching that is not a screen: where its
/// repository and the coach claim come from, and the small screens that join
/// the coaching views to the rest of the app (the chat threads, the coach
/// tabs' bottom bar).
///
/// Every navigation edge stays in `app_router.dart`, in the builder that owns
/// it, as a callback handed to these widgets.
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../app_state/eat_state.dart';
import '../ui/app_scaffold.dart' show AppTopBar;
import '../app_state/exercise_library_state.dart';
import '../domain/clock/app_clock.dart';
import '../features/eat/domain/allergy_guard.dart' show DietaryConstraints;
import '../features/eat/domain/meal_repository.dart' show MealSlot;
import '../features/eat/domain/meal_sentence_parser.dart' show ParsedItem;
import '../features/eat/data/egyptian_food_pack.dart';
import '../features/eat/data/seeded_recipe_library.dart';
import '../features/eat/domain/food_library.dart' show FoodLibrary;
import '../features/eat/presentation/eat_sample_library.dart';
import '../features/onboarding/domain/intake.dart' show LifeStage;
import '../features/private_coaching/presentation/client/coach_plan_view.dart';
import '../features/private_coaching/presentation/client/coach_today.dart';
import '../features/train/domain/my_plan.dart' show slotForPlanDay;
import '../app_state/custom_workout_state.dart' show CustomWorkoutState;
import '../features/private_coaching/presentation/client/my_coach_view.dart'
    show coachingEnded, requestClosed;
import '../app_state/workout_library_state.dart';
import '../features/onboarding/domain/starting_program.dart';
import '../features/private_coaching/presentation/plans/coach_plan_logic.dart';
import '../features/private_coaching/presentation/plans/schedule_session_sheet.dart';
import '../features/private_coaching/presentation/plans/share_meal_plan_view.dart';
import '../features/private_coaching/presentation/plans/share_workout_view.dart';
import '../features/train/domain/workout_library.dart' show AuthoredProgramme;

import '../features/account/domain/safety.dart' show BlockService;
import '../app_state/firebase_boot.dart';
import '../app_state/private_coaching_state.dart';
import '../features/private_coaching/data/chat_repository.dart';
import '../features/private_coaching/data/coaching_repository.dart';
import '../features/private_coaching/data/firestore_coaching_repository.dart';
import '../features/private_coaching/domain/chat_message.dart';
import '../features/private_coaching/domain/coach_plan.dart';
import '../features/private_coaching/domain/coach_profile.dart';
import '../features/private_coaching/domain/subscription.dart';
import '../features/private_coaching/presentation/chat/chat_list_view.dart';
import '../features/private_coaching/presentation/chat/chat_logic.dart';
import '../features/private_coaching/presentation/chat/chat_sheets.dart';
import '../features/private_coaching/presentation/chat/chat_thread_view.dart';
import '../features/private_coaching/domain/coaching_contract.dart';
import '../features/private_coaching/presentation/desk/desk_model.dart'
    show tagOf;
import '../features/private_coaching/presentation/desk/desk_text.dart';
import '../l10n/app_l10n.dart';
import '../ui/app_nav_bar.dart';

/// The production repository, or null while Firebase is not up (a phone with
/// no back end, and every test that does not provide one).
CoachingRepository? defaultCoachingRepository() =>
    FirebaseBoot.isReady ? FirestoreCoachingRepository() : null;

/// Whether the signed-in woman holds the `coachV` claim. [refresh] asks the
/// server for a new token first, which is how an approval reaches the phone
/// before the hourly refresh would.
Future<bool> readCoachClaim({bool refresh = false}) async {
  if (!FirebaseBoot.isReady) return false;
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    final token = await user.getIdTokenResult(refresh);
    return token.claims?['coachV'] == 'active';
  } catch (_) {
    return false;
  }
}

/// The page shown while a coaching screen has nothing to draw yet: the
/// standard bar (back, picture, language switch) over a quiet body.
Widget quietCoachingFrame(VoidCallback? onBack, {bool loading = false}) =>
    Scaffold(
      appBar: AppTopBar(onBack: onBack),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : const SizedBox.shrink(),
    );

/// A coach tab: the page and the coach's bottom bar under it.
class CoachTabFrame extends StatelessWidget {
  const CoachTabFrame({
    super.key,
    required this.activeScreenId,
    required this.onSelectTab,
    required this.child,
  });

  final String activeScreenId;
  final ValueChanged<String> onSelectTab;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: AppNavBar(
        activeScreenId: activeScreenId,
        destinations: coachTabs,
        onSelect: onSelectTab,
      ),
    );
  }
}

/// The coach's chat tab: every conversation she is in, newest first.
class CoachingChatListScreen extends StatelessWidget {
  const CoachingChatListScreen({super.key, required this.onOpen, this.onBack});

  final void Function(Relationship relationship) onOpen;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final state = PrivateCoachingState.instance;
    final myUid = state.repository?.uid;
    if (myUid == null) return quietCoachingFrame(onBack);
    final l10n = AppL10n.of(context);
    String nameOfClient(String uid) {
      for (final s in state.coachSubscriptions) {
        if (s.clientUid == uid) return clientName(l10n, s);
      }
      return l10n.clientTag(tagOf(uid));
    }

    return ChatListView(
      relationships: state.relationships,
      myUid: myUid,
      personOf: (uid) => ChatPerson(uid: uid, name: nameOfClient(uid)),
      onOpen: onOpen,
      onBack: onBack,
    );
  }
}

/// One conversation, for either side.
class CoachingThreadScreen extends StatelessWidget {
  const CoachingThreadScreen({
    super.key,
    required this.relId,
    this.blocks,
    this.shareOf,
    this.recipeTitleOf,
    this.onOpenPlan,
    this.onOpenRecipe,
    this.onBack,
  });

  final String relId;
  final BlockService? blocks;

  /// The coach's "+" choices for this relationship; none for a client.
  final ShareChoices Function(Relationship relationship)? shareOf;
  final String? Function(String recipeId)? recipeTitleOf;
  final void Function(ChatMessage plan)? onOpenPlan;
  final void Function(String recipeId)? onOpenRecipe;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final state = PrivateCoachingState.instance;
    final repository = state.repository;
    final myUid = repository?.uid;
    final rel = state.relationshipOf(relId);
    if (repository is! ChatThreadRepository || myUid == null || rel == null) {
      return quietCoachingFrame(onBack);
    }
    final iAmClient = myUid == rel.clientUid;
    final l10n = AppL10n.of(context);

    Widget thread(ChatPerson person) => ChatThreadView(
      repository: repository,
      relId: rel.id,
      myUid: myUid,
      person: person,
      otherIsCoach: iAmClient,
      subId: rel.activeSubId,
      open: rel.status == RelationshipStatus.active && rel.chatOpen,
      unreadAtOpen: rel.unreadOf(myUid),
      blocks: blocks,
      share: iAmClient
          ? const ShareChoices()
          : (shareOf?.call(rel) ?? const ShareChoices()),
      recipeTitleOf: recipeTitleOf,
      onOpenPlan: onOpenPlan,
      onOpenRecipe: onOpenRecipe,
      onBack: onBack,
    );

    if (!iAmClient) {
      Subscription? sub;
      for (final s in state.coachSubscriptions) {
        if (s.clientUid == rel.clientUid) {
          sub = s;
          if (s.status == SubscriptionStatus.active) break;
        }
      }
      return thread(
        ChatPerson(
          uid: rel.clientUid,
          name: sub == null
              ? l10n.clientTag(tagOf(rel.id))
              : clientName(l10n, sub),
        ),
      );
    }
    return StreamBuilder<CoachProfile?>(
      stream: repository.watchCoach(rel.coachUid),
      builder: (context, snap) {
        final coach = snap.data;
        return thread(
          ChatPerson(
            uid: rel.coachUid,
            name: coach == null || coach.displayName.isEmpty
                ? l10n.myCoach
                : coach.displayName,
            photoUrl: coach?.photoUrl,
          ),
        );
      },
    );
  }
}

/// The newest workout or meal plan of [kind] her coach shared, or null.
CoachPlan? latestCoachPlan(PlanKind kind) {
  CoachPlan? best;
  for (final plan in PrivateCoachingState.instance.coachPlansOf(kind)) {
    final at = plan.publishedAt;
    if (best == null ||
        (at != null &&
            (best.publishedAt == null || at.isAfter(best.publishedAt!)))) {
      best = plan;
    }
  }
  return best;
}

/// What the portfolio route is asked for: a coach, and whether it is her own
/// page seen as a member would see it.
class CoachPortfolioArgs {
  const CoachPortfolioArgs(this.uid, {this.preview = false});

  final String uid;
  final bool preview;
}

/// The three coach splits, as they are written.
List<AuthoredProgramme> coachSplits() => <AuthoredProgramme>[
  for (final p in StartingProgrammes.catalogue)
    ?StartingProgrammes.programme(p.programId),
];

/// The bundled recipes and the whole food pack, for a coach plan: the only
/// ids the server accepts in one, so never her own typed or community foods.
MealCatalog coachMealCatalog(AppL10n l10n) {
  final eat = EatAppState.instance
    ..ensureFoodPack()
    ..ensureRecipeBook();
  final seeded = SeededRecipeLibrary.seededIds;
  return MealCatalog(
    recipes: [
      for (final r in eat.recipeBook.recipes)
        if (seeded == null || seeded.contains(r.recipeId)) r,
    ],
    foods: FoodLibrary(EgyptianFoodPack.allFoods(l10n)),
  );
}

Subscription? coachSubscriptionOf(String subId) {
  for (final s in PrivateCoachingState.instance.coachSubscriptions) {
    if (s.id == subId) return s;
  }
  return null;
}

/// The coach's workout builder for one client.
class ShareWorkoutScreen extends StatelessWidget {
  const ShareWorkoutScreen({super.key, required this.subId, this.onBack});

  final String subId;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final repository = PrivateCoachingState.instance.repository;
    final sub = coachSubscriptionOf(subId);
    if (repository == null || sub == null) {
      return quietCoachingFrame(onBack);
    }
    final library = ExerciseLibraryState.instance;
    return StreamBuilder<List<CoachDraft>>(
      stream: repository.watchDrafts(),
      builder: (context, drafts) => ShareWorkoutView(
        repository: repository,
        subscription: sub,
        clientName: clientName(AppL10n.of(context), sub),
        splits: coachSplits(),
        templates: <CoachDraft>[
          for (final d in drafts.data ?? const <CoachDraft>[])
            if (d.kind == PlanKind.workout) d,
        ],
        exercises: library.library.exercises,
        media: library.media,
        players: library.players,
        onBack: onBack,
        onPublished: (_, _) => onBack?.call(),
      ),
    );
  }
}

/// The coach's meal-plan builder for one client.
class ShareMealScreen extends StatelessWidget {
  const ShareMealScreen({super.key, required this.subId, this.onBack});

  final String subId;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final repository = PrivateCoachingState.instance.repository;
    final sub = coachSubscriptionOf(subId);
    if (repository == null || sub == null) {
      return quietCoachingFrame(onBack);
    }
    final l10n = AppL10n.of(context);
    return StreamBuilder<List<CoachDraft>>(
      stream: repository.watchDrafts(),
      builder: (context, drafts) => ShareMealPlanView(
        repository: repository,
        subscription: sub,
        catalog: coachMealCatalog(l10n),
        clientName: clientName(l10n, sub),
        templates: <CoachDraft>[
          for (final d in drafts.data ?? const <CoachDraft>[])
            if (d.kind == PlanKind.meal) d,
        ],
        onBack: onBack,
        onPublished: (_, _) => onBack?.call(),
      ),
    );
  }
}

/// The coach's session sheet for one client.
Future<void> openScheduleSession(BuildContext context, String subId) async {
  final repository = PrivateCoachingState.instance.repository;
  final sub = coachSubscriptionOf(subId);
  if (repository == null || sub == null) return;
  var sessions = const <LiveSession>[];
  try {
    sessions = await repository
        .watchSessions(subId)
        .first
        .timeout(const Duration(seconds: 5));
  } catch (_) {
    // The sheet checks against what it has; the server checks again.
  }
  if (!context.mounted) return;
  await showScheduleSessionSheet(
    context: context,
    repository: repository,
    subscription: sub,
    sessions: sessions,
    clientName: clientName(AppL10n.of(context), sub),
  );
}

/// The coach's recipe picker: one recipe from the book into the chat.
Future<void> pickRecipeToSend(BuildContext context, String relId) async {
  final repository = PrivateCoachingState.instance.repository;
  if (repository == null) return;
  final eat = EatAppState.instance..ensureRecipeBook();
  final language = Localizations.localeOf(context).languageCode;
  final l10n = AppL10n.of(context);
  final id = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (sheet) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              l10n.recipes,
              style: Theme.of(sheet).textTheme.titleMedium,
            ),
          ),
          for (final r in eat.recipeBook.recipes)
            ListTile(
              minVerticalPadding: 12,
              title: Text(
                language == 'ar' && (r.titleAr ?? '').isNotEmpty
                    ? r.titleAr!
                    : r.titleEn,
              ),
              onTap: () => Navigator.of(sheet).pop(r.recipeId),
            ),
        ],
      ),
    ),
  );
  if (id == null) return;
  try {
    await repository.sendRecipe(relId, id);
  } catch (_) {
    // The thread shows the line as unsent and she can send it again.
  }
}

/// Her subscription as a client that My coach shows: the one running or being
/// set up, else the newest one that ended.
Subscription? currentCoachingAsClient() {
  final state = PrivateCoachingState.instance;
  final current = state.currentAsClient;
  if (current != null) return current;
  for (final s in state.clientSubscriptions) {
    if (coachingEnded(s) || requestClosed(s)) return s;
  }
  return null;
}

/// The workout plan her active coach shared (the newest), or null.
CoachPlan? activeCoachWorkoutPlan() {
  final sub = PrivateCoachingState.instance.activeAsClient;
  if (sub == null) return null;
  CoachPlan? best;
  for (final plan in PrivateCoachingState.instance.coachPlansOf(
    PlanKind.workout,
  )) {
    if (plan.workout == null || plan.coachUid != sub.coachUid) continue;
    final at = plan.publishedAt;
    if (best == null ||
        (at != null &&
            (best.publishedAt == null || at.isAfter(best.publishedAt!)))) {
      best = plan;
    }
  }
  return best;
}

/// Opens day [dayIndex] of [plan] as the next workout. False when that day is
/// not offered at her life stage.
bool startCoachWorkout(CoachPlan plan, int dayIndex, LifeStage? stage) {
  final workout = plan.workout;
  if (workout == null) return false;
  final slot = slotForPlanDay(workout, dayIndex, stage);
  if (slot == null) return false;
  CustomWorkoutState.instance.clearDraft();
  WorkoutLibraryState.instance
    ..chosenRowId = null
    ..openedSlot = slot;
  return true;
}

/// Logs one item of a coach's meal plan. A food goes through the allergy guard
/// and the shared undo window; a recipe has no log of its own, so it opens
/// ([openRecipe]) where she can read it first.
void logCoachMeal(
  BuildContext context, {
  required CoachPlan plan,
  required MealItem item,
  required String slot,
  required void Function(String recipeId) openRecipe,
}) {
  if (item.kind == MealItemKind.recipe) {
    openRecipe(item.recipeId ?? '');
    return;
  }
  if (item.kind != MealItemKind.food) return;
  final l10n = AppL10n.of(context);
  final library = eatSampleLibrary(l10n);
  final food = library.byId(item.foodId ?? '');
  if (food == null) return;
  final grams = item.grams;
  final size =
      (grams == null ? null : food.sizeForGrams(grams)) ?? food.defaultSize;
  final mealSlot = MealSlot.values.asNameMap()[slot];
  if (mealSlot == null) return;
  final today = todaysMealDay(plan, AppClock.now());
  final items = today == null
      ? const <MealItem>[]
      : plan.meal!.days[today].itemsIn(slot);
  final eat = EatAppState.instance;
  final handle = eat.logPlanned(
    context,
    slot: mealSlot,
    index: items.indexOf(item).clamp(0, 99),
    entry: ParsedItem(
      food: food,
      size: size,
      servings: 1,
      sourceText: food.names.first,
    ),
  );
  if (handle != null) eat.showUndo(context, handle);
}

/// A plan her coach shared: the workout days with Start, or the meals with a
/// log for each.
class CoachPlanScreen extends StatelessWidget {
  const CoachPlanScreen({
    super.key,
    required this.planId,
    this.lifeStage,
    this.constraints = DietaryConstraints.unknown,
    this.onStartWorkout,
    this.onOpenRecipe,
    this.onLog,
    this.onBack,
  });

  final String planId;
  final LifeStage? lifeStage;
  final DietaryConstraints constraints;
  final void Function(CoachPlan plan, int dayIndex)? onStartWorkout;
  final void Function(String recipeId)? onOpenRecipe;
  final void Function(CoachPlan plan, MealItem item, String slot)? onLog;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    CoachPlan? plan;
    for (final p in PrivateCoachingState.instance.coachPlans) {
      if (p.id == planId) plan = p;
    }
    if (plan == null) {
      return quietCoachingFrame(onBack);
    }
    final shown = plan;
    final library = ExerciseLibraryState.instance;
    return CoachPlanView(
      plan: shown,
      lifeStage: lifeStage,
      constraints: constraints,
      catalog: coachMealCatalog(AppL10n.of(context)),
      exercises: library.library.exercises,
      media: library.media,
      players: library.players,
      onStartWorkout: onStartWorkout == null
          ? null
          : (day) => onStartWorkout!(shown, day),
      onOpenRecipe: onOpenRecipe,
      onLog: onLog == null ? null : (item, slot) => onLog!(shown, item, slot),
      onBack: onBack,
    );
  }
}
