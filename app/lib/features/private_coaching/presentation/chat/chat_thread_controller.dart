/// One open thread: the live window of lines, older pages on demand, her
/// sending, the read markers and the report and block calls.
///
/// One live listener on the lines runs only between [start] and [dispose];
/// the other party's read marker is a second, one-document listener, and the
/// live-session documents are listened to only once a session card exists.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../account/domain/safety.dart';
import '../../data/chat_repository.dart';
import '../../domain/chat_message.dart';
import '../../domain/chat_screen.dart';
import '../../domain/coaching_contract.dart';
import '../../domain/coaching_failure.dart';
import '../../domain/subscription.dart';
import 'chat_logic.dart';

/// What happened to a line she tried to send.
sealed class SendOutcome {
  const SendOutcome();
}

class Sent extends SendOutcome {
  const Sent();
}

/// Nothing to send (blank).
class NothingToSend extends SendOutcome {
  const NothingToSend();
}

/// The chat filter refused it; the text stays in the field.
class Refused extends SendOutcome {
  const Refused(this.reason);
  final ChatScreenReason reason;
}

class ChatThreadController extends ChangeNotifier {
  ChatThreadController({
    required this.repository,
    required this.relId,
    required this.myUid,
    required this.otherUid,
    this.subId,
    this.open = true,
    this.otherIsCoach = false,
    DateTime Function()? now,
    this.markDelay = const Duration(seconds: 2),
    this.unreadAtOpen,
  }) : _now = now ?? DateTime.now;

  final ChatThreadRepository repository;
  final String relId;
  final String myUid;
  final String otherUid;

  /// The active subscription, needed to answer a live session.
  final String? subId;

  /// She can write: the coaching is active and the chat open.
  final bool open;
  final bool otherIsCoach;
  final DateTime Function() _now;

  /// How many lines she had not read when she opened the thread, from the
  /// relationship document. At zero there is nothing to mark on opening.
  /// Null when not known: the thread is marked.
  final int? unreadAtOpen;

  /// The least gap between two "mark read" calls while lines keep arriving.
  final Duration markDelay;

  List<ChatMessage> _live = const <ChatMessage>[];
  final List<ChatMessage> _older = <ChatMessage>[];
  Map<String, LiveSession> _sessions = const <String, LiveSession>{};
  DateTime? _otherReadAt;
  bool _loaded = false;
  bool _failed = false;
  bool _loadingOlder = false;
  bool _reachedStart = false;
  bool _disposed = false;
  bool _foreground = true;
  bool _scrolledUp = false;
  int _unseen = 0;
  Timer? _markTimer;
  bool _markDue = false;
  final Set<String> _seen = <String>{};
  StreamSubscription<List<ChatMessage>>? _lines;
  StreamSubscription<DateTime?>? _reads;
  StreamSubscription<List<LiveSession>>? _sessionFeed;

  bool get loaded => _loaded;
  bool get failed => _failed;
  bool get loadingOlder => _loadingOlder;
  bool get reachedStart => _reachedStart;
  DateTime? get otherReadAt => _otherReadAt;

  /// Lines from the other party that arrived while she was reading above.
  int get unseen => _unseen;
  Map<String, LiveSession> get sessions => _sessions;

  /// Newest first.
  List<ChatMessage> get lines => mergeLines(_live, _older);

  void start() {
    if (_lines != null || _disposed) return;
    _listenLines();
    _reads = repository.watchOtherReadAt(relId, otherUid).listen((at) {
      _otherReadAt = at;
      _notify();
    }, onError: (Object _) {});
    if (unreadAtOpen != 0) unawaited(_markNow());
  }

  void _listenLines() {
    _lines = repository
        .watchMessages(relId)
        .listen(_onLines, onError: _onLinesError);
  }

  void _onLines(List<ChatMessage> next) {
    final firstBatch = !_loaded;
    final incoming = <ChatMessage>[
      for (final m in next)
        if (!_seen.contains(m.id) && !m.isMine(myUid)) m,
    ];
    for (final m in next) {
      _seen.add(m.id);
    }
    _live = next;
    _loaded = true;
    _failed = false;
    if (next.length < CoachingLimits.messagePageSize && _older.isEmpty) {
      _reachedStart = true;
    }
    // The unread count is raised after the line is written, so a line from
    // the other party in the first batch can still be unread at zero.
    if (firstBatch &&
        unreadAtOpen == 0 &&
        next.isNotEmpty &&
        !next.first.isMine(myUid)) {
      unawaited(_markNow());
    }
    if (!firstBatch && incoming.isNotEmpty) {
      if (_scrolledUp) _unseen += incoming.length;
      _scheduleMark();
    }
    _watchSessionsIfNeeded();
    _notify();
  }

  void _onLinesError(Object _) {
    _failed = true;
    _notify();
  }

  /// Reconnects after a load failure.
  void retry() {
    if (_disposed) return;
    unawaited(_lines?.cancel());
    _failed = false;
    _listenLines();
    _notify();
  }

  // ------------------------------------------------------------- read marks

