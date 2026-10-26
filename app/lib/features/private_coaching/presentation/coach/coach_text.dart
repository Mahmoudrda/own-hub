/// Words for the coach's screens: every refusal in plain language, and the
/// labels for the choices on the forms.
library;

import '../../../../domain/format/number_label.dart';
import '../../../../l10n/app_l10n.dart';
import '../../domain/coaching_contract.dart';
import '../../domain/coaching_failure.dart';

/// [text] with Arabic-Indic and Persian digits written as 0-9, so a title she
/// typed on an Arabic keyboard reads the same everywhere. Other characters stay.
String westernDigits(String text) {
  final out = StringBuffer();
  for (final unit in text.runes) {
    if (unit >= 0x0660 && unit <= 0x0669) {
      out.writeCharCode(0x30 + unit - 0x0660);
    } else if (unit >= 0x06F0 && unit <= 0x06F9) {
      out.writeCharCode(0x30 + unit - 0x06F0);
    } else {
      out.writeCharCode(unit);
    }
  }
  return out.toString();
}

/// A calm sentence for a refusal. Never the raw code.
String coachFailureText(AppL10n l10n, CoachingFailure failure) =>
    switch (failure.refusal) {
      CoachingRefusal.unreachable => l10n.weCouldNotReachOwnHubCheck,
      CoachingRefusal.signedOut => l10n.pleaseSignInAgain_3jocz,
      CoachingRefusal.coachAppClosed => l10n.coachingIsNotOpenRightNowPlease,
      CoachingRefusal.notVerified => l10n.yourAccountNeedsToBeVerifiedFirst,
      CoachingRefusal.notACoach => l10n.thisAccountIsNotAnApprovedCoach,
      CoachingRefusal.coachSuspended => l10n.yourCoachSpaceIsPaused,
      CoachingRefusal.badRequest => l10n.somethingInThisFormNeedsAnotherLook,
      CoachingRefusal.priceOutOfRange => l10n.pickAPriceBetweenEgpLowAnd(
        countLabel(CoachingLimits.coachPriceMinEgp),
        countLabel(CoachingLimits.coachPriceMaxEgp),
      ),
      CoachingRefusal.tooManyPackages =>
        l10n.youAlreadyHaveCountPackagesEditOne(
          countLabel(CoachingLimits.maxPackages),
        ),
      CoachingRefusal.packageNotFound => l10n.weCouldNotFindThatPackageGo,
      CoachingRefusal.fileNotUploaded ||
      CoachingRefusal.imageInvalid => l10n.thatPictureCouldNotBeUsedTry,
      CoachingRefusal.mediaNotFound => l10n.thatItemIsNoLongerTherePull,
      CoachingRefusal.tooManyMedia => l10n.youHaveCountItemsRemoveOneTo(
        countLabel(CoachingLimits.mediaMaxItems),
      ),
      CoachingRefusal.healthNotReviewed =>
        l10n.readHerHealthAnswersFirstOpenHer,
      CoachingRefusal.eatingHistoryHold =>
        l10n.thisClientsAnswersOnEatingMeanYou,
      _ => l10n.somethingWentWrongPleaseTryAgain,
    };

/// The English-keyed specialty codes the application holds.
String specialtyLabel(AppL10n l10n, String code) => switch (code) {
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
  _ => code,
};
