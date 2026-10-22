/// The phone's own notifications: [NotificationPlan] turned into local
/// notifications.
///
/// Local, not pushed. Nothing is registered with a server, no token is
/// written, and the text is one of a small fixed set per kind, rotated, none
/// of it naming her training or her body, so a lock screen read by somebody
/// else learns nothing about her.
///
/// What to schedule and when is decided by the pure plan
/// (`features/train/domain/notification_plan.dart`); this file only hands the
/// result to the platform.
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

import '../features/train/domain/getting_started_tips.dart';
import '../l10n/app_l10n.dart';
import '../features/train/domain/notification_plan.dart';
import 'notification_taps.dart';

export '../features/train/domain/notification_plan.dart'
    show reminderNotificationId;

/// What came of asking for permission.
enum ReminderPermission {
  granted,

  /// She said no, now or before. Only Settings can change it.
  denied,

  /// No notifications on this phone or in this build.
  unavailable,
}

/// The words her notifications carry, in her language at the moment they are
/// set. The title is always "Own Hub".
@immutable
class ReminderText {
  const ReminderText({
    required this.title,
    required this.body,
    required this.channelName,
    required this.channelDescription,
    required this.logBody,
    required this.checkInBodies,
    required this.restBody,
    required this.checkInChannelName,
    required this.checkInChannelDescription,
    required this.restChannelName,
    required this.restChannelDescription,
    this.tipBodies = const <String>[],
    this.tipChannelName = '',
    this.tipChannelDescription = '',
    this.nudgeBodies = const <String>[],
    this.nudgeChannelName = '',
    this.nudgeChannelDescription = '',
    this.eventBodies = const <String>[],
    this.bookedEventBodies = const <String>[],
    this.eventChannelName = '',
    this.eventChannelDescription = '',
  });

  final String title;

  /// A training day.
  final String body;
  final String channelName;
  final String channelDescription;

  /// "Trained today? Add it in a tap."
  final String logBody;

  /// The rotating check-in texts, [kCheckInVariants] of them.
  final List<String> checkInBodies;

  /// "Rest is over."
  final String restBody;

  final String checkInChannelName;
  final String checkInChannelDescription;
  final String restChannelName;
  final String restChannelDescription;

  /// The getting started tips, one per [GettingStartedTip], in its order.
  final List<String> tipBodies;
  final String tipChannelName;
  final String tipChannelDescription;

  /// The friendly nudges: [kNudgeVariants] texts for each [NudgeContext], in
  /// its order (morning, midday, evening, week end).
  final List<String> nudgeBodies;
  final String nudgeChannelName;
  final String nudgeChannelDescription;

  /// The notes before an event she has no seat on, and before one she has,
  /// [kEventVariants] of each. Empty until [withEventCopy] fills them; an
  /// event note with no text is not scheduled.
  final List<String> eventBodies;
  final List<String> bookedEventBodies;
  final String eventChannelName;
  final String eventChannelDescription;

  /// This text with the event reminder words in [l10n]'s language.
  ReminderText withEventCopy(AppL10n l10n) => ReminderText(
    title: title,
    body: body,
    channelName: channelName,
    channelDescription: channelDescription,
    logBody: logBody,
    checkInBodies: checkInBodies,
    restBody: restBody,
    checkInChannelName: checkInChannelName,
    checkInChannelDescription: checkInChannelDescription,
    restChannelName: restChannelName,
    restChannelDescription: restChannelDescription,
    tipBodies: tipBodies,
    tipChannelName: tipChannelName,
    tipChannelDescription: tipChannelDescription,
    nudgeBodies: nudgeBodies,
    nudgeChannelName: nudgeChannelName,
    nudgeChannelDescription: nudgeChannelDescription,
    eventBodies: [l10n.anOwnHubEventIsComingUp, l10n.aNewOwnHubEventIsOpen],
    bookedEventBodies: [
      l10n.yourSeatIsWaiting,
      l10n.yourOwnHubEventIsAlmostHere,
    ],
    eventChannelName: l10n.eventReminders,
    eventChannelDescription: l10n.aNoteBeforeEventsYouCanJoin,
  );

  /// Every sentence a notification can carry, for the copy policy.
  List<String> get allBodies => <String>[
    body,
    logBody,
    ...checkInBodies,
    restBody,
    ...tipBodies,
    ...nudgeBodies,
    ...eventBodies,
    ...bookedEventBodies,
  ];
}

/// Schedules and cancels her notifications.
abstract class ReminderScheduler {
  /// Asks for permission to show notifications. The only call that prompts.
  Future<ReminderPermission> requestPermission();