  /// Off while the app is in the background: lines that arrive then are not
  /// read yet. Coming back marks the thread.
  set foreground(bool value) {
    if (_foreground == value) return;
    _foreground = value;
    if (value && _markDue) {
      _markDue = false;
      unawaited(_markNow());
    }
  }

  Future<void> _markNow() async {
    if (_disposed) return;
    if (!_foreground) {
      _markDue = true;
      return;
    }
    try {
      await repository.markThreadRead(relId);
    } on CoachingFailure {
      // The next arrival or the next open tries again.
    }
  }

  /// At most one call per [markDelay] while lines keep arriving.
  void _scheduleMark() {
    if (_markTimer != null) return;
    _markTimer = Timer(markDelay, () {
      _markTimer = null;
      unawaited(_markNow());
    });
  }

  // ----------------------------------------------------------------- older

  /// One page of older lines by a plain read; none after the first line.
  Future<void> loadOlder() async {
    if (_loadingOlder || _reachedStart || _disposed) return;
    DateTime? oldest;
    for (final m in lines.reversed) {
      if (m.createdAt != null) {
        oldest = m.createdAt;
        break;
      }
    }
    if (oldest == null) return;
    _loadingOlder = true;
    _notify();
    try {
      final page = await repository.olderMessages(relId, oldest);
      if (_disposed) return;
      final known = <String>{
        for (final m in _live) m.id,
        for (final m in _older) m.id,
      };
      _older.addAll([
        for (final m in page)
          if (!known.contains(m.id)) m,
      ]);
      if (page.length < CoachingLimits.messagePageSize) _reachedStart = true;
    } on CoachingFailure {
      // She can scroll up again to retry.
    } finally {
      _loadingOlder = false;
      _notify();
    }
  }

  // -------------------------------------------------------------- scrolling

  /// Where the list is: at the newest line or reading above it.
  void scrolledUp(bool value) {
    if (_scrolledUp == value) return;
    _scrolledUp = value;
    if (!value) _unseen = 0;
    _notify();
  }

  // ------------------------------------------------------------------ send

  SendOutcome send(String text) {
    if (ChatMessage.problemWith(text) != null) return const NothingToSend();
    final trimmed = text.trim();
    final reason = ChatScreen.screen(trimmed);
    if (reason != null) return Refused(reason);
    // Offline, Firestore keeps the line and sends it when the phone is back,
    // so this returns at once and the line shows a clock. A refusal that
    // comes back later gives the text back to her.
    unawaited(
      repository.sendText(relId, trimmed).catchError((Object error) {
        if (_disposed) return;
        _failedSend = (
          text: trimmed,
          failure: error is CoachingFailure
              ? error
              : const CoachingFailure(CoachingRefusal.unknown),
        );
        _notify();
      }),
    );
    return const Sent();
  }

  ({String text, CoachingFailure failure})? _failedSend;

  /// A send that failed after the field was cleared; given out once.
  ({String text, CoachingFailure failure})? takeSendFailure() {
    final f = _failedSend;
    _failedSend = null;
    return f;
  }

  bool get hasSendFailure => _failedSend != null;

  // ------------------------------------------------------ sessions on cards

  void _watchSessionsIfNeeded() {
    final id = subId;
    if (_sessionFeed != null || id == null) return;
    if (!_live.any((m) => m.type == MessageType.session)) return;
    _sessionFeed = repository.watchSessions(id).listen((list) {
      _sessions = <String, LiveSession>{for (final s in list) s.id: s};
      _notify();
    }, onError: (Object _) {});
  }

  /// The client confirms a proposed live session.
  Future<bool> confirmSession(String sessionId) =>
      respondSession(sessionId, confirm: true);

  /// The client says she cannot make a proposed live session.
  Future<bool> declineSession(String sessionId) =>
      respondSession(sessionId, confirm: false);

  Future<bool> respondSession(String sessionId, {required bool confirm}) async {
    final id = subId;
    if (id == null) return false;
    try {
      await repository.respondLiveSession(
        subId: id,
        sessionId: sessionId,
        confirm: confirm,
      );
      return true;
    } on CoachingFailure {
      return false;
    }
  }

  // ---------------------------------------------------------- report, block

  /// The newest line from the other party, or null.
  ChatMessage? get lastFromOther {
    for (final m in lines) {
      if (!m.isMine(myUid) && m.senderUid == otherUid) return m;
    }
    return null;
  }

  Future<void> reportMessage(
    ChatMessage message, {
    required String reason,
    String note = '',
    required String locale,
  }) => repository.reportMessage(
    relId: relId,
    message: message,
    reason: reason,
    note: note,
    locale: locale,
  );

  Future<void> reportProfile({
    required String reason,
    String note = '',
    required String locale,
  }) => repository.reportCoachProfile(
    coachUid: otherUid,
    reason: reason,
    note: note,
    locale: locale,
  );

  Future<void> block(BlockService blocks) =>
      blocks.block(otherUid, BlockSource.message);

  DateTime get now => _now();

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _markTimer?.cancel();
    unawaited(_lines?.cancel());
    unawaited(_reads?.cancel());
    unawaited(_sessionFeed?.cancel());
    _lines = null;
    _reads = null;
    _sessionFeed = null;
    super.dispose();
  }
}
