/// The readable names for the contract's ids, in the app's language.
library;

import '../../../../l10n/app_l10n.dart';

String governorateLabel(AppL10n l10n, String id) => switch (id) {
  'cairo' => l10n.cairo,
  'giza' => l10n.giza,
  'alexandria' => l10n.alexandria,
  'qalyubia' => l10n.qalyubia,
  'sharqia' => l10n.sharqia,
  'dakahlia' => l10n.dakahlia,
  'gharbia' => l10n.gharbia,
  'monufia' => l10n.monufia,
  'beheira' => l10n.beheira,
  'kafrElSheikh' => l10n.kafrElSheikh,
  'damietta' => l10n.damietta,
  'portSaid' => l10n.portSaid,
  'ismailia' => l10n.ismailia,
  'suez' => l10n.suez,
  'northSinai' => l10n.northSinai,
  'southSinai' => l10n.southSinai,
  'redSea' => l10n.redSea,
  'matrouh' => l10n.matrouh,
  'faiyum' => l10n.faiyum,
  'beniSuef' => l10n.beniSuef,
  'minya' => l10n.minya,
  'asyut' => l10n.asyut,
  'sohag' => l10n.sohag,
  'qena' => l10n.qena,
  'luxor' => l10n.luxor,
  'aswan' => l10n.aswan,
  'newValley' => l10n.newValley,
  _ => id,
};

String specialtyLabel(AppL10n l10n, String id) => switch (id) {
  'strength' => l10n.strength,
  'fatLoss' => l10n.fatLoss,
  'muscleGain' => l10n.muscleGain,
  'beginners' => l10n.beginners,
  'homeTraining' => l10n.homeTraining,
  'gymTraining' => l10n.gymTraining,
  'mobility' => l10n.mobility,
  'postnatalReturn' => l10n.returnAfterBirth,
  'healthyEating' => l10n.healthyEating,
  'endurance' => l10n.endurance,
  _ => id,
};

String languageLabel(AppL10n l10n, String id) => switch (id) {
  'ar' => l10n.arabicLanguage,
  'en' => l10n.englishLanguage,
  _ => id,
};

String sourceLabel(AppL10n l10n, String id) => switch (id) {
  'whatsapp' => l10n.whatsapp,
  'instagram' => l10n.instagram,
  'inPerson' => l10n.faceToFace,
  'other' => l10n.somewhereElse,
  _ => id,
};

String trainsWhereLabel(AppL10n l10n, String id) => switch (id) {
  'home' => l10n.atHome,
  'gym' => l10n.inAGym,
  'online' => l10n.online,
  _ => id,
};

String ruleLabel(AppL10n l10n, String id) => switch (id) {
  'accurateInfo' => l10n.everythingIWroteIsAccurate,
  'clientPhotoConsent' => l10n.iShareClientPhotosOnlyWithTheir,
  'noOffPlatformPayment' => l10n.iWillNotTakePaymentFromClients,
  _ => id,
};

/// The reviewer's reason codes.
String reasonLabel(AppL10n l10n, String code) => switch (code) {
  'missing' => l10n.somethingIsMissingHere,
  'unclear' => l10n.thisPartIsNotClearEnough,
  'unverifiable' => l10n.weCouldNotVerifyThis,
  'not_allowed' => l10n.thisIsNotAllowedOnOwnHub,
  _ => l10n.pleaseLookAtThisPartAgain,
};

/// The title of step [step] (1 to 8).
String applyStepTitle(AppL10n l10n, int step) => switch (step) {
  1 => l10n.aboutYou,
  2 => l10n.yourEducation,
  3 => l10n.yourCertificates,
  4 => l10n.yourSpecialties,
  5 => l10n.feedbackFromClients,
  6 => l10n.clientTransformations,
  7 => l10n.howYouCoach,
  _ => l10n.coachTerms,
};
