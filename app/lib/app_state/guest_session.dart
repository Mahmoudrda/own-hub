/// Guest mode: what a woman who has not signed in yet may do, and what happens
/// to the one thing she tried that needs an account.
///
/// Browsing is open (Home, Train, Eat, recipes, her profile). Anything that
/// saves goes through [GuestSession.require]: the action is kept on this phone
/// with its payload, she is taken to Rahma's welcome and then to sign-up, and
/// once she is verified [GuestSession.resume] replays it exactly once.
///
/// Guests are local-only. This file opens no cloud path: the cloud sync stays
/// shut until the server says she is verified, and nothing here changes that.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';

import '../domain/clock/app_clock.dart';
import '../domain/flags/feature_flags.dart';
import '../features/eat/domain/meal_repository.dart';
import '../features/eat/domain/meal_sentence_parser.dart';
import '../features/eat/presentation/eat_sample_library.dart';
import '../features/train/domain/train_repository.dart'
    show EndedReason, SessionSource;
import '../l10n/app_l10n.dart';
import '../routing/app_router.dart';
import '../routing/app_routes.dart';
import 'app_changes.dart';
import 'demo_mode.dart';
import 'eat_state.dart';
import 'snapshot_owner.dart';
import 'workout_session_state.dart';

/// The things a guest can try that need an account.
enum PendingKind { startWorkout, logMeal, favourite, bookmarkRecipe, savePlan }

/// Which side of the welcome she chose, so C06 opens on the right wording.
enum AuthIntent { signUp, signIn }

/// One kept action and what it needs to be replayed.
@immutable
class PendingAction {
  const PendingAction(this.kind, {this.payload = const <String, Object?>{}});

  /// Opening Today's workout (R03), then starting it.
  const PendingAction.startWorkout() : this(PendingKind.startWorkout);

  /// "Save my plan" on O05. The answers are already on the phone; this only
  /// remembers that she asked.
  const PendingAction.savePlan() : this(PendingKind.savePlan);

  /// A meal she was about to log: each item by food, size and servings.
  factory PendingAction.logMeal(
    List<ParsedItem> entries, {
    required MealOrigin origin,
  }) => PendingAction(
    PendingKind.logMeal,
    payload: <String, Object?>{
      'origin': origin.name,
      'items': [
        for (final entry in entries)
          <String, Object?>{
            'food': entry.food.foodId,
            'size': entry.size.id,
            'servings': entry.servings,
          },
      ],
    },
  );

  factory PendingAction.favourite(String foodId) => PendingAction(
    PendingKind.favourite,
    payload: <String, Object?>{'food': foodId},
  );

  factory PendingAction.bookmarkRecipe(String recipeId) => PendingAction(
    PendingKind.bookmarkRecipe,
    payload: <String, Object?>{'recipe': recipeId},
  );

  final PendingKind kind;
  final Map<String, Object?> payload;

  Map<String, Object?> toJson() => <String, Object?>{
    'kind': kind.name,
    'payload': payload,
  };

  static PendingAction? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final kind = PendingKind.values
        .where((value) => value.name == raw['kind'])
        .firstOrNull;
    if (kind == null) return null;
    final payload = raw['payload'];
    return PendingAction(
      kind,
      payload: payload is Map
          ? Map<String, Object?>.from(payload)
          : const <String, Object?>{},
    );
  }
}

class GuestSession {
  GuestSession._();

  static final GuestSession instance = GuestSession._();

  /// The screens a woman without an account can open. Everything else stays
  /// behind the gate. R03 is view only: starting it is a protected action,
  /// except her first workout (D62, [mayStartFirstWorkout]).
  static const Set<String> screens = {
    'T01',
    'R01',
    'R02',
    'R03',
    'R04',
    'R15',
    'E01',
    'E02',
    'E05',
    'E06',
    'A02',
  };

