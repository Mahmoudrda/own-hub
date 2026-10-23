// App Check, client side.
//
// The server refuses every callable without an App Check token
// (ENFORCE_APP_CHECK), so a build that never activates App Check reaches no
// function at all. The other mistake worth a test is the opposite one: a
// store build attesting with a debug provider.

import 'dart:io';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/app_state/firebase_boot.dart';

void main() {
  group('the providers a build attests with', () {
    test('a release build uses Play Integrity and App Attest', () {
      final choice = FirebaseBoot.appCheckChoiceFor(release: true);
      expect(choice.android, isA<AndroidPlayIntegrityProvider>());
      expect(
        choice.apple,
        isA<AppleAppAttestWithDeviceCheckFallbackProvider>(),
      );
    });

    test('a release build ignores any debug token it was given', () {
      final choice = FirebaseBoot.appCheckChoiceFor(
        release: true,
        debugToken: 'leaked',
      );
      expect(choice.android, isNot(isA<AndroidDebugProvider>()));
      expect(choice.apple, isNot(isA<AppleDebugProvider>()));
    });

    test('a debug build uses the debug providers', () {
      final choice = FirebaseBoot.appCheckChoiceFor(release: false);
      expect(choice.android, isA<AndroidDebugProvider>());
      expect(choice.apple, isA<AppleDebugProvider>());
      // No token passed: the SDK makes one up and logs it for registration.
      expect((choice.android as AndroidDebugProvider).debugToken, isNull);
      expect((choice.apple as AppleDebugProvider).debugToken, isNull);
    });

    test('a registered debug token is handed to both platforms', () {
      final choice = FirebaseBoot.appCheckChoiceFor(
        release: false,
        debugToken: 'tok',
      );
      expect((choice.android as AndroidDebugProvider).debugToken, 'tok');
      expect((choice.apple as AppleDebugProvider).debugToken, 'tok');
    });
  });

  group('the boot source', () {
    final source = File('lib/app_state/firebase_boot.dart').readAsStringSync();
    final start = source.indexOf('static Future<void> start()');
    final end = source.indexOf('static AppCheckChoice appCheckChoiceFor');
    final startBody = source.substring(start, end);

    test('activates App Check after initializeApp, inside a try', () {
      final init = startBody.indexOf('Firebase.initializeApp');
      final activate = startBody.indexOf('FirebaseAppCheck.instance.activate');
      expect(init, greaterThan(-1));
      expect(activate, greaterThan(init));
      // The nearest `try {` before activate comes after initializeApp, so the
      // activation has its own try and cannot fail the launch.
      final tryBefore = startBody.lastIndexOf('try {', activate);
      expect(tryBefore, greaterThan(init));
      expect(startBody.indexOf('catch', activate), greaterThan(activate));
    });

    test('chooses the provider by kReleaseMode, not by a flag', () {
      expect(startBody, contains('appCheckChoiceFor(release: kReleaseMode)'));
    });

    test('debug providers appear only in the non-release branch', () {
      final choose = source.substring(
        end,
        source.indexOf('static FirebaseFunctions get functions'),
      );
      final releaseReturn = choose.indexOf('if (release)');
      final releaseBranch = choose.substring(
        releaseReturn,
        choose.indexOf('}', releaseReturn),
      );
      expect(releaseBranch, isNot(contains('Debug')));
      expect(
        RegExp(r'AndroidDebugProvider').allMatches(source).length,
        1,
        reason: 'one construction, in the debug branch',
      );
    });

    test('emulators are wired in debug builds only', () {
      for (final call in <String>[
        'useAuthEmulator',
        'useFirestoreEmulator',
        'useFunctionsEmulator',
      ]) {
        final at = source.indexOf(call);
        expect(at, greaterThan(-1), reason: call);
        final guard = source.lastIndexOf(
          'if (emulatorsWanted(debug: kDebugMode, host: _kEmulatorHost',
          at,
        );
        expect(guard, greaterThan(-1), reason: call);
      }
    });
  });

  test('resetForTest clears the App Check failure too', () {
    FirebaseBoot.resetForTest();
    expect(FirebaseBoot.status, BackendStatus.notAttempted);
    expect(FirebaseBoot.appCheckFailure, isNull);
  });

  test('the region is Frankfurt', () {
    expect(kFunctionsRegion, 'europe-west3');
  });
}
