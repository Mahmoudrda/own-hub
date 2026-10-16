// What the store listings will be checked against: the iOS privacy manifest,
// the Android manifest and the copy. A mismatch between what the app declares
// and what it does is one of the most common store rejections, and for a
// women-only app built on an ID check it is also a broken promise.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final privacy = File('ios/Runner/PrivacyInfo.xcprivacy').readAsStringSync();
  final manifest = File('android/app/src/main/AndroidManifest.xml')
      .readAsStringSync();

  /// The `<dict>` that declares [type], so linkage can be read per entry.
  String entryFor(String type) {
    final at = privacy.indexOf('<string>$type</string>');
    expect(at, greaterThan(-1), reason: '$type is not declared');
    final start = privacy.lastIndexOf('<dict>', at);
    final end = privacy.indexOf('</dict>', at);
    return privacy.substring(start, end);
  }

  group('the iOS privacy manifest declares what an account collects', () {
    // Privacy policy v3, section 7.1 of the compliance plan: linked to her
    // account, never tracking, App Functionality.
    for (final type in <String>[
      'PhoneNumber',
      'UserID',
      'DeviceID',
      'Fitness',
      'Health',
      'SensitiveInfo',
      'PhotosorVideos',
      'OtherDataTypes',
    ]) {
      test(type, () {
        final entry = entryFor('NSPrivacyCollectedDataType$type');
        expect(
          entry,
          matches(RegExp(r'NSPrivacyCollectedDataTypeLinked</key>\s*<true/>')),
          reason: 'linked to her account',
        );
        expect(
          entry,
          matches(
            RegExp(r'NSPrivacyCollectedDataTypeTracking</key>\s*<false/>'),
          ),
        );
        expect(
          entry,
          contains('NSPrivacyCollectedDataTypePurposeAppFunctionality'),
        );
      });
    }

    test('nothing tracks, and diagnostics are not linked', () {
      expect(
        privacy,
        matches(RegExp(r'<key>NSPrivacyTracking</key>\s*<false/>')),
      );
      for (final type in <String>['CrashData', 'PerformanceData']) {
        expect(
          entryFor('NSPrivacyCollectedDataType$type'),
          matches(RegExp(r'NSPrivacyCollectedDataTypeLinked</key>\s*<false/>')),
          reason: type,
        );
      }
    });

    test('no invalid or retired data type is declared', () {
      // HealthFitness is not one of Apple's keys; Fitness and Health are.
      for (final type in <String>['HealthFitness', 'OtherUserContent']) {
        expect(
          privacy,
          isNot(contains('<string>NSPrivacyCollectedDataType$type</string>')),
          reason: type,
        );
      }
    });
  });

  group('the Android manifest strips what the plugins add', () {
    test('no microphone, no gallery', () {
      expect(
        manifest,
        contains('xmlns:tools="http://schemas.android.com/tools"'),
      );
      expect(
        manifest,
        contains(
          '<uses-permission android:name="android.permission.RECORD_AUDIO" '
          'tools:node="remove" />',
        ),
      );
      expect(
        manifest,
        contains(
          '<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" '
          'tools:node="remove" />',
        ),
      );
    });

    test('no storage writes', () {
      // camerax writes only to the app cache.
      expect(
        manifest,
        contains(
          '<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" '
          'tools:node="remove" />',
        ),
      );
      final safety = File('android/play-data-safety.txt').readAsStringSync();
      expect(safety, isNot(contains('WRITE_EXTERNAL_STORAGE')));
      expect(safety, isNot(contains('c2dm')));
      final preflight = File('tool/release_preflight.sh').readAsStringSync();
      expect(preflight, contains('WRITE_EXTERNAL_STORAGE'));
    });

    // R1-P5: one push, "your check is done", which she asks for on C14.
    // Firebase Cloud Messaging needs c2dm RECEIVE to deliver it, so it is no
    // longer stripped, and every store answer says what the token is for.
    test('the one push is declared everywhere it is used', () {
      expect(
        manifest,
        isNot(contains('c2dm.permission.RECEIVE" tools:node="remove"')),
      );
      expect(manifest, contains('android.permission.POST_NOTIFICATIONS'));
      expect(
        File('ios/Runner/Runner.entitlements').readAsStringSync(),
        contains('<key>aps-environment</key>'),
      );
      final safety = File('android/play-data-safety.txt').readAsStringSync();
      expect(safety, contains('push token'));
      expect(privacy, contains('the push token'));
      expect(
        privacy,
        contains('<string>NSPrivacyCollectedDataTypeDeviceID</string>'),
      );
      final preflight = File('tool/release_preflight.sh').readAsStringSync();
      expect(preflight, contains('push is declared where it is used'));
    });

    test('the camera records no sound', () {
      expect(
        File('lib/features/signup/data/camera_capture_service.dart')
            .readAsStringSync(),
        contains('enableAudio: false'),
      );
    });
  });

  test('no copy claims a licensed Egyptian provider checks her', () {
    for (final arb in <String>['lib/l10n/app_en.arb', 'lib/l10n/app_ar.arb']) {
      final text = File(arb).readAsStringSync();
      expect(text, isNot(contains('licensed Egyptian provider')), reason: arb);
      expect(text, isNot(contains('مزوّد مصري مرخّص')), reason: arb);
    }
  });

  test('the Play Data safety answers exist and match the manifest', () {
    final answers = File('android/play-data-safety.txt').readAsStringSync();
    for (final phrase in <String>[
      'Phone number',
      'User IDs',
      'national ID number',
      'Name',
      'Crash logs',
      'Health info',
      'Photos',
      'Device or other IDs',
      'not a medical device',
      '18 and over',
    ]) {
      expect(answers, contains(phrase));
    }
  });
}
