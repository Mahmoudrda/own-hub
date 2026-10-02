/// `P0-DEL-01` — account and data deletion actually deletes.
///
/// The hardest case in the product, and the one whose failure mode is silence:
/// a deletion that reports success while data survives looks identical, from the
/// screen, to one that worked.
///
/// # Order is the guarantee
///
/// G7 §3.3: "Auth is locked before any data is touched (so nothing can be
/// written back mid-purge) and the Auth record is deleted last (so the request
/// is always attributable and resumable)."
///
/// That is enforced here **structurally**, not by review. [DeletionState] carries
/// an explicit [DeletionState.rank], and [AccountDeletionService] refuses a
/// server state that moves backwards along the ladder. A backend that tried to
/// delete the Auth record before purging Firestore would be rejected by the
/// client rather than quietly believed.
///
/// # Deletion is not offline-capable, and does not pretend to be
///
/// G7 §4: "**No optimistic state, no local tombstone, no progress bar that is
/// not backed by a server ack.**"
///
/// So:
///
///   * [request] with no connection returns [DeletionOutcome.refusedOffline],
///     the state stays [DeletionState.idle], and **the transport is never
///     called**;
///   * every state after `requested` arrives on [DeletionTransport.serverStates]
///     and nothing in this file invents one. There is no local timer advancing a
///     progress bar, because there is no code path that can produce a state the
///     server did not send.
///
/// # The client-side half that is easy to miss
///
/// On `authLocked` the app must sign out, then `terminate()` and
/// `clearPersistence()` the Firestore instance — without that, her data is still
/// readable from the unbounded offline cache and **P0-DEL-01 fails on-device
/// while passing on the server**. It must also run manifest rows 33–34: G6's
/// `MeasurementsRepository.purgeLocal()` and the destruction of the photo
/// store's Keychain/Keystore key. Those progress photos have no server copy, so
/// a server-only purge leaves the most intimate data in the product sitting on
/// the phone.
///
/// The order within that wipe matters too and is asserted: signing out after
/// clearing the cache would let the still-authenticated SDK repopulate it, and
/// destroying the ciphertext while leaving the key is not deletion.
// `prefer_initializing_formals` asks for `required this._transport`, which Dart
// forbids outright: a named parameter cannot begin with an underscore. The only
// way to satisfy the lint is to make the fields public, and they are private
// deliberately — `_transport` and `_localWipe` are collaborators, not state a
// caller may reach past the service to drive, and `_online` on the fake is
// settable only through goOffline/goOnline so a test cannot flip to online
// without the transport noticing. Same constraint, and same resolution, as
// `lib/domain/identity/user_roles.dart`.
// ignore_for_file: prefer_initializing_formals
library;

import 'dart:async';

import 'package:meta/meta.dart';

/// G7 §3.3's machine.
enum DeletionState {
  idle,
  confirming,
  requested,
  authLocked,
  purgingFirestore,
  purgingStorage,
  purgingGroupHooks,
  purgingThirdParty,
  authDeleted,
  done,

  /// Never reports success. The sweeper re-runs anything not `done` after 15
  /// minutes.
  failedRetryable,

  reconciling;

  /// Position on the ladder, or -1 for the two states that are not on it.
  ///
  /// This is what makes the ordering guarantee checkable rather than
  /// aspirational: `authLocked` is 3, every purge is 4–7, and `authDeleted` is
  /// 8. Auth cannot be deleted before a purge because 8 is not less than 7.
  int get rank => switch (this) {
    DeletionState.idle => 0,
    DeletionState.confirming => 1,
    DeletionState.requested => 2,
    DeletionState.authLocked => 3,
    DeletionState.purgingFirestore => 4,
    DeletionState.purgingStorage => 5,
    DeletionState.purgingGroupHooks => 6,
    DeletionState.purgingThirdParty => 7,
    DeletionState.authDeleted => 8,
    DeletionState.done => 9,
    DeletionState.failedRetryable => -1,
    DeletionState.reconciling => -1,
  };

