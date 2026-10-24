/// "Help improve Own Hub": usage statistics, sent only if she allows them.
///
/// A choice of its own, separate from crash reports ([CrashConsent]) and from
/// the Terms: off until she turns it on, on the sign-up screen (C06, an
/// optional switch under the crash-report one) or later in Profile, then
/// Privacy. The choice is one SharedPreferences key on this phone, with a few
/// related keys beside it (last open, first open, activation) that are written
/// and cleared with it.
///
/// What it allows: the events in `lib/domain/analytics/analytics_gateway.dart`
/// (which screens and steps she uses, from closed vocabularies, never her
/// health, body, name, number or anything she typed) sent to Google Analytics
/// for Firebase and PostHog (US), which process them outside Egypt.
/// Version 2 deliberately requires fresh consent for the additional processor. Advertising storage,
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

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_boot.dart';
import 'posthog_analytics.dart';

/// The SharedPreferences key holding her choice. Cleared with everything else
/// on the phone when she deletes her data.
const String kAnalyticsAllowedKey = 'own_hub.analytics_allowed_v2';

/// The day she last opened the app while usage statistics were on, as
/// `yyyy-mm-dd`, so a return after a quiet week can be counted. Only written
/// while she allows statistics, and removed with her choice.
const String kAnalyticsLastOpenKey = 'own_hub.analytics_last_open';

/// The start of the retention and activation clocks. Holds a date (her first
/// opening with statistics on, UTC, ISO 8601), or a marker that is not a date:
/// 'declined' while statistics are off, or 'unknown' for a woman who chose in
/// app 1.0.0 (on or off). Dates are written only while she allows statistics.
const String kAnalyticsFirstOpenKey = 'own_hub.analytics_first_open';

/// Set once her first workout has been counted as activation.
const String kAnalyticsActivatedKey = 'own_hub.analytics_activated';

/// Stored as the first-open value for a woman who made her choice in app
/// 1.0.0, whether statistics were on or off: her real first opening is
/// unknown, so neither the install-age cohort nor activation is sent for her.
const String kAnalyticsFirstOpenUnknown = 'unknown';

/// Written into the first-open key when statistics are off (1.1 and later;
/// 1.0.0 never wrote it). Not a date: turning them on replaces it.
const String kAnalyticsFirstOpenDeclined = 'declined';

class AnalyticsConsent {
  AnalyticsConsent._();

  static final AnalyticsConsent instance = AnalyticsConsent._();

  bool _allowed = false;

  /// Whether she has allowed usage statistics. False until read, and false
  /// when the stored value is missing or unreadable.
  bool get allowed => _allowed;

  /// Called after her choice changes to on, so the facts every event carries
  /// (language, kitten, widget, build channel) are set once there is somewhere to send them,
  /// and so this opening is counted (the first frame ran before she chose).
  /// Wired in `main.dart` as `_onStatisticsGranted`.
  static VoidCallback? onGranted;

  /// Reads the stored choice. Called once at start-up, before Firebase.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _allowed = prefs.getBool(kAnalyticsAllowedKey) ?? false;
      // 1.0.0 always wrote the v2 key, on or off, and never the first-open key.
      // 1.1 always writes one ('declined' when off), so a stored choice with
      // none is the 1.0.0 upgrader's.
      if (prefs.containsKey(kAnalyticsAllowedKey) &&
          !prefs.containsKey(kAnalyticsFirstOpenKey)) {
        await prefs.setString(
          kAnalyticsFirstOpenKey,
          kAnalyticsFirstOpenUnknown,
        );
      }
    } catch (_) {
      _allowed = false;
    }
  }

  /// Records her choice and applies it straight away.
  ///
  /// Turning statistics on starts her retention and activation clocks at
  /// [now] (default: the moment), so a workout in the same session counts.
  /// It does not start them when the first-open marker is 'unknown' (a 1.0.0
  /// choice) or a date is already stored: those are kept as they are.
  Future<void> set(bool allowed, {DateTime? now}) async {
    final was = _allowed;
    _allowed = allowed;
    unawaited(PostHogAnalytics.instance.applyConsent(allowed));
    try {
      final prefs = await SharedPreferences.getInstance();
      // The marker goes first: a kill between the two writes must not leave a
      // v2 key without one, which load() would read as a 1.0.0 choice.
      final marker = prefs.getString(kAnalyticsFirstOpenKey);
      if (!allowed) {
        await _clearClocks(prefs);
        if (marker != kAnalyticsFirstOpenUnknown) {
          await prefs.setString(
            kAnalyticsFirstOpenKey,
            kAnalyticsFirstOpenDeclined,
          );
        }
      } else if (marker == null ||
          marker == kAnalyticsFirstOpenDeclined ||
          DateTime.tryParse(marker) == null &&
              marker != kAnalyticsFirstOpenUnknown) {
        await prefs.setString(
          kAnalyticsFirstOpenKey,
          (now ?? DateTime.now()).toUtc().toIso8601String(),
        );
      }
      await prefs.setBool(kAnalyticsAllowedKey, allowed);
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
    unawaited(PostHogAnalytics.instance.applyConsent(false));
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(kAnalyticsAllowedKey);
      await prefs.remove('own_hub.analytics_allowed');
      await _clearClocks(prefs);
      await prefs.remove(kAnalyticsFirstOpenKey);
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

  static Future<void> _clearClocks(SharedPreferences prefs) async {
    await prefs.remove(kAnalyticsLastOpenKey);
    await prefs.remove(kAnalyticsActivatedKey);
  }

  /// Her first counted opening, set to [now] the first time unless [create] is
  /// false. Null while statistics are off: nothing is written then.
  ///
  /// shortcut: turning statistics off replaces this date with the non-date
  /// 'declined' marker, so off-then-on starts a new install-age cohort. Keeping
  /// the date would store a usage date after she withdrew consent; revisit only
  /// if the consent rules allow a local date. 'unknown' (the 1.0.0 upgrader) is
  /// a migration marker and survives off and on. Neither marker is a date.
  Future<DateTime?> firstOpen(DateTime now, {bool create = true}) async {
    if (!_allowed) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(kAnalyticsFirstOpenKey) ?? '';
      if (raw == kAnalyticsFirstOpenUnknown ||
          raw == kAnalyticsFirstOpenDeclined) {
        return null;
      }
      final stored = DateTime.tryParse(raw);
      if (stored != null) return stored.toUtc();
      if (!create) return null;
      await prefs.setString(
        kAnalyticsFirstOpenKey,
        now.toUtc().toIso8601String(),
      );
      return now.toUtc();
    } catch (_) {
      return null;
    }
  }

  /// True exactly once: the first call after statistics are on. Null-safe
  /// false while they are off.
  Future<bool> claimActivation() async {
    if (!_allowed) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(kAnalyticsActivatedKey) ?? false) return false;
      await prefs.setBool(kAnalyticsActivatedKey, true);
      return true;
    } catch (_) {
      return false;
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
