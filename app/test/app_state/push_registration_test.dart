import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/push_registration.dart';

class _Store implements DeviceStore {
  final Map<String, Map<String, Object>> docs = {};
  int saves = 0;

  @override
  Future<void> save(String uid, String docId, Map<String, Object> doc) async {
    saves++;
    docs[docId] = doc;
  }

  @override
  Future<void> remove(String uid, String docId) async => docs.remove(docId);
}

class _Flag implements PushOptInFlag {
  final Map<PushTopic, String> uids = {};

  /// The C14 yes.
  String? get uid => uids[PushTopic.approval];

  @override
  Future<String?> read([PushTopic topic = PushTopic.approval]) async =>
      uids[topic];

  @override
  Future<void> write(
    String value, [
    PushTopic topic = PushTopic.approval,
  ]) async => uids[topic] = value;

  @override
  Future<void> clear() async => uids.clear();
}

class _Messaging extends Fake implements FirebaseMessaging {
  _Messaging(this.refreshes);

  final StreamController<String> refreshes;
  String token = 'token-one';
  bool tokenFails = false;
  AuthorizationStatus status = AuthorizationStatus.authorized;
  bool settingsFail = false;

  @override
  Stream<String> get onTokenRefresh => refreshes.stream;

  @override
  Future<String?> getToken({
    String? vapidKey,
    String? serviceWorkerScriptPath,
  }) async {
    if (tokenFails) throw StateError('no network');
    return token;
  }

  @override
  Future<NotificationSettings> getNotificationSettings() async {
    if (settingsFail) throw StateError('no plugin');
    return NotificationSettings(
      alert: AppleNotificationSetting.enabled,
      announcement: AppleNotificationSetting.notSupported,
      authorizationStatus: status,
      badge: AppleNotificationSetting.enabled,
      carPlay: AppleNotificationSetting.notSupported,
      lockScreen: AppleNotificationSetting.enabled,
      notificationCenter: AppleNotificationSetting.enabled,
      showPreviews: AppleShowPreviewSetting.always,
      timeSensitive: AppleNotificationSetting.notSupported,
      criticalAlert: AppleNotificationSetting.notSupported,
      sound: AppleNotificationSetting.enabled,
      providesAppNotificationSettings: AppleNotificationSetting.notSupported,
    );
  }

  @override
  Future<NotificationSettings> requestPermission({
    bool alert = true,
    bool announcement = false,
    bool badge = true,
    bool carPlay = false,
    bool criticalAlert = false,
    bool provisional = false,
    bool sound = true,
    bool providesAppNotificationSettings = false,
  }) => getNotificationSettings();
}

