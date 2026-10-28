/// "Tell me": the two pushes this app asks for, each only when she taps its
/// button, never at launch.
///
///  * **approval** (`C14`): a woman waiting for a woman reviewer may close the
///    app for up to 72 hours. When the reviewer approves her,
///    `functions/identity/push.py` sends one notification, "Your check is
///    done". Once she is in, the same registration carries the coaching
///    pushes the server already sends.
///  * **payments**: "Turn on payment alerts" on the coach's Payments inbox and
///    "Tell me when it changes" on a payment's status screen. The server sends
///    a payment push (`functions/payments/notices.py`) only to a phone that
///    listed this, and a phone that asked only for this hears nothing else.
///
/// On yes, the token is written to `users/{uid}/devices/{id}`, the document the
/// rules allow (`token`, `platform`, `appVersion`, `locale`, `updatedAt`, and
/// `topics` once she asked for payment alerts) and the account deletion
/// manifest erases. The document id is a hash of the token, not the install id:
/// the install id is a fraud signal the server only ever stores hashed, and a
/// document keyed by it would tie it to her uid in the clear.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show VoidCallback;
import 'package:shared_preferences/shared_preferences.dart';

import '../features/signup/domain/legal_acceptance.dart' show kAppVersion;

/// What came of asking.
enum PushOptIn {
  /// She said yes and this phone is registered.
  on,

  /// She said no, now or before. Only Settings can change it.
  denied,

  /// No push on this phone or in this build (no Firebase, no token).
  unavailable,
}

/// What a phone can say yes to. The words are the ones in the device
/// document's `topics` and the ones `functions/identity/push.py` filters on.
enum PushTopic {
  approval('approval'),
  payments('payments');

  const PushTopic(this.wire);
  final String wire;
}

/// Where payment alerts stand on this phone, read without asking for anything.
enum PushAlertState {
  /// She said yes and the phone allows notifications.
  on,

  /// Not asked for yet (or asked for the permission only): she can turn it on.
  off,

  /// The phone refuses notifications for Own Hub. Only Settings can change it.
  blocked,

  /// No push on this phone or in this build.
  unavailable,
}

/// Registers this phone for the pushes she asks for.
abstract class PushRegistrar {
  Future<PushOptIn> optIn({
    required String uid,
    required String locale,
    PushTopic topic = PushTopic.approval,
  });

  /// Where payment alerts stand. Never shows the system prompt.
  Future<PushAlertState> paymentAlerts({required String uid});

  /// Keeps what the server holds for this phone right after she opted in:
  /// a token Firebase rotates replaces the old one, and the approval push
  /// that arrives while the app is open calls [onApproval]. A tap on a push
  /// that was shown by the system, with the app in the background or closed,
  /// calls [onTap] with the push's data. Does nothing for a phone that never
  /// opted in, and never asks for anything.
  Future<void> watch({
    required String uid,
    required String locale,
    VoidCallback? onApproval,
    void Function(Map<String, Object?> data)? onTap,
  });

  /// Stops watching and forgets the opt-in. Signing out and deleting the
  /// account run it, so the next person on this phone starts from "never
  /// asked".
  Future<void> forget();
}

/// The SharedPreferences key holding the uid that said yes to push on `C14`.
const String kPushOptInKey = 'own_hub.push_opt_in_uid';

/// The key holding the uid that said yes to payment alerts.
const String kPaymentAlertsKey = 'own_hub.push_payment_alerts_uid';

String _flagKey(PushTopic topic) => switch (topic) {
  PushTopic.approval => kPushOptInKey,
  PushTopic.payments => kPaymentAlertsKey,
};

/// Whether this phone's push was asked for, and by whom, topic by topic.
/// Notification permission alone is not it: the same permission serves local
/// reminders.
abstract class PushOptInFlag {
  Future<String?> read([PushTopic topic = PushTopic.approval]);
  Future<void> write(String uid, [PushTopic topic = PushTopic.approval]);

  /// Forgets every topic.
  Future<void> clear();
}

class PreferencesPushOptInFlag implements PushOptInFlag {
  const PreferencesPushOptInFlag();

  @override
  Future<String?> read([PushTopic topic = PushTopic.approval]) async {
    try {
      return (await SharedPreferences.getInstance()).getString(_flagKey(topic));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String uid, [PushTopic topic = PushTopic.approval]) async {
    try {
      await (await SharedPreferences.getInstance()).setString(
        _flagKey(topic),
        uid,
      );
    } catch (_) {}
  }

  @override
  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final topic in PushTopic.values) {
        await prefs.remove(_flagKey(topic));
      }
    } catch (_) {}
  }
}

