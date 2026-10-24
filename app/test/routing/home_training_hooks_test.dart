// Home through the real router: Home carries no tier tabs, the "Your
// training" row in the Change sheet opens the quick sheet and applying it changes her plan, and
// Rahma's recipes are no longer held back before the allergy question.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/app_state/chosen_programme.dart';
import 'package:own_hub/app_state/workout_library_state.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/app_state/eat_state.dart';
import 'package:own_hub/features/account/domain/dietary_profile.dart';
import 'package:own_hub/features/eat/data/seeded_recipe_library.dart';
import 'package:own_hub/features/onboarding/domain/intake.dart';
import 'package:own_hub/features/onboarding/domain/starting_program.dart';
import 'package:own_hub/features/signup/domain/verification.dart';
import 'package:own_hub/features/train/domain/viewed_tier.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/routing/app_routes.dart';
import 'package:own_hub/theme/app_tokens.dart';

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 3200);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

Widget _app(String screenId) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppL10n.localizationsDelegates,
  supportedLocales: AppL10n.supportedLocales,
  theme: buildTheme(const Locale('en')),
  onGenerateRoute: AppRouter.onGenerateRoute,
  onUnknownRoute: AppRouter.onUnknownRoute,
  initialRoute: appRoutes[screenId]!.name,
);

void main() {
  final savedFlags = AppRouter.featureFlags;

  setUpAll(() {
    StartingProgrammes.adopt(
      File('assets/content/starting_programmes.json').readAsStringSync(),
    );
  });
  tearDownAll(StartingProgrammes.reset);

  setUp(() async {
    AppRouter.featureFlags = FeatureFlags.everything;
    AppRouter.consentRecorded = true;
    AppRouter.lastVerification = VerificationResult(
      method: VerificationMethod.automatic,
      decidedAt: DateTime(2026, 10, 2),
      imagesDeletedAt: DateTime(2026, 10, 2),
    );
    ChosenProgramme.reset();
    ViewedTier.clear();
    WorkoutLibraryState.instance
      ..openedSlot = null
      ..chosenRowId = null;
    // Past day one: the tabs and the training row belong to the working Home.
    await AppRouter.todayRepository.countWalk();
    await AppRouter.intakeRepository.merge(
      place: TrainingPlace.ladiesGym,
      goal: TrainingGoal.stronger,
      level: TrainingLevel.beginner,
      minutes: 45,
    );
  });

  tearDown(() {
    AppRouter.featureFlags = savedFlags;
    AppRouter.consentRecorded = false;
    AppRouter.lastVerification = null;
    ChosenProgramme.reset();
    ViewedTier.clear();
  });

  testWidgets('Home carries no tier tabs and no facts block', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_app('T01'));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Intermediate'), findsNothing);
    expect(find.text('Advanced'), findsNothing);
    expect(find.byKey(const ValueKey('tier-facts-line')), findsNothing);
  });

  testWidgets('the plan page shows the facts under its tabs', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_app('R02'));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byKey(const ValueKey('tier-facts-line')), findsOneWidget);
  });

  testWidgets('the Your training row opens the sheet and Apply changes her '
      'plan', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_app('T01'));
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tap(find.byKey(const ValueKey('today-change')));
    await tester.pumpAndSettle();
    expect(find.text('Split · 3 days · Beginner'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('change-training')));
    await tester.pumpAndSettle();

    final sheet = find.byKey(const ValueKey('quick-goal'));
    expect(sheet, findsOneWidget);
    await tester.tap(
      find.descendant(of: sheet, matching: find.text('Build muscle')),
    );
    await tester.pump();
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('quick-level')),
        matching: find.text('Intermediate'),
      ),
    );
    await tester.pump();
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('quick-split')),
        matching: find.text('5 days'),
      ),
    );
    await tester.pump();
    await tester.ensureVisible(find.byKey(const ValueKey('quick-apply')));
    await tester.tap(find.byKey(const ValueKey('quick-apply')));
    await tester.pumpAndSettle();

    expect(AppRouter.intakeRepository.read().goal, TrainingGoal.buildMuscle);
    expect(AppRouter.intakeRepository.read().days, 5);
    expect(
      AppRouter.herProgramme!.program.programId,
      'split_5day_intermediate',
    );
  });

  group('Rahma\'s recipes before and after the allergy question', () {
    setUp(() {
      final raw = (jsonDecode(
        File('assets/content/rahma_recipes.json').readAsStringSync(),
      ) as Map).cast<String, Object?>();
      EatAppState.instance.recipeBook = RecipeBook.fromJson(raw);
      AppRouter.dietaryRepository.reset();
    });
    tearDown(AppRouter.dietaryRepository.reset);

    test('the whole book shows before she answers', () {
      expect(AppRouter.dietaryRepository.read().asked, isFalse);
      expect(AppRouter.rahmaRecipes(), hasLength(50));
    });

    test(
      'after she names tree nuts, nothing with them or unchecked shows',
      () async {
        await AppRouter.dietaryRepository.save(
          allergies: {AllergenTag.treeNuts},
          dietary: <DietaryTag>{},
        );
        final shown = AppRouter.rahmaRecipes();
        expect(shown, isNotEmpty);
        expect(shown.length, lessThan(50));
        for (final recipe in shown) {
          expect(recipe.allergensKnown, isTrue, reason: recipe.recipeId);
          expect(
            recipe.allergensFinal.contains('tree_nuts'),
            isFalse,
            reason: recipe.recipeId,
          );
        }
      },
    );
  });
}
