/// §2 rule 9: **undo, not confirmation.**
///
/// Every logging action in this product — a set, a meal, a check-in, a post —
/// saves immediately and offers five seconds to undo. None of them asks "are you
/// sure". Confirmation is the friction this product exists to remove: a woman
/// logging a set between breaths should tap once, not twice.
///
/// The rule is enforced by the shape of this API rather than by review. There is
/// no `confirm` parameter, no `onConfirm` callback and no hook a caller could
/// pass a dialog into. Every logging path goes through [LogCommandBus], and a
/// dialog would have to be added somewhere this bus cannot see — a visible change
/// in a diff, which is the point.
///
/// **Why the draft is held here and not in Firestore's queue.** Firestore's
/// documented offline behaviour queues a write and replays it on reconnect, and
/// the documentation describes no way to cancel a queued write. If the save went
/// straight to Firestore, undoing it offline would leave the original write in
/// the queue to sync later — she would undo a set and watch it come back. So the
/// write is held locally for the undo window and only handed to the repository
/// when that window closes.
library;

import 'dart:async';

/// How long a woman has to take a log back. Five seconds, everywhere.
const Duration kUndoWindow = Duration(seconds: 5);

/// A log that has been made and can still be taken back.
///
/// [describe] is the snackbar text, and it must name the same numbers the button
/// named — if the button said "12 kg × 10", the confirmation says "12 kg × 10",
/// because a woman should never have to wonder what she just agreed to.
class UndoableLog {
  const UndoableLog({required this.describe, required this.commit});

  final String describe;

  /// What actually persists. Runs when the undo window closes.
  ///
  /// Public because the caller supplies this closure and could always invoke it
  /// directly; hiding it would buy no safety. What protects rule 9 is that the
  /// UI has exactly one logging path — this bus — which a source-level test
  /// asserts, not the privacy of this field.
  final Future<void> Function() commit;
}

/// A handle the UI holds while the undo window is open.
class LogHandle {
  LogHandle._(this._bus, this._id, this.describe);

  final LogCommandBus _bus;
  final Object _id;
  final String describe;

  /// Takes the log back. Safe to call after the window has closed — it reports
  /// false rather than throwing, because a woman tapping Undo a moment late
  /// should not crash her session.
  bool undo() => _bus._undo(_id);
}

/// The single point every logging action in the product passes through.
class LogCommandBus {
  LogCommandBus({this.window = kUndoWindow});

  /// The undo window. Injectable so tests can control it; `final`, so nothing can
  /// widen it at runtime.
  final Duration window;

  final Map<Object, _Pending> _pending = {};

  /// Logs something. Returns immediately with a handle valid for [window].
  ///
  /// Note what this signature does not accept: there is no way to ask the user
  /// first. That absence is the enforcement.
  LogHandle submit(UndoableLog log) {
    final id = Object();
    final timer = Timer(window, () => _flush(id));
    _pending[id] = _Pending(log, timer);
    return LogHandle._(this, id, log.describe);
  }

  /// True while [handle] can still be undone.
  bool isPending(LogHandle handle) => _pending.containsKey(handle._id);

  /// Commits everything still waiting. Call when a screen is leaving, so a log is
  /// never lost because she navigated away inside the window.
  Future<void> flushAll() async {
    for (final id in _pending.keys.toList()) {
      await _flush(id);
    }
  }

  /// Drops pending work without committing. For tests and for sign-out.
  void dispose() {
    for (final p in _pending.values) {
      p.timer.cancel();
    }
    _pending.clear();
  }

  bool _undo(Object id) {
    final pending = _pending.remove(id);
    if (pending == null) return false;
    pending.timer.cancel();
    // Nothing to roll back: the write never left this object.
    return true;
  }

  Future<void> _flush(Object id) async {
    final pending = _pending.remove(id);
    if (pending == null) return;
    pending.timer.cancel();
    await pending.log.commit();
  }
}

class _Pending {
  _Pending(this.log, this.timer);
  final UndoableLog log;
  final Timer timer;
}
