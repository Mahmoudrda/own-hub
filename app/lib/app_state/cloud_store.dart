/// Her week in Firestore, under her own uid — and the phone is still the copy
/// the app reads.
///
/// ## What changed, and what did not
///
/// `local_persistence.dart` is untouched in behaviour: one JSON document on the
/// handset, read before the first frame, written debounced as she goes. It was
/// the only copy. It is now the CACHE, and this file is what makes a second
/// copy exist. The order in `main()` is the promise: the local document is
/// awaited before `runApp`, and nothing here is. A woman opening the app sees
/// her own Home drawn from the phone, and whatever this does or fails to do
/// happens after that frame.
///
/// ## Four states, and what her data does in each
///
///  1. **No account, no network.** Nothing here runs. [status] is
///     [CloudStatus.local] and no Firestore object is ever constructed. This is
///     the app exactly as it was before this file existed.
///  2. **No account, network.** The same. There is no uid, so there is nowhere
///     to write; being online is not a reason to start an account.
///  3. **Signed in, not verified.** Every app-data write returns
///     `PERMISSION_DENIED`, because the deployed rules gate all of it behind a
///     server-minted `verified` claim that nothing mints yet. [status] becomes
///     [CloudStatus.notVerified], pushing stops, and **nothing is shown to
///     her** — she is not verified yet, which is not a fault and not an error.
///     Her data keeps being written to the phone. This is the state every
///     account is in today.
///  4. **Signed in and verified.** The cloud is pulled, merged into the stores
///     under the union rule in `cloud_documents.dart`, and everything is pushed
///     up. Afterwards each debounced change pushes the documents that changed.
///
/// ## There is no second queue, deliberately
///
/// Firestore's Flutter SDK enables offline persistence by default on Android
/// and iOS, and that persistence is not a cache of reads — it is a durable
/// **mutation queue**. A `set()` made with no signal is applied to the local
/// copy at once, written to disk, and sent when the network returns, across a
/// process kill. Writing our own retry queue on top would be a second source of
/// truth for "has this been sent", and the two would disagree the first time a
/// write landed while the app was closed. So nothing here retries, nothing here
/// backs off, and `Settings(persistenceEnabled:)` is deliberately never touched
/// — leaving the default on is the design decision, not an omission.
///
/// The one consequence to know about: **a `set()` future does not complete
/// until the SERVER has acknowledged the write.** With no signal it never
/// completes. So nothing in this file awaits a write in order to continue; the
/// futures are awaited only to learn that one was REFUSED, which is the single
/// fact the rules can tell us that the phone cannot.
///
/// ## It cannot take the app down, and it cannot spin
///
/// Every path is guarded the way `firebase_boot.dart` guards the boot. A denial
/// stops the pushing rather than retrying it. A pull that fails because there
/// is no signal is not an error at all — it is a woman on the metro, and the
/// writes queue behind it. [lastFailure] keeps whatever went wrong so a debug
/// session can see it; nothing renders it.
library;

import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/widgets.dart';

import '../data/pending_answers.dart';
import '../features/account/domain/health_backup.dart';
import '../features/signup/domain/auth_repository.dart';
import '../routing/app_router.dart';
import 'app_changes.dart';
import 'cloud_documents.dart';
import 'cloud_transport.dart';
import 'firebase_boot.dart';
import 'local_persistence.dart';

/// The one key the ledger lives under, beside `own_hub.snapshot`.
///
/// A **second** preferences key, which `local_persistence.dart` asks be a
/// visible decision rather than an accident. It is one here because what it
/// holds is not hers: it is a record of which documents the SERVER has already
/// accepted, so that opening the app does not re-upload a year of sessions to
/// say nothing new. Putting it inside the snapshot would mean bumping
/// `kSnapshotSchema` — throwing away every woman's restored week — every time
/// the sync changed its bookkeeping.
const String kCloudLedgerKey = 'own_hub.cloud_ledger';

/// The shape this build writes into that key, and the only shape it reads.
const int kCloudLedgerSchema = 1;

/// Where the sync has got to. Nothing renders this; it is for tests and for a
/// debug session.
enum CloudStatus {
  /// No account, or [start] has not run. The phone is the whole of it, which is
  /// the state of every widget test and of the product as it ships today.
  local,

  /// Firebase did not come up. See `firebase_boot.dart`.
  unavailable,

  /// Signed in. The first pull and push are in flight.
  linking,

  /// Signed in, and writing as she goes.
  live,

