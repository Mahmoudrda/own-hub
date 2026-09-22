/// W01, W10 and W11 — the queue, and who has waited longest.
///
/// G14 §2: **one listener serves three screens.** W01, W10 and W11 are the same
/// `relationships` query with different client-side sorts and filters, so
/// opening the inbox after the client list costs **0** reads. Stated because
/// the naive build issues three queries and triples the coach-side read budget
/// — `P0-QUEUE-01` measures it.
///
/// ## The chips are filters, not queries
///
/// *Needs reply · Reviews due · Plan needed · Assessment due.* Four queries
/// would mean four composite indexes and four times the reads; one document
/// map filtered client-side over at most [kClientCap] documents means one index
/// and one listener that W10 and W11 reuse for free. It also makes the
/// re-assessment reminder lazy: `assessmentDueAt` is a field the chip reads on
/// every open, not a cron job.
///
/// ## Waiting time is an order, not a score
///
/// Longest-waiting first, on both W01 and W10. Rule 11 — nothing here ranks
/// women; it orders *work*, by how long somebody has been waiting for a reply
/// the coach promised.
library;

import 'package:meta/meta.dart';

/// The most active clients one coach may hold.
///
/// The owner set this at 60. G14 §9.1 costed both 20 and 60 and both pass; the
/// number matters here because it bounds the listener, and a bounded listener
/// is what keeps W01 at one query forever.
const int kClientCap = 60;

/// W01's four chips.
enum QueueFilter { needsReply, reviewsDue, planNeeded, assessmentDue }

/// G11's `relationships/{relId}.queue` projection, as this feature reads it.
///
/// Every field is a *time*, not a flag, so a chip can be computed and a list
/// ordered from the same document. Nothing here is written by this feature.
@immutable
class ClientQueueState {
  const ClientQueueState({
    this.oldestUnansweredAt,
    this.unreadForCoach = 0,
    this.reviewDueAt,
    this.planNeededAt,
    this.assessmentDueAt,
    this.latestAssessmentId,
  });

  /// When the oldest unanswered message arrived. Null when nothing waits.
  final DateTime? oldestUnansweredAt;

  final int unreadForCoach;

  final DateTime? reviewDueAt;
  final DateTime? planNeededAt;

  /// Drives the lazy re-assessment reminder. A field, not a scheduler.
  final DateTime? assessmentDueAt;

  /// W02's pointer, so "her latest assessment" is a direct `get` and never a
  /// query.
  final String? latestAssessmentId;

  bool get hasUnanswered => oldestUnansweredAt != null || unreadForCoach > 0;

  /// How long the oldest message has waited, at [now]. Null when nothing does.
  ///
  /// The clock is passed in rather than read here, so the queue can be tested
  /// at an exact minute and so nothing in this layer depends on the time the
  /// test happens to run.
  Duration? waitingFor(DateTime now) {
    final since = oldestUnansweredAt;
    return since == null ? null : now.difference(since);
  }

  bool matches(QueueFilter filter, DateTime now) => switch (filter) {
    QueueFilter.needsReply => hasUnanswered,
    QueueFilter.reviewsDue => _isDue(reviewDueAt, now),
    QueueFilter.planNeeded => _isDue(planNeededAt, now),
    QueueFilter.assessmentDue => _isDue(assessmentDueAt, now),
  };

  static bool _isDue(DateTime? at, DateTime now) =>
      at != null && !at.isAfter(now);
}

/// One client, as the coach's screens read her.
///
/// Note what is absent: no weight, no measurement, no score. W02 renders her
/// constraints from the assessment and the shared projection; nothing about her
/// body is carried on this type, so nothing can sort a list of women by one.
@immutable
class CoachClient {
  const CoachClient({
    required this.clientUid,
    required this.displayName,
    this.queue = const ClientQueueState(),
    this.startedOn,
    this.coachingEndsOn,
  });

  final String clientUid;

  /// Her name as she gave it. Never rendered into an analytics event.
  final String displayName;

  final ClientQueueState queue;
  final DateTime? startedOn;
  final DateTime? coachingEndsOn;

  @override
  String toString() => 'CoachClient($clientUid)';
}

/// The one list, sorted and filtered for three screens.
class ClientQueue {
  const ClientQueue._();

  /// Longest-waiting first; everyone who is not waiting keeps her relative
  /// order behind them.
  ///
  /// A stable sort, so two clients with nothing waiting do not swap places
  /// every time the listener delivers. A list that reshuffles under her thumb
  /// reads as broken even when the set is identical.
  static List<CoachClient> longestWaitingFirst(Iterable<CoachClient> clients) {
    final indexed = clients.toList(growable: false).asMap().entries.toList();
    indexed.sort((a, b) {
      final left = a.value.queue.oldestUnansweredAt;
      final right = b.value.queue.oldestUnansweredAt;
      if (left == null && right == null) return a.key.compareTo(b.key);
      // Nothing waiting sorts last: the screen is a queue of work, and a client
      // with no question is not work.
      if (left == null) return 1;
      if (right == null) return -1;
      final byAge = left.compareTo(right);
      return byAge != 0 ? byAge : a.key.compareTo(b.key);
    });
    return <CoachClient>[for (final entry in indexed) entry.value];
  }

  /// The same documents, filtered by one chip. **No second query.**
  static List<CoachClient> matching(
    Iterable<CoachClient> clients,
    QueueFilter filter, {
    required DateTime now,
  }) => <CoachClient>[
    for (final client in longestWaitingFirst(clients))
      if (client.queue.matches(filter, now)) client,
  ];

  /// How many chips have anything behind them — W01 shows a count, never a
  /// badge on an empty filter.
  static Map<QueueFilter, int> counts(
    Iterable<CoachClient> clients, {
    required DateTime now,
  }) => <QueueFilter, int>{
    for (final filter in QueueFilter.values)
      filter: clients.where((c) => c.queue.matches(filter, now)).length,
  };

  /// Whether another client would fit inside the cap.
  static bool hasRoomFor(int activeClientCount) =>
      activeClientCount < kClientCap;

  /// Places left. Never negative, so a coach who is over the cap after a
  /// migration reads "0 places", not a negative number.
  static int placesLeft(int activeClientCount) {
    final left = kClientCap - activeClientCount;
    return left < 0 ? 0 : left;
  }
}
