/// Her week, written to this phone and read back when she opens the app.
///
/// Until this existed every store in the app was in memory and nothing else, so
/// closing it lost the session she had just logged, the meal she had just
/// recorded, her cycle, her settings and even the language she had chosen. An
/// app that forgets the week is not a fitness app.
///
/// ## Nothing leaves the phone
///
/// There is no backend here and this adds none. One JSON document, written to
/// the handset's own preference store under one key, read back at launch, and
/// erased when she deletes everything. No network call is made from this file
/// and none is reachable from it.
///
/// ## Why `shared_preferences` rather than a file
///
/// The deciding argument is the store rather than the API. A file under the
/// application support directory needs the file-timestamp APIs Apple covers by
/// its required-reason rules, so a file-based store means hand-authoring
/// `PrivacyInfo.xcprivacy` and keeping it right; get it wrong and the upload is
/// refused at submission. `shared_preferences` ships its own privacy manifest
/// declaring the NSUserDefaults reason it uses, so the manifest travels with
/// the package.
///
/// Choosing it costs nothing in shape. The snapshot is still **one document**
/// under **one key**, so a launch is one read and one decode, not a key per
/// store — which is also what makes the document versionable and what makes
/// deletion one removal rather than a list somebody has to keep up to date.
///
/// ## When it writes
///
/// [AppChanges] is the app's one "something of hers changed" signal, and every
/// mutation already bumps it. So that is what this listens to, debounced by
/// [writeDelay]: a burst of taps is one write rather than twenty, and the write
/// happens off the frame that caused it. It also writes on
/// `AppLifecycleState.paused` and `detached`, which is the moment she swipes
/// the app away — [flush] cancels the pending timer and writes immediately, so
/// the last few hundred milliseconds are not the ones she loses.
///
/// `detached` is best effort by nature: the process may be gone before an
/// asynchronous write lands. `paused` fires first in every ordinary case and
/// has time, and the debounce means there is rarely more than one change
/// outstanding anyway.
///
/// ## What a write costs, and why it is still on the main isolate
///
/// [_write] calls `jsonEncode(AppSnapshot.capture())` on the main isolate, so
/// the cost grows with everything she has ever done. Measured on the document
/// the app really writes (`test/qa/round6/r6_01_snapshot_cost_test.dart`), at
/// two years of training — 400 sessions of five moves and three sets — the
/// encode was **10.5 ms** on a laptop. `app_snapshot.dart` then stopped writing
/// every prescription twice, which took the same document from 1802 KB to 953
/// KB and the encode to **6.6 ms**. A 2020 budget Android runs Dart four to six
/// times slower, so that is roughly 42-63 ms a write before, 26-40 ms after.
///
/// Moving the encode to another isolate was measured and **not** adopted. The
/// snapshot has to reach the worker, and `compute` copies the whole object
/// graph out of this isolate to send it — a copy this isolate pays for, and one
/// that costs about what the encode costs.
///
/// Measured as the longest gap a 1 ms ticker went unserved while each ran,
/// which is the stall a frame would be dropped in rather than a median, so it
/// is a worse number than the 6.6 ms above and not comparable to it:
///
/// | history | `jsonEncode` here | `compute(jsonEncode, …)` |
/// |---|---|---|
/// | 400 sessions | 10.6 ms | 7.2 ms |
/// | 800 sessions | 15.0 ms | 23.0 ms |
///
/// A third of a saving at two years, a loss at four, plus an isolate spawn on
/// every write and a second copy of her entire history live in memory while it
/// runs. The honest answer is that the encode belongs where it is until the
/// snapshot is written incrementally rather than whole — at which point the
/// isolate stops being the question.
///
/// ## Nothing is pruned, capped, or expired, and that is deliberate
///
/// `train` is 99.7% of the document at two years, and it is 542 KB of the
/// prescriptions she was given and 409 KB of the outcomes she logged. Both are
/// hers. Neither is derivable from anything else on this phone: last year's
/// assignment is not kept anywhere a cap could rebuild it from.
///
/// It is also the source `cloud_documents.dart` uploads from, so a record
/// dropped here is dropped before it was ever backed up — a cap would delete
/// her history exactly once, silently, and for good. A slow write is the
/// better failure.
///
/// ## When it reads
///
/// Once, in `main()`, before `runApp`. The first screen she sees is already
/// hers rather than the app's defaults replaced a frame later.
///
/// ## It cannot take the app down
///
/// Every path through this file is guarded. A missing, empty, truncated,
/// corrupt or older document restores nothing and the app opens on its
/// defaults; a platform store that throws is caught and recorded in
/// [lastFailure] rather than raised. `app_snapshot.dart` holds the other half
/// of that promise: decoding is separated from applying, so nothing is ever
/// half restored.
///
/// ## It is off unless something turns it on
///
/// [start] is called from `main()` and nowhere else. A widget test that pumps
/// `OwnHubApp` directly gets no listener and no platform channel, which is why
/// adding this changed no existing test.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_changes.dart';
import 'app_snapshot.dart';

