/// What she already told Own Hub in setup, in the words coaching uses, so the
/// join sheet and the coach quiz do not ask it twice.
///
/// Only the four answers coaching shares with setup: goal, level, days and
/// place. Nothing about her health, her life stage or what she eats is ever
/// carried over; those stay questions of their own. Every value is one of
/// `CoachingEnums`, and she can change each one.
///
/// Nothing is offered until she has finished setup, and the place only once
/// she answered where she trains: before that the intake holds the
/// preselected defaults, which are not her answers.
library;

import '../../onboarding/domain/intake.dart';

typedef SetupAnswers = ({
  String? goal,
  String? level,
  int? days,
  String? place,
});

const SetupAnswers noSetupAnswers = (
  goal: null,
  level: null,
  days: null,
  place: null,
);

SetupAnswers setupAnswersFor(
  Intake intake, {
  required bool setupDone,
  required bool placeAnswered,
}) {
  if (!setupDone) return noSetupAnswers;
  return (
    goal: switch (intake.goal) {
      TrainingGoal.stronger => 'stronger',
      TrainingGoal.buildMuscle => 'buildMuscle',
      TrainingGoal.loseSteadily => 'loseSteadily',
      TrainingGoal.feelBetter => 'feelBetter',
      TrainingGoal.backIntoIt => 'backIntoIt',
    },
    level: intake.level.wireName,
    days: intake.days,
    place: placeAnswered
        ? switch (intake.place) {
            TrainingPlace.home => 'home',
            TrainingPlace.ladiesGym => 'gym',
            TrainingPlace.both => 'both',
          }
        : null,
  );
}