  /// Signed in, and the server refuses app data because the `verified` claim
  /// has not been minted for her. Local-only, silently, by design.
  notVerified,
}

/// Reads the cloud once, merges it into the stores, and writes her changes up.
class CloudStore {
  CloudStore._();

  static final CloudStore instance = CloudStore._();

  /// How long a burst of changes settles before one push.
  ///
  /// Much longer than [LocalPersistence.writeDelay]'s 400ms, and the difference
  /// is the point: the phone is the copy she will actually read back, so it is
  /// written eagerly. The cloud is the copy that matters when the phone is
  /// lost, so it is written in batches — a set of three logged one rep at a
  /// time is one upload rather than nine.
  static const Duration pushDelay = Duration(seconds: 3);

  /// Where the documents go. Replaceable so a test can hold them in memory.
  ///
  /// Lazily built: constructing the real one reaches `FirebaseFirestore
  /// .instance`, which throws when Firebase never came up — and Firebase never
  /// comes up in a widget test.
  CloudTransport get transport => _transport ??= FirestoreCloudTransport();
  set transport(CloudTransport value) => _transport = value;
  CloudTransport? _transport;

  /// Where the ledger is kept. The same storage seam the snapshot uses, under
  /// its own key.
  SnapshotStorage ledgerStorage = const PreferencesSnapshotStorage(
    key: kCloudLedgerKey,
  );

  CloudStatus get status => _status;
  CloudStatus _status = CloudStatus.local;

  /// The account her data is being written under, or null.
  String? get uid => _uid;
  String? _uid;

  /// The last thing that went wrong, kept rather than thrown.
  ///
  /// Nothing renders it. It exists so that "the backend is refusing us" is
  /// inspectable in a debug session instead of being a silence — the same
  /// bargain `FirebaseBoot.failure` makes.
  Object? lastFailure;

  /// How many records the last merge took from the cloud. Zero is the ordinary
  /// case: an account whose cloud side holds nothing this phone did not write.
  int mergedFromCloud = 0;

  /// The digest of every document the server has already accepted, by path.
  /// A document whose digest is unchanged is not written again.
  final Map<String, String> _accepted = <String, String>{};

  /// Paths queued and not yet acknowledged. A write in flight is not queued a
  /// second time, which is what keeps a long stretch with no signal from
  /// stacking the same document once per debounce.
  final Set<String> _inFlight = <String>{};

  StreamSubscription<AuthState>? _auth;
  Timer? _pending;
  bool _running = false;
  _PushOnPause? _observer;

  bool get isRunning => _running;

  /// Starts watching for an account and for her changes.
  ///
  /// Call once, from `main()`, AFTER `FirebaseBoot.start()` and after
  /// `LocalPersistence.load()`. Returns as soon as the listeners are attached:
  /// the pull and the first push run on their own, so this never delays a
  /// frame. Never throws.
  Future<void> start() async {
    if (_running) return;
    // Not "Firebase is optional" — Firebase is ABSENT, in every widget test and
    // on a phone whose Play Services is broken. Returning here is what keeps
    // this file from being something the app can fail on.
    if (!FirebaseBoot.isReady) {
      _status = CloudStatus.unavailable;
      return;
    }
    _running = true;

    expectFirstAnswer();

    await _loadLedger();

    _auth = AppRouter.authRepository.watch().listen(
      _authChanged,
      // A dead auth stream must not become an unhandled error in the zone that
      // is drawing her Home screen.
      onError: (Object error) => lastFailure = error,
    );
    AppChanges.instance.addListener(_changed);
    _observer = _PushOnPause(this);
    WidgetsBinding.instance.addObserver(_observer!);
  }

  /// Stops listening and drops any pending push. For tests, and for the wipe.
  void stop() {
    _pending?.cancel();
    _pending = null;
    // Whatever was expected is not coming now. A screen must never be left
    // holding its tongue by a store that has been shut down.
    _firstAnswer();
    if (!_running) return;
    _running = false;
    unawaited(_auth?.cancel());
    _auth = null;
    AppChanges.instance.removeListener(_changed);
    final observer = _observer;
    if (observer != null) {
      WidgetsBinding.instance.removeObserver(observer);
      _observer = null;
    }
  }

  /// Pushes now, cancelling any pending push.
  ///
  /// Called when the app is paused, and by tests that want to look at what was
  /// written. It does **not** wait for the server: with no signal that would
  /// never return, and the queue on disk is what carries the write across the
  /// process ending.
  Future<void> syncNow() async {
    _pending?.cancel();
    _pending = null;
    _push();
  }

