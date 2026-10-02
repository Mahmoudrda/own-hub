/// The real [DeletionTransport]: `delete_account` (S4).
///
/// The callable runs the whole deletion on the server, synchronously, and
/// answers `{state: "done", journal: [...]}` with the eight states it went
/// through, in order (contracts/identity_contract.json `deletionJournal`).
/// [serverStates] replays that journal, so `AccountDeletionService` receives
/// exactly what the server acknowledged and nothing it did not: `authLocked`
/// runs the handset wipe, and `done` is the only success.
///
/// A replay, not a live channel, and it has to be: the service subscribes only
/// after [requestDeletion] returns, so a broadcast emitted during the call
/// would be lost. `Stream.fromIterable` is made on subscription instead.
///
/// The account screen stays open to an unverified woman (Protected List 6),
/// and so does this: the callable is gated on being signed in, not on the
/// `verified` claim.
library;

import 'package:cloud_functions/cloud_functions.dart';

import '../../../app_state/firebase_boot.dart';
import '../domain/account_deletion_service.dart';

/// Callable name, identical on both sides of the contract.
const String kDeleteAccountCallable = 'delete_account';

/// The deletion could not be requested because there is no connection.
/// Nothing was deleted.
class DeletionOffline implements Exception {
  const DeletionOffline();
}

/// App Check refused this copy of the app. Nothing was deleted; she is told
/// to install the latest version.
class DeletionAppCannotReach implements Exception {
  const DeletionAppCannotReach();
}

/// The request reached the server and did not finish there. The server
/// records it and its sweeper finishes the deletion (every 15 minutes, once a
/// request has been idle for 10), so the honest message is "it will finish".
class DeletionUnfinished implements Exception {
  const DeletionUnfinished(this.code);
  final String code;
}

/// Sends `delete_account` and returns the response data.
typedef DeleteAccountCall = Future<Object?> Function();

class CallableDeletionTransport implements DeletionTransport {
  CallableDeletionTransport({
    required this.isOnline,
    DeleteAccountCall? call,
  }) : _call = call ?? _callFunction;

  /// Whether a call can be made at all: Firebase up and her account signed in.
  final bool Function() isOnline;
  final DeleteAccountCall _call;

  /// What the server acknowledged, in order.
  List<DeletionState> journal = const <DeletionState>[];

  static Future<Object?> _callFunction() async {
    final callable = FirebaseBoot.functions.httpsCallable(
      kDeleteAccountCallable,
      options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
    );
    final response = await callable.call<Object?>(const <String, Object?>{});
    return response.data;
  }

  @override
  bool get online => isOnline();

  @override
  Future<void> requestDeletion() async {
    final Object? data;
    try {
      data = await _call();
    } on FirebaseFunctionsException catch (error) {
      // Never reached the server, or reached it without a usable sign-in:
      // nothing was deleted anywhere.
      if (error.code == 'unavailable' || error.code == 'unauthenticated') {
        throw const DeletionOffline();
      }
      if (error.code == 'failed-precondition' &&
          error.message == 'app_check_missing') {
        throw const DeletionAppCannotReach();
      }
      // INTERNAL internal_error: the server recorded `failedRetryable` and its
      // sweeper finishes the deletion. Anything else is treated the same way:
      // never as done.
      throw DeletionUnfinished(error.code);
    }
    journal = journalFrom(data);
    if (journal.isEmpty || journal.last != DeletionState.done) {
      // An answer that does not end in `done` is not a deletion she can be
      // told about. The server's record decides; the sweeper finishes it.
      throw const DeletionUnfinished('no-done');
    }
  }

  /// The server's journal, as states. Unknown names are dropped rather than
  /// guessed at.
  static List<DeletionState> journalFrom(Object? data) {
    final raw = data is Map ? data['journal'] : null;
    if (raw is! List) return const <DeletionState>[];
    final byName = {for (final s in DeletionState.values) s.name: s};
    return <DeletionState>[
      for (final name in raw) ?byName[name],
    ];
  }

  @override
  Stream<DeletionState> serverStates() => Stream.fromIterable(journal);
}
