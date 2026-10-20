// N6: a claim read that is still in flight when her verification is
// forgotten (sign-out, account deletion) must not reopen the gate, and a read
// for one uid must not settle the gate for another.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:own_hub/app_state/verification_memory.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/routing/app_router.dart';

import 'offline_verification_launch_test.dart' show FakeBackend;

FeatureFlags get _gated =>
    FeatureFlags.allOff.with_({for (final f in Feature.values) f: true});

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
    'a token read in flight during forgetVerification is discarded',
    () async {
      final answer = Completer<bool>();
      final backend = FakeBackend(
        claim: ({bool forceRefresh = false}) => answer.future,
      );
      AppRouter.verificationBackend = backend;
      AppRouter.watchVerificationToken();

      backend.tokens.add(Object());
      await Future<void>.delayed(Duration.zero);

      // Account deleted while the read is still out. Same uid: the race is the
      // generation, not the uid.
      await AppRouter.forgetVerification();
      answer.complete(true);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(AppRouter.isVerified, isFalse);
      expect(AppRouter.verificationGate('P01'), isNotNull);
      expect(await VerificationMemory.verifiedUid(), isNull);
    },
  );

  test(
    'a forced refresh in flight during forgetVerification is discarded',
    () async {
      final answer = Completer<bool>();
      AppRouter.verificationBackend = FakeBackend(
        claim: ({bool forceRefresh = false}) => answer.future,
      );

      final refresh = AppRouter.refreshVerificationClaim();
      await AppRouter.forgetVerification();
      answer.complete(true);
      await refresh;
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(AppRouter.isVerified, isFalse);
      expect(await VerificationMemory.verifiedUid(), isNull);
    },
  );

  test('a read for one uid does not settle the gate for the next', () async {
    final answer = Completer<bool>();
    final backend = FakeBackend(
      claim: ({bool forceRefresh = false}) => answer.future,
    );
    AppRouter.verificationBackend = backend;

    final refresh = AppRouter.refreshVerificationClaim();
    backend.uid = 'u2';
    answer.complete(true);
    await refresh;
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(AppRouter.isVerified, isFalse);
    expect(await VerificationMemory.verifiedUid(), isNull);
  });
}
