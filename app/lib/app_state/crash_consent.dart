/// Crash reports are sent only if she allows them (privacy policy v3, 3.7).
///
/// Off until she says otherwise: on the sign-up screen (C06, an optional
/// switch under her number) or later in Profile, then Privacy. The choice is
/// one SharedPreferences key on this phone. Nothing about it goes to the
/// server, because a crash report is never linked to her account anyway.
///
/// Turning it off also deletes any report still waiting on the phone, so
/// "off" means nothing more leaves, not just nothing new.
///
/// The native defaults stay off (`firebase_crashlytics_collection_enabled` in
/// the Android manifest, `FirebaseCrashlyticsCollectionEnabled` in
/// Info.plist), so nothing is collected before this is read.
library;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_boot.dart';

/// The SharedPreferences key holding her choice. Cleared with everything else
/// on the phone when she deletes her data.
const String kCrashReportsAllowedKey = 'own_hub.crash_reports_allowed';

class CrashConsent {
  CrashConsent._();

  static final CrashConsent instance = CrashConsent._();

  bool _allowed = false;

  /// Whether she has allowed crash reports. False until read, and false when
  /// the stored value is missing or unreadable.
  bool get allowed => _allowed;

  /// Reads the stored choice. Called once at start-up, before Firebase.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _allowed = prefs.getBool(kCrashReportsAllowedKey) ?? false;
    } catch (_) {
      _allowed = false;
    }
  }

  /// Records her choice and applies it straight away.
  Future<void> set(bool allowed) async {
    _allowed = allowed;
    try {
      await (await SharedPreferences.getInstance()).setBool(
        kCrashReportsAllowedKey,
        allowed,
      );
    } catch (_) {
      // The in-memory value is what the crash handlers read. A failed write
      // means the next launch starts from off, which is the safe direction.
    }
    await FirebaseBoot.applyCrashConsent(allowed);
  }

  /// Back to off, and the key gone. Part of deleting everything on the phone.
  Future<void> erase() async {
    _allowed = false;
    try {
      await (await SharedPreferences.getInstance()).remove(
        kCrashReportsAllowedKey,
      );
    } catch (_) {}
    await FirebaseBoot.applyCrashConsent(false);
  }

  @visibleForTesting
  void resetForTest({bool allowed = false}) {
    _allowed = allowed;
  }
}