  /// Forgets which account this phone was linked to and what the server has.
  ///
  /// Account deletion calls it. The documents themselves are purged by the
  /// deletion Function against the manifest — Firestore does not cascade and a
  /// client cannot delete `users/{uid}` by rule — so what this clears is only
  /// this phone's memory of the link. Leaving it would mean a new account on
  /// the same handset inheriting a ledger that says her documents were already
  /// uploaded, and never uploading them.
  Future<void> forget() async {
    _pending?.cancel();
    _pending = null;
    _uid = null;
    _ledgerUid = null;
    _accepted.clear();
    _inFlight.clear();
    mergedFromCloud = 0;
    _status = _running ? CloudStatus.local : _status;
    try {
      await ledgerStorage.erase();
    } catch (error) {
      lastFailure = error;
    }
  }

  /// Forgets that the server holds her health documents and her root
  /// document (N5).
  ///
  /// Turning the health backup off makes the server purge the cloud copy, but
  /// this ledger still remembered every one of those documents as accepted,
  /// so turning it back on uploaded only what had changed since: the rest of
  /// her history was gone from the cloud for good. Called when the backup is
  /// switched off and again just before it is switched on, so the next push
  /// sends the whole history. The root document goes too, because it carries
  /// her life stage and allergies only while the backup is on.
  Future<void> forgetHealthUploads() async {
    _accepted.removeWhere(
      (path, _) =>
          path.isEmpty || kHealthCollections.any((c) => path.startsWith('$c/')),
    );
    await _saveLedger();
  }

  /// Tries again after something changed that this app cannot observe.
  ///
  /// There is exactly one such thing: the `verified` claim. It is minted by a
  /// server on its own schedule and it does not arrive on this app's auth
  /// stream — `AuthRepository.watch()` carries the sign-in flow, not a token
  /// refresh — so an account that becomes verified while the app is open stays
  /// [CloudStatus.notVerified] until the next launch. Her data is safe either
  /// way; it is on the phone and it goes up when the link is next attempted.
  /// The screen that learns the verification passed can call this and skip the
  /// wait.
  ///
  /// Safe to call at any time and from anywhere: with no account, with Firebase
  /// absent, or while already live, it does nothing.
  Future<void> retryLink() async {
    final uid = _uid;
    if (uid == null || !_running) return;
    await _link(uid);
  }

  /// One pull and merge for [uid], waited on for at most [bound] (R9).
  ///
  /// For the moment right after sign-in, when the app has to choose between
  /// setup and Home and her setup answers may be in the cloud rather than on
  /// this phone. Past the bound the link carries on by itself and the choice
  /// is made on what is here. Does nothing when the store is not running.
  /// Never throws.
  Future<void> linkWithin(String uid, Duration bound) async {
    if (!_running) return;
    try {
      await _link(uid).timeout(bound);
    } catch (_) {
      // Slow or failed: the phone's answer stands.
    }
  }

  /// Back to a fresh instance, holding nothing. Tests only.
  @visibleForTesting
  void reset() {
    // `stop()` releases the pending answer, so a reset store never leaves a
    // screen waiting on a pull that will never be attempted.
    stop();
    _transport = null;
    ledgerStorage = const PreferencesSnapshotStorage(key: kCloudLedgerKey);
    _status = CloudStatus.local;
    _uid = null;
    _ledgerUid = null;
    _accepted.clear();
    _inFlight.clear();
    mergedFromCloud = 0;
    lastFailure = null;
  }

  /// Signs the store in by hand, for a test and for a caller that already knows
  /// the uid. The ordinary path is the auth stream.
  @visibleForTesting
  Future<void> linkFor(String uid) => _link(uid);

  // ------------------------------------------------------------- lifecycle --

  void _authChanged(AuthState state) {
    switch (state) {
      case AuthSignedIn(:final uid):
        if (_uid == uid && _status != CloudStatus.local) return;
        unawaited(_link(uid));
      case AuthSignedOut():
      case AuthAwaitingCode():
        // No account is an answer. The phone is the whole of her data, it was
        // read before the first frame, and nothing else is coming.
        _firstAnswer();
        // Signing out stops the pushing and keeps the ledger: she may sign back
        // into the same account on the same handset, and re-uploading a year of
        // sessions to say nothing new is the cost of forgetting.
        _pending?.cancel();
        _pending = null;
        _uid = null;
        _inFlight.clear();
        _status = CloudStatus.local;
    }
  }

