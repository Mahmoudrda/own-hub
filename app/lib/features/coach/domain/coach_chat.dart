/// `K16` — a conversation with a client.
///
/// # §2 rule 2, as a compile-time guarantee
///
/// *A message never changes a plan.* G12 §5 specifies the mechanism precisely:
/// [CoachMessageDraft] has fields `body`, `attachments` and `replyTo` and **no
/// plan fields**, and [CoachChatService] has **no constructor dependency on any
/// plan repository** — so there is no call path from chat to `plans/**`. That is
/// a property of the type graph rather than of a reviewer's attention.
///
/// The second line is the storage layer: G12 §6 makes a message document's key
/// set exact and explicitly forbids `planVersion`, `assignmentId`, `sets`,
/// `publish` and `applyToPlan`. [bannedMessageKeys] holds the same list so the
/// two can be asserted against each other.
///
/// # Sending offline is queued, never failed
///
/// `P0-CCHAT-01`. G12 §4 puts chat on the writable side of the offline line,
/// unlike accepting an enquiry: a message costs no capacity and takes no money,
/// so queuing it is safe in exactly the way queuing an accept is not.
///
/// The message id is a **client-generated id, made once and reused on retry**
/// (spine C1), so a reconnect sends it exactly once. [CoachChatService.draftId]
/// is the only place one is minted, and it is minted before the first attempt
/// rather than at send time — a new id per attempt is precisely the duplicate
/// the rule exists to prevent.
///
/// # The banner is context, not data
///
/// `K16`'s amber line — "Second quiet week. Her rest week is already used." —
/// comes from the client-view projection and says only what the sharing switches
/// permit. When the switch is off there is no banner, because there is nothing
/// in the document to draw one from (see `client_view.dart`).
// `prefer_initializing_formals` asks for `required this._sink`, which Dart
// forbids outright: a named parameter cannot begin with an underscore. The only
// way to satisfy the lint is to make the field public, and it is private
// deliberately — a caller holding the sink could deliver a message straight to
// storage, bypassing the queue that makes `P0-CCHAT-01` true. The same note and
// the same decision appear on `lib/domain/identity/user_roles.dart`.
// ignore_for_file: prefer_initializing_formals
library;

import 'dart:async';

import 'package:meta/meta.dart';

/// Keys a message document may never carry. G12 §6, as data.
const Set<String> bannedMessageKeys = {
  'planVersion',
  'assignmentId',
  'sets',
  'publish',
  'applyToPlan',
};

/// The only keys a message document carries. G12 §6's `hasOnly` list.
const Set<String> messageKeys = {
  'senderUid',
  'coachUid',
  'clientUid',
  'body',
  'attachments',
  'replyTo',
  'createdAt',
  'readAt',
};

/// Where a message has got to.
enum MessageDelivery {
  /// Written locally and waiting for signal. `K16` marks the row quietly.
  /// **Never rendered as failed** (`P0-CCHAT-01`).
  queued,

  /// Acknowledged by the server.
  sent;

  bool get isPending => this == MessageDelivery.queued;
}

/// What she is about to send.
///
/// Three fields. Look at what is not here, and at [bannedMessageKeys] for the
/// list this type is the absence of.
@immutable
class CoachMessageDraft {
  const CoachMessageDraft({
    required this.body,
    this.attachments = const <String>[],
    this.replyTo,
  });

  final String body;

  /// Media refs, never bytes. The uploader holds the picture; this holds a path.
  final List<String> attachments;

  /// The id of the message being answered.
  final String? replyTo;

  /// Whether there is anything to send.
  bool get isSendable => body.trim().isNotEmpty || attachments.isNotEmpty;
}

/// One message in the thread.
@immutable
class CoachMessage {
  const CoachMessage({
    required this.msgId,
    required this.relId,
    required this.senderUid,
    required this.coachUid,
    required this.clientUid,
    required this.body,
    required this.createdAt,
    this.attachments = const <String>[],
    this.replyTo,
    this.readAt,
    this.delivery = MessageDelivery.sent,
  });

  /// The client-generated id. Made once, reused on every retry.
  final String msgId;

  final String relId;
  final String senderUid;

  /// Denormalised onto every message so no security rule needs a `get()`, which
  /// would be a billed read on the chat hot path (G12 §7.3).
  final String coachUid;
  final String clientUid;

  final String body;
  final List<String> attachments;
  final String? replyTo;
  final DateTime createdAt;
  final DateTime? readAt;
  final MessageDelivery delivery;

  /// Whether the coach wrote it — which side of `K16` it is drawn on.
  bool get isFromCoach => senderUid == coachUid;

  CoachMessage copyWith({MessageDelivery? delivery, DateTime? readAt}) =>
      CoachMessage(
        msgId: msgId,
        relId: relId,
        senderUid: senderUid,
        coachUid: coachUid,
        clientUid: clientUid,
        body: body,
        attachments: attachments,
        replyTo: replyTo,
        createdAt: createdAt,
        readAt: readAt ?? this.readAt,
        delivery: delivery ?? this.delivery,
      );

  /// The field names this message would write. Asserted against [messageKeys]
  /// and [bannedMessageKeys].
  Set<String> get wireKeys => <String>{
    'senderUid',
    'coachUid',
    'clientUid',
    'body',
    if (attachments.isNotEmpty) 'attachments',
    if (replyTo != null) 'replyTo',
    'createdAt',
    if (readAt != null) 'readAt',
  };
}

