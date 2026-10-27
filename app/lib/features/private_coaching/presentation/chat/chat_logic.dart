/// The rules behind the chat screens, with no widgets: which tick a line gets,
/// how lines group under day separators, what the list previews and how times
/// read. Western digits in both languages.
library;

import '../../../../l10n/app_l10n.dart';
import '../../../../domain/format/date_label.dart';
import '../../domain/chat_message.dart';
import '../coaching_when.dart' show coachClockLabel, egyptianMonday;
import '../../domain/coaching_contract.dart';
import '../../domain/subscription.dart';

/// Who she is talking to.
class ChatPerson {
  const ChatPerson({
    required this.uid,
    required this.name,
    this.photoUrl,
    this.subtitle,
  });

  final String uid;
  final String name;
  final String? photoUrl;

  /// The line under the name in the thread ("Your coach", the package and the
  /// days left). Null leaves the name alone.
  final String? subtitle;
}

/// Clock while it waits for the server, one tick once stored, two once the
/// other party opened the chat after it.
enum ChatTick { pending, sent, read }

ChatTick tickOf(ChatMessage message, DateTime? otherReadAt) {
  final at = message.createdAt;
  if (message.pending || at == null) return ChatTick.pending;
  if (otherReadAt != null && otherReadAt.isAfter(at)) return ChatTick.read;
  return ChatTick.sent;
}

// ------------------------------------------------------------------- thread

/// One chat row for the list, taken from a relationship alone.
class ChatThread {
  const ChatThread({
    required this.relId,
    required this.otherUid,
    required this.open,
    required this.unread,
    this.last,
    this.at,
    this.subId,
  });

  final String relId;
  final String otherUid;

  /// She can write in it: the coaching is active and the chat is open.
  final bool open;
  final int unread;
  final LastMessage? last;
  final DateTime? at;
  final String? subId;

  factory ChatThread.of(Relationship r, String myUid) => ChatThread(
    relId: r.id,
    otherUid: r.otherParty(myUid),
    open: r.status == RelationshipStatus.active && r.chatOpen,
    unread: r.unreadOf(myUid),
    last: r.lastMessage,
    at: r.lastMessage?.at ?? r.lastMessageAt,
    subId: r.activeSubId,
  );

  /// Newest first; chats with no line yet go last.
  static int newestFirst(ChatThread a, ChatThread b) {
    final x = a.at;
    final y = b.at;
    if (x == null && y == null) return a.relId.compareTo(b.relId);
    if (x == null) return 1;
    if (y == null) return -1;
    final byTime = y.compareTo(x);
    return byTime != 0 ? byTime : a.relId.compareTo(b.relId);
  }
}

/// What the list shows after the name: the start of the last line, a word for
/// anything that is not text, and "You: " in front of her own.
String previewOf(AppL10n l10n, LastMessage last, String myUid) {
  final text = last.text.replaceAll(RegExp(r'\s+'), ' ').trim();
  final body = switch (last.type) {
    MessageType.text => text.isEmpty ? l10n.messageHidden : text,
    MessageType.recipe => l10n.recipe,
    MessageType.image => l10n.photo,
    MessageType.video => l10n.video,
    MessageType.audio => l10n.voiceNote,
    MessageType.workoutPlan => l10n.workoutPlan,
    MessageType.mealPlan => l10n.mealPlan,
    MessageType.session => l10n.liveSession,
    MessageType.system => text.isEmpty ? l10n.newActivityInTheChat : text,
  };
  final mine = last.senderUid == myUid && last.type != MessageType.system;
  return mine ? l10n.youText(body) : body;
}

// -------------------------------------------------------------------- times

String clockOf(AppL10n l10n, DateTime at) => coachClockLabel(l10n, at);

DateTime _day(DateTime t) {
  final l = t.toLocal();
  return DateTime(l.year, l.month, l.day);
}

String weekdayName(AppL10n l10n, int weekday) => switch (weekday) {
  DateTime.monday =>
    l10n.localeName.startsWith('ar') ? egyptianMonday : l10n.monday,
  DateTime.tuesday => l10n.tuesday,
  DateTime.wednesday => l10n.wednesday,
  DateTime.thursday => l10n.thursday,
  DateTime.friday => l10n.friday,
  DateTime.saturday => l10n.saturday,
  _ => l10n.sunday,
};

/// Today, Yesterday, a weekday inside the last week, else the date.
String dayLabel(AppL10n l10n, DateTime at, DateTime now) {
  final day = _day(at);
  final today = _day(now);
  final gap = DateTime.utc(
    today.year,
    today.month,
    today.day,
  ).difference(DateTime.utc(day.year, day.month, day.day)).inDays;
  if (gap == 0) return l10n.today;
  if (gap == 1) return l10n.yesterday;
  if (gap > 1 && gap < 7) return weekdayName(l10n, day.weekday);
  return dayMonthYearLabel(l10n, day);
}

