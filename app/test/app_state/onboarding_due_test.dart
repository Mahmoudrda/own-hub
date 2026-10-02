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
    AppRouter.featureFlags = FeatureFlags.shipped.with_({
      Feature.accountRequired: false,
    });
    AppRouter.intakeRepository.reset();
    expect(OnboardingState.instance.isDue, isTrue);
  });

  test(
    'account required, not verified: not owed (C16 asks inside sign-up)',
    () {
      AppRouter.featureFlags = FeatureFlags.shipped.with_({
        Feature.accountRequired: true,
      });
      AppRouter.intakeRepository.reset();
      AppRouter.lastVerification = null;
      expect(OnboardingState.instance.isDue, isFalse);
    },
  );

  test('account required, verified, setup not done: owed at launch', () {
    AppRouter.featureFlags = FeatureFlags.shipped.with_({
      Feature.accountRequired: true,
    });
    AppRouter.intakeRepository.restore(Intake.defaults);
    AppRouter.lastVerification = verified;
    expect(OnboardingState.instance.isDue, isTrue);
  });

  test('account required, verified, setup done: not owed', () {
    AppRouter.featureFlags = FeatureFlags.shipped.with_({
      Feature.accountRequired: true,
    });
    AppRouter.intakeRepository.restore(Intake.defaults, setupDone: true);
    AppRouter.lastVerification = verified;
    expect(OnboardingState.instance.isDue, isFalse);
  });
}
