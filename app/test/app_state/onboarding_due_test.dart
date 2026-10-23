// N2: setup is owed to a verified woman whose life stage did not travel.
//
// With an account required the four questions used to be owed only inside
// sign-up (C16 to O01). A woman who came back on a new phone with the health
// backup off has her other answers restored but not her life stage, so setup
// is left not done (see cloud_documents.dart _foldUser) and must be asked at
// launch rather than skipped.

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/app_state/onboarding_state.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/features/onboarding/domain/intake.dart';
import 'package:own_hub/features/signup/domain/verification.dart';
import 'package:own_hub/routing/app_router.dart';

void main() {
  final savedFlags = AppRouter.featureFlags;
  tearDown(() {
    AppRouter.featureFlags = savedFlags;
    AppRouter.lastVerification = null;
    AppRouter.intakeRepository.reset();
  });

  final verified = VerificationResult(
    method: VerificationMethod.automatic,
    decidedAt: DateTime(2026, 10, 2),
    imagesDeletedAt: DateTime(2026, 10, 2),
  );

  test('no account required: owed whenever setup is not done', () {
    AppRouter.featureFlags = FeatureFlags.allOff.with_({
      Feature.accountRequired: false,
    });
    AppRouter.intakeRepository.reset();
    expect(OnboardingState.instance.isDue, isTrue);
  });

  test(
    'account required, no account: owed, a guest opens on the questions',
    () {
      AppRouter.featureFlags = FeatureFlags.allOff.with_({
        Feature.accountRequired: true,
      });
      AppRouter.intakeRepository.reset();
      AppRouter.lastVerification = null;
      expect(AppRouter.signedInUid, isNull);
      expect(OnboardingState.instance.isDue, isTrue);
    },
  );

  test('a guest who skipped or finished the questions is not asked again', () {
    AppRouter.featureFlags = FeatureFlags.allOff.with_({
      Feature.accountRequired: true,
    });
    AppRouter.intakeRepository.reset();
    OnboardingState.instance.finish();
    expect(OnboardingState.instance.isDue, isFalse);
  });

  test('account required, verified, setup not done: owed at launch', () {
    AppRouter.featureFlags = FeatureFlags.allOff.with_({
      Feature.accountRequired: true,
    });
    AppRouter.intakeRepository.restore(Intake.defaults);
    AppRouter.lastVerification = verified;
    expect(OnboardingState.instance.isDue, isTrue);
  });

  test('account required, verified, setup done: not owed', () {
    AppRouter.featureFlags = FeatureFlags.allOff.with_({
      Feature.accountRequired: true,
    });
    AppRouter.intakeRepository.restore(Intake.defaults, setupDone: true);
    AppRouter.lastVerification = verified;
    expect(OnboardingState.instance.isDue, isFalse);
  });

  // The value-first order: she builds her week on O03 and O05 before she has
  // an account. "Save my week and join" runs `finish()`, so once she is
  // verified the walk is not owed again and she is not asked twice.
  test('week built before sign-up: not owed after verification', () {
    AppRouter.featureFlags = FeatureFlags.allOff.with_({
      Feature.accountRequired: true,
    });
    AppRouter.intakeRepository.reset();
    OnboardingState.instance.beforeSignup = true;
    addTearDown(() => OnboardingState.instance.beforeSignup = false);

    OnboardingState.instance.finish();
    expect(OnboardingState.instance.isDue, isFalse, reason: 'not verified');

    AppRouter.lastVerification = verified;
    expect(OnboardingState.instance.isDue, isFalse, reason: 'already done');
  });
}