/// The time on a chat row: hh:mm today, otherwise the day.
String listTimeLabel(AppL10n l10n, DateTime at, DateTime now) =>
    _day(at) == _day(now) ? clockOf(l10n, at) : dayLabel(l10n, at, now);

// -------------------------------------------------------------------- lines

/// Newest first: the lines she has now, then the older pages she loaded. A
/// line in both is kept once, from the live list. Lines the server has not
/// stamped yet (her own, waiting) lead.
List<ChatMessage> mergeLines(List<ChatMessage> live, List<ChatMessage> older) {
  final byId = <String, ChatMessage>{};
  for (final m in older) {
    byId[m.id] = m;
  }
  for (final m in live) {
    byId[m.id] = m;
  }
  final waiting = <ChatMessage>[
    for (final m in live)
      if (m.createdAt == null) m,
  ];
  final stamped =
      <ChatMessage>[
        for (final m in byId.values)
          if (m.createdAt != null) m,
      ]..sort((a, b) {
        final byTime = b.createdAt!.compareTo(a.createdAt!);
        return byTime != 0 ? byTime : b.id.compareTo(a.id);
      });
  final ids = byId.keys.toSet();
  return <ChatMessage>[
    for (final m in <ChatMessage>[...waiting, ...stamped])
      // The server adds its own "hidden" line beside a hidden message; the
      // message already says so, so one notice is enough.
      if (!(m.type == MessageType.system &&
          m.systemKind == SystemMessageKind.hidden &&
          m.id.startsWith('hidden_') &&
          ids.contains(m.id.substring(7))))
        m,
  ];
}

sealed class ChatItem {
  const ChatItem();
}

class DayItem extends ChatItem {
  const DayItem(this.at);
  final DateTime at;
}

class LineItem extends ChatItem {
  const LineItem(this.message, {required this.tail, required this.mine});
  final ChatMessage message;

  /// First line of a run from the same sender: it gets the bubble's tail.
  final bool tail;
  final bool mine;
}

/// Newest first, for a reversed list: a day separator sits after (above) the
/// oldest line of its day.
List<ChatItem> buildItems(
  List<ChatMessage> newestFirst, {
  required String myUid,
  required DateTime now,
}) {
  DateTime when(ChatMessage m) => m.createdAt ?? now;
  bool bubble(ChatMessage m) => m.type != MessageType.system && !m.hidden;
  final out = <ChatItem>[];
  for (var i = 0; i < newestFirst.length; i++) {
    final m = newestFirst[i];
    final older = i + 1 < newestFirst.length ? newestFirst[i + 1] : null;
    final sameDay = older != null && _day(when(older)) == _day(when(m));
    final tail =
        bubble(m) &&
        (older == null ||
            !sameDay ||
            !bubble(older) ||
            older.senderUid != m.senderUid);
    out.add(LineItem(m, tail: tail, mine: m.isMine(myUid)));
    if (!sameDay) out.add(DayItem(when(m)));
  }
  return out;
}

// ------------------------------------------------------------ header and card

/// "Your coach" for a client; the package and days left for a coach reading a
/// client's chat. [sub] is the active subscription between them, if any.
String threadSubtitle(
  AppL10n l10n, {
  required bool otherIsCoach,
  Subscription? sub,
  required DateTime now,
}) {
  if (otherIsCoach) return l10n.yourCoach;
  if (sub == null) return l10n.yourClient;
  final title = sub.package.title;
  final days = sub.daysLeft(now);
  if (title.isEmpty || days == null) return l10n.yourClient;
  return days <= 0
      ? l10n.packageEndsToday(title)
      : l10n.packageDaysDaysLeft(title, '$days');
}

String systemLine(AppL10n l10n, SystemMessageKind? kind) => switch (kind) {
  SystemMessageKind.started => l10n.coachingStarted,
  SystemMessageKind.ended => l10n.coachingEnded,
  SystemMessageKind.endsSoon => l10n.coachingEndsSoon,
  SystemMessageKind.planUpdated => l10n.aPlanWasUpdated,
  SystemMessageKind.sessionConfirmed => l10n.liveSessionConfirmed,
  SystemMessageKind.sessionDone => l10n.liveSessionFinished,
  SystemMessageKind.checkIn => l10n.weeklyCheckInSent,
  SystemMessageKind.hidden || null => l10n.thisMessageWasHiddenAndWasNot,
};