void main() {
  late _Store store;
  late _Flag flag;
  late StreamController<String> refreshes;
  late _Messaging messaging;
  late FirebasePushRegistrar registrar;
  late StreamController<RemoteMessage> opened;
  RemoteMessage? launchedWith;

  setUp(() {
    store = _Store();
    flag = _Flag();
    refreshes = StreamController<String>.broadcast();
    messaging = _Messaging(refreshes);
    opened = StreamController<RemoteMessage>.broadcast();
    launchedWith = null;
    registrar = FirebasePushRegistrar(
      messaging: messaging,
      sync: DeviceTokenSync(store: store, platform: 'android'),
      optInFlag: flag,
      onMessage: const Stream<RemoteMessage>.empty(),
      onOpened: opened.stream,
      initial: () async => launchedWith,
    );
  });

  tearDown(() async {
    await refreshes.close();
    await opened.close();
  });

  test('permission alone writes nothing and follows nothing', () async {
    await registrar.watch(uid: 'u1', locale: 'ar');
    refreshes.add('token-two');
    await pumpEventQueue();
    expect(store.saves, 0);
    expect(store.docs, isEmpty);
    expect(refreshes.hasListener, isFalse);
  });

  test(
    'after opt-in a refresh writes the new document, removes the old',
    () async {
      expect(await registrar.optIn(uid: 'u1', locale: 'ar'), PushOptIn.on);
      expect(flag.uid, 'u1');
      expect(store.docs.keys, [deviceDocId('token-one')]);

      await registrar.watch(uid: 'u1', locale: 'ar');
      refreshes.add('token-two');
      await pumpEventQueue();
      expect(store.docs.keys, [deviceDocId('token-two')]);
    },
  );

  test('an opt-in by another uid does not carry over', () async {
    await registrar.optIn(uid: 'u1', locale: 'ar');
    final saves = store.saves;
    await registrar.forget();
    await registrar.watch(uid: 'u2', locale: 'ar');
    expect(store.saves, saves);
  });

  test('sign-out stops watching and clears the flag', () async {
    await registrar.optIn(uid: 'u1', locale: 'ar');
    expect(refreshes.hasListener, isTrue);

    await registrar.forget();
    await pumpEventQueue();
    expect(flag.uid, isNull);
    expect(refreshes.hasListener, isFalse);

    refreshes.add('token-three');
    await pumpEventQueue();
    expect(store.docs.keys, [deviceDocId('token-one')]);

    await registrar.watch(uid: 'u1', locale: 'ar');
    expect(refreshes.hasListener, isFalse);
  });

  group('a tap on a push', () {
    const push = {'kind': 'instapayConfirmed', 'paymentId': 'p1'};
    late List<Map<String, Object?>> taps;

    setUp(() => taps = []);

    Future<void> watching() async {
      await registrar.optIn(uid: 'u1', locale: 'ar');
      await registrar.watch(uid: 'u1', locale: 'ar', onTap: taps.add);
    }

    test(
      'with the app in the background reaches onTap with its data',
      () async {
        await watching();
        opened.add(const RemoteMessage(data: push));
        await pumpEventQueue();
        expect(taps, [push]);
      },
    );

    test(
      'that launched the app reaches onTap once, however often she watches',
      () async {
        launchedWith = const RemoteMessage(data: push);
        await watching();
        await pumpEventQueue();
        await registrar.watch(uid: 'u1', locale: 'ar', onTap: taps.add);
        await pumpEventQueue();
        expect(taps, [push]);
      },
    );

    test('is still heard when the token cannot be read', () async {
      await registrar.optIn(uid: 'u1', locale: 'ar');
      messaging.tokenFails = true;
      launchedWith = const RemoteMessage(data: push);
      await registrar.watch(uid: 'u1', locale: 'ar', onTap: taps.add);
      opened.add(const RemoteMessage(data: push));
      await pumpEventQueue();
      expect(taps, [push, push]);
    });

    test('is not followed for a phone that never opted in', () async {
      launchedWith = const RemoteMessage(data: push);
      await registrar.watch(uid: 'u1', locale: 'ar', onTap: taps.add);
      await pumpEventQueue();
      expect(opened.hasListener, isFalse);
      expect(taps, isEmpty);
    });

    test('stops arriving at sign-out', () async {
      await watching();
      await registrar.forget();
      await pumpEventQueue();
      expect(opened.hasListener, isFalse);
      opened.add(const RemoteMessage(data: push));
      await pumpEventQueue();
      expect(taps, isEmpty);
    });

    test('without an onTap is not followed at all', () async {
      launchedWith = const RemoteMessage(data: push);
      await registrar.optIn(uid: 'u1', locale: 'ar');
      await registrar.watch(uid: 'u1', locale: 'ar');
      await pumpEventQueue();
      expect(opened.hasListener, isFalse);
    });
  });

  group('payment alerts are a second, separate yes', () {
    Map<String, Object> only() => store.docs.values.single;

    test('the C14 yes still writes no topics', () async {
      await registrar.optIn(uid: 'u1', locale: 'ar');
      expect(only().containsKey('topics'), isFalse);
      expect(only().keys.toSet(), {
        'token',
        'platform',
        'appVersion',
        'locale',
        'updatedAt',
      });
    });

    test('a phone that asked only for them lists only them', () async {
      expect(
        await registrar.optIn(
          uid: 'u1',
          locale: 'ar',
          topic: PushTopic.payments,
        ),
        PushOptIn.on,
      );
      expect(only()['topics'], ['payments']);
      expect(flag.uids, {PushTopic.payments: 'u1'});
    });

    test('a phone that said yes on C14 first keeps that yes', () async {
      await registrar.optIn(uid: 'u1', locale: 'ar');
      await registrar.optIn(uid: 'u1', locale: 'ar', topic: PushTopic.payments);
      expect(only()['topics'], ['approval', 'payments']);
    });

    test('and C14 after payments does not take them away', () async {
      await registrar.optIn(uid: 'u1', locale: 'ar', topic: PushTopic.payments);
      await registrar.optIn(uid: 'u1', locale: 'ar');
      expect(only()['topics'], ['approval', 'payments']);
    });

    test('a yes by another uid is not hers', () async {
      await registrar.optIn(uid: 'u1', locale: 'ar', topic: PushTopic.payments);
      store.docs.clear();
      await registrar.optIn(uid: 'u2', locale: 'ar');
      expect(only().containsKey('topics'), isFalse);
    });

    test('a refreshed token keeps what she said yes to', () async {
      await registrar.optIn(uid: 'u1', locale: 'ar', topic: PushTopic.payments);
      await registrar.watch(uid: 'u1', locale: 'ar');
      refreshes.add('token-two');
      await pumpEventQueue();
      expect(store.docs.keys, [deviceDocId('token-two')]);
      expect(only()['topics'], ['payments']);
    });

    test('and after a restart too', () async {
      await registrar.optIn(uid: 'u1', locale: 'ar', topic: PushTopic.payments);
      final restarted = FirebasePushRegistrar(
        messaging: messaging,
        sync: DeviceTokenSync(store: store, platform: 'android'),
        optInFlag: flag,
        onMessage: const Stream<RemoteMessage>.empty(),
        onOpened: opened.stream,
        initial: () async => null,
      );
      await restarted.watch(uid: 'u1', locale: 'ar');
      refreshes.add('token-two');
      await pumpEventQueue();
      expect(only()['topics'], ['payments']);
    });

    test('a push tap is heard by a phone that asked only for them', () async {
      const push = {'kind': 'instapayConfirmed', 'paymentId': 'p1'};
      final taps = <Map<String, Object?>>[];
      await registrar.optIn(uid: 'u1', locale: 'ar', topic: PushTopic.payments);
      await registrar.watch(uid: 'u1', locale: 'ar', onTap: taps.add);
      opened.add(const RemoteMessage(data: push));
      await pumpEventQueue();
      expect(taps, [push]);
    });

    test('sign-out forgets them too', () async {
      await registrar.optIn(uid: 'u1', locale: 'ar', topic: PushTopic.payments);
      await registrar.forget();
      expect(flag.uids, isEmpty);
      expect(await registrar.paymentAlerts(uid: 'u1'), PushAlertState.off);
    });

    test('the state is read without asking for anything', () async {
      expect(await registrar.paymentAlerts(uid: 'u1'), PushAlertState.off);
      expect(store.saves, 0);

      await registrar.optIn(uid: 'u1', locale: 'ar', topic: PushTopic.payments);
      expect(await registrar.paymentAlerts(uid: 'u1'), PushAlertState.on);
      expect(await registrar.paymentAlerts(uid: 'u2'), PushAlertState.off);

      messaging.status = AuthorizationStatus.denied;
      expect(await registrar.paymentAlerts(uid: 'u1'), PushAlertState.blocked);

      messaging.status = AuthorizationStatus.notDetermined;
      expect(await registrar.paymentAlerts(uid: 'u1'), PushAlertState.off);

      messaging.settingsFail = true;
      expect(
        await registrar.paymentAlerts(uid: 'u1'),
        PushAlertState.unavailable,
      );
    });

    test('a refusal writes nothing and says so', () async {
      messaging.status = AuthorizationStatus.denied;
      expect(
        await registrar.optIn(
          uid: 'u1',
          locale: 'ar',
          topic: PushTopic.payments,
        ),
        PushOptIn.denied,
      );
      expect(store.saves, 0);
      expect(flag.uids, isEmpty);
    });
  });
}
