// P0-QUEUE-01 and P0-QUEUE-02 — W01, W10 and W11 are one listener.
//
// G14 §2: the four chips are client-side filters over the same ≤60 documents,
// "not four queries". The naive build issues three queries for three screens
// and four more for the chips; this one issues **one**, and the tests below
// measure that rather than asserting it.
//
// The second property is quieter and matters more: the list orders *work*, by
// how long somebody has been waiting for a reply she was promised. It never
// ranks women, and there is nothing on the type it could rank them by.

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/coachplan/domain/clients/coach_client.dart';
import 'package:own_hub/features/coachplan/domain/clients/coach_client_repository.dart';

import 'source_scan.dart';

final DateTime _now = DateTime(2026, 9, 19, 18, 0);

CoachClient _client(
  String uid, {
  Duration? waiting,
  int unread = 0,
  DateTime? reviewDueAt,
  DateTime? planNeededAt,
  DateTime? assessmentDueAt,
}) => CoachClient(
  clientUid: uid,
  displayName: uid,
  queue: ClientQueueState(
    oldestUnansweredAt: waiting == null ? null : _now.subtract(waiting),
    unreadForCoach: unread,
    reviewDueAt: reviewDueAt,
    planNeededAt: planNeededAt,
    assessmentDueAt: assessmentDueAt,
  ),
);

/// Three waiting 19 h / 6 h / 1 h, one review due, one assessment due — the
/// precondition P0-QUEUE-01 states, verbatim.
List<CoachClient> _book() => <CoachClient>[
  _client('nour', waiting: const Duration(hours: 6)),
  _client('habiba', waiting: const Duration(hours: 19)),
  _client('mariam', waiting: const Duration(hours: 1)),
  _client('salma', reviewDueAt: _now.subtract(const Duration(hours: 2))),
  _client('dina', assessmentDueAt: _now.subtract(const Duration(days: 3))),
  _client('yasmin'),
];

void main() {
  group('P0-QUEUE-01 — the queue is ordered by waiting time', () {
    test('longest waiting first, and nobody waiting sorts last', () {
      expect(
        ClientQueue.longestWaitingFirst(_book()).map((c) => c.clientUid),
        <String>['habiba', 'nour', 'mariam', 'salma', 'dina', 'yasmin'],
        reason: 'a client with no question is not work',
      );
    });

    test('two clients with nothing waiting keep their order', () {
      final settled = <CoachClient>[_client('a'), _client('b'), _client('c')];
      // Run it twice: a list that reshuffles under her thumb reads as broken
      // even when the set is identical.
      expect(
        ClientQueue.longestWaitingFirst(settled).map((c) => c.clientUid),
        <String>['a', 'b', 'c'],
      );
      expect(
        ClientQueue.longestWaitingFirst(
          ClientQueue.longestWaitingFirst(settled),
        ).map((c) => c.clientUid),
        <String>['a', 'b', 'c'],
      );
    });

    test('four chips, one listener, no extra reads', () async {
      final repo = InMemoryCoachClientRepository(clients: _book());

      final clients = await repo.clients();
      final afterFirstRead = repo.reads;
      expect(repo.queries, 1);
      expect(afterFirstRead, 6);

      // Every chip is a filter over what the listener already delivered.
      for (final filter in QueueFilter.values) {
        ClientQueue.matching(clients, filter, now: _now);
      }
      // W10 and then W11 open on the same documents.
      await repo.clients();
      await repo.clients();

      expect(repo.queries, 1, reason: 'four chips are not four queries');
      expect(
        repo.reads,
        afterFirstRead,
        reason: 'opening the inbox after the client list costs 0 reads',
      );
    });

    test('each chip holds what it says it holds', () {
      final counts = ClientQueue.counts(_book(), now: _now);
      expect(counts[QueueFilter.needsReply], 3);
      expect(counts[QueueFilter.reviewsDue], 1);
      expect(counts[QueueFilter.assessmentDue], 1);
      expect(counts[QueueFilter.planNeeded], 0);
    });

    test('a chip due in the future is not due yet', () {
      final later = <CoachClient>[
        _client('nour', reviewDueAt: _now.add(const Duration(days: 1))),
      ];
      expect(ClientQueue.matching(later, QueueFilter.reviewsDue, now: _now), isEmpty);
    });

    test('an unread message counts as waiting even with no timestamp', () {
      expect(
        ClientQueue.matching(
          <CoachClient>[_client('nour', unread: 2)],
          QueueFilter.needsReply,
          now: _now,
        ),
        hasLength(1),
      );
    });

    test('waiting time is measured against a clock that is passed in', () {
      expect(
        _client('nour', waiting: const Duration(hours: 19)).queue.waitingFor(_now),
        const Duration(hours: 19),
      );
      expect(_client('yasmin').queue.waitingFor(_now), isNull);
    });
  });

  group('P0-QUEUE-02 — a coach with no clients', () {
    test('"no clients" and "not loaded" are different states', () async {
      final repo = InMemoryCoachClientRepository();
      expect(
        repo.hasLoaded,
        isFalse,
        reason: 'rendering the day-one empty state over a coach\'s real book '
            'would be a lie at the worst possible moment',
      );

      expect(await repo.clients(), isEmpty);
      expect(repo.hasLoaded, isTrue);
    });

    test('a delta from the listener is not a new query', () async {
      final repo = InMemoryCoachClientRepository(clients: _book());
      await repo.clients();

      final next = repo.withDelta(<CoachClient>[..._book(), _client('new')]);
      expect(next.queries, 1);
      expect(next.reads, repo.reads);
      expect((await next.clients()).length, 7);
    });
  });

  group('the cap is sixty', () {
    test('sixty fit, sixty-one do not', () {
      expect(kClientCap, 60);
      expect(ClientQueue.hasRoomFor(59), isTrue);
      expect(ClientQueue.hasRoomFor(60), isFalse);
      expect(ClientQueue.placesLeft(58), 2);
    });

    test('a coach over the cap reads zero places, never a negative number', () {
      expect(ClientQueue.placesLeft(64), 0);
    });

    test('the listener stays bounded, so W01 stays one query forever', () async {
      final repo = InMemoryCoachClientRepository(
        clients: <CoachClient>[
          for (var i = 0; i < kClientCap; i++)
            _client('u$i', waiting: Duration(minutes: kClientCap - i)),
        ],
      );
      final clients = await repo.clients();
      expect(clients, hasLength(60));
      expect(repo.queries, 1);
      expect(clients.first.clientUid, 'u0', reason: 'longest waiting first');
    });
  });

  group('rule 11 — it orders work, it does not rank women', () {
    test('there is nothing on a client this feature could rank her by', () {
      final source = coachPlanSources()['domain/clients/coach_client.dart']!;
      for (final banned in <String>{
        ...kForbiddenWeightFields,
        ...kForbiddenResultFields,
        'score',
        'rating',
        'rank',
        'leaderboard',
      }) {
        expect(source.contains(banned), isFalse, reason: banned);
      }
    });

    test('and the repository offers no sort parameter to pass one to', () {
      final source =
          coachPlanSources()['domain/clients/coach_client_repository.dart']!;
      expect(source.contains('orderBy'), isFalse);
      expect(source.contains('sortBy'), isFalse);
      expect(
        source.contains('Future<void> save'),
        isFalse,
        reason: 'G11 owns relationships/**; this feature never writes one',
      );
    });
  });
}
