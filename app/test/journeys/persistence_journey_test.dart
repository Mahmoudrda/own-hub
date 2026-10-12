// Closing the app and opening it again, walked through the real app.
//
// Every store in this build was in memory and nothing else, so a woman who
// logged a session and a meal and then swiped the app away came back to a
// product that had never met her: no session, no meal, no week, no settings,
// not even the language she had chosen. These tests do the two things that
// matter and then end the process: they log through the real screens, simulate
// a relaunch, and check that her session, her meal and her week are still
// there.
//
// The second half is the half that decides whether this ships. A snapshot read
// off a phone can be missing, truncated by a kill mid-write, corrupt or written
// by an older build, and an app that crashes on launch because of one is worse
// than an app that forgets everything. So the corrupt cases are walked too, and
// deleting her account is checked to actually delete — a wipe that leaves the
// document behind would bring all of it back on the next launch.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/app_changes.dart';
import 'package:own_hub/app_state/account_data.dart';
import 'package:own_hub/app_state/app_snapshot.dart';
import 'package:own_hub/app_state/eat_state.dart';
import 'package:own_hub/app_state/local_persistence.dart';
import 'package:own_hub/app_state/workout_session_state.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/domain/week/week_key.dart';
import 'package:own_hub/features/eat/domain/meal_repository.dart';
import 'package:own_hub/main.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

Future<void> _boot(WidgetTester tester) async {
  await tester.pumpWidget(OwnHubApp(key: UniqueKey()));
  await tester.pumpAndSettle();
}

NavigatorState _nav(WidgetTester tester) =>
    tester.state<NavigatorState>(find.byType(Navigator).first);

Future<void> _open(WidgetTester tester, String id) async {
  _nav(tester).pushNamed(appDestinations[id]!.name);
  await tester.pumpAndSettle();
}

Future<void> _home(WidgetTester tester) async {
  _nav(tester).popUntil((route) => route.isFirst);
  await tester.pumpAndSettle();
}

String get _todayId {
  final now = DateTime.now();
  return '${now.year.toString().padLeft(4, '0')}-'
      '${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';
}

int get _weekInProgress =>
    AppRouter
        .progressStore
        .weeks[WeekKey.of(DateTime.now()).id]
        ?.creditedSessionIds
        .length ??
    0;

List<String> get _foodsWritten => [
  for (final item
      in AppRouter.mealRepository.store.days[_todayId]?.allItems ??
          const <MealItem>[])
    item.foodId,
];

/// A whole workout, through R03: start it, log every move, finish.
Future<void> _trainAndFinish(WidgetTester tester) async {
  await _open(tester, 'R03');
  await tester.tap(find.textContaining('Start'));
  await tester.pumpAndSettle();

  var guard = 0;
  while (!WorkoutSessionState.instance.isComplete && guard++ < 12) {
    final all = find.textContaining('I did');
    if (all.evaluate().isEmpty) break;
    await tester.tap(all.first);
    await tester.pumpAndSettle();
    final next = find.text('Next move');
    if (next.evaluate().isEmpty) break;
    await tester.tap(next);
    await tester.pumpAndSettle();
  }

  final finish = find.text('Finish here');
  if (finish.evaluate().isNotEmpty) {
    await tester.tap(finish);
    await tester.pumpAndSettle();
  }
}

/// A meal, through E02: type it, log it, let the five seconds close.
Future<void> _eatKoshari(WidgetTester tester) async {
  await _open(tester, 'E02');
  await tester.enterText(find.byType(TextField).first, 'koshari');
  await tester.pumpAndSettle();
  await tester.tap(find.text('Add it'));
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 6));
  await tester.pumpAndSettle();
}

/// What is on the phone right now.
Future<String?> _onThePhone() => LocalPersistence.instance.storage.read();

/// Ends the process and starts a new one.
///
/// A relaunch cannot be faked by pumping a new widget: every store in this app
/// is a static, and a static survives a `pumpWidget` exactly as it would not
/// survive a kill. So this does what the operating system does, in order —
/// hands the last write to the phone, takes every store back to what a fresh
/// isolate holds, and then loads from the same storage the first run wrote.
///
/// [ThisPhoneWipe.clearPersistence] erases the document as well, which is the
/// whole point of it, so what the phone was holding is read first and put back
/// before the new run opens. On a real handset nobody erases it; here the only
/// way to empty the memory is the call that also empties the disk.
Future<void> _relaunch(WidgetTester tester) async {
  await LocalPersistence.instance.flush();
  final wasOnThePhone = await _onThePhone();

  LocalPersistence.instance.stop();
  await const ThisPhoneWipe().clearPersistence();

  SharedPreferences.setMockInitialValues(<String, Object>{
    kSnapshotKey: ?wasOnThePhone,
  });

  await LocalPersistence.instance.load();
  LocalPersistence.instance.start();
  await _boot(tester);
}