  /// Pulls, merges, and pushes everything once.
  ///
  /// This is the migration: a woman who used the app for weeks with no account
  /// arrives here the first time she signs in, holding a real local week and an
  /// empty cloud. The merge cannot delete — see the rule at the top of
  /// `cloud_documents.dart` — so an empty cloud changes nothing, and the push
  /// that follows is what puts her week where losing the phone stops costing it.
  Future<void> _link(String uid) async {
    try {
      await _linkOnce(uid);
    } finally {
      // Pulled, refused or failed: all three are answers, and a screen holding
      // its tongue has to be released by every one of them.
      _firstAnswer();
    }
  }

  /// Whether the one answer [start] is waiting for has been given.
  ///
  /// A latch rather than a counter. `retryLink` and a second sign-in both reach
  /// [_link] again, and a second pull is not a second reason to make Home go
  /// quiet: by then she has been shown something, and taking it back would be
  /// the flicker this exists to prevent.
  bool _firstAnswerGiven = true;

  /// Starts waiting for whatever a sign-in is going to say about her history.
  ///
  /// Called by [start], synchronously and before any await, because `main()`
  /// calls [start] BEFORE `runApp` — this is the only point early enough to
  /// stop `T06` saying "Day 1" in the first frame and withdrawing it when the
  /// pull lands. See `lib/data/pending_answers.dart`.
  ///
  /// Visible for testing as well because a widget test cannot bring Firebase
  /// up, and [start] returns before this line without it. The paths worth
  /// proving are the ones that RELEASE the wait: a pull that lands, one that is
  /// refused, one that fails, a sign-out, and a stop.
  @visibleForTesting
  void expectFirstAnswer() {
    _firstAnswerGiven = false;
    PendingAnswers.expect();
  }

  void _firstAnswer() {
    if (_firstAnswerGiven) return;
    _firstAnswerGiven = true;
    PendingAnswers.answered();
  }

  Future<void> _linkOnce(String uid) async {
    _uid = uid;
    _status = CloudStatus.linking;
    mergedFromCloud = 0;

    // A different account on the same handset. What the SERVER accepted is per
    // account, so the ledger from the last one says nothing true about this one.
    if (_ledgerUid != uid) {
      _accepted.clear();
      _inFlight.clear();
      _ledgerUid = uid;
    }

    List<CloudDoc>? remote;
    try {
      remote = await transport.pull(uid);
    } on CloudRefused catch (refused) {
      lastFailure = refused;
      if (refused.refusal == CloudRefusal.notVerified) {
        // Every gated collection is closed to her until a server mints the
        // claim. Nothing is wrong and nothing is said; the phone carries on.
        _status = CloudStatus.notVerified;
        return;
      }
      // No signal. Not a state to act on: the pushes below go onto Firestore's
      // own queue and leave with the network.
    } catch (error) {
      lastFailure = error;
    }

    // Health documents are taken from the cloud only while she has the
    // health backup on. Off, the phone's own copy is the only one, and a
    // stale cloud copy must not be folded back into it.
    if (remote != null && !HealthBackupPreference.instance.enabled) {
      remote = <CloudDoc>[
        for (final doc in remote)
          if (!kHealthCollections.contains(doc.collection)) doc,
      ];
    }

    if (remote != null && remote.isNotEmpty) {
      mergedFromCloud = CloudDocuments.mergeIn(remote);
      if (mergedFromCloud > 0) {
        // Two things follow from a merge, and both have to: every open screen
        // has to redraw from stores that changed under it, and the merged week
        // has to reach the phone. One bump does both — `LocalPersistence` is
        // listening to the same signal.
        AppChanges.bump();
      }
    }

    if (_status == CloudStatus.linking) _status = CloudStatus.live;
    _push();
  }

  void _changed() {
    if (_status != CloudStatus.live) return;
    _pending?.cancel();
    _pending = Timer(pushDelay, () {
      _pending = null;
      _push();
    });
  }

