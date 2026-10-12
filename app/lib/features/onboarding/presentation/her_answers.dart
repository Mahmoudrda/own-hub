/// Her setup answers read back to her in one line.
///
/// This was the single dictionary entry "Three days a week, 15 minutes, at
/// home", printed under the words "Built from your answers" to every
/// woman who finished setup. A woman who chose four days and twenty minutes at
/// a gym was told, on the screen whose entire job is to prove her answers
/// counted, that she had chosen something else.
///
/// One string per place rather than a place inserted into a sentence: Arabic
/// puts "في المنزل" and "في نادٍ للسيدات" in a sentence that has to agree with
/// them, and a template with a noun dropped into it reads as machine
/// translation. The numbers are placeholders in both languages and stay Western
/// digits (`P0-A11Y-01`).
///
/// Used by `O05`, where she sees her week built, by day-one Home, so the
/// week she saved is the week Home names, and by `C14` while she waits.
library;

import '../../../l10n/app_l10n.dart';
import '../domain/intake.dart';

///
/// [placeAnswered] is whether she was asked where she trains. The one-screen
/// "Your week" never asks, so her place is only the default then, and the
/// line says her days and minutes and claims no place at all.
String herAnswersLine(
  AppL10n l10n,
  Intake intake, {
  required bool placeAnswered,
}) {
  final days = '${intake.days}';
  final minutes = '${intake.minutes}';
  if (!placeAnswered) {
    return l10n.daysAWeekDaysMinutesASession_1a2wl(days, minutes);
  }
  return switch (intake.place) {
    TrainingPlace.home => l10n.daysAWeekDaysMinutesASession(days, minutes),
    TrainingPlace.ladiesGym => l10n.daysAWeekDaysMinutesASession_1qm7e(
      days,
      minutes,
    ),
    TrainingPlace.both => l10n.daysAWeekDaysMinutesASession_1cc8s(
      days,
      minutes,
    ),
  };
}
