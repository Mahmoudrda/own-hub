// What setup already told Own Hub is carried into coaching in coaching's words,
// and nothing else is.

import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/features/onboarding/domain/intake.dart';
import 'package:own_hub/features/private_coaching/domain/coaching_contract.dart';
import 'package:own_hub/features/private_coaching/domain/setup_prefill.dart';
import 'package:own_hub/routing/app_router.dart';

void main() {
  test('nothing is offered before setup is finished', () {
    expect(
      setupAnswersFor(
        const Intake(goal: TrainingGoal.buildMuscle),
        setupDone: false,
        placeAnswered: true,
      ),
      noSetupAnswers,
    );
  });

  test('every setup goal, level and place has a coaching value', () {
    for (final goal in TrainingGoal.values) {
      for (final place in TrainingPlace.values) {
        final answers = setupAnswersFor(
          Intake(goal: goal, place: place),
          setupDone: true,
          placeAnswered: true,
        );
        expect(CoachingEnums.goals, contains(answers.goal));
        expect(CoachingEnums.places, contains(answers.place));
      }
    }
    for (final level in TrainingLevel.values) {
      expect(
        CoachingEnums.levels,
        contains(
          setupAnswersFor(
            Intake(level: level),
            setupDone: true,
            placeAnswered: true,
          ).level,
        ),
      );
    }
    for (var days = 1; days <= 7; days++) {
      expect(
        setupAnswersFor(
          Intake(days: days),
          setupDone: true,
          placeAnswered: true,
        ).days,
        days,
      );
    }
  });

  test('a place she never answered is not offered as hers', () {
    final answers = setupAnswersFor(
      const Intake(),
      setupDone: true,
      placeAnswered: false,
    );
    expect(answers.place, isNull);
    expect(answers.goal, 'stronger');
  });

  test('the answers carry no health, life-stage or eating field', () {
    // The record has four fields and no others: a new one is a decision.
    final answers = setupAnswersFor(
      const Intake(lifeStage: LifeStage.pregnant),
      setupDone: true,
      placeAnswered: true,
    );
    expect(answers.toString().toLowerCase(), isNot(contains('pregnan')));
  });

  group('through the router', () {
    final saved = AppRouter.featureFlags;
    tearDown(() {
      AppRouter.featureFlags = saved;
      AppRouter.intakeRepository.reset();
    });

    test('switched off, nothing is offered even when setup is done', () async {
      await AppRouter.intakeRepository.merge(goal: TrainingGoal.buildMuscle);
      AppRouter.intakeRepository.markSetupDone();
      AppRouter.featureFlags = FeatureFlags.everything.with_({
        Feature.prefillFromSetup: false,
      });
      expect(AppRouter.setupAnswersForCoaching(), noSetupAnswers);
      AppRouter.featureFlags = FeatureFlags.everything;
      expect(AppRouter.setupAnswersForCoaching().goal, 'buildMuscle');
    });
  });
}