  /// Writes the documents that are not already on the server.
  ///
  /// Synchronous by design. It queues the writes and returns; the futures are
  /// picked up below only to record an acceptance or to notice a refusal.
  void _push() {
    final uid = _uid;
    if (uid == null) return;
    if (_status != CloudStatus.live && _status != CloudStatus.linking) return;

    List<CloudDoc> docs;
    try {
      docs = CloudDocuments.capture();
    } catch (error) {
      // Something in a store did not shape. Better to leave the last accepted
      // documents standing than to take the app down over an upload.
      lastFailure = error;
      return;
    }

    for (final doc in docs) {
      final path = doc.path;
      if (_inFlight.contains(path)) continue;
      final digest = _digestOf(doc);
      if (_accepted[path] == digest) continue;
      _inFlight.add(path);
      unawaited(
        transport
            .push(uid, doc)
            .then((_) {
              _inFlight.remove(path);
              // Still the same account. An acknowledgement can arrive minutes
              // after the write, long enough for her to have signed out or
              // deleted everything — and recording it then would rebuild the
              // ledger `forget()` just erased, leaving a new account on this
              // handset believing her documents were already uploaded.
              if (_uid != uid) return;
              // Recorded only on an acknowledgement. A write still sitting on
              // the queue is not a write the server has, and treating it as one
              // is how a document that was later refused is never sent again.
              _accepted[path] = digest;
              unawaited(_saveLedger());
            })
            .catchError((Object error) {
              _inFlight.remove(path);
              lastFailure = error;
              if (error is CloudRefused &&
                  error.refusal == CloudRefusal.notVerified) {
                // Stop. Not back off, not retry with a longer delay: the claim
                // she is missing is minted by a server on its own schedule, and
                // a client that keeps asking is a client billing her battery to
                // be told no. The next sign-in re-attempts it.
                _status = CloudStatus.notVerified;
                _pending?.cancel();
                _pending = null;
              }
            }),
      );
    }
  }

  // ---------------------------------------------------------------- ledger --

  String? _ledgerUid;

  /// A short, stable fingerprint of a document's contents.
  ///
  /// sha1 over a canonical rendering rather than `jsonEncode`, because the
  /// documents hold `DateTime`s and the server-time sentinel, neither of which
  /// encodes — and because map ordering must not change the answer or every
  /// launch would look like a change. `crypto`'s sha1 is already a dependency
  /// for the content-addressed ids in Eat, and this is the same kind of use:
  /// not a security boundary, a key that two runs agree on.
  String _digestOf(CloudDoc doc) =>
      sha1.convert(utf8.encode(_canonical(doc.data))).toString();

  static String _canonical(Object? value) => switch (value) {
    null => 'null',
    final Map<String, Object?> map =>
      '{${(map.keys.toList()..sort()).map((k) => '$k:${_canonical(map[k])}').join(',')}}',
    final List<Object?> list => '[${list.map(_canonical).join(',')}]',
    final DateTime time => time.toUtc().toIso8601String(),
    // The sentinel resolves server-side, so it must render as a constant or
    // every document would look different every time it was captured.
    _ when identical(value, kServerTime) => 'serverTime',
    _ => '$value',
  };

  Future<void> _loadLedger() async {
    String? stored;
    try {
      stored = await ledgerStorage.read();
    } catch (error) {
      lastFailure = error;
      return;
    }
    if (stored == null || stored.isEmpty) return;
    try {
      final parsed = jsonDecode(stored);
      if (parsed is! Map<String, Object?>) return;
      if (parsed['schema'] != kCloudLedgerSchema) return;
      _ledgerUid = parsed['uid'] is String ? parsed['uid'] as String : null;
      final digests = parsed['accepted'];
      if (digests is Map<String, Object?>) {
        for (final entry in digests.entries) {
          if (entry.value is String) _accepted[entry.key] = entry.value as String;
        }
      }
    } catch (error) {
      // A truncated or foreign ledger means one wasted round of uploads, which
      // land on the same deterministic ids and change nothing. It must never
      // mean a failed launch.
      lastFailure = error;
      _accepted.clear();
      _ledgerUid = null;
    }
  }

  Future<void> _saveLedger() async {
    try {
      await ledgerStorage.write(
        jsonEncode(<String, Object?>{
          'schema': kCloudLedgerSchema,
          'uid': _ledgerUid,
          'accepted': _accepted,
        }),
      );
    } catch (error) {
      lastFailure = error;
    }
  }
}

/// Pushes when she swipes the app away.
///
/// A separate object rather than making [CloudStore] an observer, for the same
/// reason `local_persistence.dart` keeps its own: the only thing the app's sync
/// singleton exposes is syncing.
class _PushOnPause with WidgetsBindingObserver {
  _PushOnPause(this._store);

  final CloudStore _store;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_store.syncNow());
    }
  }
}