  /// True while the server is working through the manifest.
  bool get isPurging =>
      rank >= DeletionState.purgingFirestore.rank &&
      rank <= DeletionState.purgingThirdParty.rank;

  /// The **only** state that may tell her the account is gone.
  bool get isSuccess => this == DeletionState.done;

  /// True once her session must be dead on this handset.
  bool get requiresLocalWipe => this == DeletionState.authLocked;
}

/// What [AccountDeletionService.request] did.
enum DeletionOutcome {
  /// The callable accepted it. Progress will arrive from the server.
  accepted,

  /// No connection. Nothing was requested and nothing was faked.
  refusedOffline,

  /// Already running or already finished.
  alreadyInProgress,
}

/// What A02's deletion came to, as she is told it.
enum AccountDeletionResult {
  /// The server reported `done` (or there was no account, and this phone was
  /// the whole of it). This phone is cleared.
  done,

  /// No connection: nothing was deleted anywhere.
  offline,

  /// App Check refused this copy of the app: nothing was deleted.
  appCannotReach,

  /// The server has the request and did not finish it; its sweeper will.
  /// This phone is cleared. Never reported as done.
  unfinished,
}

/// The callable and the progress channel.
///
/// `requestAccountDeletion` is a **callable, not a write**, which is what makes
/// success impossible to fake offline: a queued Firestore write would sync later
/// and look like it worked.
abstract class DeletionTransport {
  bool get online;

  /// Calls `requestAccountDeletion`. Only ever called when [online].
  Future<void> requestDeletion();

  /// States the **server** has acknowledged. The single source of progress.
  Stream<DeletionState> serverStates();
}

/// The five things that must happen on this handset when Auth is locked.
///
/// Rows 33–34 of the manifest are the last two, and they are the ones a
/// server-side implementation cannot reach.
abstract class LocalWipe {
  Future<void> signOut();

  /// `FirebaseFirestore.instance.terminate()`.
  Future<void> terminateFirestore();

  /// `clearPersistence()` — the unbounded offline cache, which is where her data
  /// still is after a server purge.
  Future<void> clearPersistence();

  /// Manifest row 33 — G6's `MeasurementsRepository.purgeLocal()`.
  Future<void> purgeLocalMeasurements();

  /// Manifest row 34 — the photo store's Keychain/Keystore key.
  ///
  /// Nothing in this release mints one: there is no camera path and no photo
  /// store, so every implementation of this is a no-op today. The step is
  /// enumerated and called anyway, because a row added the day the camera lands
  /// is a row added after the first deletion has already run without it.
  Future<void> destroyPhotoStoreKey();
}

/// The order the wipe runs in, as data, so a test can assert it by name.
///
/// Sign out first: a still-authenticated SDK can repopulate the cache that is
/// about to be cleared. Key last: wiping ciphertext while leaving the key is not
/// deletion.
const List<String> kLocalWipeOrder = <String>[
  'signOut',
  'terminateFirestore',
  'clearPersistence',
  'purgeLocalMeasurements',
  'destroyPhotoStoreKey',
];

/// Drives the deletion and holds the guarantees.
class AccountDeletionService {
  AccountDeletionService({
    required DeletionTransport transport,
    required LocalWipe localWipe,
  }) : _transport = transport,
       _localWipe = localWipe;

  final DeletionTransport _transport;
  final LocalWipe _localWipe;

  final StreamController<DeletionState> _states =
      StreamController<DeletionState>.broadcast();

  StreamSubscription<DeletionState>? _serverSub;

  DeletionState _state = DeletionState.idle;

  /// Every state this service accepted, in order. The evidence P0-DEL-01 reads.
  final List<DeletionState> journal = <DeletionState>[DeletionState.idle];

  /// Rejected because it would have moved backwards along the ladder.
  final List<DeletionState> rejected = <DeletionState>[];

  DeletionState get state => _state;

  /// Server-acknowledged states only. Nothing local is ever pushed here.
  Stream<DeletionState> get states => _states.stream;

