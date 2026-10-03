// Her health data is local unless she opts in, and opting in is server first.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:own_hub/app_state/account_data.dart';
import 'package:own_hub/features/account/data/callable_health_consent_store.dart';
import 'package:own_hub/features/account/domain/health_backup.dart';
import 'package:own_hub/features/account/domain/privacy_settings.dart';
import 'package:own_hub/features/account/presentation/privacy_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';

class _FakeStore implements HealthConsentStore {
  _FakeStore({this.fail = false, this.state});

  bool fail;
  HealthConsentState? state;
  final List<bool> calls = <bool>[];

  @override
  Future<void> record({required bool granted}) async {
    calls.add(granted);
    if (fail) throw StateError('unavailable');
    state = granted ? HealthConsentState.granted : HealthConsentState.withdrawn;
  }

  @override
  Future<HealthConsentState?> current(String uid) async {
    if (fail) throw StateError('unavailable');
    return state;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final pref = HealthBackupPreference.instance;

  setUp(() {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    pref.resetForTest();
  });

  group('R6: a stale withdrawal never purges a backup she turned back on', () {
    test(
      'off offline, on online, then reconcile: the backup stays on',
      () async {
        final store = _FakeStore(state: HealthConsentState.granted);
        final controller = HealthBackupController(store: store);
        await pref.set(true);

        // Off, with no network: off here, the withdrawal remembered.
        store.fail = true;
        expect(await controller.disable(), isFalse);
        expect(pref.withdrawPending, isTrue);

        // Back online, on again.
        store.fail = false;
        expect(await controller.enable(), isTrue);
        expect(pref.withdrawPending, isFalse);

        // What start-up and A03 do next.
        expect(await controller.retryPendingWithdraw(), isTrue);
        await controller.reconcile('u1');

        expect(pref.enabled, isTrue);
        expect(store.state, HealthConsentState.granted);
        expect(
          store.calls.last,
          isTrue,
          reason: 'no withdrawal after the grant',
        );
        pref.resetForTest();
        await pref.load();
        expect(
          pref.withdrawPending,
          isFalse,
          reason: 'and not after a restart',
        );
      },
    );

    test('a withdrawal already in flight finishes before the grant', () async {
      final store = _FakeStore(state: HealthConsentState.granted);
      final controller = HealthBackupController(store: store);
      await pref.set(false);
      await pref.setWithdrawPending(true);

      final retry = controller.retryPendingWithdraw();
      expect(await controller.enable(), isTrue);
      await retry;

      expect(store.calls, [false, true]);
      expect(store.state, HealthConsentState.granted);
      expect(pref.enabled, isTrue);
      expect(pref.withdrawPending, isFalse);
    });

    test('a failed grant keeps the withdrawal she asked for', () async {
      final store = _FakeStore(fail: true);
      final controller = HealthBackupController(store: store);
      await pref.setWithdrawPending(true);
      expect(await controller.enable(), isFalse);
      expect(pref.withdrawPending, isTrue);
    });
  });

  group('a pending withdrawal belongs to the account that asked for it', () {
    // The marker used to be per phone. A different account signing in on the
    // same handset (the sign-in-again path, a shared phone) would have had
    // its own health consent withdrawn, and its cloud copy purged, by the
    // start-up retry of somebody else's "off".

    Future<void> offlineOffAs(String uid) async {
      await pref.set(true);
      await HealthBackupController(
        store: _FakeStore(fail: true),
        uid: uid,
      ).disable();
      pref.resetForTest();
      await pref.load();
    }

    test('the uid is stored with the marker and survives a restart', () async {
      await offlineOffAs('uid-a');
      expect(pref.withdrawPending, isTrue);
      expect(pref.withdrawPendingUid, 'uid-a');
      expect(
        (await SharedPreferences.getInstance()).getString(
          kHealthWithdrawPendingUidKey,
        ),
        'uid-a',
      );
    });

    test('another account signing in is never withdrawn', () async {
      await offlineOffAs('uid-a');

      final store = _FakeStore(state: HealthConsentState.granted);
      expect(
        await HealthBackupController(
          store: store,
          uid: 'uid-b',
        ).retryPendingWithdraw(),
        isTrue,
      );
      expect(store.calls, isEmpty, reason: 'B never asked for a withdrawal');
      expect(store.state, HealthConsentState.granted);
      expect(pref.withdrawPending, isFalse, reason: 'cleared: account changed');
      expect(
        (await SharedPreferences.getInstance()).getBool(
          kHealthWithdrawPendingKey,
        ),
        isNull,
      );
    });

    test('the same account signing back in is withdrawn', () async {
      await offlineOffAs('uid-a');

      final store = _FakeStore(state: HealthConsentState.granted);
      expect(
        await HealthBackupController(
          store: store,
          uid: 'uid-a',
        ).retryPendingWithdraw(),
        isTrue,
      );
      expect(store.calls, <bool>[false]);
      expect(pref.withdrawPending, isFalse);
    });

    test(
      "a failed grant by another account does not inherit A's marker",
      () async {
        await offlineOffAs('uid-a');

        final store = _FakeStore(fail: true);
        expect(
          await HealthBackupController(store: store, uid: 'uid-b').enable(),
          isFalse,
        );
        expect(store.calls, <bool>[true], reason: 'no withdrawal sent for A');
        expect(pref.withdrawPending, isFalse);
      },
    );

    test('a marker written before uids were stored is not replayed', () async {
      SharedPreferences.setMockInitialValues(const <String, Object>{
        kHealthWithdrawPendingKey: true,
      });
      pref.resetForTest();
      await pref.load();

      final store = _FakeStore(state: HealthConsentState.granted);
      await HealthBackupController(
        store: store,
        uid: 'uid-b',
      ).retryPendingWithdraw();
      expect(store.calls, isEmpty);
      expect(pref.withdrawPending, isFalse);
    });
  });

  test('off by default, including after a load with nothing stored', () async {
    expect(pref.enabled, isFalse);
    await pref.load();
    expect(pref.enabled, isFalse);
  });

  test('the choice survives a restart under its own key', () async {
    await pref.set(true);
    pref.resetForTest();
    await pref.load();
    expect(pref.enabled, isTrue);
    expect(
      (await SharedPreferences.getInstance()).getBool(kHealthBackupKey),
      isTrue,
    );
  });

  test('turning it on records the consent first, then switches on', () async {
    final store = _FakeStore();
    var synced = 0;
    final controller = HealthBackupController(
      store: store,
      onEnabled: () => synced++,
    );
    expect(await controller.enable(), isTrue);
    expect(store.calls, <bool>[true]);
    expect(pref.enabled, isTrue);
    expect(synced, 1);
  });

  test('it cannot switch on unless the server confirmed', () async {
    final store = _FakeStore(fail: true);
    var synced = 0;
    final controller = HealthBackupController(
      store: store,
      onEnabled: () => synced++,
    );
    expect(await controller.enable(), isFalse);
    expect(pref.enabled, isFalse);
    expect(synced, 0);
  });

  test('turning it off stops uploads here at once, even offline', () async {
    // C4(d). It used to change nothing when the withdraw call failed, which
    // left her health data uploading after she said stop. Now the phone stops
    // first; the server withdrawal (and the cloud purge) follows when it can.
    await pref.set(true);
    final store = _FakeStore(fail: true);
    var stopped = 0;
    final controller = HealthBackupController(
      store: store,
      onDisabled: () => stopped++,
    );
    expect(await controller.disable(), isFalse, reason: 'server not reached');
    expect(pref.enabled, isFalse, reason: 'off on this phone regardless');
    expect(stopped, 1);
    expect(pref.withdrawPending, isTrue);
    expect(
      (await SharedPreferences.getInstance()).getBool(
        kHealthWithdrawPendingKey,
      ),
      isTrue,
      reason: 'remembered across a restart',
    );

    // Back online: the retry sends the withdrawal and clears the marker.
    store.fail = false;
    expect(await controller.retryPendingWithdraw(), isTrue);
    expect(store.calls.last, isFalse);
    expect(pref.withdrawPending, isFalse);
    expect(pref.enabled, isFalse);
  });

  test('a pending withdrawal survives a restart and is retried', () async {
    await pref.set(true);
    await HealthBackupController(store: _FakeStore(fail: true)).disable();
    pref.resetForTest();
    await pref.load();
    expect(pref.enabled, isFalse);
    expect(pref.withdrawPending, isTrue);

    final store = _FakeStore();
    expect(
      await HealthBackupController(store: store).retryPendingWithdraw(),
      isTrue,
    );
    expect(store.calls, <bool>[false]);
  });

  test('with nothing pending, the retry calls nobody', () async {
    final store = _FakeStore();
    expect(
      await HealthBackupController(store: store).retryPendingWithdraw(),
      isTrue,
    );
    expect(store.calls, isEmpty);
  });

  test('online, turning it off withdraws and leaves nothing pending', () async {
    await pref.set(true);
    final store = _FakeStore();
    expect(await HealthBackupController(store: store).disable(), isTrue);
    expect(store.calls, <bool>[false]);
    expect(pref.enabled, isFalse);
    expect(pref.withdrawPending, isFalse);
  });

  test(
    'the server wins: a withdrawn or missing consent switches it off',
    () async {
      for (final serverState in <HealthConsentState?>[
        HealthConsentState.withdrawn,
        null,
      ]) {
        await pref.set(true);
        await HealthBackupController(store: _FakeStore(state: serverState))
            .reconcile('u1');
        expect(pref.enabled, isFalse, reason: '$serverState');
      }
      await pref.set(true);
      await HealthBackupController(
        store: _FakeStore(state: HealthConsentState.granted),
      ).reconcile('u1');
      expect(pref.enabled, isTrue);
    },
  );

  test('deleting everything on the phone forgets the choice', () async {
    await pref.set(true);
    await const ThisPhoneWipe().clearPersistence();
    await Future<void>.delayed(Duration.zero);
    expect(pref.enabled, isFalse);
    expect(
      (await SharedPreferences.getInstance()).getBool(kHealthBackupKey),
      isNull,
    );
  });

  group('the callable store speaks the server shape', () {
    test('payload', () {
      expect(CallableHealthConsentStore.payloadFor(granted: true), {
        'consentVersion': 1,
        'granted': true,
      });
      expect(
        CallableHealthConsentStore.payloadFor(granted: false)['granted'],
        isFalse,
      );
    });

    test('document', () {
      expect(
        CallableHealthConsentStore.stateFromDoc({
          'version': 1,
          'state': 'granted',
        }),
        HealthConsentState.granted,
      );
      expect(
        CallableHealthConsentStore.stateFromDoc({
          'version': 1,
          'state': 'withdrawn',
        }),
        HealthConsentState.withdrawn,
      );
      expect(
        CallableHealthConsentStore.stateFromDoc({
          'version': 2,
          'state': 'granted',
        }),
        isNull,
      );
      expect(CallableHealthConsentStore.stateFromDoc(null), isNull);
    });
  });

  group('A03', () {
    Widget host(HealthBackupController? controller) => MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      theme: buildTheme(const Locale('en')),
      home: PrivacyView(
        service: PrivacySettingsService(InMemoryPrivacyRepository()),
        healthBackup: controller,
      ),
    );

    testWidgets('no account, no row', (tester) async {
      await tester.pumpWidget(host(null));
      await tester.pumpAndSettle();
      expect(find.text('Back up my health data'), findsNothing);
    });

    testWidgets('agreeing in the sheet turns it on, server first', (
      tester,
    ) async {
      final store = _FakeStore();
      await tester.pumpWidget(host(HealthBackupController(store: store)));
      await tester.pumpAndSettle();
      expect(find.text('Back up my health data'), findsOneWidget);
      expect(find.textContaining('stay on this phone only'), findsOneWidget);

      await tester.tap(find.text('Back up my health data'));
      await tester.pumpAndSettle();
      // The sheet names where the copy goes.
      expect(find.textContaining('Frankfurt'), findsOneWidget);
      expect(find.textContaining('United States'), findsOneWidget);
      expect(store.calls, isEmpty);

      await tester.ensureVisible(find.text('I agree, back up my health data'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('I agree, back up my health data'));
      await tester.pumpAndSettle();
      expect(store.calls, <bool>[true]);
      expect(pref.enabled, isTrue);
    });

    testWidgets('not now changes nothing', (tester) async {
      final store = _FakeStore();
      await tester.pumpWidget(host(HealthBackupController(store: store)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Back up my health data'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Not now'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(store.calls, isEmpty);
      expect(pref.enabled, isFalse);
    });

    testWidgets('a failed call is said plainly and nothing changes', (
      tester,
    ) async {
      final store = _FakeStore(fail: true);
      await tester.pumpWidget(host(HealthBackupController(store: store)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Back up my health data'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('I agree, back up my health data'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('I agree, back up my health data'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('health-backup-error')), findsOneWidget);
      expect(pref.enabled, isFalse);
    });
  });
}
