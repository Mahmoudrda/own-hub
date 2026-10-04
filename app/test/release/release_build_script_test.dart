// R11: a Dart crash in a release build has to be readable.
//
// Crashlytics gets a stack of addresses from an obfuscated AOT build. It can
// only turn them back into file and line when the symbols written by
// `--split-debug-info` are uploaded for that exact build. `tool/build_release.sh`
// is the one way a release is built, so it is what is checked here. The build
// itself is not run by this test.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _script = File('tool/build_release.sh');

String _androidAppId() {
  final options = File('lib/firebase_options.dart').readAsStringSync();
  final android = options.substring(
    options.indexOf('static const FirebaseOptions android'),
  );
  return RegExp(r"appId: '([^']+)'").firstMatch(android)!.group(1)!;
}

void main() {
  test('the release build script exists and is a bash script', () {
    expect(_script.existsSync(), isTrue);
    expect(_script.readAsStringSync(), startsWith('#!/usr/bin/env bash'));
  });

  test(
    'it builds the AAB and the split APKs, obfuscated, with symbols kept',
    () {
      final source = _script.readAsStringSync();
      expect(source, contains('flutter build appbundle'));
      expect(source, contains('flutter build apk'));
      expect(source, contains('--split-per-abi'));
      final builds = RegExp(
        r'^flutter build (appbundle|apk)[^\n]*',
        multiLine: true,
      ).allMatches(source).map((m) => m.group(0)!).toList();
      expect(builds, hasLength(2));
      for (final build in builds) {
        expect(build, contains('--release'), reason: build);
        expect(build, contains('--obfuscate'), reason: build);
        expect(build, contains(r'--split-debug-info="$SYMBOLS'), reason: build);
      }
      expect(source, contains(r'SYMBOLS="build/symbols/$VERSION"'));
    },
  );

  test('it prints the upload for the Android app this build talks to', () {
    final source = _script.readAsStringSync();
    expect(
      source,
      contains('firebase crashlytics:symbols:upload --app=${_androidAppId()}'),
    );
  });

  test('the iOS equivalent is written down in the header', () {
    final header = _script
        .readAsLinesSync()
        .takeWhile((l) => l.startsWith('#'))
        .join('\n');
    expect(header, contains('dSYM'));
    expect(header, contains('flutter build ipa'));
    expect(header, contains('--split-debug-info'));
  });

  test('the Crashlytics Gradle plugin is not added', () {
    for (final path in [
      'android/settings.gradle.kts',
      'android/app/build.gradle.kts',
    ]) {
      final file = File(path);
      if (!file.existsSync()) continue;
      expect(
        file.readAsStringSync(),
        isNot(contains('firebase-crashlytics-gradle')),
      );
      expect(
        file.readAsStringSync(),
        isNot(contains('com.google.firebase.crashlytics')),
      );
    }
  });

  test('symbols are never committed', () {
    final result = Process.runSync('git', [
      'check-ignore',
      '-q',
      'build/symbols/1.0.0+1/app.android-arm64.symbols',
    ]);
    expect(result.exitCode, 0, reason: 'build/symbols must be gitignored');
  });

  test('the preflight checks the release script', () {
    expect(
      File('tool/release_preflight.sh').readAsStringSync(),
      contains('tool/build_release.sh'),
    );
  });
}
