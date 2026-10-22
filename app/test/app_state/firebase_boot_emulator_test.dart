// The local emulators are reachable from a debug build only.
//
// A release or profile build must always talk to production, whatever
// `OWNHUB_EMULATOR_HOST` was given, so every emulator call sits behind
// `emulatorsWanted`, and `emulatorsWanted` needs a debug build.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/app_state/firebase_boot.dart';

void main() {
  test('only a debug build with a host uses the emulators', () {
    expect(emulatorsWanted(debug: true, host: '10.0.2.2'), isTrue);
    expect(emulatorsWanted(debug: true, host: ''), isFalse);
    expect(emulatorsWanted(debug: false, host: '10.0.2.2'), isFalse);
    expect(emulatorsWanted(debug: false, host: ''), isFalse);
  });

  test('every emulator call is behind emulatorsWanted(debug: kDebugMode)', () {
    final lines = File('lib/app_state/firebase_boot.dart').readAsLinesSync();
    final guard = RegExp(
      r'if \(emulatorsWanted\(debug: kDebugMode, host: _kEmulatorHost\)\) \{',
    );
    final calls = RegExp(r'\.use(Auth|Firestore|Functions|Storage)Emulator\(');
    var found = 0;
    for (var i = 0; i < lines.length; i++) {
      if (!calls.hasMatch(lines[i])) continue;
      found++;
      var guarded = false;
      for (var j = i; j >= 0 && i - j < 25; j--) {
        if (guard.hasMatch(lines[j])) {
          guarded = true;
          break;
        }
      }
      expect(guarded, isTrue, reason: 'unguarded emulator call: ${lines[i]}');
    }
    // Auth, Firestore, Storage (twice) and Functions.
    expect(found, 5);
  });

  test('the debug host define is read in one place only', () {
    final source = File('lib/app_state/firebase_boot.dart').readAsStringSync();
    expect(RegExp('OWNHUB_EMULATOR_HOST\'\\)').allMatches(source).length, 1);
    expect(
      File('firebase.e2e.json').existsSync() ||
          File('../firebase.e2e.json').existsSync(),
      isTrue,
    );
  });
}