/// The document id for a token: a hash, so the id says nothing by itself.
String deviceDocId(String token) =>
    sha256.convert(utf8.encode(token)).toString().substring(0, 32);

/// What is written for one phone. The rules' key whitelist, exactly.
///
/// `topics` is written only once she asked for payment alerts, and then lists
/// everything she said yes to (the server hears a phone with no list as the
/// `C14` yes alone), so the C14 registration is still the four fields it was.
Map<String, Object> deviceDocument({
  required String token,
  required String platform,
  required String locale,
  String appVersion = kAppVersion,
  Set<PushTopic> topics = const {PushTopic.approval},
}) => <String, Object>{
  'token': token,
  'platform': platform,
  'appVersion': appVersion,
  'locale': locale,
  'updatedAt': FieldValue.serverTimestamp(),
  if (topics.contains(PushTopic.payments))
    'topics': <String>[
      for (final topic in PushTopic.values)
        if (topics.contains(topic)) topic.wire,
    ],
};

/// Where a phone's token document lives.
abstract class DeviceStore {
  Future<void> save(String uid, String docId, Map<String, Object> document);
  Future<void> remove(String uid, String docId);
}

class FirestoreDeviceStore implements DeviceStore {
  FirestoreDeviceStore([FirebaseFirestore? db])
    : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _doc(String uid, String docId) =>
      _db.collection('users').doc(uid).collection('devices').doc(docId);

  @override
  Future<void> save(String uid, String docId, Map<String, Object> document) =>
      _doc(uid, docId).set(document, SetOptions(merge: true));

  @override
  Future<void> remove(String uid, String docId) => _doc(uid, docId).delete();
}

/// One phone's token document, kept current.
///
/// The document id is a hash of the token, so a rotated token is a new
/// document: the old one is removed, or the server would keep sending to a
/// token that no longer reaches her.
class DeviceTokenSync {
  DeviceTokenSync({required this.store, required this.platform});

  final DeviceStore store;
  final String platform;
  String? _docId;

  /// What she has said yes to on this phone. A rotated token is written with
  /// the same list, or the new document would lose her yes.
  Set<PushTopic> topics = const {PushTopic.approval};

  /// The id of the document this phone owns now, if any.
  String? get docId => _docId;

  /// Remembers a token already registered, without writing it again.
  void adopt(String token) => _docId = deviceDocId(token);

  Future<void> register({
    required String uid,
    required String locale,
    required String token,
  }) async {
    final id = deviceDocId(token);
    await store.save(
      uid,
      id,
      deviceDocument(
        token: token,
        platform: platform,
        locale: locale == 'en' ? 'en' : 'ar',
        topics: topics,
      ),
    );
    _docId = id;
  }

  /// Firebase rotated the token: the new document, then the old one gone.
  Future<void> refreshed({
    required String uid,
    required String locale,
    required String token,
  }) async {
    final old = _docId;
    if (old == deviceDocId(token)) return;
    await register(uid: uid, locale: locale, token: token);
    if (old != null) await store.remove(uid, old);
  }

  StreamSubscription<String> follow(
    Stream<String> refreshes, {
    required String uid,
    required String locale,
  }) => refreshes.listen(
    (token) => unawaited(
      refreshed(
        uid: uid,
        locale: locale,
        token: token,
      ).catchError((Object _) {}),
    ),
    onError: (Object _) {},
  );
}

/// What the approval push carries in its data, so the app knows what it is
/// about. The same word `functions/identity/push.py` sends.
const String kApprovalPushKind = 'verificationApproved';

class FirebasePushRegistrar implements PushRegistrar {
  FirebasePushRegistrar({
    FirebaseMessaging? messaging,
    FirebaseFirestore? db,
    DeviceTokenSync? sync,
    this._optInFlag = const PreferencesPushOptInFlag(),
    this._onMessage,
    this._onOpened,
    this._initial,
  }) : _messaging = messaging ?? FirebaseMessaging.instance,
       _sync =
           sync ??
           DeviceTokenSync(
             store: FirestoreDeviceStore(db),
             platform: Platform.isIOS ? 'ios' : 'android',
           );

  final FirebaseMessaging _messaging;
  final DeviceTokenSync _sync;
  final PushOptInFlag _optInFlag;
  final Stream<RemoteMessage>? _onMessage;
  final Stream<RemoteMessage>? _onOpened;
  final Future<RemoteMessage?> Function()? _initial;
  final List<StreamSubscription<Object?>> _watching = [];

  /// The push that launched the app is handed out once: [watch] can run again
  /// after she opts in, and the same tap must not open its screen twice.
  bool _initialTaken = false;

