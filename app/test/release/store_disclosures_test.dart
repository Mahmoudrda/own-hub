// What the store listings will be checked against: the iOS privacy manifest,
// the Android manifest and the copy. A mismatch between what the app declares
// and what it does is one of the most common store rejections, and for a
// women-only app built on an ID check it is also a broken promise.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final privacy = File('ios/Runner/PrivacyInfo.xcprivacy').readAsStringSync();
  final manifest = File(
    'android/app/src/main/AndroidManifest.xml',
  ).readAsStringSync();

  /// The `<dict>` that declares [type], so linkage can be read per entry.
  String entryFor(String type) {
    final at = privacy.indexOf('<string>$type</string>');
    expect(at, greaterThan(-1), reason: '$type is not declared');
    final start = privacy.lastIndexOf('<dict>', at);
    final end = privacy.indexOf('</dict>', at);
    return privacy.substring(start, end);
  }

  group('the iOS privacy manifest declares what an account collects', () {
    for (final type in <String>[
      'PhoneNumber',
      'UserID',
      'HealthFitness',
      'OtherUserContent',
      'OtherDataTypes',
    ]) {
      test(type, () {
        final entry = entryFor('NSPrivacyCollectedDataType$type');
        expect(
          entry,
          matches(
            RegExp(r'NSPrivacyCollectedDataTypeLinked</key>\s*<true/>'),
          ),
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

    test('the device id is still declared, and nothing tracks', () {
      entryFor('NSPrivacyCollectedDataTypeDeviceID');
      expect(
        privacy,
        matches(RegExp(r'<key>NSPrivacyTracking</key>\s*<false/>')),
      );
    });
  });

  group('the Android manifest strips what the plugins add', () {
    test('no microphone, no gallery', () {
      expect(manifest, contains('xmlns:tools="http://schemas.android.com/tools"'));
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

    test('the camera records no sound', () {
      expect(
        File(
          'lib/features/signup/data/camera_capture_service.dart',
        ).readAsStringSync(),
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
      'government ID number',
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
