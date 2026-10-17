// The adapter-side pieces of WP10a that run without a phone: the time-zone
// follower, the sync between her state and the scheduler, tap routing, token
// refresh, and the snapshot.

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/app_snapshot.dart';
import 'package:own_hub/app_state/notification_sync.dart';
import 'package:own_hub/app_state/notification_taps.dart';
import 'package:own_hub/app_state/push_registration.dart';
import 'package:own_hub/app_state/reminder_scheduler.dart';
import 'package:own_hub/features/train/domain/notification_plan.dart';
import 'package:own_hub/features/train/domain/training_reminders.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:flutter/material.dart';

class _Scheduler implements ReminderScheduler {
  final List<List<PlannedNotification>> applied = [];
  final List<PlannedNotification> rests = [];
  int restCancelled = 0;
  int cancelled = 0;
  bool failApply = false;

  @override
  Future<ReminderPermission> requestPermission() async =>
      ReminderPermission.granted;

  @override
  Future<void> apply(List<PlannedNotification> plan, ReminderText text) async {
    if (failApply) throw StateError('no');
    applied.add(plan);
  }

  @override
  Future<void> scheduleRest(
    PlannedNotification rest,
    ReminderText text,
  ) async => rests.add(rest);

  @override
  Future<void> cancelRest() async => restCancelled++;

  @override
  Future<void> cancel() async => cancelled++;
}

class _Store implements DeviceStore {
  final Map<String, Map<String, Object>> docs = {};

  @override
  Future<void> save(
    String uid,
    String docId,
    Map<String, Object> document,
  ) async => docs[docId] = document;

  @override
  Future<void> remove(String uid, String docId) async => docs.remove(docId);
}

