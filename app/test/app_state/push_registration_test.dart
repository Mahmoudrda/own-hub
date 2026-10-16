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
  String? uid;

  @override
  Future<String?> read() async => uid;

  @override
  Future<void> write(String value) async => uid = value;

  @override
  Future<void> clear() async => uid = null;
}

class _Messaging extends Fake implements FirebaseMessaging {
  _Messaging(this.refreshes);

  final StreamController<String> refreshes;
  String token = 'token-one';

  @override
  Stream<String> get onTokenRefresh => refreshes.stream;

  @override
  Future<String?> getToken({
    String? vapidKey,
    String? serviceWorkerScriptPath,
  }) async => token;

  @override
  Future<NotificationSettings> getNotificationSettings() async =>
      const NotificationSettings(
        alert: AppleNotificationSetting.enabled,
        announcement: AppleNotificationSetting.notSupported,
        authorizationStatus: AuthorizationStatus.authorized,
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

  setUp(() {
    store = _Store();
    flag = _Flag();
    refreshes = StreamController<String>.broadcast();
    messaging = _Messaging(refreshes);
    registrar = FirebasePushRegistrar(
      messaging: messaging,
      sync: DeviceTokenSync(store: store, platform: 'android'),
      optInFlag: flag,
      onMessage: const Stream<RemoteMessage>.empty(),
    );
  });

  tearDown(() => refreshes.close());

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
}