/// Where sent messages go. Implemented by Firestore in production and by a fake
/// in tests, so this service never imports Firebase.
abstract class CoachMessageSink {
  /// Delivers one message. Throws when there is no signal, which is what the
  /// service turns into a queued row rather than a failure.
  Future<void> deliver(CoachMessage message);

  /// The thread, newest last. `limit` is capped by the rules at 50 (G12 §6).
  Future<List<CoachMessage>> thread(String relId, {int limit = 20});
}

/// Sending a message.
///
/// **This class deliberately takes no plan repository, no publisher and no
/// assignment writer.** Rule 2 is enforced by what it cannot reach.
class CoachChatService {
  CoachChatService({required CoachMessageSink sink, required this.coachUid})
    : _sink = sink;

  final CoachMessageSink _sink;
  final String coachUid;

  int _minted = 0;

  /// Every message that has been queued and not yet acknowledged, by id.
  final Map<String, CoachMessage> _queued = <String, CoachMessage>{};

  /// Mints the id for one message, **once**.
  ///
  /// Called by the composer when she starts typing, not when she taps send, so
  /// a retry reuses it. In production this is a UUID; here it is deterministic
  /// per session so a test can name it.
  String draftId() => 'msg-$coachUid-${++_minted}';

  /// How many messages are waiting for signal.
  int get queuedCount => _queued.length;

  bool isQueued(String msgId) => _queued.containsKey(msgId);

  /// Sends, or queues.
  ///
  /// Returns the message either way, with [CoachMessage.delivery] saying which.
  /// There is no failure return and no thrown exception on a network problem:
  /// `P0-CCHAT-01` requires the row to appear "immediately marked queued, never
  /// as failed".
  Future<CoachMessage> send({
    required String relId,
    required String clientUid,
    required CoachMessageDraft draft,
    required String msgId,
    required DateTime at,
  }) async {
    final message = CoachMessage(
      msgId: msgId,
      relId: relId,
      senderUid: coachUid,
      coachUid: coachUid,
      clientUid: clientUid,
      body: draft.body,
      attachments: draft.attachments,
      replyTo: draft.replyTo,
      createdAt: at,
      delivery: MessageDelivery.queued,
    );

    // Queued first, so the row exists before the attempt. If the app died
    // between the attempt and the acknowledgement, the message is still hers.
    _queued[msgId] = message;

    try {
      await _sink.deliver(message);
      _queued.remove(msgId);
      return message.copyWith(delivery: MessageDelivery.sent);
    } on Object {
      return message;
    }
  }

  /// Retries everything waiting, oldest first.
  ///
  /// Each retry reuses the id it was minted with, so a message that reached the
  /// server on a first attempt whose acknowledgement was lost overwrites itself
  /// rather than arriving twice (`P0-CCHAT-01`, spine C1).
  Future<int> flush() async {
    var sent = 0;
    for (final id in _queued.keys.toList()) {
      final message = _queued[id];
      if (message == null) continue;
      try {
        await _sink.deliver(message);
        _queued.remove(id);
        sent++;
      } on Object {
        // Leave the rest queued. A failure partway is not a reason to drop
        // what has not been tried.
        return sent;
      }
    }
    return sent;
  }

  Future<List<CoachMessage>> thread(String relId, {int limit = 20}) =>
      _sink.thread(relId, limit: limit);
}

/// An in-memory sink, strict where the server is strict.
///
/// It refuses any message carrying a banned key — which cannot happen through
/// [CoachMessageDraft], and is checked anyway, because the value of the check is
/// that it fails the day somebody adds a field.
class InMemoryMessageSink implements CoachMessageSink {
  InMemoryMessageSink({this.online = true});

  /// Flip to false for airplane mode.
  bool online;

  final Map<String, List<CoachMessage>> _threads =
      <String, List<CoachMessage>>{};

  /// Every delivery that reached "the server", in order. A test asserts against
  /// this to prove a retried message arrived exactly once.
  final List<String> delivered = <String>[];

  List<CoachMessage> messagesIn(String relId) =>
      List.unmodifiable(_threads[relId] ?? const <CoachMessage>[]);

  void seed(CoachMessage message) =>
      _threads.putIfAbsent(message.relId, () => []).add(message);

  @override
  Future<void> deliver(CoachMessage message) async {
    if (!online) {
      throw StateError('No signal. The caller queues; it does not fail.');
    }
    final offending = message.wireKeys.intersection(bannedMessageKeys);
    if (offending.isNotEmpty) {
      throw StateError(
        'Rule 2: a message may carry no plan field. Offending: $offending',
      );
    }

    delivered.add(message.msgId);
    final thread = _threads.putIfAbsent(message.relId, () => []);
    // Merge by document id, exactly as Firestore does. This is what makes a
    // replayed send collapse into itself instead of duplicating.
    final at = thread.indexWhere((m) => m.msgId == message.msgId);
    final stored = message.copyWith(delivery: MessageDelivery.sent);
    if (at >= 0) {
      thread[at] = stored;
    } else {
      thread.add(stored);
    }
  }

  @override
  Future<List<CoachMessage>> thread(String relId, {int limit = 20}) async {
    final all = _threads[relId] ?? const <CoachMessage>[];
    // limit(20) with a cursor in production; the tail is what K16 draws.
    return all.length <= limit ? List.of(all) : all.sublist(all.length - limit);
  }
}
