/// "Help improve Own Hub": usage statistics, sent only if she allows them.
///
/// A choice of its own, separate from crash reports ([CrashConsent]) and from
/// the Terms: off until she turns it on, on the sign-up screen (C06, an
/// optional switch under the crash-report one) or later in Profile, then
/// Privacy. The choice is one SharedPreferences key on this phone.
///
/// What it allows: the events in `lib/domain/analytics/analytics_gateway.dart`
/// (which screens and steps she uses, from closed vocabularies, never her
/// health, body, name, number or anything she typed) sent to Google Analytics
/// for Firebase, which may process them outside Egypt. Advertising storage,
/// ad user data and ad personalisation are denied always; the advertising ID
/// and IDFA are never collected (AndroidManifest.xml, Info.plist, Podfile).
///
/// Turning it off stops collection, sets `analytics_storage` back to denied
/// and resets the analytics instance id on this phone, so what was sent before
/// cannot be joined to anything sent later. Nothing is collected before this
/// is read: collection is off natively (`firebase_analytics_collection_enabled`
/// in the Android manifest, `FIREBASE_ANALYTICS_COLLECTION_ENABLED` in
/// Info.plist) until `FirebaseBoot` applies her choice.
library;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_boot.dart';

/// The SharedPreferences key holding her choice. Cleared with everything else
/// on the phone when she deletes her data.
const String kAnalyticsAllowedKey = 'own_hub.analytics_allowed';

/// The day she last opened the app while usage statistics were on, as
/// `yyyy-mm-dd`, so a return after a quiet week can be counted. Only written
/// while she allows statistics, and removed with her choice.
const String kAnalyticsLastOpenKey = 'own_hub.analytics_last_open';

class AnalyticsConsent {
  AnalyticsConsent._();

  static final AnalyticsConsent instance = AnalyticsConsent._();

  bool _allowed = false;

  /// Whether she has allowed usage statistics. False until read, and false
  /// when the stored value is missing or unreadable.
  bool get allowed => _allowed;

  /// Called after her choice changes to on, so the facts every event carries
  /// (language, kitten, widget) are set once there is somewhere to send them.
  /// Wired in `main.dart`.
  static VoidCallback? onGranted;

  /// Reads the stored choice. Called once at start-up, before Firebase.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _allowed = prefs.getBool(kAnalyticsAllowedKey) ?? false;
    } catch (_) {
      _allowed = false;
    }
  }

  /// Records her choice and applies it straight away.
  Future<void> set(bool allowed) async {
    final was = _allowed;
    _allowed = allowed;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(kAnalyticsAllowedKey, allowed);
      if (!allowed) await prefs.remove(kAnalyticsLastOpenKey);
    } catch (_) {
      // The in-memory value is what the sink reads. A failed write means the
      // next launch starts from off, which is the safe direction.
    }
    await FirebaseBoot.applyAnalyticsConsent(allowed);
    if (allowed && !was) onGranted?.call();
  }

  /// Back to off, the keys gone and the instance id reset. Part of deleting
  /// everything on the phone.
  Future<void> erase() async {
    _allowed = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(kAnalyticsAllowedKey);
      await prefs.remove(kAnalyticsLastOpenKey);
    } catch (_) {}
    await FirebaseBoot.applyAnalyticsConsent(false);
  }

  /// Days since she last opened the app with statistics on, or null when
  /// there is no earlier day or statistics are off. Records today either way
  /// while they are on. Nothing is written while they are off.
  Future<int?> daysSinceLastOpen(DateTime now) async {
    if (!_allowed) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      // Calendar days in UTC, so a clock change is not a day.
      final today = DateTime.utc(now.year, now.month, now.day);
      final stored = DateTime.tryParse(
        prefs.getString(kAnalyticsLastOpenKey) ?? '',
      );
      await prefs.setString(kAnalyticsLastOpenKey, _day(today));
      if (stored == null) return null;
      final previous = DateTime.utc(stored.year, stored.month, stored.day);
      return today.difference(previous).inDays;
    } catch (_) {
      return null;
    }
  }

  static String _day(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  @visibleForTesting
  void resetForTest({bool allowed = false}) {
    _allowed = allowed;
  }
}