  /// The live-workout screens a guest may open, and only while her first
  /// workout is under way or has just finished ([mayOpenForFirstWorkout], D62).
  static const Set<String> workoutScreens = {'R06', 'R07', 'R08', 'R09', 'R10'};

  /// Workouts she has finished on this phone: measured and closed as
  /// finished. A session with no set logged, or one she discarded, is closed
  /// as abandoned (`WorkoutSessionState`), so it does not use up the guest
  /// workout. Read from the sessions themselves, so it holds after the app is
  /// closed.
  static int finishedWorkouts() => AppRouter.trainRepository.sessions
      .where(
        (s) =>
            s.source == SessionSource.live &&
            s.completed &&
            s.endedReason == EndedReason.finished,
      )
      .length;

  static bool get _guestWithNoAccount =>
      AppRouter.featureFlags.isOn(Feature.guestFirstWorkout) &&
      isBrowsing &&
      AppRouter.signedInUid == null;

  /// Whether she may start a workout without an account (D62): the switch is
  /// on, she has no account, her setup is done (life-stage screening runs
  /// there, before the plan) and she has finished no workout yet. Never inside
  /// the sample tour, which raises the join sheet instead.
  static bool mayStartFirstWorkout(BuildContext context) =>
      DemoScope.maybeOf(context) == null &&
      _guestWithNoAccount &&
      AppRouter.intakeRepository.setupDone &&
      finishedWorkouts() == 0;

  /// Whether this guest may open [screenId] as part of her first workout: any
  /// live screen while it is under way, and R10 alone once it has finished, so
  /// the finished page opens but no second workout can be started from it.
  static bool mayOpenForFirstWorkout(String screenId) {
    if (!workoutScreens.contains(screenId) || !_guestWithNoAccount) return false;
    final session = WorkoutSessionState.instance;
    final finished = finishedWorkouts();
    if (session.day != null && finished == 0) return true;
    return screenId == 'R10' && session.lastFinished != null && finished <= 1;
  }

  /// A kept action is dropped after this long, so a meal she walked away from
  /// is never logged days later.
  static const Duration keptFor = Duration(hours: 24);

  /// Replaced in tests.
  @visibleForTesting
  static DateTime Function() clock = AppClock.now;

  PendingAction? pending;
  DateTime? pendingAt;

  /// Set by the welcome's CTA, read by C06.
  AuthIntent intent = AuthIntent.signUp;

  /// A woman who is signed in with her check still open chose "Keep
  /// exploring" on C14: she browses as a guest until the check is done.
  bool exploring = false;

  /// What [favouriteHandler] needs to replay a kept favourite. Set by Eat once
  /// favourites exist.
  static FutureOr<void> Function(BuildContext context, String foodId)?
  favouriteHandler;

  bool _resuming = false;

  /// True when the app is closed to her: an account is required and she has
  /// not been verified.
  static bool get isGuest =>
      AppRouter.featureFlags.isOn(Feature.accountRequired) &&
      !AppRouter.isVerified;

  /// True when this phone holds the data of an account that signed out. A
  /// signed-out phone like that is not a guest's: Home would draw her meals
  /// and her week for whoever picks it up, so it opens on the front door, as
  /// it did before guest mode. A fresh install, or a phone after "delete
  /// everything", has no owner.
  static bool get phoneHasOwner => SnapshotOwner.instance.owner != null;

  /// True when she may browse the [screens] above: signed out on a phone with
  /// no previous account's data, or signed in with the check open and "Keep
  /// exploring" chosen.
  static bool get isBrowsing =>
      isGuest &&
      ((AppRouter.signedInUid == null && !phoneHasOwner) || instance.exploring);

  /// Asks for an account before [action]. True means go ahead.
  ///
  /// False means the action has been kept and she is on her way: to Rahma's
  /// welcome when she has no account, to her check when she has one that is
  /// not finished. Inside the sample tour it raises the join sheet instead.
  static bool require(BuildContext context, PendingAction action) {
    if (!isGuest) return true;
    if (DemoScope.maybeOf(context) case final demo?) {
      demo.requestJoin(context);
      return false;
    }
    instance._keep(action);
    if (AppRouter.signedInUid != null) {
      AppRouter.openAccountCheck(context);
      return false;
    }
    AppRouter.openFounderWelcome(context, intent: AuthIntent.signUp);
    return false;
  }

