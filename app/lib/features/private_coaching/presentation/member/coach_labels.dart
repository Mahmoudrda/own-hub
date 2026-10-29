/// Words for the coaching enums, in her language, and the price format.
library;

import '../../../../app_state/payments_switch.dart';
import '../../../../domain/flags/feature_flags.dart';
import '../../../../domain/format/number_label.dart';
import '../../../../l10n/app_l10n.dart';
import '../../../../routing/app_router.dart';
import '../../../account/presentation/allergen_labels.dart';

/// Whether prices are charged: the compiled-in payments flag, or the InstaPay
/// server switch (`config/payments.enabled`), the one that is real in this
/// release. While it is off every package is free for members.
bool get coachingPaymentsOn =>
    AppRouter.featureFlags.isOn(Feature.payments) || PaymentsSwitch.live;

/// Allergies in her language, joined as a list. A name this
/// build does not know is shown as it came rather than hidden.
String allergenNames(AppL10n l10n, Iterable<String> wires) =>
    <String>[for (final w in wires) allergenLabelForWire(l10n, w) ?? w]
        .fold('', (all, name) => all.isEmpty ? name : l10n.listItem(all, name));

/// 1800 becomes "1,800". Western digits in both languages.
String formatEgp(int value) => countLabel(value);

String goalLabel(AppL10n l10n, String goal) => switch (goal) {
  'stronger' => l10n.getStronger,
  'buildMuscle' => l10n.buildMuscle,
  'loseSteadily' => l10n.loseWeightSteadily,
  'feelBetter' => l10n.feelBetterInMyBody,
  'backIntoIt' => l10n.getBackIntoIt,
  _ => goal,
};

String placeLabel(AppL10n l10n, String place) => switch (place) {
  'home' => l10n.atHome,
  'gym' => l10n.atTheGym,
  'both' => l10n.both,
  _ => place,
};

/// Where the budget bands `under1500`, `from1500to3000` and `over3000` meet.
const int kBudgetMidFromEgp = 1500;
const int kBudgetTopFromEgp = 3000;

String budgetLabel(AppL10n l10n, String band) => switch (band) {
  'under1500' => l10n.underEgpN(formatEgp(kBudgetMidFromEgp)),
  'from1500to3000' => l10n.egpLowToHigh(
    formatEgp(kBudgetMidFromEgp),
    formatEgp(kBudgetTopFromEgp),
  ),
  'over3000' => l10n.overEgpN(formatEgp(kBudgetTopFromEgp)),
  _ => band,
};

String specialtyLabel(AppL10n l10n, String key) => switch (key) {
  'strength' => l10n.strength,
  'fatLoss' => l10n.fatLoss,
  'muscleGain' => l10n.muscleGain,
  'beginners' => l10n.beginners,
  'homeTraining' => l10n.homeTraining,
  'gymTraining' => l10n.gymTraining,
  'mobility' => l10n.mobility,
  'postnatalReturn' => l10n.postnatalReturn,
  'healthyEating' => l10n.healthyEating,
  'endurance' => l10n.endurance,
  _ => key,
};

String languageLabel(AppL10n l10n, String key) => switch (key) {
  'ar' => l10n.arabic,
  'en' => l10n.english,
  _ => key,
};

String badgeLabel(AppL10n l10n, String key) => switch (key) {
  'verifiedCoach' => l10n.verifiedCoach,
  'certificatesChecked' => l10n.certificatesChecked,
  'yearsCoaching' => l10n.yearsCoaching,
  _ => key,
};

String reportReasonLabel(AppL10n l10n, String reason) => switch (reason) {
  'harassment' => l10n.harassmentOrBullying,
  'man_account' => l10n.thisLooksLikeAMansAccount,
  'nudity' => l10n.nudityOrSexualContent,
  'spam' => l10n.spamOrAdvertising,
  'impersonation' => l10n.pretendingToBeSomeoneElse,
  'self_harm' => l10n.selfHarmOrDanger,
  'off_platform_payment' => l10n.askingForPaymentOutsideOwnHub,
  'contact_sharing' => l10n.askingToTalkOutsideOwnHub,
  'unsafe_advice' => l10n.unsafeTrainingOrFoodAdvice,
  _ => l10n.somethingElse,
};
