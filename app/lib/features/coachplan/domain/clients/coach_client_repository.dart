/// One listener, three screens — W01, W10 and W11.
///
/// G14 §2: the four chips are client-side filters over the same ≤60 documents,
/// "not four queries". Opening the inbox after the client list costs **0**
/// reads. `P0-QUEUE-01` measures exactly that, which is why this fake counts.
///
/// This feature **never writes** `relationships/**`. G11 owns that collection;
/// W09's feedback and W10's threads go through its API. So there is no `save`
/// here, and no method that could grow one without the omission being obvious.
library;

import 'coach_client.dart';

/// Refused because a coach cannot hold more than the cap allows.
class ClientCapReached implements Exception {
  const ClientCapReached(this.activeCount);

  final int activeCount;

  @override
  String toString() => 'ClientCapReached($activeCount of $kClientCap)';
}

abstract class CoachClientRepository {
  /// The active clients, longest-waiting first, capped at [kClientCap].
  ///
  /// The first call reads; every call after it is served from what the
  /// listener already holds, which is what makes W10 and W11 free.
  Future<List<CoachClient>> clients();

  /// Whether the listener has delivered yet. W01 distinguishes "no clients"
  /// from "not loaded", because rendering the day-one empty state over a
  /// coach's real book would be a lie at the worst moment.
  bool get hasLoaded;
}

class InMemoryCoachClientRepository implements CoachClientRepository {
  InMemoryCoachClientRepository({
    List<CoachClient> clients = const <CoachClient>[],
  }) : _clients = List<CoachClient>.unmodifiable(clients);

  final List<CoachClient> _clients;

  /// Documents read. The first call reads the page; later calls read nothing.
  int reads = 0;

  /// How many times the query itself was issued. One, forever.
  int queries = 0;

  bool _loaded = false;

  @override
  bool get hasLoaded => _loaded;

  @override
  Future<List<CoachClient>> clients() async {
    if (!_loaded) {
      queries += 1;
      reads += _clients.length;
      _loaded = true;
    }
    return ClientQueue.longestWaitingFirst(_clients);
  }

  /// A delta from the listener — no new query, no re-read of the page.
  InMemoryCoachClientRepository withDelta(List<CoachClient> next) {
    final repo = InMemoryCoachClientRepository(clients: next)
      .._loaded = _loaded
      ..queries = queries
      ..reads = reads;
    return repo;
  }
}
