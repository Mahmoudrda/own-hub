/// Whose week the snapshot on this phone is.
///
/// The app keeps one snapshot for the whole handset. Signing out leaves it in
/// place, so a different woman signing in on the same phone would otherwise
/// open on the previous woman's workouts, meals and cycle. The uid of the
/// account that owns the snapshot is stored beside it, and every sign-in is
/// checked against it before any of her data is shown or synced.
///
/// * The owner differs: everything of hers is erased and the owner becomes
///   the new uid. What the woman signing in did on the way is kept: her
///   language, the terms she accepted at `C06`, this installation's id, and
///   the week she built before signing up (`ThisPhoneWipe.keepsSignUp`).
/// * The owner matches: nothing happens.
/// * No owner is stored (a phone from before this existed): the uid is adopted
///   and nothing is erased.
///
/// The tour and the demo are signed out, so they never reach [claim] and never
/// write an owner.
library;

import 'dart:async';
import 'dart:convert';

import '../features/account/domain/account_deletion_service.dart'
    show LocalWipe;
import 'account_data.dart';
import 'app_snapshot.dart';
import 'local_persistence.dart';
import 'onboarding_state.dart';

/// Kept under its own key so erasing the snapshot does not forget the owner.
const String kSnapshotOwnerKey = 'own_hub.snapshot_owner';

class SnapshotOwner {
  SnapshotOwner._();

  static final SnapshotOwner instance = SnapshotOwner._();

  /// Where the uid is kept. Replaceable so a test can hold it in memory.
  SnapshotStorage storage = const PreferencesSnapshotStorage(
    key: kSnapshotOwnerKey,
  );

  /// The wipe run when the owner changes. Replaceable for a test.
  LocalWipe wipe = const ThisPhoneWipe(keepsOwner: true, keepsSignUp: true);

  String? _owner;
  bool _loaded = false;

  /// The uid stored with the snapshot, as last loaded or claimed.
  String? get owner => _owner;

  /// Reads the stored owner. Call before [claim], and before the snapshot is
  /// shown. Never throws: an unreadable store reads as no owner.
  Future<void> load() async {
    try {
      _owner = await storage.read();
    } catch (_) {
      _owner = null;
    }
    _loaded = true;
  }

  /// Checks [uid] against the stored owner. Returns true when it erased.
  ///
  /// The erase of the stores happens synchronously inside this call, before
  /// its first await, so a caller that does not wait still cannot render or
  /// sync the previous woman's data afterwards. Only the writes to the phone's
  /// storage are awaited.
  Future<bool> claim(String uid) {
    if (uid.isEmpty) return Future<bool>.value(false);
    final previous = _owner;
    if (previous == uid) {
      _weekClaimed();
      return Future<bool>.value(false);
    }
    _owner = uid;
    if (previous == null) {
      _weekClaimed();
      return _store(uid).then((_) => false);
    }
    // Reads `weekBuiltSignedOut` to decide whether the answers on the phone
    // are hers. Runs to the end before its first await, so the marker is
    // cleared below only once it has been read.
    unawaited(wipe.clearPersistence());
    unawaited(wipe.purgeLocalMeasurements());
    _weekClaimed();
    return _eraseThenStore(uid).then((_) => true);
  }

  /// The week built before sign-up now belongs to an account, so the next
  /// change of account must not read it as the next woman's.
  static void _weekClaimed() {
    OnboardingState.instance.weekBuiltSignedOut = false;
  }

  Future<void> _eraseThenStore(String uid) async {
    // The snapshot goes, then comes back holding only what the empty stores
    // and the device-level choices (language) hold now.
    await LocalPersistence.instance.erase();
    try {
      await LocalPersistence.instance.storage.write(
        jsonEncode(AppSnapshot.capture()),
      );
    } catch (error) {
      LocalPersistence.instance.lastFailure = error;
    }
    await _store(uid);
  }

  Future<void> _store(String uid) async {
    try {
      await storage.write(uid);
    } catch (_) {}
  }

  /// Forgets the owner. Deleting the account calls it.
  Future<void> forget() async {
    _owner = null;
    try {
      await storage.erase();
    } catch (_) {}
  }

  /// Back to a fresh instance. Tests only.
  void resetForTest() {
    _owner = null;
    _loaded = false;
    storage = const PreferencesSnapshotStorage(key: kSnapshotOwnerKey);
    wipe = const ThisPhoneWipe(keepsOwner: true, keepsSignUp: true);
  }

  /// Whether [load] has run.
  bool get isLoaded => _loaded;
}
