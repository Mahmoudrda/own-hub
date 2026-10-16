// The Android side of the notification engine (WP10a): the permissions it
// needs and the receivers that keep its alarms across a restart.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final manifest = File('android/app/src/main/AndroidManifest.xml')
      .readAsStringSync();

  for (final permission in [
    'POST_NOTIFICATIONS',
    'RECEIVE_BOOT_COMPLETED',
    'SCHEDULE_EXACT_ALARM',
  ]) {
    test('$permission is declared', () {
      expect(
        manifest,
        contains(
          '<uses-permission android:name="android.permission.$permission"',
        ),
      );
    });
  }

  test('the scheduled and boot receivers are declared', () {
    expect(
      manifest,
      contains(
        'com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver',
      ),
    );
    final boot = RegExp(
      r'<receiver[^>]*ScheduledNotificationBootReceiver[\s\S]*?</receiver>',
    ).firstMatch(manifest);
    expect(boot, isNotNull);
    for (final action in [
      'android.intent.action.BOOT_COMPLETED',
      'android.intent.action.MY_PACKAGE_REPLACED',
    ]) {
      expect(boot!.group(0), contains(action));
    }
  });

  test('exact alarms are not the way every reminder is scheduled', () {
    final adapter = File('lib/app_state/reminder_scheduler.dart')
        .readAsStringSync();
    // Her days and the check-ins are inexact; only the rest alert may be
    // exact, and only when the phone says it can.
    expect(adapter, contains('canScheduleExactNotifications'));
    expect(adapter, contains('AndroidScheduleMode.inexactAllowWhileIdle'));
  });

  test('she is never sent to Settings for the exact-alarm permission', () {
    final adapter = File('lib/app_state/reminder_scheduler.dart')
        .readAsStringSync();
    expect(adapter, isNot(contains('requestExactAlarmsPermission')));
  });
}
