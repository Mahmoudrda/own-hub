/// The phone's own reminders: [TrainingReminders] turned into weekly local
/// notifications.
///
/// Local, not pushed. Nothing is registered with a server, no token is
/// written, and the text is fixed ("Your session is ready when you are"), so
/// a lock screen read by somebody else learns nothing about her.
///
/// The permission is asked only when she taps "Remind me": Android 13 and
/// later show POST_NOTIFICATIONS then, iOS its own prompt. Initialising the
/// plugin asks for nothing.
library;

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../features/train/domain/training_reminders.dart';

/// What came of asking for permission.
enum ReminderPermission {
  granted,

  /// She said no, now or before. Only Settings can change it.
  denied,

  /// No notifications on this phone or in this build.
  unavailable,
}

/// The words a reminder carries, in her language at the moment it is set.
@immutable
class ReminderText {
  const ReminderText({
    required this.title,
    required this.body,
    required this.channelName,
    required this.channelDescription,
  });

  final String title;
  final String body;
  final String channelName;
  final String channelDescription;
}

/// Schedules and cancels her reminders.
abstract class ReminderScheduler {
  /// Asks for permission to show notifications. The only call that prompts.
  Future<ReminderPermission> requestPermission();

  /// Replaces whatever was scheduled with [reminders]. Asks for nothing.
  Future<void> schedule(TrainingReminders reminders, ReminderText text);

  /// Removes every reminder this app scheduled.
  Future<void> cancel();

  /// The plugin on a phone, nothing anywhere else (tests, desktop).
  static ReminderScheduler forPlatform() {
    if (kIsWeb) return const NoReminderScheduler();
    if (Platform.isAndroid || Platform.isIOS) {
      return LocalNotificationsReminderScheduler();
    }
    return const NoReminderScheduler();
  }
}

/// The notification id for a weekday. A fixed block, so changing days
/// replaces rather than adds, and [ReminderScheduler.cancel] touches nothing
/// else this app shows.
int reminderNotificationId(int weekday) => 7100 + weekday;

/// The Android channel. Its own, so she can silence reminders in the phone's
/// settings without silencing "your check is done".
const String kReminderChannelId = 'training_reminders';

/// The small icon: a white silhouette, kept from resource shrinking by
/// `res/raw/keep.xml`.
const String kReminderIcon = 'ic_stat_ownhub';

class LocalNotificationsReminderScheduler implements ReminderScheduler {
  LocalNotificationsReminderScheduler({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  Future<void>? _ready;

  Future<void> _init() => _ready ??= () async {
    tz_data.initializeTimeZones();
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
    } catch (_) {
      // The app is for women in Egypt. A zone the database does not know is
      // rarer than a phone set to Cairo.
      tz.setLocalLocation(tz.getLocation('Africa/Cairo'));
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings(kReminderIcon),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
  }();

  @override
  Future<ReminderPermission> requestPermission() async {
    try {
      await _init();
      final bool? allowed;
      if (Platform.isAndroid) {
        allowed = await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.requestNotificationsPermission();
      } else {
        allowed = await _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, sound: true);
      }
      if (allowed == null) return ReminderPermission.unavailable;
      return allowed ? ReminderPermission.granted : ReminderPermission.denied;
    } catch (_) {
      return ReminderPermission.unavailable;
    }
  }

  @override
  Future<void> schedule(TrainingReminders reminders, ReminderText text) async {
    await _init();
    await cancel();
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        kReminderChannelId,
        text.channelName,
        channelDescription: text.channelDescription,
        icon: kReminderIcon,
      ),
      iOS: const DarwinNotificationDetails(),
    );
    final now = tz.TZDateTime.now(tz.local);
    for (final weekday in reminders.weekdays) {
      final at = nextReminderAt(
        DateTime(now.year, now.month, now.day, now.hour, now.minute),
        weekday: weekday,
        hour: reminders.hour,
        minute: reminders.minute,
      );
      await _plugin.zonedSchedule(
        id: reminderNotificationId(weekday),
        title: text.title,
        body: text.body,
        scheduledDate: tz.TZDateTime(
          tz.local,
          at.year,
          at.month,
          at.day,
          at.hour,
          at.minute,
        ),
        notificationDetails: details,
        // Inexact: a few minutes either way, and no exact-alarm permission to
        // ask for or declare.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }
  }

  @override
  Future<void> cancel() async {
    await _init();
    for (var weekday = DateTime.monday; weekday <= DateTime.sunday; weekday++) {
      await _plugin.cancel(id: reminderNotificationId(weekday));
    }
  }
}

/// Nowhere to show a notification: says so, and schedules nothing.
class NoReminderScheduler implements ReminderScheduler {
  const NoReminderScheduler();

  @override
  Future<ReminderPermission> requestPermission() async =>
      ReminderPermission.unavailable;

  @override
  Future<void> schedule(TrainingReminders reminders, ReminderText text) async {}

  @override
  Future<void> cancel() async {}
}
