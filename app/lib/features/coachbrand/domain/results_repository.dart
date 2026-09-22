/// Two writers, disjoint key sets — as two interfaces rather than one.
///
/// G13 §6 splits `coaches/{coachUid}/results/{resultId}` into a coach key set
/// (`order`, `requestedAt`, `relationshipId`, stamps) and a client key set
/// (`consentState`, `scope`, `mediaIds`, `quote`, …). A single repository with
/// both would be one careless parameter away from letting a coach write the
/// client's half.
///
/// So there are two:
///
///   * [ResultsRepository] — what B08 has. It can **ask** and it can **reorder**.
///     There is no method on it that accepts `mediaIds`, `quote`, `numbers`,
///     `scope` or `consentState`, so the coach path has nothing to call.
///   * [ClientConsentPort] — what the client's consent sheet has. Grant,
///     decline, withdraw. G11 routes the notification to it; G13 provides it.
///
/// `results_repository_test.dart` scans this file's own source and asserts that
/// [ResultsRepository] declares no member naming any client-owned field,
/// because an interface can always grow a method in a hurry and a reviewer
/// cannot be the last line of defence on this particular file.
library;

import 'dart:async';

import 'consent.dart';
import 'derived_numbers.dart';

/// The collection is capped at 50 per coach (G13 §9). A 51st request is
/// refused, with archive-an-old-one offered — an unbounded collection is a
/// collection scan waiting to happen.
const int kMaxResultsPerCoach = 50;

/// Refused because the security rule would refuse it.
class ResultWriteRejected implements Exception {
  ResultWriteRejected(this.reason);
  final String reason;

  @override
  String toString() => 'ResultWriteRejected: $reason';
}

/// What B08 can do. Ask, reorder, read.
abstract class ResultsRepository {
  /// Every result on this coach, in her order.
  Future<List<ClientResult>> results();

  Stream<List<ClientResult>> watchResults();

  Future<ClientResult?> byId(String resultId);

  /// Creates the document in `requested`, with no content.
  ///
  /// Takes a [ResultRequest], which has five fields and none of them is a
  /// photograph, a number or a sentence.
  Future<void> requestResult(ResultRequest request);

  /// Moves a result up or down her page. The only field she may change.
  Future<void> reorder(String resultId, int order);
}

/// What the client's own consent sheet can do.
///
/// Separate interface, separate implementer in production — this is her
/// surface, reached from a notification and (G13 §10 Q8) from A03 Privacy, so
/// a woman who wants her photo down does not have to find the coach's page.
abstract class ClientConsentPort {
  /// Her yes. She picks the pictures, the figures and the sentence.
  Future<ClientResult> grant({
    required String resultId,
    required ConsentScope scope,
    required DateTime at,
    List<String> mediaIds = const <String>[],
    String? quote,
  });

  /// Her no.
  Future<ClientResult> decline({
    required String resultId,
    required DateTime at,
  });

  /// Her taking it back.
  ///
  /// Takes a [WithdrawalIntent] rather than an id, because the intent carries
  /// whether she confirmed and whether there was signal — and an unconfirmed
  /// intent does nothing. Withdrawal is the documented exception to §2 rule 9.
  Future<ClientResult> withdraw(WithdrawalIntent intent);
}

/// Shared documents, so a coach repository and a client port see one truth.
class ResultsStore {
  ResultsStore({Map<String, ClientResult>? results}) : results = {...?results};

  final Map<String, ClientResult> results;
}

