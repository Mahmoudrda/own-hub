/// Her health data stays on her phone unless she asks for a cloud copy.
///
/// Cycle days, period dates, daily check-ins, body measurements (weight lives
/// there), her life stage (pregnancy, postpartum, injury) and her allergies are
/// sensitive personal data under Egypt's PDPL. Copying them to Firestore in
/// Frankfurt is a transfer abroad, and it needs its own explicit consent. So the
/// default is the one the product has always promised: they stay on the
/// handset, and the local snapshot is the only copy.
///
/// **Opting in** records a separate consent on the server first
/// (`record_health_consent`, written to `users/{uid}/consents/health-v1`), and
/// only after the server has written it does this phone start backing up.
/// **Opting out** asks the server to withdraw the consent and delete the cloud
/// copy, and only then stops. If either call fails nothing changes, and she is
/// told so.
///
/// The preference is its own SharedPreferences key rather than part of the
/// snapshot, so the snapshot schema does not move.
library;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The consent wording version for the health backup. Must move together with
/// the server's `config.HEALTH_CONSENT_VERSION`; the shared contract pins both.
const int kHealthConsentVersion = 1;

/// The server's consent document id, under `users/{uid}/consents/`.
const String kHealthConsentDocId = 'health-v1';

/// The callable that grants or withdraws the health backup consent.
const String kRecordHealthConsentCallable = 'record_health_consent';

/// The SharedPreferences key holding whether the backup is on.
const String kHealthBackupKey = 'own_hub.health_backup';

/// Set when she turned the backup off but the server has not yet confirmed
/// the withdrawal (and the purge of the cloud copy). Retried at start-up and
/// whenever A03 opens, until it succeeds.
const String kHealthWithdrawPendingKey =
    'own_hub.health_backup_withdraw_pending';

/// The collections that only leave the phone with her health consent.
const Set<String> kHealthCollections = <String>{
  'checkins',
  'measurements',
  'cycle',
  'periods',
};

/// The `users/{uid}.profile` keys that only leave the phone with it.
const Set<String> kHealthProfileKeys = <String>{'lifeStage', 'allergies'};

/// The server's record of her health consent, as far as this phone cares.
enum HealthConsentState { granted, withdrawn }

/// Whether this phone backs up her health data. Off unless she turned it on.
class HealthBackupPreference {
  HealthBackupPreference._();

  static final HealthBackupPreference instance = HealthBackupPreference._();

  bool _enabled = false;

  /// Read synchronously by the cloud capture on every debounce.
  bool get enabled => _enabled;

  /// Reads the stored choice. Called once at start-up, before the cloud sync.
  /// A missing or unreadable value is off.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool(kHealthBackupKey) ?? false;
      _withdrawPending = prefs.getBool(kHealthWithdrawPendingKey) ?? false;
    } catch (_) {
      _enabled = false;
    }
  }

  bool _withdrawPending = false;

  /// She turned it off and the server has not confirmed the withdrawal yet.
  bool get withdrawPending => _withdrawPending;

  Future<void> setWithdrawPending(bool pending) async {
    _withdrawPending = pending;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (pending) {
        await prefs.setBool(kHealthWithdrawPendingKey, true);
      } else {
        await prefs.remove(kHealthWithdrawPendingKey);
      }
    } catch (_) {
      // Still pending in memory for this session.
    }
  }

  Future<void> set(bool enabled) async {
    _enabled = enabled;
    try {
      await (await SharedPreferences.getInstance()).setBool(
        kHealthBackupKey,
        enabled,
      );
    } catch (_) {
      // The in-memory value is what the sync reads; a failed write means the
      // next launch starts from off, which is the safe direction.
    }
  }

  /// Back to off, and the key gone. Part of deleting everything on the phone.
  Future<void> erase() async {
    _enabled = false;
    _withdrawPending = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(kHealthBackupKey);
      await prefs.remove(kHealthWithdrawPendingKey);
    } catch (_) {}
  }

  @visibleForTesting
  void resetForTest() {
    _enabled = false;
    _withdrawPending = false;
  }
}

/// Where her health consent is granted, withdrawn and read back.
abstract class HealthConsentStore {
  /// Grants ([granted] true) or withdraws it. Throws when the server did not
  /// confirm, in which case nothing may change on the phone.
  Future<void> record({required bool granted});

  /// The server's current record, or null when there is none.
  Future<HealthConsentState?> current(String uid);
}

/// Turns the backup on and off, server first.
class HealthBackupController {
  HealthBackupController({
    required this.store,
    HealthBackupPreference? preference,
    this.onEnabled,
    this.onDisabled,
  }) : preference = preference ?? HealthBackupPreference.instance;

  /// Called the moment it is switched off on this phone, before the server
  /// answers.
  final VoidCallback? onDisabled;

  final HealthConsentStore store;
  final HealthBackupPreference preference;

  /// Called once the backup is on, to push what is already on the phone.
  final VoidCallback? onEnabled;

  bool get enabled => preference.enabled;

  /// Why the last [enable] did not go through, or null. Read by A03 to tell
  /// "no connection" from "this copy of the app is refused" (R3).
  Object? lastFailure;

  /// True when the server recorded her consent and the backup is now on.
  Future<bool> enable() async {
    lastFailure = null;
    try {
      await store.record(granted: true);
    } catch (error) {
      lastFailure = error;
      return false;
    }
    await preference.set(true);
    onEnabled?.call();
    return true;
  }

  /// Turns the backup off. Health uploads stop on this phone at once,
  /// whatever the network does: the preference is off before the server is
  /// asked. Then the server withdraws the consent and deletes the cloud copy.
  ///
  /// True when the server confirmed. False means the call did not get
  /// through: the backup is still off here, the withdrawal is remembered and
  /// retried ([retryPendingWithdraw], at start-up and when A03 opens), and
  /// she is told the cloud copy will be removed when she is back online.
  Future<bool> disable() async {
    await preference.set(false);
    await preference.setWithdrawPending(true);
    onDisabled?.call();
    return retryPendingWithdraw();
  }

  /// Sends a withdrawal that did not reach the server. True when nothing is
  /// pending any more. Never throws.
  Future<bool> retryPendingWithdraw() async {
    if (!preference.withdrawPending) return true;
    try {
      await store.record(granted: false);
    } catch (_) {
      return false;
    }
    await preference.setWithdrawPending(false);
    return true;
  }

  /// The server wins: if this phone thinks the backup is on but the server
  /// holds no granted consent, it is turned off here. An unreadable answer
  /// changes nothing, because the rules refuse health writes without the
  /// consent anyway.
  Future<void> reconcile(String uid) async {
    if (!preference.enabled) return;
    HealthConsentState? state;
    try {
      state = await store.current(uid);
    } catch (_) {
      return;
    }
    if (state != HealthConsentState.granted) {
      await preference.set(false);
    }
  }
}
