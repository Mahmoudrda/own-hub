// N2: once a fresh token has been read in this session, its `verified` claim
// is the truth. A server `approved` state, or this phone's memory, opens the
// gate only while no fresh read has succeeded (the offline case R1 was built
// for). A fresh false closes it: staff can revoke a claim after approval, and
// the `users/{uid}.verification` document may still say approved.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:own_hub/app_state/verification_memory.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/features/signup/domain/server_verification.dart';
import 'package:own_hub/routing/app_router.dart';

import 'offline_verification_launch_test.dart' show FakeBackend;

FeatureFlags get _gated =>
    FeatureFlags.allOff.with_({for (final f in Feature.values) f: true});

const _approved = ServerVerification(ServerVerificationState.approved);

void main() {
  final savedBackend = AppRouter.verificationBackend;
  final savedFlags = AppRouter.featureFlags;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppRouter.forgetVerification();
    AppRouter.featureFlags = _gated;
  });

  tearDown(() async {
    AppRouter.verificationBackend = savedBackend;
    AppRouter.featureFlags = savedFlags;
    await AppRouter.forgetVerification();
  });

  test(
    'approved state with a fresh false claim leaves the gate closed',
    () async {
      AppRouter.verificationBackend = FakeBackend(
        claim: ({bool forceRefresh = false}) async => false,
        status: () async => _approved,
      );

      await AppRouter.readVerificationAtLaunch();

      expect(
        AppRouter.serverVerification?.state,
        ServerVerificationState.approved,
      );
      expect(AppRouter.isVerified, isFalse);
      expect(AppRouter.verificationGate('P01'), isNotNull);
    },
  );

  test('an approved state set later in the session does not outvote a fresh '
      'false claim', () async {
    AppRouter.verificationBackend = FakeBackend(
      claim: ({bool forceRefresh = false}) async => false,
    );
    await AppRouter.readVerificationAtLaunch();

    AppRouter.serverVerification = _approved;

    expect(AppRouter.isVerified, isFalse);
  });

  test('a memory left from before is not used after a fresh false', () async {
    await VerificationMemory.rememberVerified('u1');
    final backend = FakeBackend(
      claim: ({bool forceRefresh = false}) async =>
          throw FirebaseAuthException(code: 'network-request-failed'),
    );
    AppRouter.verificationBackend = backend;
    await AppRouter.readVerificationAtLaunch();
    expect(AppRouter.isVerified, isTrue, reason: 'offline: R1 holds');

    backend.claim = ({bool forceRefresh = false}) async => false;
    await AppRouter.refreshVerificationClaim();

    expect(AppRouter.isVerified, isFalse);
    expect(await VerificationMemory.verifiedUid(), isNull);
  });

  test('a fresh false after a server approval closes the gate again', () async {
    AppRouter.verificationBackend = FakeBackend(
      claim: ({bool forceRefresh = false}) async => false,
    );

    AppRouter.markApprovedByServer();
    await Future<void>.delayed(Duration.zero);

    expect(AppRouter.isVerified, isFalse);
  });

  test('offline, an approved state still opens the product (R1)', () async {
    AppRouter.verificationBackend = FakeBackend(
      claim: ({bool forceRefresh = false}) async =>
          throw FirebaseAuthException(code: 'network-request-failed'),
      cached: _approved,
    );

    await AppRouter.readVerificationAtLaunch();

    expect(AppRouter.isVerified, isTrue);
  });
}
