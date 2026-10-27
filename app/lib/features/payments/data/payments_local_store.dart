library;

import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// Things that stay on the phone: her own InstaPay handle (asked once), the
/// answer to the optional "help improve" question, and the idempotency key of
/// the action she is in the middle of. A retry or a double tap reuses the
/// key, so the server makes one payment.
class PaymentsLocalStore {
  static const _handleKey = 'payments.senderHandle';
  static const _consentKey = 'payments.learnConsent';
  static const _askedKey = 'payments.learnAsked';

  Future<SharedPreferences?> _prefs() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (_) {
      return null;
    }
  }

  Future<String> senderHandle() async =>
      (await _prefs())?.getString(_handleKey) ?? '';

  Future<void> saveSenderHandle(String handle) async {
    await (await _prefs())?.setString(_handleKey, handle.trim().toLowerCase());
  }

  Future<bool> learnConsent() async =>
      (await _prefs())?.getBool(_consentKey) ?? false;

  Future<bool> consentAsked() async =>
      (await _prefs())?.getBool(_askedKey) ?? false;

  Future<void> answerLearnConsent(bool yes) async {
    final p = await _prefs();
    await p?.setBool(_consentKey, yes);
    await p?.setBool(_askedKey, true);
  }

  /// "Delete everything": her handle and her answer.
  Future<void> erase() async {
    final p = await _prefs();
    for (final k in const [_handleKey, _consentKey, _askedKey]) {
      await p?.remove(k);
    }
  }

  /// 24 hex characters; the server takes 8 to 64 of letters, digits, `_`, `-`.
  static String newKey([Random? r]) {
    final g = r ?? Random.secure();
    const hex = '0123456789abcdef';
    return List<String>.generate(24, (_) => hex[g.nextInt(16)]).join();
  }
}
