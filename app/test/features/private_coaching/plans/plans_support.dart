// Test doubles and fixtures for the plan and My coach tests.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:own_hub/features/eat/domain/food_library.dart';
import 'package:own_hub/features/eat/domain/recipe.dart';
import 'package:own_hub/features/private_coaching/data/coaching_repository.dart';
import 'package:own_hub/features/private_coaching/domain/coach_plan.dart';
import 'package:own_hub/features/private_coaching/domain/coach_profile.dart';
import 'package:own_hub/features/private_coaching/domain/coaching_contract.dart';
import 'package:own_hub/features/private_coaching/domain/coaching_failure.dart';
import 'package:own_hub/features/private_coaching/domain/subscription.dart';
import 'package:own_hub/features/private_coaching/presentation/plans/coach_plan_logic.dart';
import 'package:own_hub/features/onboarding/domain/intake.dart' show LifeStage;
import 'package:own_hub/features/train/domain/my_plan.dart';
import 'package:own_hub/features/train/domain/workout_library.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';

/// Records the calls the plan screens make. Anything else is not expected.
class RecordingRepo implements CoachingRepository {
  RecordingRepo({this.uid = 'client1'});

  @override
  String? uid;

  final List<(String, Map<String, Object?>)> calls = [];
  List<LiveSession> sessions = const [];
  int watchCoachCalls = 0;
  int watchSessionCalls = 0;
  CoachingFailure? failEnd;
  CoachingFailure? failPublish;
  CoachingFailure? Function(String subId)? failPublishFor;

  @override
  Future<SubscriptionStatus> endMyCoaching(
    String subId, {
    String? reason,
  }) async {
    calls.add(('endMyCoaching', {'subId': subId}));
    final failure = failEnd;
    if (failure != null) throw failure;
    return SubscriptionStatus.endedEarly;
  }

  @override
  Future<SubscriptionStatus> cancelCoachingRequest(String subId) async {
    calls.add(('cancelCoachingRequest', {'subId': subId}));
    return SubscriptionStatus.cancelled;
  }

  @override
  Future<({String planId, int revision})> publishCoachPlan({
    required String subId,
    required String name,
    MyPlan? workout,
    MealPlanBody? meal,
    String? planId,
    String? startsOn,
  }) async {
    calls.add((
      'publish',
      publishPlanRequest(
        subId: subId,
        name: name,
        workout: workout,
        meal: meal,
        planId: planId,
        startsOn: startsOn,
      ),
    ));
    final refused = failPublishFor?.call(subId) ?? failPublish;
    if (refused != null) throw refused;
    return (planId: planId ?? 'plan1', revision: 1);
  }

  @override
  Future<String> saveDraft(CoachDraft draft) async {
    calls.add(('saveDraft', {...draft.toWrite()}));
    return 'draft1';
  }

  @override
  Future<String> scheduleLiveSession({
    required String subId,
    required DateTime startsAt,
    required int minutes,
    required String link,
  }) async {
    calls.add((
      'schedule',
      {'subId': subId, 'startsAt': startsAt, 'minutes': minutes, 'link': link},
    ));
    return 's1';
  }

  @override
  Future<SessionStatus> respondLiveSession({
    required String subId,
    required String sessionId,
    required bool confirm,
  }) async {
    calls.add(('respond', {'sessionId': sessionId, 'confirm': confirm}));
    return confirm ? SessionStatus.confirmed : SessionStatus.declined;
  }

  @override
  Future<({SessionStatus status, int sessionsUsed})> markSessionDone({
    required String subId,
    required String sessionId,
  }) async {
    calls.add(('done', {'sessionId': sessionId}));
    return (status: SessionStatus.confirmed, sessionsUsed: 0);
  }

  @override
  Stream<CoachProfile?> watchCoach(String coachUid) {
    watchCoachCalls++;
    return Stream.value(CoachProfile(uid: coachUid, displayName: 'Coach Sara'));
  }

