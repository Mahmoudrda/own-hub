// R5-03. Deleting her account, while a write is already in the platform's
// hands.
//
// `LocalPersistence.erase()` cancels the pending timer synchronously and its
// doc comment used to claim that settled it: "a write already scheduled can
// never land after a deletion". The timer is only the window before `_write`
// STARTS. `_changed` fires it with `unawaited(_write())`, and `_write` then
// suspends at `await storage.write(...)`. A deletion arriving inside that
// suspension cancels a timer that has already fired, erases the key, and the
// write it never knew about completes afterwards and puts the whole document
// back.
//
// The consequence is the one the method exists to prevent: she deletes her
// account and her entire week is waiting for her at the next launch.
//
// `_SlowStorage` holds its write open on a completer so the race is a
// certainty rather than something a test gets lucky with.
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/local_persistence.dart';

/// A store whose `write` does not finish until the test says so.
class _SlowStorage implements SnapshotStorage {
  String? document;
  int writes = 0;
  int erases = 0;

  /// Completed by the test to let the in-flight write land.
  final Completer<void> writeGate = Completer<void>();

  /// Completed by this class when `write` has suspended, so the test knows the
  /// race window is open rather than guessing at it with a delay.
  final Completer<void> writeStarted = Completer<void>();

  @override
  Future<String?> read() async => document;

  @override
  Future<void> write(String snapshot) async {
    writes++;
    if (!writeStarted.isCompleted) writeStarted.complete();
    await writeGate.future;
    document = snapshot;
  }

  @override
  Future<void> erase() async {
    erases++;
    document = null;
  }
}

void main() {
  // `start()` registers a `WidgetsBindingObserver` for the swipe-away flush.
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a write already in flight cannot undo a deletion', () async {
    final storage = _SlowStorage();
    final persistence = LocalPersistence.instance;
    addTearDown(persistence.reset);
    persistence.reset();
    persistence.storage = storage;
    persistence.start();

    // A write, started and suspended inside the platform store.
    final writing = persistence.flush();
    await storage.writeStarted.future;
    expect(storage.writes, 1, reason: 'the write should be in flight');

    // She deletes her account, in that exact window.
    await persistence.erase();
    expect(storage.document, isNull);

    // The platform finally lets the write go.
    storage.writeGate.complete();
    await writing;

    expect(
      storage.document,
      isNull,
      reason: 'a write that lost the race to a deletion put her week back on '
          'the phone — the next launch would restore everything she deleted',
    );
  });

  test('an ordinary write after a deletion is kept', () async {
    // The guard must not make the app unable to save again. She deleted
    // everything, then carried on using the app; that is her data and it
    // belongs on the phone.
    final storage = _SlowStorage();
    final persistence = LocalPersistence.instance;
    addTearDown(persistence.reset);
    persistence.reset();
    persistence.storage = storage;
    persistence.start();

    await persistence.erase();
    storage.writeGate.complete();
    await persistence.flush();

    expect(storage.document, isNotNull);
    expect(storage.erases, 1, reason: 'only the deletion should have erased');
  });
}
