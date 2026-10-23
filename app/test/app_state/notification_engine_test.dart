// The adapter-side pieces of the notification engine that run without a
// phone: the time-zone follower, the sync between her state and the
// scheduler, tap routing, token refresh, and the snapshot.

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/app_snapshot.dart';
import 'package:own_hub/app_state/events_state.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/features/events/domain/event_registration.dart';
import 'package:own_hub/features/events/domain/event_repository.dart';
import 'package:own_hub/features/events/domain/hub_event.dart';
import 'package:own_hub/domain/clock/app_clock.dart';
import 'package:own_hub/features/train/domain/getting_started_tips.dart';
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

class _Registrar implements EventRegistrar {
  _Registrar(Set<String> mine, {this.offline = false}) : mine = {...mine};

  final Set<String> mine;
  final bool offline;

  @override
  Future<bool> isRegistered(String eventId) async {
    if (offline) throw const EventRegistrationException(SeatFailure.offline);
    return mine.contains(eventId);
  }

  @override
  Future<SeatResult> register(String eventId) async =>
      SeatResult(registered: true, seatsTaken: 1);

  @override
  Future<SeatResult> cancel(String eventId) async =>
      SeatResult(registered: false, seatsTaken: 0);
}

void main() {
  final en = lookupAppL10n(const Locale('en'));
  final text = AppRouter.reminderText(en).withEventCopy(en);
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
      // Nudges off: with them on, the shared casual budget can spend itself
      // on nudges before next week's "Trained today?", which is right but not
      // what this test is about.
      ReminderState.instance
        ..permissionGranted = true
        ..prefs = const NotificationPrefs(nudges: false)
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

    test(
      'logging a meal answers today\'s nudge and rebuilds the plan',
      () async {
        ReminderState.instance
          ..permissionGranted = true
          ..prefs = const NotificationPrefs(checkIns: false);
        final scheduler = _Scheduler();
        AppRouter.reminderScheduler = scheduler;
        addTearDown(() {
          AppRouter.reminderScheduler = null;
          AppClock.debugNow = null;
        });
        // A day early enough that its nudge is still ahead.
        DateTime? day;
        for (var d = 0; d < 7 && day == null; d++) {
          final at = DateTime(2026, 10, 14 + d, 6);
          final today = NotificationSync.planFor(at).where(
            (n) =>
                n.kind == PlanKind.nudge &&
                n.at.day == at.day &&
                n.at.month == at.month,
          );
          if (today.isNotEmpty) day = at;
        }
        expect(day, isNotNull, reason: 'some day this week has a nudge');
        await NotificationSync.reapply(scheduler, text, now: day);
        expect(
          scheduler.applied.last.where(
            (n) => n.kind == PlanKind.nudge && n.at.day == day!.day,
          ),
          isNotEmpty,
        );

        AppClock.debugNow = () => day!;
        await AppRouter.noteMealLogged();
        expect(ReminderState.instance.lastActiveAt, day);
        expect(scheduler.applied, hasLength(2));
        expect(
          scheduler.applied.last.where(
            (n) => n.kind == PlanKind.nudge && n.at.day == day!.day,
          ),
          isEmpty,
        );
      },
    );

    test('a tip pushed past the end is done, one it moved is still due', () {
      final anchor = DateTime(2026, 10, 1, 10);
      final series = TipSeries(
        anchorAt: anchor,
        due: {
          GettingStartedTip.videos: DateTime(2026, 10, 3, 18),
          GettingStartedTip.mealScan: DateTime(2026, 10, 4, 18),
        },
        done: {GettingStartedTip.firstWorkout},
      );
      final moved = NotificationSync.tipsApplied(
        series,
        [
          PlannedNotification(
            id: GettingStartedTip.videos.id,
            kind: PlanKind.tip,
            at: DateTime(2026, 10, 5, 18),
            variant: GettingStartedTip.videos.index,
          ),
        ],
        leftOut: [
          PlannedNotification(
            id: GettingStartedTip.mealScan.id,
            kind: PlanKind.tip,
            at: DateTime(2026, 10, 4, 18),
            variant: GettingStartedTip.mealScan.index,
          ),
        ],
      );
      expect(moved.due.keys, {GettingStartedTip.videos});
      expect(moved.due[GettingStartedTip.videos], DateTime(2026, 10, 5, 18));
      expect(moved.done, {
        GettingStartedTip.firstWorkout,
        GettingStartedTip.mealScan,
      });
    });

    test('a tip cut by the 3-note cap stays due, not done', () {
      final anchor = DateTime(2026, 10, 1, 10);
      final series = TipSeries(
        anchorAt: anchor,
        due: {
          GettingStartedTip.videos: DateTime(2026, 10, 3, 18),
          GettingStartedTip.mealScan: DateTime(2026, 10, 4, 18),
        },
        done: {GettingStartedTip.firstWorkout},
      );
      final kept = NotificationSync.tipsApplied(series, [
        PlannedNotification(
          id: GettingStartedTip.videos.id,
          kind: PlanKind.tip,
          at: DateTime(2026, 10, 3, 18),
          variant: GettingStartedTip.videos.index,
        ),
      ]);
      expect(kept.due[GettingStartedTip.mealScan], DateTime(2026, 10, 4, 18));
      expect(kept.due[GettingStartedTip.videos], DateTime(2026, 10, 3, 18));
      expect(kept.done, {GettingStartedTip.firstWorkout});
    });

    test('on day one the cap keeps three of seven tips and none go done', () {
      final anchor = DateTime(2026, 10, 1, 10);
      final tips = [
        for (final tip in GettingStartedTip.values)
          PlannedNotification(
            id: tip.id,
            kind: PlanKind.tip,
            at: DateTime(anchor.year, anchor.month, anchor.day + tip.day, 18),
            variant: tip.index,
          ),
      ];
      final leftOut = <PlannedNotification>[];
      final plan = NotificationPlan.build(
        now: anchor,
        permitted: true,
        lastActiveAt: anchor,
        prefs: const NotificationPrefs(nudges: false),
        tips: tips,
        tipsEnd: tipSeriesEnd(anchor),
        tipsLeftOut: leftOut,
      );
      final planned = plan.where((n) => n.kind == PlanKind.tip).toList();
      expect(planned.length, kNudgesUnanswered);
      expect(leftOut, isEmpty);

      final series = NotificationSync.tipsApplied(
        TipSeries(
          anchorAt: anchor,
          due: {
            for (final tip in GettingStartedTip.values) tip: tips[tip.index].at,
          },
        ),
        plan,
        leftOut: leftOut,
      );
      expect(series.done, isEmpty);
      expect(series.due.keys.toSet(), GettingStartedTip.values.toSet());
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
    test('the friendly nudges switch round-trips, off and on', () {
      for (final on in [false, true]) {
        ReminderState.instance
          ..permissionGranted = true
          ..prefs = NotificationPrefs(nudges: on);
        final saved = jsonEncode(AppSnapshot.capture());
        ReminderState.instance.reset();
        AppSnapshot.restore(saved);
        expect(ReminderState.instance.prefs.nudges, on);
      }
    });

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

  group('event reminders', () {
    final shipped = AppRouter.featureFlags;
    final start = DateTime(2026, 10, 20, 19);

    HubEvent event(String id, DateTime at, {int taken = 3}) => HubEvent(
      id: id,
      titleEn: 'Class $id',
      titleAr: 'حصة $id',
      startsAt: at.toUtc(),
      endsAt: at.add(const Duration(hours: 1)).toUtc(),
      mode: EventMode.online,
      status: EventStatus.published,
      capacity: 20,
      seatsTaken: taken,
    );

    List<PlannedNotification> events(_Scheduler s) =>
        s.applied.last.where((n) => n.kind == PlanKind.eventReminder).toList();

    setUp(() {
      AppRouter.featureFlags = FeatureFlags.allOff.with_({
        Feature.today: true,
        Feature.events: true,
      });
      EventsState.instance.reset();
      ReminderState.instance.permissionGranted = true;
    });
    tearDown(() {
      AppRouter.featureFlags = shipped;
      AppRouter.reminderScheduler = null;
      EventsState.instance.reset();
    });

    test('the plan carries the notes for the events she can join', () async {
      EventsState.instance.now = () => now;
      EventsState.instance.seed([event('a', start)]);
      final scheduler = _Scheduler();
      await NotificationSync.reapply(scheduler, text, now: now);
      final notes = events(scheduler);
      expect(notes.map((n) => n.at), [
        DateTime(2026, 10, 17, 10),
        DateTime(2026, 10, 19, 18),
        DateTime(2026, 10, 20, 16),
      ]);
      expect(ReminderState.instance.eventPlan, notes);
    });

    test('a seat she holds changes the notes to the booked pair', () async {
      EventsState.instance.now = () => now;
      EventsState.instance.seed([event('a', start)]);
      EventsState.instance.seedBooked(['a']);
      final scheduler = _Scheduler();
      await NotificationSync.reapply(scheduler, text, now: now);
      expect(events(scheduler).map((n) => n.at), [
        DateTime(2026, 10, 20, 9),
        DateTime(2026, 10, 20, 16),
      ]);
    });

    test('with the switch off there are none, and the saved ones go', () async {
      EventsState.instance.now = () => now;
      EventsState.instance.seed([event('a', start)]);
      final scheduler = _Scheduler();
      await NotificationSync.reapply(scheduler, text, now: now);
      expect(ReminderState.instance.eventPlan, isNotEmpty);
      ReminderState.instance.prefs = const NotificationPrefs(events: false);
      await NotificationSync.reapply(scheduler, text, now: now);
      expect(events(scheduler), isEmpty);
      expect(ReminderState.instance.eventPlan, isEmpty);
    });

    test('before any read, the notes already on the phone stand', () async {
      ReminderState.instance.eventPlan = [
        PlannedNotification(
          id: 7171,
          kind: PlanKind.eventReminder,
          at: DateTime(2026, 10, 17, 10),
        ),
        PlannedNotification(
          id: 7172,
          kind: PlanKind.eventReminder,
          at: DateTime(2026, 10, 12, 10),
        ),
      ];
      final scheduler = _Scheduler();
      await NotificationSync.reapply(scheduler, text, now: now);
      // The one still ahead is kept; the one gone by is not.
      expect(events(scheduler).map((n) => n.id), [7171]);
    });

    test('a read that finds no events cancels what was saved', () async {
      ReminderState.instance.eventPlan = [
        PlannedNotification(
          id: 7171,
          kind: PlanKind.eventReminder,
          at: DateTime(2026, 10, 17, 10),
        ),
      ];
      EventsState.instance.now = () => now;
      EventsState.instance.seed(const []);
      final scheduler = _Scheduler();
      await NotificationSync.reapply(scheduler, text, now: now);
      expect(events(scheduler), isEmpty);
      expect(ReminderState.instance.eventPlan, isEmpty);
    });

    test('a refresh plans the notes once the seats are known', () async {
      final scheduler = _Scheduler();
      AppRouter.reminderScheduler = scheduler;
      await NotificationSync.reapply(scheduler, text, now: now);
      final registrar = _Registrar({'a'});
      final reader = InMemoryEvents([
        event('a', start),
        event('b', DateTime(2026, 10, 24, 19)),
      ]);
      EventsState.instance.now = () => now;
      EventsState.instance.source = () => reader;
      EventsState.instance.registrar = () => registrar;
      await EventsState.instance.refresh(force: true);
      final notes = events(scheduler);
      // a is booked (two notes), b is not (three).
      expect(notes, hasLength(5));
      expect(notes.where((n) => eventFromCode(n.variant).booked), hasLength(2));
    });

    test('booking and cancelling plan the notes again', () async {
      final scheduler = _Scheduler();
      AppRouter.reminderScheduler = scheduler;
      await NotificationSync.reapply(scheduler, text, now: now);
      final registrar = _Registrar({});
      EventsState.instance.now = () => now;
      EventsState.instance.seed([event('a', start)]);
      EventsState.instance.registrar = () => registrar;
      registrar.mine.add('a');
      EventsState.instance.setSeats('a', 4);
      await pumpEventQueue();
      expect(events(scheduler).map((n) => n.at), [
        DateTime(2026, 10, 20, 9),
        DateTime(2026, 10, 20, 16),
      ]);
      registrar.mine.clear();
      EventsState.instance.setSeats('a', 3);
      await pumpEventQueue();
      expect(events(scheduler), hasLength(3));
    });

    test('switching events off in the app cancels the saved notes', () async {
      final scheduler = _Scheduler();
      AppRouter.reminderScheduler = scheduler;
      ReminderState.instance.eventPlan = [
        PlannedNotification(
          id: 7171,
          kind: PlanKind.eventReminder,
          at: DateTime(2026, 10, 17, 10),
        ),
      ];
      await NotificationSync.reapply(scheduler, text, now: now);
      AppRouter.featureFlags = FeatureFlags.allOff.with_({
        Feature.today: true,
        Feature.events: false,
      });
      EventsState.instance.now = () => now;
      await EventsState.instance.refresh(force: true);
      expect(events(scheduler), isEmpty);
      expect(ReminderState.instance.eventPlan, isEmpty);
    });

    test('an unreadable seat does not stop the notes', () async {
      final scheduler = _Scheduler();
      AppRouter.reminderScheduler = scheduler;
      await NotificationSync.reapply(scheduler, text, now: now);
      final reader = InMemoryEvents([event('a', start)]);
      EventsState.instance.now = () => now;
      EventsState.instance.source = () => reader;
      EventsState.instance.registrar = () => _Registrar({}, offline: true);
      await EventsState.instance.refresh(force: true);
      expect(events(scheduler), hasLength(3));
    });

    test('the adapter gives them their own channel, words and screen', () {
      final note = PlannedNotification(
        id: 7171,
        kind: PlanKind.eventReminder,
        at: start,
        variant: eventVariantCode(booked: false, variant: 1),
      );
      final booked = PlannedNotification(
        id: 7173,
        kind: PlanKind.eventReminder,
        at: start,
        variant: eventVariantCode(booked: true, variant: 0),
      );
      expect(reminderPayloadFor(note), 'T09');
      expect(reminderBodyFor(note, text), text.eventBodies[1]);
      expect(reminderBodyFor(booked, text), text.bookedEventBodies[0]);
      final channel = reminderChannelFor(PlanKind.eventReminder, text);
      expect(channel.$1, kEventChannelId);
      expect(channel.$2, text.eventChannelName);
      expect(channel.$3, text.eventChannelDescription);
      expect(channel.$1, isNot(reminderChannelFor(PlanKind.training, text).$1));
    });

    test('with no event words yet, an event note is never scheduled', () {
      final full = AppRouter.reminderText(en);
      final bare = ReminderText(
        title: full.title,
        body: full.body,
        channelName: full.channelName,
        channelDescription: full.channelDescription,
        logBody: full.logBody,
        checkInBodies: full.checkInBodies,
        restBody: full.restBody,
        checkInChannelName: full.checkInChannelName,
        checkInChannelDescription: full.checkInChannelDescription,
        restChannelName: full.restChannelName,
        restChannelDescription: full.restChannelDescription,
      );
      final note = PlannedNotification(
        id: 7171,
        kind: PlanKind.eventReminder,
        at: start,
      );
      expect(eventReminderBody(note, bare), isNull);
      expect(eventReminderBody(note, text), isNotNull);
    });

    test('a tap opens the events list, or Today when events are off', () {
      expect(NotificationTaps.routeFor('T09', sessionLive: false), isNotNull);
      expect(
        NotificationTaps.routeFor(
          'T09',
          sessionLive: false,
          isOn: (id) => id == 'T09',
        ),
        '/today/t09',
      );
      expect(
        NotificationTaps.routeFor(
          'T09',
          sessionLive: false,
          isOn: (id) => id == 'T01',
        ),
        '/today/t01',
      );
      expect(
        NotificationTaps.routeFor(
          'T09',
          sessionLive: false,
          top: '/today/t09',
          isOn: (id) => true,
        ),
        isNull,
      );
    });
  });

  group('event reminder choices survive a restart', () {
    test('the switch and the saved notes round-trip', () {
      ReminderState.instance
        ..permissionGranted = true
        ..prefs = const NotificationPrefs(events: false)
        ..eventPlan = [
          PlannedNotification(
            id: 7172,
            kind: PlanKind.eventReminder,
            at: DateTime(2026, 10, 19, 18),
            variant: 3,
          ),
        ];
      final saved = jsonEncode(AppSnapshot.capture());
      ReminderState.instance.reset();
      AppSnapshot.restore(saved);
      expect(ReminderState.instance.prefs.events, isFalse);
      expect(ReminderState.instance.eventPlan, [
        PlannedNotification(
          id: 7172,
          kind: PlanKind.eventReminder,
          at: DateTime(2026, 10, 19, 18),
          variant: 3,
        ),
      ]);
    });

    test('a snapshot from before this switch reads as on', () {
      ReminderState.instance
        ..permissionGranted = true
        ..prefs = const NotificationPrefs(nudges: false);
      final snapshot =
          jsonDecode(jsonEncode(AppSnapshot.capture())) as Map<String, Object?>;
      final section = Map<String, Object?>.from(snapshot['reminders']! as Map)
        ..remove('eventsOn')
        ..remove('eventPlan');
      snapshot['reminders'] = section;
      ReminderState.instance.reset();
      AppSnapshot.restore(jsonEncode(snapshot));
      expect(ReminderState.instance.prefs.events, isTrue);
      expect(ReminderState.instance.prefs.nudges, isFalse);
      expect(ReminderState.instance.eventPlan, isEmpty);
    });

    test('a damaged saved note is dropped, not scheduled', () {
      ReminderState.instance.permissionGranted = true;
      final snapshot =
          jsonDecode(jsonEncode(AppSnapshot.capture())) as Map<String, Object?>;
      final section = Map<String, Object?>.from(snapshot['reminders']! as Map)
        ..['eventPlan'] = [
          {'id': 7101, 'at': '2026-10-19T18:00:00.000', 'variant': 0},
          {'id': 7172, 'at': 'not a time', 'variant': 0},
          {'id': 7173, 'variant': 0},
          'junk',
          {'id': 7175, 'at': '2026-10-19T18:00:00.000', 'variant': 1},
        ];
      snapshot['reminders'] = section;
      ReminderState.instance.reset();
      AppSnapshot.restore(jsonEncode(snapshot));
      expect(ReminderState.instance.eventPlan.map((n) => n.id), [7175]);
    });
  });

  group('a tap on a notification', () {
    test('opens only a screen on the list', () {
      expect(NotificationTaps.destinations, {
        'T01',
        'T02',
        'R09',
        'E01',
        'P01',
        'T09',
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
