/// What this phone remembers about her check, between launches.
///
/// Two facts, each tied to the uid it is about:
///
///  * **verified**: a fresh ID token said `verified == true` for this uid on
///    this phone. Read at launch only when the token itself cannot be read
///    for want of a network (an expired token offline throws), so a verified
///    woman on the metro opens her own product instead of C14. It is never
///    written from anything but the server's claim, and a token that later
///    says she is not verified removes it. The server rules still decide
///    every read and write of server data.
///  * **review asked**: she tapped "Ask for the call" (or asked on C15), so
///    C14 stops offering the button after a restart.
///
/// Both go on sign-out and on account deletion (`AppRouter.forgetVerification`).
library;

import 'package:shared_preferences/shared_preferences.dart';

const String kVerifiedUidKey = 'own_hub.verified_uid';
const String kReviewAskedUidKey = 'own_hub.review_asked_uid';

abstract final class VerificationMemory {
  /// The uid a fresh token last proved verified on this phone, or null.
  static Future<String?> verifiedUid() => _read(kVerifiedUidKey);

  static Future<void> rememberVerified(String uid) =>
      _write(kVerifiedUidKey, uid);

  /// The uid that asked for a reviewer's call on this phone, or null.
  static Future<String?> reviewAskedUid() => _read(kReviewAskedUidKey);

  static Future<void> rememberReviewAsked(String uid) =>
      _write(kReviewAskedUidKey, uid);

  /// Both facts gone. Never throws.
  static Future<void> forget() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(kVerifiedUidKey);
      await prefs.remove(kReviewAskedUidKey);
    } catch (_) {}
  }

  static Future<String?> _read(String key) async {
    try {
      final value = (await SharedPreferences.getInstance()).getString(key);
      return value == null || value.isEmpty ? null : value;
    } catch (_) {
      return null;
    }
  }

  static Future<void> _write(String key, String uid) async {
    try {
      await (await SharedPreferences.getInstance()).setString(key, uid);
    } catch (_) {}
  }
}
