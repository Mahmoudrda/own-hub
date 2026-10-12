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
final _ios = File('tool/build_ios.sh');

String _androidAppId() => _appId('android');

String _appId(String platform) {
  final options = File('lib/firebase_options.dart').readAsStringSync();
  final block = options.substring(
    options.indexOf('static const FirebaseOptions $platform'),
  );
  return RegExp(r"appId: '([^']+)'").firstMatch(block)!.group(1)!;
}

/// The build-number expression, the same in both scripts.
const _buildNumber =
    r'BUILD="${BUILD_NUMBER:-$(( ($(date -u +%s) - 1767225600) / 60 ))}"';

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

  group('the iPhone build script', () {
    test('exists, is bash and can be run', () {
      expect(_ios.existsSync(), isTrue);
      expect(_ios.readAsStringSync(), startsWith('#!/usr/bin/env bash'));
      final mode = _ios.statSync().modeString();
      expect(mode[2], 'x', reason: 'tool/build_ios.sh must be executable');
    });

    test('builds one obfuscated ipa with its symbols, version and team', () {
      final source = _ios.readAsStringSync();
      final builds = RegExp(
        r'^flutter build ipa[^\n]*',
        multiLine: true,
      ).allMatches(source).map((m) => m.group(0)!).toList();
      expect(builds, hasLength(1));
      final build = builds.single;
      for (final flag in [
        '--release',
        '--obfuscate',
        r'--split-debug-info="$SYMBOLS"',
        r'--build-number="$BUILD"',
        r'--dart-define=APP_VERSION="$VERSION"',
        '--export-options-plist=ios/ExportOptions.plist',
      ]) {
        expect(build, contains(flag), reason: flag);
      }
      expect(source, contains(r'SYMBOLS="build/symbols/$VERSION-ios"'));
    });

    test('never uses the advertising identifier, and checks the archive', () {
      final source = _ios.readAsStringSync();
      expect(source, contains('export FIREBASE_ANALYTICS_WITHOUT_ADID=true'));
      expect(source, contains('ASIdentifierManager'));
      expect(source, isNot(contains('ADMIN_BUILD')));
    });

    test('stops before building when a store build would be refused', () {
      final source = _ios.readAsStringSync();
      expect(source, contains('-ge 26'), reason: 'Xcode 26 or later');
      expect(source, contains('GoogleService-Info.plist'));
      expect(source, contains('YOUR_TEAM_ID'));
      expect(source, contains('legal_links.dart'));
    });

    test('its symbols go to the iOS app this build talks to', () {
      expect(
        _ios.readAsStringSync(),
        contains('IOS_APP_ID="${_appId('ios')}"'),
      );
    });

    test('both scripts number builds the same way', () {
      expect(_script.readAsStringSync(), contains(_buildNumber));
      expect(_ios.readAsStringSync(), contains(_buildNumber));
    });
  });
}
