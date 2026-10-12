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

/// The uid of the account whose withdrawal is pending.
///
/// The marker is about one account's consent, not about the phone. Without
/// this, a different account signing in on the same handset would have its
/// own consent withdrawn by the retry. A marker with no uid (written before
/// this key existed) belongs to nobody this phone can name, so it is dropped
/// rather than replayed against whoever is signed in.
const String kHealthWithdrawPendingUidKey =
    'own_hub.health_backup_withdraw_pending_uid';

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
      _withdrawPendingUid = prefs.getString(kHealthWithdrawPendingUidKey);
    } catch (_) {
      _enabled = false;
    }
  }

  bool _withdrawPending = false;
  String? _withdrawPendingUid;

  /// She turned it off and the server has not confirmed the withdrawal yet.
  bool get withdrawPending => _withdrawPending;

  /// Whose withdrawal is pending, or null when none is or it was written
  /// without one.
  String? get withdrawPendingUid =>
      _withdrawPending ? _withdrawPendingUid : null;

  /// Whether a withdrawal is pending for exactly this account.
  bool withdrawPendingFor(String? uid) =>
      _withdrawPending && _withdrawPendingUid == uid;

  /// The withdrawal being sent right now, or null. Shared by every
  /// controller, so turning the backup on can wait for it (R6).
  Future<bool>? withdrawInFlight;

  /// Marks [uid]'s withdrawal as pending, or clears the marker.
  Future<void> setWithdrawPending(bool pending, {String? uid}) async {
    _withdrawPending = pending;
    _withdrawPendingUid = pending ? uid : null;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (pending) {
        await prefs.setBool(kHealthWithdrawPendingKey, true);
        if (uid == null) {
          await prefs.remove(kHealthWithdrawPendingUidKey);
        } else {
          await prefs.setString(kHealthWithdrawPendingUidKey, uid);
        }
      } else {
        await prefs.remove(kHealthWithdrawPendingKey);
        await prefs.remove(kHealthWithdrawPendingUidKey);
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
    _withdrawPendingUid = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(kHealthBackupKey);
      await prefs.remove(kHealthWithdrawPendingKey);
      await prefs.remove(kHealthWithdrawPendingUidKey);
    } catch (_) {}
  }

  @visibleForTesting
  void resetForTest() {
    _enabled = false;
    _withdrawPending = false;
    _withdrawPendingUid = null;
    withdrawInFlight = null;
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
    this.uid,
  }) : preference = preference ?? HealthBackupPreference.instance;

  /// The signed-in account this controller acts for. A pending withdrawal is
  /// sent only when it was made by this account, and dropped when it was not.
  final String? uid;

  /// Called the moment it is switched off on this phone, before the server
  /// answers.
  final VoidCallback? onDisabled;

  final HealthConsentStore store;
  final HealthBackupPreference preference;

  /// Called once the backup is on, to push what is already on the phone.
  final VoidCallback? onEnabled;

  bool get enabled => preference.enabled;

  /// Why the last [enable], or the last withdrawal, did not go through, or
  /// null. Read by A03 to tell "no connection" from "this copy of the app is
  /// refused" (R3) and "sign in again" (N4).
  Object? lastFailure;

  /// True when the server recorded her consent and the backup is now on.
  ///
  /// A withdrawal she made earlier and that never reached the server is
  /// superseded here (R6): any retry already in flight is let finish first,
  /// then the pending flag is cleared BEFORE the grant is sent, so no later
  /// retry can withdraw the consent she has just given and purge the backup
  /// she has just turned on. If the grant fails, the withdrawal she asked for
  /// is pending again.
  Future<bool> enable() async {
    lastFailure = null;
    final inFlight = preference.withdrawInFlight;
    if (inFlight != null) await inFlight;
    await _forgetAnotherAccountsWithdrawal();
    final wasPending = preference.withdrawPendingFor(uid);
    if (wasPending) await preference.setWithdrawPending(false);
    try {
      await store.record(granted: true);
    } catch (error) {
      lastFailure = error;
      if (wasPending) await preference.setWithdrawPending(true, uid: uid);
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
    lastFailure = null;
    await preference.set(false);
    await preference.setWithdrawPending(true, uid: uid);
    onDisabled?.call();
    return retryPendingWithdraw();
  }

  /// Sends a withdrawal that did not reach the server. True when nothing is
  /// pending any more. Never throws.
  ///
  /// A withdrawal another account made on this phone is never sent: the
  /// account has changed, so the marker is cleared instead.
  Future<bool> retryPendingWithdraw() {
    if (!preference.withdrawPending) return Future.value(true);
    // Synchronous up to here on purpose: an [enable] started right after this
    // call must find the attempt in [withdrawInFlight] (R6).
    if (!preference.withdrawPendingFor(uid)) {
      return preference.setWithdrawPending(false).then((_) => true);
    }
    return _sendPendingWithdraw();
  }

  /// Clears a pending withdrawal that is not this account's.
  Future<void> _forgetAnotherAccountsWithdrawal() async {
    if (preference.withdrawPending && !preference.withdrawPendingFor(uid)) {
      await preference.setWithdrawPending(false);
    }
  }

  Future<bool> _sendPendingWithdraw() {
    final running = preference.withdrawInFlight;
    if (running != null) return running;
    final attempt = () async {
      try {
        await store.record(granted: false);
      } catch (error) {
        lastFailure = error;
        return false;
      }
      await preference.setWithdrawPending(false);
      return true;
    }();
    preference.withdrawInFlight = attempt;
    return attempt.whenComplete(() {
      if (identical(preference.withdrawInFlight, attempt)) {
        preference.withdrawInFlight = null;
      }
    });
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
