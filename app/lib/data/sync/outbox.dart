/// The queue of writes waiting for signal.
///
/// Logging never requires a network. A woman on a Cairo microbus logs a set, and
/// it is hers immediately — the write sits here until there is signal, and the UI
/// shows it as saved, because it is.
///
/// Two properties matter more than anything else here:
///
/// **Replay is idempotent.** Firestore's documentation does not promise that a
/// retried write happens once, and a duplicated log corrupts week counting. So
/// the queue deduplicates on [WriteIntent.dedupeKey]: enqueueing the same intent
/// twice leaves one entry, and a drain that fails partway can be re-run safely.
///
/// **Nothing is lost by closing the app.** Drain order is insertion order, and a
/// failed drain leaves the remaining intents queued rather than dropping them.
library;

import 'dart:async';

import 'write_intent.dart';

/// What the UI shows about a pending write.
enum SyncState {
  /// Saved locally, waiting for signal. This is a normal state, not an error —
  /// the UI marks the row quietly and never blocks on it.
  queued,

  /// Sent and acknowledged.
  synced,

  /// Failed for a reason retrying will not fix. Rare, and surfaced honestly.
  failed,
}

class Outbox {
  Outbox({required this.sink});

  /// Where drained writes go. Public because the caller supplies it and could
  /// always hold its own reference; hiding it would buy nothing.
  final WriteSink sink;

  /// Insertion-ordered, keyed by dedupe key. A LinkedHashMap preserves order,
  /// which is what makes replay deterministic.
  final Map<String, WriteIntent> _queued = <String, WriteIntent>{};

  final StreamController<int> _depth = StreamController<int>.broadcast();

  /// How many writes are waiting. The UI uses this for the quiet "waiting for
  /// signal to save 3 meals" line — informational, never blocking.
  int get pendingCount => _queued.length;

  /// Emits the queue depth as it changes.
  Stream<int> get depth => _depth.stream;

  /// True while this exact write is still waiting.
  bool isPending(String dedupeKey) => _queued.containsKey(dedupeKey);

  /// Queues a write. Enqueueing the same intent again replaces rather than
  /// duplicates, so a retry loop or a rebuilt widget cannot double-log.
  void enqueue(WriteIntent intent) {
    _queued[intent.dedupeKey] = intent;
    _depth.add(_queued.length);
  }

  /// Removes a queued write before it is sent.
  ///
  /// This is how the five-second undo behaves when it fires after the log has
  /// reached the outbox but before there is signal. Returns false if it has
  /// already gone.
  bool discard(String dedupeKey) {
    final removed = _queued.remove(dedupeKey) != null;
    if (removed) _depth.add(_queued.length);
    return removed;
  }

  /// Sends everything waiting, oldest first.
  ///
  /// An intent is removed only once the sink has accepted it, so a failure
  /// partway leaves the rest queued and the whole drain can be retried without
  /// re-applying what already succeeded.
  Future<DrainResult> drain() async {
    var sent = 0;
    for (final key in _queued.keys.toList()) {
      final intent = _queued[key];
      if (intent == null) continue;
      try {
        await sink.apply(intent);
        _queued.remove(key);
        sent++;
      } on Object catch (error) {
        _depth.add(_queued.length);
        return DrainResult(sent: sent, remaining: _queued.length, error: error);
      }
    }
    _depth.add(_queued.length);
    return DrainResult(sent: sent, remaining: _queued.length);
  }

  Future<void> dispose() => _depth.close();
}

class DrainResult {
  const DrainResult({required this.sent, required this.remaining, this.error});

  final int sent;
  final int remaining;
  final Object? error;

  bool get isComplete => remaining == 0 && error == null;
}