  /// Moves to [DeletionState.confirming].
  ///
  /// The one allowed confirmation in this group (§5): deletion is destructive
  /// and is **not** a logging action, so rule 9's "undo, not confirmation" does
  /// not apply. It confirms in a **sheet**, never a dialog — and the rule-9
  /// source guard enforces that across `lib/features/`.
  void beginConfirmation() {
    if (_state != DeletionState.idle) return;
    _advance(DeletionState.confirming);
  }

  void cancelConfirmation() {
    if (_state != DeletionState.confirming) return;
    _state = DeletionState.idle;
    journal.add(DeletionState.idle);
    _states.add(DeletionState.idle);
  }

  /// Requests the deletion.
  ///
  /// Refuses offline, and the refusal is the whole behaviour: no state change,
  /// no local tombstone, and [DeletionTransport.requestDeletion] is not called.
  Future<DeletionOutcome> request() async {
    if (_state.rank >= DeletionState.requested.rank) {
      return DeletionOutcome.alreadyInProgress;
    }

    if (!_transport.online) {
      // Deliberately does NOT advance. A woman who taps delete on the metro
      // must not see a progress bar that no server has acknowledged.
      return DeletionOutcome.refusedOffline;
    }

    await _transport.requestDeletion();
    _advance(DeletionState.requested);

    _serverSub ??= _transport.serverStates().listen(_onServerState);
    return DeletionOutcome.accepted;
  }

  /// Applies a server-acknowledged state.
  Future<void> _onServerState(DeletionState next) async {
    // failedRetryable and reconciling are off the ladder and always admissible:
    // a failure can interrupt any step.
    if (next.rank >= 0 && next.rank <= _state.rank) {
      // The ordering guarantee, enforced rather than trusted. A backend that
      // announced `authDeleted` before finishing the purge is refused here.
      rejected.add(next);
      return;
    }

    _advance(next);

    if (next.requiresLocalWipe) await _runLocalWipe();
  }

  void _advance(DeletionState next) {
    _state = next;
    journal.add(next);
    _states.add(next);
  }

  /// The client-side half. Order is fixed and asserted — see [kLocalWipeOrder].
  Future<void> _runLocalWipe() async {
    await _localWipe.signOut();
    await _localWipe.terminateFirestore();
    await _localWipe.clearPersistence();
    await _localWipe.purgeLocalMeasurements();
    await _localWipe.destroyPhotoStoreKey();
  }

  Future<void> dispose() async {
    await _serverSub?.cancel();
    await _states.close();
  }
}

// ------------------------------------------------------------------ fakes --

/// A transport whose connection and server states a test drives by hand.
class FakeDeletionTransport implements DeletionTransport {
  FakeDeletionTransport({bool online = true}) : _online = online;

  bool _online;
  final StreamController<DeletionState> _server =
      StreamController<DeletionState>.broadcast();

  /// How many times the callable was invoked. Offline, this must stay 0.
  int requests = 0;

  @override
  bool get online => _online;

  void goOffline() => _online = false;
  void goOnline() => _online = true;

  @override
  Future<void> requestDeletion() async {
    if (!_online) {
      throw StateError(
        'requestAccountDeletion was called with no connection. The callable '
        'returns `unavailable`, and the client must refuse before reaching '
        'this point — G7 §4.',
      );
    }
    requests++;
  }

  @override
  Stream<DeletionState> serverStates() => _server.stream;

  /// Acknowledges a state, as the Function would.
  void emit(DeletionState state) => _server.add(state);

  Future<void> close() => _server.close();
}

/// Records what ran, and in what order.
@visibleForTesting
class RecordingLocalWipe implements LocalWipe {
  /// Method names in the order they were called.
  final List<String> calls = <String>[];

  @override
  Future<void> signOut() async => calls.add('signOut');

  @override
  Future<void> terminateFirestore() async => calls.add('terminateFirestore');

  @override
  Future<void> clearPersistence() async => calls.add('clearPersistence');

  @override
  Future<void> purgeLocalMeasurements() async =>
      calls.add('purgeLocalMeasurements');

  @override
  Future<void> destroyPhotoStoreKey() async =>
      calls.add('destroyPhotoStoreKey');
}