  /// Replaces every planned notification (her days, "Trained today?", the
  /// check-ins) with [plan]. Asks for nothing and leaves a rest alert alone.
  Future<void> apply(List<PlannedNotification> plan, ReminderText text);

  /// One "Rest is over" at [rest]'s time, replacing any other.
  Future<void> scheduleRest(PlannedNotification rest, ReminderText text);

  /// Removes the rest alert.
  Future<void> cancelRest();

  /// Removes every notification this app scheduled.
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

/// The Android channels. Their own, so she can silence one in the phone's
/// settings without silencing the others or "your check is done".
const String kReminderChannelId = 'training_reminders';
const String kCheckInChannelId = 'gentle_checkins';
const String kRestChannelId = 'rest_timer';
const String kTipChannelId = 'getting_started_tips';
const String kNudgeChannelId = 'friendly_nudges';
const String kEventChannelId = 'event_reminders';

/// The small icon: a white silhouette, kept from resource shrinking by
/// `res/raw/keep.xml`.
const String kReminderIcon = 'ic_stat_ownhub';

/// Keeps `tz.local` on the phone's zone.
///
/// A phone carried to another zone, or one that changed its zone while the
/// app slept, would otherwise keep firing at the old zone's hour: the plugin
/// stores each notification against the zone it was scheduled in. [sync] runs
/// before every schedule and says whether the zone moved.
class LocalZone {
  LocalZone({
    Future<String> Function()? read,
    void Function(String name)? use,
    this.current,
  }) : _read = read ?? _readFromPhone,
       _use = use ?? _useInTimezonePackage;

  /// The app is for women in Egypt. A zone the database does not know is
  /// rarer than a phone set to Cairo.
  static const String fallback = 'Africa/Cairo';

  final Future<String> Function() _read;
  final void Function(String name) _use;

  /// The zone in use now.
  String? current;

  static Future<String> _readFromPhone() async =>
      (await FlutterTimezone.getLocalTimezone()).identifier;

  static void _useInTimezonePackage(String name) =>
      tz.setLocalLocation(tz.getLocation(name));

  /// True when the zone differs from the one last used (or none was set).
  Future<bool> sync() async {
    String name;
    try {
      name = await _read();
    } catch (_) {
      name = fallback;
    }
    if (name == current) return false;
    try {
      _use(name);
    } catch (_) {
      name = fallback;
      if (name == current) return false;
      _use(name);
    }
    current = name;
    return true;
  }
}

/// The Android channel a note of [kind] shows in: id, name, description and
/// importance. Every kind has its own; an event note never falls back to the
/// training channel.
@visibleForTesting
(String, String, String, Importance) reminderChannelFor(
  PlanKind kind,
  ReminderText text,
) => switch (kind) {
  PlanKind.checkIn => (
    kCheckInChannelId,
    text.checkInChannelName,
    text.checkInChannelDescription,
    Importance.defaultImportance,
  ),
  PlanKind.restOver => (
    kRestChannelId,
    text.restChannelName,
    text.restChannelDescription,
    Importance.high,
  ),
  PlanKind.tip => (
    kTipChannelId,
    text.tipChannelName,
    text.tipChannelDescription,
    Importance.defaultImportance,
  ),
  PlanKind.nudge => (
    kNudgeChannelId,
    text.nudgeChannelName,
    text.nudgeChannelDescription,
    Importance.defaultImportance,
  ),
  PlanKind.eventReminder => (
    kEventChannelId,
    text.eventChannelName,
    text.eventChannelDescription,
    Importance.defaultImportance,
  ),
  _ => (
    kReminderChannelId,
    text.channelName,
    text.channelDescription,
    Importance.defaultImportance,
  ),
};

/// The words of an event note, or null when [text] has none yet.
@visibleForTesting
String? eventReminderBody(PlannedNotification item, ReminderText text) {
  final code = eventFromCode(item.variant);
  final bodies = code.booked ? text.bookedEventBodies : text.eventBodies;
  return bodies.isEmpty ? null : bodies[code.variant % bodies.length];
}

/// The words a note carries.
@visibleForTesting
String reminderBodyFor(PlannedNotification item, ReminderText text) =>
    switch (item.kind) {
      PlanKind.training => text.body,
      PlanKind.didYouTrain => text.logBody,
      PlanKind.checkIn =>
        text.checkInBodies[item.variant % text.checkInBodies.length],
      PlanKind.restOver => text.restBody,
      PlanKind.tip =>
        item.variant >= 0 && item.variant < text.tipBodies.length
            ? text.tipBodies[item.variant]
            : text.body,
      PlanKind.nudge =>
        item.variant >= 0 && item.variant < text.nudgeBodies.length
            ? text.nudgeBodies[item.variant]
            : text.body,
      PlanKind.eventReminder => eventReminderBody(item, text) ?? text.body,
    };

/// The screen a tap opens. A screen id and nothing else.
@visibleForTesting
String reminderPayloadFor(PlannedNotification item) => switch (item.kind) {
  PlanKind.didYouTrain => 'T02',
  PlanKind.restOver => 'R09',
  PlanKind.tip => GettingStartedTip.of(item)?.screen ?? 'T01',
  PlanKind.nudge => nudgeScreen(item.variant),
  PlanKind.eventReminder => 'T09',
  _ => 'T01',
};

class LocalNotificationsReminderScheduler implements ReminderScheduler {
  LocalNotificationsReminderScheduler({
    FlutterLocalNotificationsPlugin? plugin,
    LocalZone? zone,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
       _zone = zone ?? LocalZone();

  final FlutterLocalNotificationsPlugin _plugin;
  final LocalZone _zone;
  Future<void>? _ready;

  Future<void> _init() => _ready ??= () async {
    tz_data.initializeTimeZones();
    await _zone.sync();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings(kReminderIcon),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) =>
          NotificationTaps.received(response.payload),
    );
    try {
      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) {
        NotificationTaps.received(launch?.notificationResponse?.payload);
      }
    } catch (_) {}
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