/// The one key the whole snapshot lives under.
///
/// Named for the app and the thing, not for a store, so a second key is a
/// visible decision rather than an accident. `shared_preferences` prefixes it
/// with `flutter.` on the platform side; that is the package's business.
const String kSnapshotKey = 'own_hub.snapshot';

/// Where a snapshot is kept. One implementation ships; the interface exists so
/// a test can watch what was written without a platform channel.
abstract class SnapshotStorage {
  /// The stored document, or null when there is none.
  Future<String?> read();

  Future<void> write(String snapshot);

  /// Removes it. Deleting her account has to reach this, or a restart would
  /// bring back everything she just deleted.
  Future<void> erase();
}

/// The handset's own preference store.
///
/// `SharedPreferences.getInstance()` is asked for on every call rather than
/// cached in a field. It caches internally, so this costs nothing — and it
/// means `SharedPreferences.setMockInitialValues` in a test is picked up
/// instead of being shadowed by an instance captured earlier.
class PreferencesSnapshotStorage implements SnapshotStorage {
  /// [key] defaults to [kSnapshotKey], which is her week and the only thing
  /// this class was originally for. It is a parameter because `cloud_store.dart`
  /// keeps a second, much smaller document beside it — the record of which
  /// documents the server has already accepted — and that document wants the
  /// same read-write-erase seam and the same tested behaviour, not a second
  /// copy of it. A second KEY is still a visible decision: see
  /// `kCloudLedgerKey` for the argument that it earns one.
  const PreferencesSnapshotStorage({this.key = kSnapshotKey});

  final String key;

  @override
  Future<String?> read() async =>
      (await SharedPreferences.getInstance()).getString(key);

  @override
  Future<void> write(String snapshot) async {
    await (await SharedPreferences.getInstance()).setString(key, snapshot);
  }

  @override
  Future<void> erase() async {
    await (await SharedPreferences.getInstance()).remove(key);
  }
}

/// Reads the snapshot at launch and writes it back as she goes.
class LocalPersistence {
  LocalPersistence._();

  static final LocalPersistence instance = LocalPersistence._();

  /// How long a burst of changes is allowed to settle before one write.
  ///
  /// Long enough that tapping through a set of three is one write, short enough
  /// that swiping the app away half a second later has nothing to lose.
  static const Duration writeDelay = Duration(milliseconds: 400);

  /// Where the document goes. Replaceable so a test can hold it in memory.
  SnapshotStorage storage = const PreferencesSnapshotStorage();

  /// How many sections the last [load] put back. Zero is a first run, and also
  /// a document that could not be read — the two are the same to her.
  int restoredSections = 0;

  /// The last error a read or a write raised, kept rather than thrown.
  ///
  /// Nothing renders it. It exists so that "storage is broken" is inspectable
  /// in a debug session instead of being a silence.
  Object? lastFailure;

  Timer? _pending;

  /// The document most recently written, and where. A change that leaves the
  /// encoded document as it was (a bump for a screen redraw, a reward re-read)
  /// writes nothing: on a low-end phone a write is the biggest single cost of
  /// every tap, and her history is megabytes at two years.
  ///
  /// Compared without `savedAt`, which is the clock and differs every time.
  String? _lastWritten;
  SnapshotStorage? _lastWrittenTo;
  bool _running = false;
  _FlushOnPause? _observer;

  /// How many times [erase] has been asked for. Compared, never read for its
  /// value — see [_write], which uses a change in it to detect that a deletion
  /// overtook a write it had already handed to the platform.
  int _erasures = 0;

  /// True while this is listening for changes.
  bool get isRunning => _running;

  /// Reads the phone and puts back what is there. Call before `runApp`.
  ///
  /// Never throws: a store that cannot be read leaves every store at its
  /// defaults, which is the state the app had before any of this existed.
  Future<void> load() async {
    String? stored;
    try {
      stored = await storage.read();
    } catch (error) {
      lastFailure = error;
      restoredSections = 0;
      return;
    }
    restoredSections = AppSnapshot.restore(stored);
  }

  /// Starts listening. Every change she makes is written, debounced.
  void start() {
    if (_running) return;
    _running = true;
    AppChanges.instance.addListener(_changed);
    final binding = WidgetsBinding.instance;
    _observer = _FlushOnPause(this);
    binding.addObserver(_observer!);
  }

