// N5: with Firebase unavailable, the phone's memory of a verified uid opens
// the local product only when it is the uid that was last signed in on this
// phone. And the memory never travels to another phone in an Android backup.

import 'dart:io';

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

  group('Firebase unavailable', () {
    test(
      'memory for a uid other than the last signed in opens nothing',
      () async {
        await VerificationMemory.rememberVerified('u1');
        await VerificationMemory.rememberSignedIn('u2');
        AppRouter.verificationBackend = FakeBackend(ready: false, uid: null);

        await AppRouter.readVerificationAtLaunch();

        expect(AppRouter.isVerified, isFalse);
        expect(AppRouter.verificationGate('P01'), isNotNull);
      },
    );

    test('memory with no record of who signed in opens nothing', () async {
      await VerificationMemory.rememberVerified('u1');
      AppRouter.verificationBackend = FakeBackend(ready: false, uid: null);

      await AppRouter.readVerificationAtLaunch();

      expect(AppRouter.isVerified, isFalse);
    });

    test('memory for the uid last signed in opens the local product', () async {
      await VerificationMemory.rememberVerified('u1');
      await VerificationMemory.rememberSignedIn('u1');
      AppRouter.verificationBackend = FakeBackend(ready: false, uid: null);

      await AppRouter.readVerificationAtLaunch();

      expect(AppRouter.isVerified, isTrue);
    });
  });

  group('who is signed in is kept up to date', () {
    test('a launch with Firebase records the signed-in uid', () async {
      AppRouter.verificationBackend = FakeBackend(
        uid: 'u2',
        claim: ({bool forceRefresh = false}) async => false,
      );
      await AppRouter.readVerificationAtLaunch();
      expect(await VerificationMemory.lastSignedInUid(), 'u2');
    });

    test('a launch with Firebase and nobody signed in clears it', () async {
      await VerificationMemory.rememberSignedIn('u1');
      AppRouter.verificationBackend = FakeBackend(uid: null);
      await AppRouter.readVerificationAtLaunch();
      expect(await VerificationMemory.lastSignedInUid(), isNull);
    });

    test('sign-out and deletion forget it', () async {
      await VerificationMemory.rememberSignedIn('u1');
      await AppRouter.forgetVerification();
      expect(await VerificationMemory.lastSignedInUid(), isNull);
    });
  });

  group('Android backup', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();

    test('cloud backup is off', () {
      expect(manifest, contains('android:allowBackup="false"'));
    });

    test('device-to-device transfer excludes everything', () {
      expect(
        manifest,
        contains('android:dataExtractionRules="@xml/data_extraction_rules"'),
      );
      final rules = File(
        'android/app/src/main/res/xml/data_extraction_rules.xml',
      ).readAsStringSync();
      for (final section in ['cloud-backup', 'device-transfer']) {
        expect(rules, contains('<$section>'));
      }
      expect(rules, contains('domain="sharedpref"'));
    });
  });
}