  void _keep(PendingAction action) {
    pending = action;
    pendingAt = clock();
    AppChanges.bump();
  }

  /// Forgets the kept action without replaying it.
  void cancel() {
    if (pending == null) return;
    pending = null;
    pendingAt = null;
    AppChanges.bump();
  }

  /// Back to a guest with nothing kept: sign-out and account deletion.
  void reset() {
    pending = null;
    pendingAt = null;
    exploring = false;
    intent = AuthIntent.signUp;
    _resuming = false;
  }

  /// C14's "Keep exploring": back to Home as a guest with her check still
  /// open. Clears the stack so Back does not return to the wait.
  static void keepExploring(BuildContext context) {
    instance.exploring = true;
    AppChanges.bump();
    unawaited(
      Navigator.of(context)
          .pushNamedAndRemoveUntil(appRoutes['T01']!.name, (_) => false),
    );
  }

  /// Replays the kept action once she is verified. Does nothing before that,
  /// and nothing a second time: the action is cleared and stored before it
  /// runs.
  Future<void> resume(BuildContext context) async {
    final action = pending;
    if (action == null || _resuming || !AppRouter.isVerified) return;
    _resuming = true;
    exploring = false;
    final at = pendingAt;
    pending = null;
    pendingAt = null;
    AppChanges.bump();
    try {
      if (at != null && clock().difference(at) > keptFor) return;
      if (!context.mounted) return;
      await _replay(context, action);
    } finally {
      _resuming = false;
    }
  }

  Future<void> _replay(BuildContext context, PendingAction action) async {
    switch (action.kind) {
      case PendingKind.savePlan:
        return;
      case PendingKind.startWorkout:
        AppRouter.openSessionStart(context);
      case PendingKind.logMeal:
        _replayMeal(context, action.payload);
      case PendingKind.bookmarkRecipe:
        final recipe = action.payload['recipe'];
        if (recipe is! String) return;
        final eat = EatAppState.instance;
        if (!eat.isSaved(recipe)) eat.toggleSaved(context, recipe);
        eat.openRecipeId = recipe;
        AppRouter.openRecipeDetail(context);
      case PendingKind.favourite:
        final food = action.payload['food'];
        final handler = favouriteHandler;
        if (food is String && handler != null) await handler(context, food);
    }
  }

  void _replayMeal(BuildContext context, Map<String, Object?> payload) {
    final items = payload['items'];
    if (items is! List) return;
    final library = eatSampleLibrary(AppL10n.of(context));
    final entries = <ParsedItem>[];
    for (final item in items) {
      if (item is! Map) continue;
      final entry = entryFor(
        library,
        '${item['food']}',
        sizeId: item['size'] as String?,
      );
      if (entry == null) continue;
      final servings = item['servings'];
      entries.add(
        ParsedItem(
          food: entry.food,
          size: entry.size,
          servings: servings is int && servings > 0 ? servings : 1,
          sourceText: entry.sourceText,
        ),
      );
    }
    if (entries.isEmpty) return;
    final origin = MealOrigin.values
        .where((value) => value.name == payload['origin'])
        .firstOrNull;
    final eat = EatAppState.instance;
    final handle = eat.log(
      context,
      entries: entries,
      origin: origin ?? MealOrigin.search,
    );
    if (handle == null) return;
    AppRouter.openLoggedDay(context);
    eat.showUndo(context, handle);
  }

  /// For the T01 builder: replays a kept action after the frame, once.
  void resumeAfterFrame(BuildContext context) {
    if (pending == null || !AppRouter.isVerified) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) unawaited(resume(context));
    });
  }
}
