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

import 'dart:convert';
import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

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

class FirebasePushRegistrar implements PushRegistrar {
  FirebasePushRegistrar({FirebaseMessaging? messaging, FirebaseFirestore? db})
    : _messaging = messaging ?? FirebaseMessaging.instance,
      _db = db ?? FirebaseFirestore.instance;

  final FirebaseMessaging _messaging;
  final FirebaseFirestore _db;

  @override
  Future<PushOptIn> optIn({
    required String uid,
    required String locale,
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
        AuthorizationStatus.authorized || AuthorizationStatus.provisional =>
          true,
        _ => false,
      };
      if (!allowed) return PushOptIn.denied;
      final token = await _messaging.getToken();
      if (token == null || token.isEmpty) return PushOptIn.unavailable;
      await _db
          .collection('users')
          .doc(uid)
          .collection('devices')
          .doc(deviceDocId(token))
          .set(
            deviceDocument(
              token: token,
              platform: Platform.isIOS ? 'ios' : 'android',
              locale: locale == 'en' ? 'en' : 'ar',
            ),
            SetOptions(merge: true),
          );
      return PushOptIn.on;
    } catch (_) {
      return PushOptIn.unavailable;
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
}