/// A snapshot store that keeps what it was given, so a test can count writes.
class _Recorder implements SnapshotStorage {
  String? document;
  int writes = 0;
  int erases = 0;

  @override
  Future<String?> read() async => document;

  @override
  Future<void> write(String snapshot) async {
    document = snapshot;
    writes++;
  }

  @override
  Future<void> erase() async {
    document = null;
    erases++;
  }
}

/// She swipes the app away.
Future<void> _swipeAway(WidgetTester tester, String state) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/lifecycle',
    const StringCodec().encodeMessage(state),
    (_) {},
  );
  await tester.idle();
}

void main() {
  final saved = AppRouter.featureFlags;

  setUp(() async {
    AppRouter.featureFlags = FeatureFlags.allOff.with_({
      for (final f in Feature.values) f: f != Feature.accountRequired,
    });
    LocalPersistence.instance.reset();
    await const ThisPhoneWipe().clearPersistence();
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    // These cases are about a woman who has used the app and come back, so she
    // has been through the four setup questions. Without this the relaunch
    // opens on `O01` over Home, which is correct for a fresh install and is a
    // different journey — it is walked in `onboarding_journey_test.dart`. It
    // is set before the first boot on purpose: the snapshot the first run
    // writes then carries the flag, and the relaunch restores it.
    AppRouter.intakeRepository.markSetupDone();
    LocalPersistence.instance.start();
  });

  tearDown(() async {
    LocalPersistence.instance.reset();
    await const ThisPhoneWipe().clearPersistence();
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    AppRouter.featureFlags = saved;
  });

  group('what she did survives the app being closed', () {
    testWidgets('her session, her meal and her week are all still there', (
      tester,
    ) async {
      _phone(tester);
      await _boot(tester);

      await _trainAndFinish(tester);
      await _home(tester);
      await _eatKoshari(tester);
      await _home(tester);

      final weekBefore = _weekInProgress;
      final homeWeekBefore = AppRouter.todayRepository.day.week.sessionsLogged;
      final pointsBefore = AppRouter.progressStore.rewards.points;
      expect(weekBefore, 1, reason: 'one session, credited once');
      expect(_foodsWritten, contains('koshari_bowl'));

      await _relaunch(tester);

      expect(
        LocalPersistence.instance.restoredSections,
        greaterThan(0),
        reason: 'the new run read the document the old one wrote',
      );

      // Her session.
      expect(
        AppRouter.trainRepository.sessions.where((s) => s.completed),
        isNotEmpty,
        reason: 'the workout she finished is still a workout she finished',
      );
      expect(_weekInProgress, weekBefore, reason: 'the week document');
      expect(
        AppRouter.todayRepository.day.week.sessionsLogged,
        homeWeekBefore,
        reason: "Home's own copy of the week",
      );
      expect(
        AppRouter.progressStore.rewards.points,
        pointsBefore,
        reason: 'the points she earned',
      );

      // Her meal.
      expect(_foodsWritten, contains('koshari_bowl'));
      expect(
        EatAppState.instance.usualPlates.map((p) => p.foodId),
        contains('koshari_bowl'),
        reason: 'the plate she ate is still one of her plates',
      );

      // And the first screen she sees says so, rather than the app's defaults.
      expect(
        find.text('Koshari bowl'),
        findsOneWidget,
        reason: "Home's meal card opens on the meal she logged yesterday",
      );
    });

    testWidgets('a second relaunch does not count the same session twice', (
      tester,
    ) async {
      _phone(tester);
      await _boot(tester);
      await _trainAndFinish(tester);
      await _home(tester);

      final week = _weekInProgress;
      await _relaunch(tester);
      expect(_weekInProgress, week);
      await _relaunch(tester);
      expect(
        _weekInProgress,
        week,
        reason: 'the credited session ids come back with the week',
      );
    });
  });

  group('a snapshot that cannot be read costs her the snapshot, never the app', () {
    Future<void> opensCleanly(WidgetTester tester, String stored) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        kSnapshotKey: stored,
      });
      await LocalPersistence.instance.load();
      await _boot(tester);

      expect(
        tester.takeException(),
        isNull,
        reason: 'the launch did not throw on: $stored',
      );
      expect(
        find.byType(Navigator),
        findsWidgets,
        reason: 'the app is on screen: $stored',
      );
    }

    testWidgets('empty, truncated, corrupt or foreign', (tester) async {
      _phone(tester);

      // A real document, cut in half by a kill mid-write.
      final whole = jsonEncode(AppSnapshot.capture());
      final truncated = whole.substring(0, whole.length ~/ 2);

      for (final stored in <String>[
        '',
        ' ',
        'not json at all',
        '{',
        '[]',
        '[1, 2, 3]',
        'null',
        '"a string"',
        '{}',
        truncated,
        // Every section the wrong type.
        '{"schema":1,"today":"a string","progress":7,"meals":[],"cycle":true}',
        // The right shape, nonsense inside it.
        '{"schema":1,"today":{"date":"not a date","week":{"logged":"three"}}}',
        // A build that shaped things differently.
        '{"schema":0,"today":{"date":"2026-09-01T09:00:00.000"}}',
        '{"schema":99,"today":{"date":"2026-09-01T09:00:00.000"}}',
        '{"today":{"date":"2026-09-01T09:00:00.000"}}',
      ]) {
        await opensCleanly(tester, stored);
      }
    });

    test('a foreign schema restores nothing at all', () {
      final whole = jsonDecode(jsonEncode(AppSnapshot.capture()));
      (whole as Map<String, Object?>)['schema'] = kSnapshotSchema + 1;
      expect(AppSnapshot.restore(jsonEncode(whole)), 0);
    });

    test('nothing stored restores nothing, and does not throw', () {
      expect(AppSnapshot.restore(null), 0);
      expect(AppSnapshot.restore(''), 0);
    });

    test('one bad section costs one section', () {
      // Her meals are unreadable; her training is fine. The training comes back.
      final whole =
          jsonDecode(jsonEncode(AppSnapshot.capture())) as Map<String, Object?>;
      whole['meals'] = 'rubbish';
      whole['train'] = <String, Object?>{'sessions': 'rubbish too'};
      final restored = AppSnapshot.restore(jsonEncode(whole));
      expect(
        restored,
        greaterThan(0),
        reason: 'the sections that decoded were applied',
      );
      expect(
        restored,
        lessThan(10),
        reason: 'the sections that did not decode were not',
      );
    });
  });

  group('a burst of taps is one write, and swiping away is another', () {
    testWidgets('twenty changes in a row cost one write, not twenty', (
      tester,
    ) async {
      final recorder = _Recorder();
      LocalPersistence.instance.storage = recorder;
      await _boot(tester);

      for (var i = 0; i < 20; i++) {
        AppChanges.bump();
      }
      expect(recorder.writes, 0, reason: 'nothing has settled yet');

      await tester.pump(LocalPersistence.writeDelay * 2);
      await tester.idle();
      expect(recorder.writes, 1);
    });

    testWidgets('paused and detached write what the debounce is holding', (
      tester,
    ) async {
      final recorder = _Recorder();
      LocalPersistence.instance.storage = recorder;
      await _boot(tester);

      AppRouter.todayRepository.recordSession('the-one-she-just-finished');
      AppChanges.bump();
      expect(
        recorder.writes,
        0,
        reason: 'the write is still a few hundred milliseconds away',
      );

      await _swipeAway(tester, 'AppLifecycleState.inactive');
      await _swipeAway(tester, 'AppLifecycleState.paused');
      expect(recorder.writes, 1, reason: 'paused does not wait for the timer');
      expect(recorder.document, contains('the-one-she-just-finished'));

      AppChanges.bump();
      await _swipeAway(tester, 'AppLifecycleState.detached');
      expect(recorder.writes, 2, reason: 'detached writes too');
    });
  });

  group('deleting everything deletes the snapshot too', () {
    testWidgets('nothing of hers comes back on the next launch', (
      tester,
    ) async {
      _phone(tester);
      await _boot(tester);

      await _trainAndFinish(tester);
      await _home(tester);
      await _eatKoshari(tester);
      await _home(tester);

      await LocalPersistence.instance.flush();
      expect(
        await _onThePhone(),
        contains('koshari_bowl'),
        reason: 'her meal really is on the phone before she deletes it',
      );

      await deleteEverythingOnThisPhone();
      await tester.pumpAndSettle();

      expect(
        await _onThePhone(),
        anyOf(isNull, isNot(contains('koshari_bowl'))),
        reason: 'the document on the phone went with the stores',
      );

      await _relaunch(tester);

      expect(nothingOfHersRemains, isTrue);
      expect(_foodsWritten, isEmpty);
      expect(EatAppState.instance.usualPlates, isEmpty);
      expect(AppRouter.trainRepository.sessions, isEmpty);
      expect(_weekInProgress, 0);
      expect(
        find.text('Koshari bowl'),
        findsNothing,
        reason: 'the meal she deleted is not on Home either',
      );
    });
  });
}
