// S14, client half: crash reporting that cannot carry anything about her.
//
// firebase_crashlytics ships only on these terms: no user identifier, no
// custom key holding anything, no breadcrumb log lines, collection off in
// debug and off at native start-up, and declared as CrashData (not linked)
// in the iOS privacy manifest and in the Play Data safety notes.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/app_state/firebase_boot.dart';

Iterable<File> _dartFiles(String dir) => Directory(dir)
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'));

void main() {
  test('nothing in the app attaches an identity, a key or a log line', () {
    final banned = RegExp(r'\.(setUserIdentifier|setCustomKey|log)\s*\(');
    final offenders = <String>[];
    for (final file in _dartFiles('lib')) {
      final source = file.readAsStringSync();
      if (!source.contains('Crashlytics')) continue;
      for (final match in banned.allMatches(source)) {
        offenders.add('${file.path}: ${match.group(0)}');
      }
    }
    expect(offenders, isEmpty);
  });

  test('only a release build collects', () {
    expect(FirebaseBoot.crashCollectionFor(release: true), isTrue);
    expect(FirebaseBoot.crashCollectionFor(release: false), isFalse);
    final boot = File('lib/app_state/firebase_boot.dart').readAsStringSync();
    expect(
      boot,
      contains('crashCollectionFor(release: kReleaseMode)'),
      reason: 'the build mode decides, never a flag',
    );
  });

  test('native collection is off until Dart turns it on', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    expect(
      RegExp(
        r'firebase_crashlytics_collection_enabled"\s*android:value="false"',
      ).hasMatch(manifest),
      isTrue,
    );
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    expect(
      RegExp(
        r'<key>FirebaseCrashlyticsCollectionEnabled</key>\s*<false/>',
      ).hasMatch(plist),
      isTrue,
    );
  });

  test('declared as CrashData, not linked, and in the Data safety notes', () {
    final privacy = File(
      'ios/Runner/PrivacyInfo.xcprivacy',
    ).readAsStringSync();
    expect(
      RegExp(
        r'NSPrivacyCollectedDataTypeCrashData</string>\s*'
        r'<key>NSPrivacyCollectedDataTypeLinked</key>\s*<false/>',
      ).hasMatch(privacy),
      isTrue,
    );
    final safety = File('android/play-data-safety.txt').readAsStringSync();
    expect(safety, contains('Crash logs'));
    expect(safety, isNot(contains('if crash')));
  });
}