/// A strict fake implementing both halves — but exposed as two types.
///
/// A test that wants the coach's view holds it as a [ResultsRepository] and
/// therefore cannot call [grant] even by accident.
class InMemoryResultsRepository
    implements ResultsRepository, ClientConsentPort {
  InMemoryResultsRepository({ResultsStore? store, this.bests = const {}})
    : store = store ?? ResultsStore();

  final ResultsStore store;

  /// `users/{clientUid}/bests/*`, read through G6. The Function derives from
  /// these; nothing else can put a figure on a result.
  final Map<String, List<ClientBest>> bests;

  final StreamController<List<ClientResult>> _changes =
      StreamController<List<ClientResult>>.broadcast();

  List<ClientResult> get _ordered {
    final out = store.results.values.toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    return List.unmodifiable(out);
  }

  void _emit() => _changes.add(_ordered);

  // ───────────────────────────────────────────────────── the coach's half

  @override
  Future<List<ClientResult>> results() async => _ordered;

  @override
  Stream<List<ClientResult>> watchResults() async* {
    yield _ordered;
    yield* _changes.stream;
  }

  @override
  Future<ClientResult?> byId(String resultId) async => store.results[resultId];

  @override
  Future<void> requestResult(ResultRequest request) async {
    if (store.results.length >= kMaxResultsPerCoach) {
      throw ResultWriteRejected(
        'A coach holds at most $kMaxResultsPerCoach results. Archive an old '
        'one first.',
      );
    }
    if (store.results.containsKey(request.resultId)) {
      // Deterministic ids: a replayed request collides with itself rather than
      // asking the same woman twice (spine C1).
      return;
    }
    store.results[request.resultId] = ClientResult.fromRequest(request);
    _emit();
  }

  @override
  Future<void> reorder(String resultId, int order) async {
    final existing = store.results[resultId];
    if (existing == null) return;
    store.results[resultId] = existing.reorderedByCoach(order);
    _emit();
  }

  // ──────────────────────────────────────────────────── the client's half

  @override
  Future<ClientResult> grant({
    required String resultId,
    required ConsentScope scope,
    required DateTime at,
    List<String> mediaIds = const <String>[],
    String? quote,
  }) async {
    final existing = _require(resultId);
    if (existing.consentState != ConsentState.requested) {
      throw ResultWriteRejected(
        'Only a requested result can be granted; $resultId is '
        '${existing.consentState.name}.',
      );
    }

    var granted = existing.grantedByClient(
      at: at,
      scope: scope,
      mediaIds: mediaIds,
      quote: quote,
    );

    // The Function's half, in the same transaction the real one uses.
    granted = granted.withDerivedNumbers(bests[existing.clientUid] ?? const []);

    store.results[resultId] = granted;
    _emit();
    return granted;
  }

  @override
  Future<ClientResult> decline({
    required String resultId,
    required DateTime at,
  }) async {
    final next = _require(resultId).declinedByClient(at: at);
    store.results[resultId] = next;
    _emit();
    return next;
  }

  @override
  Future<ClientResult> withdraw(WithdrawalIntent intent) async {
    final existing = _require(intent.resultId);

    if (!intent.isActionable) {
      throw ResultWriteRejected(
        'A withdrawal must be confirmed. Consent withdrawal is the one '
        'destructive action in this flow that confirms rather than undoes.',
      );
    }

    final next = existing.withdrawnByClient(at: intent.requestedAt);
    store.results[intent.resultId] = next;
    _emit();
    return next;
  }

  // ─────────────────────────────────────────────── the Function's half

  /// Fourteen days with no answer, or a grant past [kConsentValidity].
  ClientResult functionExpired(String resultId, DateTime at) {
    final next = _require(resultId).expiredByServer(at: at);
    store.results[resultId] = next;
    _emit();
    return next;
  }

  /// `onAccountDelete(uid)` from G1.
  List<ClientResult> functionOrphanedFor(String clientUid, DateTime at) {
    final touched = <ClientResult>[];
    for (final entry in store.results.entries.toList()) {
      if (entry.value.clientUid != clientUid) continue;
      final next = entry.value.orphanedByAccountDeletion(at: at);
      store.results[entry.key] = next;
      touched.add(next);
    }
    if (touched.isNotEmpty) _emit();
    return List.unmodifiable(touched);
  }

  ClientResult functionRevoked(String resultId, DateTime at) {
    final next = _require(resultId).revokedByModeration(at: at);
    store.results[resultId] = next;
    _emit();
    return next;
  }

  ClientResult _require(String resultId) {
    final existing = store.results[resultId];
    if (existing == null) {
      throw ResultWriteRejected('No result $resultId.');
    }
    return existing;
  }

  Future<void> dispose() => _changes.close();
}