void main() {
  final en = lookupAppL10n(const Locale('en'));
  final text = AppRouter.reminderText(en);
  final now = DateTime(2026, 10, 14, 10);

  setUp(() => ReminderState.instance.reset());
  tearDown(() => ReminderState.instance.reset());

  group('time zone', () {
    test(
      'first sync sets the zone; the same zone again does nothing',
      () async {
        final used = <String>[];
        final zone = LocalZone(read: () async => 'Africa/Cairo', use: used.add);
        expect(await zone.sync(), isTrue);
        expect(await zone.sync(), isFalse);
        expect(used, ['Africa/Cairo']);
      },
    );

    test('a phone that moved zone is noticed and used', () async {
      var phone = 'Africa/Cairo';
      final used = <String>[];
      final zone = LocalZone(read: () async => phone, use: used.add);
      await zone.sync();
      phone = 'Asia/Riyadh';
      expect(await zone.sync(), isTrue);
      expect(zone.current, 'Asia/Riyadh');
      expect(used, ['Africa/Cairo', 'Asia/Riyadh']);
    });

    test('a zone the database does not know falls back to Cairo', () async {
      final used = <String>[];
      final zone = LocalZone(
        read: () async => 'Mars/Olympus',
        use: (name) {
          if (name == 'Mars/Olympus') throw ArgumentError(name);
          used.add(name);
        },
      );
      expect(await zone.sync(), isTrue);
      expect(zone.current, LocalZone.fallback);
      expect(used, [LocalZone.fallback]);
    });

    test('a phone that cannot say falls back too', () async {
      final zone = LocalZone(
        read: () async => throw StateError('no'),
        use: (_) {},
      );
      await zone.sync();
      expect(zone.current, LocalZone.fallback);
    });
  });

  group('sync between her state and the phone', () {
    test('asks for nothing and schedules nothing before permission', () async {
      final scheduler = _Scheduler();
      await NotificationSync.reapply(scheduler, text, now: now);
      expect(scheduler.applied, isEmpty);
      await NotificationSync.restCancelled(scheduler);
      expect(scheduler.restCancelled, 0);
    });

    test(
      'a woman who saved reminders before this release counts as allowed',
      () async {
        ReminderState.instance.schedule = TrainingReminders(
          weekdays: {DateTime.wednesday},
        );
        final scheduler = _Scheduler();
        await NotificationSync.reapply(scheduler, text, now: now);
        expect(scheduler.applied, hasLength(1));
      },
    );

    test(
      'reapplying on resume (and a new zone) replaces, never adds',
      () async {
        ReminderState.instance
          ..permissionGranted = true
          ..schedule = TrainingReminders(weekdays: {DateTime.wednesday});
        final scheduler = _Scheduler();
        await NotificationSync.reapply(scheduler, text, now: now);
        await NotificationSync.reapply(scheduler, text, now: now);
        expect(scheduler.applied, hasLength(2));
        expect(scheduler.applied.first, scheduler.applied.last);
      },
    );

    test(
      'a failing phone is swallowed unless the sheet asks to hear',
      () async {
        ReminderState.instance.permissionGranted = true;
        final scheduler = _Scheduler()..failApply = true;
        await NotificationSync.reapply(scheduler, text, now: now);
        await expectLater(
          NotificationSync.reapply(scheduler, text, now: now, quiet: false),
          throwsStateError,
        );
      },
    );

    test('backgrounding mid-rest leaves one alert at the deadline', () async {
      ReminderState.instance.permissionGranted = true;
      final scheduler = _Scheduler();
      await NotificationSync.reapply(scheduler, text, now: now);
      final deadline = now.add(const Duration(seconds: 40));
      await NotificationSync.restBackgrounded(scheduler, deadline, now: now);
      expect(scheduler.rests.single.at, deadline);
      await NotificationSync.restCancelled(scheduler);
      expect(scheduler.restCancelled, 1);
    });

    test('with the rest alert off, backgrounding leaves nothing', () async {
      ReminderState.instance
        ..permissionGranted = true
        ..prefs = const NotificationPrefs(restAlert: false);
      final scheduler = _Scheduler();
      await NotificationSync.reapply(scheduler, text, now: now);
      await NotificationSync.restBackgrounded(
        scheduler,
        now.add(const Duration(seconds: 40)),
        now: now,
      );
      expect(scheduler.rests, isEmpty);
    });

    test('logging a session ends today\'s "Trained today?"', () async {
      ReminderState.instance
        ..permissionGranted = true
        ..schedule = TrainingReminders(weekdays: {DateTime.wednesday})
        ..lastActiveAt = now;
      final scheduler = _Scheduler();
      await NotificationSync.reapply(scheduler, text, now: now);
      expect(
        scheduler.applied.last
            .where((n) => n.kind == PlanKind.didYouTrain)
            .single
            .at,
        DateTime(2026, 10, 14, 21),
      );
      ReminderState.instance.lastSessionAt = now;
      await NotificationSync.reapplyLast(scheduler, now: now);
      expect(
        scheduler.applied.last
            .where((n) => n.kind == PlanKind.didYouTrain)
            .single
            .at,
        DateTime(2026, 10, 21, 21),
      );
    });

    test('opening the app twice in a day is not news; a new day is', () {
      final state = ReminderState.instance;
      expect(state.noteActive(now), isTrue);
      expect(state.noteActive(now.add(const Duration(hours: 3))), isFalse);
      expect(state.noteActive(now.add(const Duration(days: 1))), isTrue);
    });

    test('account deletion forgets all of it', () {
      ReminderState.instance
        ..offered = true
        ..permissionGranted = true
        ..schedule = TrainingReminders(weekdays: {DateTime.sunday})
        ..prefs = const NotificationPrefs(checkIns: false)
        ..lastActiveAt = now
        ..lastSessionAt = now
        ..reset();
      final state = ReminderState.instance;
      expect(state.permitted, isFalse);
      expect(state.prefs, const NotificationPrefs());
      expect(state.lastActiveAt, isNull);
      expect(state.lastSessionAt, isNull);
    });
  });

  group('her choices survive a restart', () {
    test('the reminders section round-trips', () {
      ReminderState.instance
        ..offered = true
        ..permissionGranted = true
        ..schedule = TrainingReminders(weekdays: {DateTime.sunday}, hour: 9)
        ..prefs = const NotificationPrefs(logNudge: false, restAlert: false)
        ..lastActiveAt = now
        ..lastSessionAt = now.subtract(const Duration(days: 2));
      final saved = jsonEncode(AppSnapshot.capture());
      ReminderState.instance.reset();
      AppSnapshot.restore(saved);
      final state = ReminderState.instance;
      expect(state.permissionGranted, isTrue);
      expect(
        state.prefs,
        const NotificationPrefs(logNudge: false, restAlert: false),
      );
      // Kept as a day, not a minute.
      expect(state.lastActiveAt, DateTime(2026, 10, 14));
      expect(state.lastSessionAt, DateTime(2026, 10, 12));
      expect(state.schedule?.hour, 9);
    });
  });

  group('a tap on a notification', () {
    test('opens only a screen on the list', () {
      expect(NotificationTaps.destinations, {
        'T01',
        'T02',
        'R09',
        ...NotificationTaps.tipDestinations,
      });
      expect(NotificationTaps.routeFor('X99', sessionLive: true), isNull);
      expect(NotificationTaps.routeFor(null, sessionLive: true), isNull);
      expect(
        NotificationTaps.routeFor('T02', sessionLive: false),
        '/today/t02',
      );
    });

    test('a tap on the screen she is already on opens nothing', () {
      expect(
        NotificationTaps.routeFor('T02', sessionLive: false, top: '/today/t02'),
        isNull,
      );
    });

    test(
      '"Rest is over" opens the live session, never a second one over it',
      () {
        // Already in the session: nothing to push.
        expect(
          NotificationTaps.routeFor(
            'R09',
            sessionLive: true,
            top: '/train/r09',
          ),
          isNull,
        );
        // Somewhere else with a session live: back into it.
        expect(
          NotificationTaps.routeFor(
            'R09',
            sessionLive: true,
            top: '/today/t01',
          ),
          '/train/r07',
        );
        // No session: a rest means nothing.
        expect(NotificationTaps.routeFor('R09', sessionLive: false), isNull);
      },
    );
  });

  group('push token refresh', () {
    test(
      'a rotated token writes the new document and removes the old',
      () async {
        final store = _Store();
        final sync = DeviceTokenSync(store: store, platform: 'android');
        await sync.register(uid: 'u1', locale: 'ar', token: 'token-one');
        final oldId = deviceDocId('token-one');
        expect(store.docs.keys, [oldId]);

        final refreshes = StreamController<String>();
        final sub = sync.follow(refreshes.stream, uid: 'u1', locale: 'ar');
        refreshes.add('token-two');
        await pumpEventQueue();

        expect(store.docs.keys, [deviceDocId('token-two')]);
        expect(store.docs[deviceDocId('token-two')]!['token'], 'token-two');
        expect(sync.docId, deviceDocId('token-two'));
        await sub.cancel();
        await refreshes.close();
      },
    );

    test(
      'the document keeps the rules\' whitelist, and no id is the token',
      () async {
        final store = _Store();
        final sync = DeviceTokenSync(store: store, platform: 'ios');
        await sync.register(uid: 'u1', locale: 'en', token: 'abc');
        final doc = store.docs.values.single;
        expect(doc.keys.toSet(), {
          'token',
          'platform',
          'appVersion',
          'locale',
          'updatedAt',
        });
        expect(doc['platform'], 'ios');
        expect(store.docs.keys.single, isNot(contains('abc')));
      },
    );

    test('the same token twice is not rewritten or removed', () async {
      final store = _Store();
      final sync = DeviceTokenSync(store: store, platform: 'android');
      await sync.register(uid: 'u1', locale: 'ar', token: 't');
      await sync.refreshed(uid: 'u1', locale: 'ar', token: 't');
      expect(store.docs, hasLength(1));
    });

    test('an adopted token is the one a later refresh replaces', () async {
      final store = _Store();
      await store.save('u1', deviceDocId('old'), {'token': 'old'});
      final sync = DeviceTokenSync(store: store, platform: 'android')
        ..adopt('old');
      await sync.refreshed(uid: 'u1', locale: 'ar', token: 'new');
      expect(store.docs.keys, [deviceDocId('new')]);
    });

    test('the approval push is the one kind the server sends', () {
      expect(kApprovalPushKind, 'verificationApproved');
    });
  });
}