  /// Everything this phone has said yes to for [uid], plus [adding].
  Future<Set<PushTopic>> _topicsOf(String uid, {PushTopic? adding}) async => {
    ?adding,
    for (final topic in PushTopic.values)
      if (await _optInFlag.read(topic) == uid) topic,
  };

  @override
  Future<PushOptIn> optIn({
    required String uid,
    required String locale,
    PushTopic topic = PushTopic.approval,
  }) async {
    try {
      // Android 13 and later show the POST_NOTIFICATIONS prompt here; iOS
      // shows its own. Nothing asks before this tap.
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: false,
        sound: true,
      );
      final allowed = switch (settings.authorizationStatus) {
        AuthorizationStatus.authorized ||
        AuthorizationStatus.provisional => true,
        _ => false,
      };
      if (!allowed) return PushOptIn.denied;
      final token = await _messaging.getToken();
      if (token == null || token.isEmpty) return PushOptIn.unavailable;
      _sync.topics = await _topicsOf(uid, adding: topic);
      await _sync.register(uid: uid, locale: locale, token: token);
      await _optInFlag.write(uid, topic);
      _follow(uid: uid, locale: locale);
      return PushOptIn.on;
    } catch (_) {
      return PushOptIn.unavailable;
    }
  }

  @override
  Future<PushAlertState> paymentAlerts({required String uid}) async {
    try {
      final settings = await _messaging.getNotificationSettings();
      return switch (settings.authorizationStatus) {
        AuthorizationStatus.authorized || AuthorizationStatus.provisional =>
          await _optInFlag.read(PushTopic.payments) == uid
              ? PushAlertState.on
              : PushAlertState.off,
        AuthorizationStatus.denied => PushAlertState.blocked,
        _ => PushAlertState.off,
      };
    } catch (_) {
      return PushAlertState.unavailable;
    }
  }

  @override
  Future<void> watch({
    required String uid,
    required String locale,
    VoidCallback? onApproval,
    void Function(Map<String, Object?> data)? onTap,
  }) async {
    try {
      final topics = await _topicsOf(uid);
      if (topics.isEmpty) return;
      final settings = await _messaging.getNotificationSettings();
      final allowed =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
      if (!allowed) return;
      _sync.topics = topics;
      try {
        final token = await _messaging.getToken();
        if (token != null && token.isNotEmpty) _sync.adopt(token);
      } catch (_) {
        // A token that cannot be read now arrives with the next refresh; a tap
        // on a push must still be heard.
      }
      _follow(uid: uid, locale: locale, onApproval: onApproval, onTap: onTap);
    } catch (_) {}
  }

  @override
  Future<void> forget() async {
    _stopWatching();
    await _optInFlag.clear();
  }

  void _stopWatching() {
    for (final subscription in _watching) {
      unawaited(subscription.cancel());
    }
    _watching.clear();
  }

  void _follow({
    required String uid,
    required String locale,
    VoidCallback? onApproval,
    void Function(Map<String, Object?> data)? onTap,
  }) {
    _stopWatching();
    _watching.add(
      _sync.follow(_messaging.onTokenRefresh, uid: uid, locale: locale),
    );
    // The system shows nothing while the app is open, so the approval arrives
    // as data and the screen refreshes what it knows.
    if (onApproval != null) {
      _watching.add(
        (_onMessage ?? FirebaseMessaging.onMessage).listen((message) {
          if (message.data['kind'] == kApprovalPushKind) onApproval();
        }, onError: (Object _) {}),
      );
    }
    if (onTap == null) return;
    _watching.add(
      (_onOpened ?? FirebaseMessaging.onMessageOpenedApp).listen(
        (message) => onTap(message.data),
        onError: (Object _) {},
      ),
    );
    if (_initialTaken) return;
    _initialTaken = true;
    unawaited(
      (_initial?.call() ?? _messaging.getInitialMessage())
          .then((message) {
            if (message != null) onTap(message.data);
          })
          .catchError((Object _) {}),
    );
  }
}

/// A build with no Firebase: nothing to register with, and it says so.
class UnavailablePushRegistrar implements PushRegistrar {
  const UnavailablePushRegistrar();

  @override
  Future<PushOptIn> optIn({
    required String uid,
    required String locale,
    PushTopic topic = PushTopic.approval,
  }) async => PushOptIn.unavailable;

  @override
  Future<PushAlertState> paymentAlerts({required String uid}) async =>
      PushAlertState.unavailable;

  @override
  Future<void> watch({
    required String uid,
    required String locale,
    VoidCallback? onApproval,
    void Function(Map<String, Object?> data)? onTap,
  }) async {}

  @override
  Future<void> forget() async {}
}
