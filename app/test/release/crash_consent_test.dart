// M3: crash reports by consent (privacy policy v3, 3.7).
//
// Off until she allows them, at C06 or in Privacy. Without consent no report
// is made, and unsent ones are deleted at boot and when she turns them off.
// Deleting everything on the phone puts the choice back to off.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:own_hub/app_state/crash_consent.dart';
import 'package:own_hub/app_state/crash_reports.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    CrashConsent.instance.resetForTest();
  });

  test('off until she says otherwise', () async {
    await CrashConsent.instance.load();
    expect(CrashConsent.instance.allowed, isFalse);
  });

  test('her choice is kept on the phone and read back', () async {
    await CrashConsent.instance.set(true);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(kCrashReportsAllowedKey), isTrue);

    CrashConsent.instance.resetForTest();
    await CrashConsent.instance.load();
    expect(CrashConsent.instance.allowed, isTrue);

    await CrashConsent.instance.set(false);
    expect(prefs.getBool(kCrashReportsAllowedKey), isFalse);
  });

  test('erasing puts it back to off and removes the key', () async {
    await CrashConsent.instance.set(true);
    await CrashConsent.instance.erase();
    expect(CrashConsent.instance.allowed, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey(kCrashReportsAllowedKey), isFalse);
  });

  test('without consent no report is made', () async {
    // Firebase is not up in a test, so a report attempt would throw. Without
    // consent the wrapper returns before touching Crashlytics at all.
    CrashConsent.instance.resetForTest(allowed: false);
    await CrashReports.uncaught(StateError('x'), StackTrace.current);
    await CrashReports.flutterError(
      FlutterErrorDetails(exception: Exception('x')),
    );
  });

  test('the boot deletes unsent reports without consent', () {
    final boot = File('lib/app_state/firebase_boot.dart').readAsStringSync();
    expect(boot, contains('deleteUnsentReports()'));
    expect(boot, contains('CrashConsent.instance.allowed'));
    final wrapper = File('lib/app_state/crash_reports.dart').readAsStringSync();
    expect(
      RegExp(r'if \(!allowed\) return;').allMatches(wrapper).length,
      2,
      reason: 'both report paths return early without consent',
    );
  });

  test('deleting everything on the phone resets the choice', () {
    final wipe = File('lib/app_state/account_data.dart').readAsStringSync();
    expect(wipe, contains('CrashConsent.instance.erase()'));
    expect(wipe, contains('PendingLegalAcceptance.erase()'));
  });

  test('main reads the choice before Firebase starts', () {
    final main = File('lib/main.dart').readAsStringSync();
    final load = main.indexOf('CrashConsent.instance.load()');
    final start = main.indexOf('FirebaseBoot.start()');
    expect(load, greaterThan(-1));
    expect(load, lessThan(start));
  });

  test('a release build wires no analytics sink', () {
    // The only sink is the debug console, and only under kDebugMode.
    final main = File('lib/main.dart').readAsStringSync();
    final at = main.indexOf('AppRouter.analytics =');
    expect(at, greaterThan(-1));
    final guard = main.lastIndexOf('if (kDebugMode)', at);
    expect(guard, greaterThan(-1));
    expect(at - guard, lessThan(120), reason: 'the sink sits inside the guard');
    expect('AppRouter.analytics ='.allMatches(main).length, 1);
  });
}