  /// Stops listening and drops any pending write. For tests, and for symmetry.
  void stop() {
    _pending?.cancel();
    _pending = null;
    if (!_running) return;
    _running = false;
    AppChanges.instance.removeListener(_changed);
    final observer = _observer;
    if (observer != null) {
      WidgetsBinding.instance.removeObserver(observer);
      _observer = null;
    }
  }

  /// Writes now, cancelling any pending write.
  ///
  /// Called when the app is paused or detached, and by tests that want the
  /// document on the phone before they look at it.
  Future<void> flush() async {
    _pending?.cancel();
    _pending = null;
    if (!_running) return;
    await _write();
  }

  /// Cancels any pending write and removes the stored document.
  ///
  /// Deleting her account calls it. Without it, everything she deleted would be
  /// back the next time she opened the app — which would turn a fixed blocker
  /// into a broken one.
  ///
  /// The cancellation is **synchronous**: it happens before the first await, so
  /// a write already scheduled can never land after a deletion, whatever the
  /// platform store does next. The removal itself is asynchronous and the wipe
  /// deliberately does not wait for it — deleting her data must not be hostage
  /// to a platform call, and a store that is slow, wedged or unavailable must
  /// still leave every in-memory store empty and the screen saying so. The
  /// returned future is for a caller that wants to know when the phone is
  /// clear; the tests are the ones that want it.
  ///
  /// Cancelling the timer is not on its own enough, and for a while this file
  /// claimed it was. The timer is only the window before `_write` STARTS;
  /// `_changed` fires it with `unawaited(_write())`, and `_write` then suspends
  /// at `await storage.write(...)`. A deletion arriving in that suspension
  /// cancels a timer that has already fired, erases the key, and then the write
  /// it never knew about completes and puts the whole document back — so she
  /// deletes her account, and her entire week is waiting for her at the next
  /// launch. That is exactly the "fixed blocker into a broken one" this method
  /// exists to prevent. [_erasures] closes it: it is bumped here, before the
  /// first await, and `_write` re-erases if it changed underneath it.
  Future<void> erase() async {
    _erasures++;
    _pending?.cancel();
    _pending = null;
    _lastWritten = null;
    try {
      await storage.erase();
    } catch (error) {
      lastFailure = error;
    }
  }

  /// Back to a fresh instance, holding nothing. Tests only.
  @visibleForTesting
  void reset() {
    stop();
    storage = const PreferencesSnapshotStorage();
    restoredSections = 0;
    lastFailure = null;
    _lastWritten = null;
    _lastWrittenTo = null;
  }

  void _changed() {
    _pending?.cancel();
    _pending = Timer(writeDelay, () {
      _pending = null;
      unawaited(_write());
    });
  }

  Future<void> _write() async {
    // Read before the first await, so it names the state of the world this
    // write belongs to. See [erase].
    final erasuresWhenStarted = _erasures;
    String snapshot;
    String body;
    try {
      final captured = AppSnapshot.capture();
      final savedAt = captured.remove('savedAt');
      body = jsonEncode(captured);
      // Put back at the front without a second encode of her whole history.
      snapshot = '{"savedAt":${jsonEncode(savedAt)},${body.substring(1)}';
    } catch (error) {
      // Something in a store did not encode. Better to keep the last good
      // document than to replace it with nothing.
      lastFailure = error;
      return;
    }
    final target = storage;
    if (body == _lastWritten && identical(target, _lastWrittenTo)) return;
    // Claimed before the await: a second flush in the same turn (paused, then
    // detached) compares against this write, not against the one before it.
    // A failed write gives the claim back, and an erase clears it.
    _lastWritten = body;
    _lastWrittenTo = target;
    try {
      await target.write(snapshot);
    } catch (error) {
      lastFailure = error;
      _lastWritten = null;
      return;
    }
    // A deletion landed while the platform was holding this write. The
    // document on the phone is now one `erase` already removed once, so remove
    // it again rather than leave her deleted week sitting there. Bounded: an
    // erase bumps the counter once, so at most one extra removal per racing
    // write, and a write that starts after the erase sees an unchanged counter
    // and is left alone — she is using the app again, and that is her data.
    if (_erasures != erasuresWhenStarted) {
      _lastWritten = null;
      try {
        await storage.erase();
      } catch (error) {
        lastFailure = error;
      }
    }
  }
}

/// Writes when she swipes the app away.
///
/// A separate object rather than making [LocalPersistence] an observer, so the
/// only thing the app's one storage singleton exposes is storage.
class _FlushOnPause with WidgetsBindingObserver {
  _FlushOnPause(this._persistence);

  final LocalPersistence _persistence;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_persistence.flush());
    }
  }
}
