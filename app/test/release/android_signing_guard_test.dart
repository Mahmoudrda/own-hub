// A release build without android/key.properties must fail, not quietly sign
// with the debug key. A debug-signed artefact cannot be uploaded to Play, and
// worse, it can be shared by hand and installed as if it were the real app.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final gradle = File('android/app/build.gradle.kts').readAsStringSync();

  test('a release build without key.properties throws', () {
    expect(gradle, contains('GradleException'));
    expect(gradle, contains('gradle.taskGraph.whenReady'));
    expect(gradle, contains('android/key.properties is missing'));
  });

  test('the debug key is used for release only when explicitly allowed', () {
    // The old fallback: `else { signingConfigs.getByName("debug") }` with no
    // condition of its own.
    expect(
      RegExp(r'else\s*\{\s*signingConfigs\.getByName\("debug"\)\s*\}')
          .hasMatch(gradle),
      isFalse,
    );
    expect(gradle, contains('OWNHUB_ALLOW_DEBUG_SIGNING'));
    expect(gradle, contains('allowDebugSigning'));
  });
}
