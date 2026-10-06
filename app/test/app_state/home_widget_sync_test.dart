// The widget payload is written as she goes, and taken away when she leaves.
//
// `HomeWidgetSync` over an in-memory store, with time controlled: a burst of
// changes is one write, an unchanged payload is not written twice, both
// widgets are reloaded, signing out and deleting her account clear it, and a
// woman who is not let in (the tour, or a signed-out phone) never has her
// numbers written at all.

import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/account_data.dart';
import 'package:own_hub/app_state/app_changes.dart';
import 'package:own_hub/app_state/home_widget_sync.dart';
import 'package:own_hub/features/today/domain/today_day.dart';
import 'package:own_hub/features/today/domain/widget_projection.dart';

class _FakeWidgetStore implements WidgetStore {
  final Map<String, String> values = {};
  final List<String> groups = [];
  final List<String> reloads = [];
  int saves = 0;

  @override
  Future<void> useAppGroup(String groupId) async => groups.add(groupId);

  @override
  Future<void> save(String key, String? value) async {
    saves++;
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }

  @override
  Future<void> reload(String kind) async => reloads.add(kind);

  Map<String, Object?>? get payload {
    final raw = values[kWidgetPayloadKey];
    return raw == null ? null : (jsonDecode(raw) as Map).cast();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sync = HomeWidgetSync.instance;
  late _FakeWidgetStore store;
  late int done;
  late bool open;

  TodayDay day() => TodayDay(
    date: DateTime(2026, 10, 6, 9),
    state: DayState.nothingDone,
    arc: const FirstWeekArc(hasAnyLog: true),
    week: WeekProgress(sessionsLogged: done, sessionsTarget: 3),
  );

  void startSync() => sync.start(readDay: day, isOpen: () => open);

  setUp(() {
    sync.reset();
    store = _FakeWidgetStore();
    sync.store = store;
    sync.now = () => DateTime(2026, 10, 6, 10);
    done = 1;
    open = true;
  });

  tearDown(sync.reset);

  test('writes once at start, in the App Group, and reloads both kinds', () {
    fakeAsync((async) {
      startSync();
      async.flushMicrotasks();
      expect(store.groups, [kWidgetAppGroup]);
      expect(store.payload!['done'], 1);
      expect(store.reloads, kWidgetKinds);
      expect(kWidgetKinds, ['OwnHubWeek', 'OwnHubToday']);
    });
  });

  test('a burst of changes is one debounced write', () {
    fakeAsync((async) {
      startSync();
      async.flushMicrotasks();
      final before = store.saves;
      done = 2;
      for (var i = 0; i < 5; i++) {
        AppChanges.bump();
        async.elapse(const Duration(milliseconds: 100));
      }
      expect(store.saves, before);
      async.elapse(HomeWidgetSync.writeDelay);
      expect(store.saves, before + 1);
      expect(store.payload!['done'], 2);
    });
  });

  test('an unchanged payload is not written or reloaded again', () {
    fakeAsync((async) {
      startSync();
      async.flushMicrotasks();
      final saves = store.saves;
      final reloads = store.reloads.length;
      AppChanges.bump();
      async.elapse(const Duration(seconds: 1));
      expect(store.saves, saves);
      expect(store.reloads.length, reloads);
    });
  });

  test('her in-app language rewrites it', () {
    fakeAsync((async) {
      startSync();
      async.flushMicrotasks();
      sync.useLocale(const Locale('ar'));
      async.flushMicrotasks();
      expect(store.payload!['lang'], 'ar');
    });
  });

  test('not let in: closed, and none of her numbers are written', () {
    fakeAsync((async) {
      open = false;
      done = 3;
      startSync();
      AppChanges.bump();
      async.elapse(const Duration(seconds: 1));
      final payload = store.payload!;
      expect(payload['state'], 'closed');
      expect(payload.containsKey('done'), isFalse);
      expect(store.values[kWidgetPayloadKey], isNot(contains('3')));
    });
  });

  test('the gate opening later opens the widget', () {
    fakeAsync((async) {
      open = false;
      startSync();
      async.flushMicrotasks();
      expect(store.payload!['state'], 'closed');
      open = true;
      AppChanges.bump();
      async.elapse(const Duration(seconds: 1));
      expect(store.payload!['state'], 'open');
    });
  });

  test('clear() removes the key and reloads both widgets', () {
    fakeAsync((async) {
      startSync();
      async.flushMicrotasks();
      store.reloads.clear();
      sync.clear();
      async.flushMicrotasks();
      expect(store.values.containsKey(kWidgetPayloadKey), isFalse);
      expect(store.reloads, kWidgetKinds);
    });
  });

  test('a write pending at sign-out never lands', () {
    fakeAsync((async) {
      startSync();
      async.flushMicrotasks();
      done = 2;
      AppChanges.bump();
      sync.clear();
      async.elapse(const Duration(seconds: 1));
      expect(store.values.containsKey(kWidgetPayloadKey), isFalse);
    });
  });

  test('deleting everything on this phone clears it', () async {
    startSync();
    await sync.flush();
    expect(store.payload, isNotNull);
    open = false;
    await deleteEverythingOnThisPhone();
    // The wipe bumps once at the end, which writes the closed payload.
    await sync.flush();
    final payload = store.payload;
    expect(payload == null || payload['state'] == 'closed', isTrue);
    expect(store.saves, greaterThanOrEqualTo(2));
    expect(store.values[kWidgetPayloadKey] ?? '', isNot(contains('"done"')));
  });

  test('signing out clears it', () async {
    startSync();
    await sync.flush();
    final savesBefore = store.saves;
    await const ThisPhoneWipe().signOut();
    await Future<void>.delayed(Duration.zero);
    expect(store.values.containsKey(kWidgetPayloadKey), isFalse);
    expect(store.saves, savesBefore + 1);
  });

  test('off unless started: clear() touches no store', () async {
    await sync.clear();
    expect(store.saves, 0);
    expect(store.groups, isEmpty);
  });
}
