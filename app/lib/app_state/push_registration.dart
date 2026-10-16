/// "Tell me when I'm in": the one push this app asks for.
///
/// A woman waiting on `C14` for a woman reviewer may close the app for up to
/// 72 hours. When the reviewer approves her, `functions/identity/push.py`
/// sends one notification, "Your check is done", to every phone she
/// registered here. Nothing else is ever pushed.
///
/// Asked only when she taps the button, never at launch. On yes, the token is
/// written to `users/{uid}/devices/{id}`, the document the rules allow
/// (`token`, `platform`, `appVersion`, `locale`, `updatedAt`) and the account
/// deletion manifest erases. The document id is a hash of the token, not the
/// install id: the install id is a fraud signal the server only ever stores
/// hashed, and a document keyed by it would tie it to her uid in the clear.
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

/// Registers this phone for the approval push.
abstract class PushRegistrar {
  Future<PushOptIn> optIn({required String uid, required String locale});

  /// Keeps what the server holds for this phone right after she opted in:
  /// a token Firebase rotates replaces the old one, and the approval push
  /// that arrives while the app is open calls [onApproval]. Does nothing for
  /// a phone that never opted in, and never asks for anything.
  Future<void> watch({
    required String uid,
    required String locale,
    VoidCallback? onApproval,
  });

  /// Stops watching and forgets the opt-in. Signing out and deleting the
  /// account run it, so the next person on this phone starts from "never
  /// asked".
  Future<void> forget();
}

/// The SharedPreferences key holding the uid that said yes to push on `C14`.
const String kPushOptInKey = 'own_hub.push_opt_in_uid';

/// Whether this phone's push was asked for, and by whom. Notification
/// permission alone is not it: the same permission serves local reminders.
abstract class PushOptInFlag {
  Future<String?> read();
  Future<void> write(String uid);
  Future<void> clear();
}

class PreferencesPushOptInFlag implements PushOptInFlag {
  const PreferencesPushOptInFlag();

  @override
  Future<String?> read() async {
    try {
      return (await SharedPreferences.getInstance()).getString(kPushOptInKey);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String uid) async {
    try {
      await (await SharedPreferences.getInstance()).setString(
        kPushOptInKey,
        uid,
      );
    } catch (_) {}
  }

  @override
  Future<void> clear() async {
    try {
      await (await SharedPreferences.getInstance()).remove(kPushOptInKey);
    } catch (_) {}
  }
}

/// The document id for a token: a hash, so the id says nothing by itself.
String deviceDocId(String token) =>
    sha256.convert(utf8.encode(token)).toString().substring(0, 32);

/// What is written for one phone. The rules' key whitelist, exactly.
Map<String, Object> deviceDocument({
  required String token,
  required String platform,
  required String locale,
  String appVersion = kAppVersion,
}) => <String, Object>{
  'token': token,
  'platform': platform,
  'appVersion': appVersion,
  'locale': locale,
  'updatedAt': FieldValue.serverTimestamp(),
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
  final List<StreamSubscription<Object?>> _watching = [];

  @override
  Future<PushOptIn> optIn({required String uid, required String locale}) async {
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
      await _sync.register(uid: uid, locale: locale, token: token);
      await _optInFlag.write(uid);
      _follow(uid: uid, locale: locale);
      return PushOptIn.on;
    } catch (_) {
      return PushOptIn.unavailable;
    }
  }

  @override
  Future<void> watch({
    required String uid,
    required String locale,
    VoidCallback? onApproval,
  }) async {
    try {
      if (await _optInFlag.read() != uid) return;
      final settings = await _messaging.getNotificationSettings();
      final allowed =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
      if (!allowed) return;
      final token = await _messaging.getToken();
      if (token != null && token.isNotEmpty) _sync.adopt(token);
      _follow(uid: uid, locale: locale, onApproval: onApproval);
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
  }
}

/// A build with no Firebase: nothing to register with, and it says so.
class UnavailablePushRegistrar implements PushRegistrar {
  const UnavailablePushRegistrar();

  @override
  Future<PushOptIn> optIn({
    required String uid,
    required String locale,
  }) async => PushOptIn.unavailable;

  @override
  Future<void> watch({
    required String uid,
    required String locale,
    VoidCallback? onApproval,
  }) async {}

  @override
  Future<void> forget() async {}
}
