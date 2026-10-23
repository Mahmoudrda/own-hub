/// What the coach's desk shows, worked out from the lists the app already
/// streams: her subscriptions and her chats. Nothing here reads anything.
library;

import '../../domain/coaching_contract.dart';
import '../../domain/subscription.dart';

/// A client the coach has not written to for this many days needs a follow up.
const int kQuietDays = 7;

/// A client's last line left unanswered this long needs a reply.
const Duration kReplyWait = Duration(hours: 24);

enum DeskFilter { all, unread, followUp, endingSoon }

/// Why a client is on the follow up list, most urgent first.
enum FollowUpReason { sessionToday, waitingReply, endingSoon, quiet }

/// One active client: her subscription joined to her chat.
class DeskClient {
  const DeskClient({
    required this.subscription,
    required this.relationship,
    required this.unread,
    required this.daysLeft,
    required this.reasons,
    required this.quietDays,
    required this.lastActivity,
  });

  final Subscription subscription;
  final Relationship? relationship;

  /// Lines she has not read yet.
  final int unread;
  final int? daysLeft;
  final List<FollowUpReason> reasons;

  /// Whole days since anything was said, or since the coaching began.
  final int quietDays;
  final DateTime? lastActivity;

  String get id => subscription.id;
  String get relId => subscription.relId;
  String get clientUid => subscription.clientUid;
  String get name => subscription.clientName;
  LastMessage? get lastMessage => relationship?.lastMessage;

  bool get needsFollowUp => reasons.isNotEmpty;
  bool get endsSoon => reasons.contains(FollowUpReason.endingSoon);

  /// Lower-cased name and id tail, for the search box.
  String get searchKey => '${name.toLowerCase()} ${tagOf(id)}';

  bool matches(DeskFilter filter) => switch (filter) {
    DeskFilter.all => true,
    DeskFilter.unread => unread > 0,
    DeskFilter.followUp => needsFollowUp,
    DeskFilter.endingSoon => endsSoon,
  };
}

/// "#a1b2": the last four characters of an id, for a client with no name.
String tagOf(String id) =>
    '#${id.length <= 4 ? id : id.substring(id.length - 4)}';

class DeskModel {
  DeskModel._({
    required this.requests,
    required this.clients,
    required this.unreadClients,
    required this.followUps,
  });

  /// New requests, the oldest first.
  final List<Subscription> requests;

  /// Active clients, the latest activity first.
  final List<DeskClient> clients;

  /// Clients with unread lines, the latest first.
  final List<DeskClient> unreadClients;

  /// Clients to follow up, the most urgent first.
  final List<DeskClient> followUps;

  int get endingSoonCount => clients.where((c) => c.endsSoon).length;

  int countOf(DeskFilter filter) => switch (filter) {
    DeskFilter.all => clients.length,
    DeskFilter.unread => unreadClients.length,
    DeskFilter.followUp => followUps.length,
    DeskFilter.endingSoon => endingSoonCount,
  };

  /// [subscriptions] are the coach's open ones; [relationships] are her chats.
  factory DeskModel.build({
    required Iterable<Subscription> subscriptions,
    required Iterable<Relationship> relationships,
    required String? myUid,
    required DateTime now,
  }) {
    final chats = <String, Relationship>{
      for (final r in relationships) r.id: r,
    };
    final requests = <Subscription>[];
    final clients = <DeskClient>[];
    for (final sub in subscriptions) {
      if (sub.status == SubscriptionStatus.requested) {
        requests.add(sub);
      } else if (sub.status == SubscriptionStatus.active) {
        clients.add(_client(sub, chats[sub.relId], myUid, now));
      }
    }
    requests.sort((a, b) => _compareTime(a.createdAt, b.createdAt));
    clients.sort(_byActivity);
    return DeskModel._(
      requests: requests,
      clients: clients,
      unreadClients: <DeskClient>[
        for (final c in clients)
          if (c.unread > 0) c,
      ],
      followUps: <DeskClient>[
        for (final c in clients)
          if (c.needsFollowUp) c,
      ]..sort(_byUrgency),
    );
  }

  /// [query] is matched on the name, case-insensitively.
  List<DeskClient> filtered(DeskFilter filter, String query) {
    final needle = query.trim().toLowerCase();
    return <DeskClient>[
      for (final c in clients)
        if (c.matches(filter) &&
            (needle.isEmpty || c.searchKey.contains(needle)))
          c,
    ];
  }

  static DeskClient _client(
    Subscription sub,
    Relationship? chat,
    String? myUid,
    DateTime now,
  ) {
    final line = chat?.lastMessage;
    final last = line?.at ?? chat?.lastMessageAt;
    final began = sub.startsAt ?? sub.acceptedAt ?? sub.createdAt;
    final since = last ?? began;
    final quiet = since == null ? 0 : now.difference(since).inDays;
    // Whose line was last: hers, the client's, or neither (no line yet, or a
    // system line).
    final byCoach = line != null && line.senderUid == myUid;
    final byClient = line != null && line.senderUid == sub.clientUid;
    final coachSilent = byCoach
        ? last != null && now.difference(last).inDays >= kQuietDays
        : !byClient &&
              (began != null && now.difference(began).inDays >= kQuietDays);
    final unanswered =
        byClient && last != null && now.difference(last) >= kReplyWait;
    final reasons = <FollowUpReason>[
      if (_isToday(sub.nextSessionAt, now)) FollowUpReason.sessionToday,
      if (unanswered) FollowUpReason.waitingReply,
      if (sub.endsSoon(now)) FollowUpReason.endingSoon,
      if (coachSilent) FollowUpReason.quiet,
    ];
    return DeskClient(
      subscription: sub,
      relationship: chat,
      unread: myUid == null ? 0 : (chat?.unreadOf(myUid) ?? 0),
      daysLeft: sub.daysLeft(now),
      reasons: reasons,
      quietDays: quiet < 0 ? 0 : quiet,
      lastActivity: last ?? sub.startsAt ?? sub.acceptedAt,
    );
  }

  static bool _isToday(DateTime? at, DateTime now) {
    if (at == null) return false;
    final a = at.toLocal();
    final n = now.toLocal();
    return a.year == n.year && a.month == n.month && a.day == n.day;
  }

  static int _byActivity(DeskClient a, DeskClient b) {
    final x = a.lastActivity;
    final y = b.lastActivity;
    if (x == null && y == null) return a.id.compareTo(b.id);
    if (x == null) return 1;
    if (y == null) return -1;
    final byTime = y.compareTo(x);
    return byTime != 0 ? byTime : a.id.compareTo(b.id);
  }

  static int _byUrgency(DeskClient a, DeskClient b) {
    final byReason = a.reasons.first.index.compareTo(b.reasons.first.index);
    if (byReason != 0) return byReason;
    if (a.reasons.first == FollowUpReason.endingSoon) {
      final byDays = (a.daysLeft ?? 0).compareTo(b.daysLeft ?? 0);
      if (byDays != 0) return byDays;
    }
    final byQuiet = b.quietDays.compareTo(a.quietDays);
    return byQuiet != 0 ? byQuiet : a.id.compareTo(b.id);
  }

  static int _compareTime(DateTime? a, DateTime? b) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    return a.compareTo(b);
  }
}