  NotificationDetails _details(PlanKind kind, ReminderText text) {
    final (id, name, description, importance) = reminderChannelFor(kind, text);
    return NotificationDetails(
      android: AndroidNotificationDetails(
        id,
        name,
        channelDescription: description,
        icon: kReminderIcon,
        importance: importance,
      ),
      iOS: const DarwinNotificationDetails(),
    );
  }

  tz.TZDateTime _zoned(DateTime at) =>
      tz.TZDateTime(tz.local, at.year, at.month, at.day, at.hour, at.minute);

  Future<void> _schedule(
    PlannedNotification item,
    ReminderText text, {
    required AndroidScheduleMode mode,
  }) => _plugin.zonedSchedule(
    id: item.id,
    title: text.title,
    body: reminderBodyFor(item, text),
    scheduledDate: item.kind == PlanKind.restOver
        ? tz.TZDateTime.from(item.at, tz.local)
        : _zoned(item.at),
    notificationDetails: _details(item.kind, text),
    androidScheduleMode: mode,
    matchDateTimeComponents: item.weekly
        ? DateTimeComponents.dayOfWeekAndTime
        : null,
    payload: reminderPayloadFor(item),
  );

  @override
  Future<void> apply(List<PlannedNotification> plan, ReminderText text) async {
    await _init();
    await _zone.sync();
    for (final id in kPlannedIds) {
      await _plugin.cancel(id: id);
    }
    for (final item in plan) {
      // Never an event note in the training words: with no event text yet it
      // is left out.
      if (item.kind == PlanKind.eventReminder &&
          eventReminderBody(item, text) == null) {
        continue;
      }
      // Inexact: a few minutes either way, and nothing to ask her for.
      await _schedule(
        item,
        text,
        mode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  @override
  Future<void> scheduleRest(PlannedNotification rest, ReminderText text) async {
    await _init();
    await _zone.sync();
    await _plugin.cancel(id: kRestOverId);
    // Exact when the phone allows it, because a rest alert a few minutes late
    // is not an alert. Never a reason to send her to Settings: without it the
    // alert is simply less precise.
    var exact = false;
    if (Platform.isAndroid) {
      try {
        exact =
            await _plugin
                .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin
                >()
                ?.canScheduleExactNotifications() ??
            false;
      } catch (_) {}
    }
    try {
      await _schedule(
        rest,
        text,
        mode: exact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (_) {
      // The exact permission can be withdrawn between the check and the call.
      // A late alert beats none.
      if (!exact) rethrow;
      await _schedule(
        rest,
        text,
        mode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  @override
  Future<void> cancelRest() async {
    await _init();
    await _plugin.cancel(id: kRestOverId);
  }

  @override
  Future<void> cancel() async {
    await _init();
    for (final id in [...kPlannedIds, kRestOverId]) {
      await _plugin.cancel(id: id);
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
  Future<void> apply(List<PlannedNotification> plan, ReminderText text) async {}

  @override
  Future<void> scheduleRest(
    PlannedNotification rest,
    ReminderText text,
  ) async {}

  @override
  Future<void> cancelRest() async {}

  @override
  Future<void> cancel() async {}
}
