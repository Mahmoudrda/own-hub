// S14, client half: crash reporting that cannot carry anything about her.
//
// firebase_crashlytics ships only on these terms: no user identifier, no
// custom key holding anything, no breadcrumb log lines, collection off in
// debug and off at native start-up, and declared as CrashData (not linked)
// in the iOS privacy manifest and in the Play Data safety notes.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/app_state/crash_reports.dart';

import 'package:own_hub/app_state/firebase_boot.dart';

Iterable<File> _dartFiles(String dir) =>
    Directory(dir)
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

  group('R8: a report carries the type of the error and its stack only', () {
    test('the reason is the runtime type, never the message', () {
      final report = CrashReports.scrub(
        StateError('phone +201001234567 national id 29801011234567'),
      );
      expect(report.toString(), 'StateError');
      expect(report.toString(), isNot(contains('+20')));
      expect(CrashReports.scrub('a message string').toString(), 'String');
      expect(
        CrashReports.scrub(
          FlutterErrorDetails(exception: Exception('Mona, 29801011234567')),
        ).toString(),
        'FlutterErrorDetails',
      );
    });

    test('nothing but CrashReports talks to Crashlytics about an error', () {
      // A raw error object, a FlutterErrorDetails or a message string would
      // reach the console through any of these. Only the wrapper may call
      // them, and only with a scrubbed value.
      final calls = RegExp(
        r'\.(recordError|recordFlutterError|recordFlutterFatalError)\s*\(',
      );
      final offenders = <String>[];
      for (final file in _dartFiles('lib')) {
        if (file.path.endsWith('crash_reports.dart')) continue;
        for (final match in calls.allMatches(file.readAsStringSync())) {
          offenders.add('${file.path}: ${match.group(0)}');
        }
      }
      expect(offenders, isEmpty);

      final wrapper = File('lib/app_state/crash_reports.dart')
          .readAsStringSync();
      expect(
        RegExp(r'recordError\(\s*scrub\(').allMatches(wrapper).length,
        calls.allMatches(wrapper).length,
        reason:
            'every call inside the wrapper sends scrub(...) and nothing else',
      );
      expect(wrapper, isNot(contains('reason:')));
      expect(wrapper, isNot(contains('information:')));
    });
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
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    expect(
      RegExp(
        r'firebase_crashlytics_collection_enabled"\s*android:value="false"',
      ).hasMatch(manifest),
      isTrue,
    );
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    expect(
      RegExp(r'<key>FirebaseCrashlyticsCollectionEnabled</key>\s*<false/>')
          .hasMatch(plist),
      isTrue,
    );
  });

  test('declared as CrashData, not linked, and in the Data safety notes', () {
    final privacy = File('ios/Runner/PrivacyInfo.xcprivacy').readAsStringSync();
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