  @override
  Stream<List<LiveSession>> watchSessions(String subId) {
    watchSessionCalls++;
    return Stream.value(sessions);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

Widget host(
  Widget child, {
  Locale locale = const Locale('en'),
  double scale = 1,
}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppL10n.localizationsDelegates,
  supportedLocales: AppL10n.supportedLocales,
  theme: buildTheme(locale),
  builder: (context, c) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: c!,
  ),
  home: child,
);

Subscription sub({
  List<String> allergies = const [],
  SubscriptionStatus status = SubscriptionStatus.active,
  int included = 4,
  int used = 1,
  DateTime? endsAt,
  Intake? intake,
}) => Subscription(
  id: 'sub1',
  coachUid: 'coach1',
  clientUid: 'client1',
  status: status,
  package: const PackageSnapshot(title: 'Monthly'),
  sessionsIncluded: included,
  sessionsUsed: used,
  endsAt: endsAt ?? DateTime.utc(2026, 11, 20),
  intake: intake ?? Intake(allergies: allergies),
);

AuthoredMove move(String id, {List<String> tags = const ['none']}) =>
    AuthoredMove(
      exerciseId: id,
      nameEn: 'Move $id',
      nameAr: 'تمرين $id',
      sets: 3,
      reps: 10,
      contraindications: tags,
    );

AuthoredProgramme split() => AuthoredProgramme(
  programId: 'split3',
  titleEn: 'Three days',
  titleAr: 'تلات أيام',
  status: ProgrammeStatus.published,
  sessions: [
    for (final d in ['a', 'b'])
      AuthoredSession(
        sessionId: d,
        titleEn: 'Day $d',
        titleAr: 'يوم $d',
        minutes: 40,
        lifeStages: const {LifeStage.none, LifeStage.pregnant},
        moves: [move('${d}1'), move('${d}2')],
      ),
  ],
);

MyPlan workoutPlan() => MyPlan.fork(split());

Recipe recipe(
  String id, {
  Set<String> allergens = const {},
  bool known = true,
  int? kcal = 400,
  List<RecipeIngredient> ingredients = const [],
  int serves = 1,
}) => Recipe(
  recipeId: id,
  source: RecipeSource.book,
  sectionId: 's',
  orderInSection: 1,
  status: RecipeStatus.published,
  version: 1,
  titleEn: 'Dish $id',
  titleAr: 'طبق $id',
  titleSearch: [id],
  bodyAr: '',
  ingredients: ingredients,
  serves: serves,
  ingredientsBasis: IngredientsBasis.measures,
  steps: const [],
  variants: const [],
  components: const [],
  kcal: kcal,
  proteinG: 20,
  carbsG: 30,
  fatG: 10,
  macroBasis: kcal == null ? MacroBasis.withheld : MacroBasis.computed,
  allergensDerived: allergens,
  allergensExtra: const {},
  allergensRemoved: const {},
  allergensFinal: allergens,
  advisories: const {},
  dietTags: const {},
  authoredBy: 'rahma_mohsen',
  allergenReviewedBy: known ? 'qa' : null,
  tier: RecipeTier.free,
  brandHints: const {},
);

Food food(String id, {Set<String>? allergens}) => Food(
  foodId: id,
  names: ['Food $id'],
  allergens: allergens,
  sizes: const [
    FoodSize(
      id: 'M',
      label: 'M',
      kcal: 200,
      proteinG: 10,
      carbsG: 20,
      fatG: 5,
      grams: 100,
    ),
  ],
);

MealCatalog catalog({List<Recipe>? recipes}) => MealCatalog(
  recipes:
      recipes ??
      [
        recipe('r1'),
        recipe('r2', allergens: {'sesame'}),
        recipe('r3', known: false),
      ],
  foods: FoodLibrary([food('f1', allergens: {}), food('f2')]),
);

MealPlanBody mealBody() => MealPlanBody(
  days: [
    MealDay(
      label: 'Day 1',
      slots: {
        'breakfast': [MealItem.recipe('r1', 2)],
        'lunch': [MealItem.food('f1', 150), MealItem.free('Fruit')],
        'dinner': [MealItem.recipe('r2', 1)],
      },
    ),
  ],
);

class AuthoredSessionFor {
  static AuthoredSession make(List<AuthoredMove> moves) => AuthoredSession(
    sessionId: 'mine_1',
    titleEn: 'D',
    titleAr: 'D',
    minutes: 30,
    lifeStages: const {LifeStage.none, LifeStage.pregnant},
    moves: moves,
  );
}
