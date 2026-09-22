/// §2.2 — **a coach's message never changes a plan; publishing does.**
///
/// This file is the first of the four enforcement points G11 names, and it is
/// the one that is enforced by *absence*: there is exactly one write path for a
/// message, it takes exactly two arguments, and neither of them can address
/// anything but a message inside one relationship.
///
/// ## What is deliberately missing
///
///  * **No overload.** [MessageRepository.send] is declared once. There is no
///    `sendAndUpdate`, no `send(… , {bool alsoPublish})`, no second positional
///    parameter and no named parameter of any kind. A caller who wanted a
///    message to move a coached schedule would have to add one, which is a
///    visible change in a diff — the same technique `LogCommandBus` uses
///    against a confirmation dialog.
///  * **No import that could reach a schedule.** This library imports
///    `package:meta/meta.dart` and nothing else. That is asserted, not merely
///    true today: `message_repo_has_no_plan_path_test.dart` walks this file and
///    every file it imports and fails if either forbidden token appears in any
///    of them.
///  * **No field a card could be synthesised from.** [MessageDraft] carries a
///    kind, a body, attachments and an optional [ContextRef] that *points at* a
///    record she can open. It carries no version, no effective date and no
///    "changed" flag, so "Sara shortened Thursday" typed into a bubble produces
///    a bubble and nothing else. The card that says a schedule was updated is
///    built somewhere else entirely, from published versions — see
///    `plan_update_card.dart`.
///  * **No transcript.** A voice note is an attachment with a duration. There
///    is no field on this type, or on any type it holds, capable of carrying
///    words extracted from her voice, and `coached_product_rules_test.dart`
///    bans the identifier across this whole feature.
///
/// ## The scope type
///
/// [WriteScope] is sealed with a single variant. A sealed type with one member
/// looks redundant and is not: it is the place a second variant would have to
/// be added, and adding one is the reviewable act. Every write this repository
/// performs is built from `WriteScope.relationshipMessage`, so the set of
/// documents this file can touch is closed by the type system rather than by
/// care.
library;

import 'package:meta/meta.dart';

/// The two parties, and the id both of them can compute.
///
/// `relId` is `{coachUid}__{clientUid}` — coach first, **double** underscore
/// (G11 §11-R1, and G9's `CoachRelationship` already spells it this way). The
/// order is load-bearing: the Storage rules recover party membership by
/// splitting this id, so a single underscore would parse ambiguously the day a
/// provider widens the uid alphabet.
@immutable
class RelationshipRef {
  const RelationshipRef({required this.coachUid, required this.clientUid});

  /// Parses `{coachUid}__{clientUid}`, or throws.
  ///
  /// Throws rather than returning null because every caller of this is building
  /// a write path, and a null-tolerant parse there is how a write lands under a
  /// half-built id.
  factory RelationshipRef.parse(String relId) {
    final parts = relId.split('__');
    if (parts.length != 2 || parts[0].isEmpty || parts[1].isEmpty) {
      throw ArgumentError.value(
        relId,
        'relId',
        'A relationship id is "{coachUid}__{clientUid}" — coach first, two '
            'underscores.',
      );
    }
    return RelationshipRef(coachUid: parts[0], clientUid: parts[1]);
  }

  final String coachUid;
  final String clientUid;

  /// The deterministic document id. Both parties compute it; neither queries
  /// for it, so no screen in this feature needs an index to find the thread.
  String get relId => '${coachUid}__$clientUid';

  bool includes(String uid) => uid == coachUid || uid == clientUid;

  @override
  bool operator ==(Object other) =>
      other is RelationshipRef &&
      other.coachUid == coachUid &&
      other.clientUid == clientUid;

  @override
  int get hashCode => Object.hash(coachUid, clientUid);

  @override
  String toString() => 'RelationshipRef($relId)';
}

/// What a message may be.
///
/// `attachment` is a record reference — the bubble that opens her session —
/// rather than a file. Files are `image`, `clip` and `voice`.
enum MessageKind { text, voice, image, clip, attachment }

/// The kinds of record a bubble may point at.
///
/// Every one of these is something she already owns: her own assignment, her
/// own session, her own meal day, her own review. There is no variant for a
/// version, and that is the point — a bubble cannot reference a schedule
/// revision, so tapping one can never be the thing that applies it.
enum ContextKind { assignment, session, meal, review }

/// "Opens the record", G14's phrase.
@immutable
class ContextRef {
  const ContextRef({required this.kind, required this.id});

  final ContextKind kind;

  /// The record's own deterministic id — a date key, a session id, an ISO week.
  final String id;

  @override
  bool operator ==(Object other) =>
      other is ContextRef && other.kind == kind && other.id == id;

  @override
  int get hashCode => Object.hash(kind, id);

  @override
  String toString() => 'ContextRef(${kind.name}:$id)';
}

/// A file travelling with a message.
///
/// [blurApplied] is required and has no default. Rule 6 / C11 is enforced at
/// the upload door, and a default of `true` here would be this file quietly
/// claiming something it cannot know, while a default of `false` would let a
/// caller forget. Requiring it makes the caller state what it did.
@immutable
class MessageAttachment {
  const MessageAttachment({
    required this.storagePath,
    required this.mime,
    required this.bytes,
    required this.blurApplied,
    this.durationMs,
  });

  final String storagePath;
  final String mime;
  final int bytes;

  /// Whether on-device blur ran before the bytes left the handset.
  final bool blurApplied;

  /// Present for a voice note or a clip. A **duration**, never words: there is
  /// no transcript field here and no method that could produce one.
  final int? durationMs;

  @override
  String toString() => 'MessageAttachment($mime, $bytes B)';
}

/// Everything a woman or her coach can put in a bubble.
@immutable
class MessageDraft {
  const MessageDraft({
    required this.senderUid,
    required this.kind,
    this.body,
    this.attachments = const <MessageAttachment>[],
    this.contextRef,
  });

  final String senderUid;
  final MessageKind kind;

  /// ≤ 4000 characters, immutable after create.
  final String? body;

  final List<MessageAttachment> attachments;

  /// The record this bubble refers to, if it refers to one.
  final ContextRef? contextRef;

  /// Deliberately absent: a version, an effective date, a "plan changed" flag,
  /// a transcript. See the library comment.
  @override
  String toString() => 'MessageDraft(${kind.name} by $senderUid)';
}

/// Where a message has got to. G11 §3.3, five states plus a failure.
///
/// `delivered` and `read` are derived from the two parties' read cursors, so
/// there is no per-message receipt write on the hottest path in the feature.
enum MessageDeliveryState { queued, sent, delivered, read, failed }

/// A message as it exists after [MessageRepository.send].
@immutable
class CoachMessage {
  const CoachMessage({
    required this.id,
    required this.relId,
    required this.senderUid,
    required this.kind,
    required this.createdAt,
    required this.state,
    this.body,
    this.attachments = const <MessageAttachment>[],
    this.contextRef,
  });

  final String id;
  final String relId;
  final String senderUid;
  final MessageKind kind;
  final DateTime createdAt;
  final MessageDeliveryState state;
  final String? body;
  final List<MessageAttachment> attachments;
  final ContextRef? contextRef;

  CoachMessage withState(MessageDeliveryState next) => CoachMessage(
    id: id,
    relId: relId,
    senderUid: senderUid,
    kind: kind,
    createdAt: createdAt,
    state: next,
    body: body,
    attachments: attachments,
    contextRef: contextRef,
  );

  @override
  String toString() => 'CoachMessage($id ${kind.name} ${state.name})';
}

/// The closed set of documents this file is allowed to address.
///
/// One variant, on purpose. See the library comment.
@immutable
sealed class WriteScope {
  const WriteScope();

  /// One message, inside one relationship.
  const factory WriteScope.relationshipMessage(String relId, String msgId) =
      RelationshipMessageScope;

  /// The document path this scope names.
  String get path;
}

@immutable
final class RelationshipMessageScope extends WriteScope {
  const RelationshipMessageScope(this.relId, this.msgId);

  final String relId;
  final String msgId;

  @override
  String get path => 'relationships/$relId/messages/$msgId';

  @override
  String toString() => 'WriteScope($path)';
}

/// One write, addressed by a [WriteScope] and nothing else.
@immutable
class WriteIntent {
  const WriteIntent({required this.scope, required this.data});

  final WriteScope scope;
  final Map<String, Object?> data;

  @override
  String toString() => 'WriteIntent(${scope.path})';
}

/// The only write path for a message.
///
/// [send] takes a relationship and a draft. **That is the entire surface**: no
/// overload, no flag, no second parameter. Read methods are separate and
/// return records; none of them writes.
abstract class MessageRepository {
  /// Sends [draft] in [ref], returning the id the message was minted with.
  ///
  /// The id is minted once by the caller's device and reused on every retry, so
  /// a failed send retried offline collapses onto the same document instead of
  /// forking the thread (spine C1). That is why [draft] carries no id: the
  /// repository mints it, hands it back, and a retry passes it to [retry].
  Future<String> send(RelationshipRef ref, MessageDraft draft);

  /// Re-sends a message that was rejected, **reusing its id**.
  ///
  /// Separate from [send] rather than a parameter on it, for the same reason
  /// `MealLogService` splits correcting from adding a helping: a boolean there
  /// is how two intents collapse into one path and a retry silently becomes a
  /// second message.
  Future<void> retry(RelationshipRef ref, String msgId);

  /// The thread, newest last. Bounded: `limit(30)` plus a cursor in the real
  /// implementation, and the fake holds only what a test put in it.
  Future<List<CoachMessage>> thread(RelationshipRef ref, {int limit = 30});

  /// Moves this reader's cursor. Both parties write distinct keys, so the two
  /// writes merge rather than overwrite.
  Future<void> markRead(RelationshipRef ref, String readerUid, DateTime at);
}

/// An in-memory implementation, strict where the real one is strict.
///
/// It enforces the things that would otherwise pass here and fail in
/// production: the sender must be a party, the id shape must parse, a body is
/// capped, a retry must reuse its id, and a thread that has been closed refuses
/// writes rather than queueing them.
class InMemoryMessageRepository implements MessageRepository {
  InMemoryMessageRepository({
    this.now,
    this.rejectFirstSend = false,
    this.closed = false,
  });

  /// Injected clock. Tests drive it; nothing here reads the wall clock twice
  /// for one message.
  final DateTime Function()? now;

  /// Makes the first send fail, so the retry path is exercisable.
  final bool rejectFirstSend;

  /// True once the relationship has ended: history stays readable and the
  /// composer is closed. A forced write is refused rather than queued.
  bool closed;

  final Map<String, List<CoachMessage>> _threads =
      <String, List<CoachMessage>>{};
  final Map<String, Map<String, DateTime>> _cursors =
      <String, Map<String, DateTime>>{};

  /// Every intent this repository built, in order. A test asserts against this
  /// to prove that sending a message produced exactly one write and that its
  /// scope named a message.
  final List<WriteIntent> intents = <WriteIntent>[];

  int _counter = 0;
  bool _rejectedOnce = false;

  DateTime _clock() => now?.call() ?? DateTime(2026, 9, 19, 20, 41);

  @override
  Future<String> send(RelationshipRef ref, MessageDraft draft) async {
    _assertWritable(ref, draft.senderUid);

    final id = 'm${++_counter}';
    final failing = rejectFirstSend && !_rejectedOnce;
    if (failing) _rejectedOnce = true;

    final message = CoachMessage(
      id: id,
      relId: ref.relId,
      senderUid: draft.senderUid,
      kind: draft.kind,
      createdAt: _clock(),
      state: failing ? MessageDeliveryState.failed : MessageDeliveryState.sent,
      body: draft.body,
      attachments: draft.attachments,
      contextRef: draft.contextRef,
    );

    _threads.putIfAbsent(ref.relId, () => <CoachMessage>[]).add(message);

    // Exactly one intent, whose scope can name only a message.
    intents.add(
      WriteIntent(
        scope: WriteScope.relationshipMessage(ref.relId, id),
        data: <String, Object?>{
          'senderUid': draft.senderUid,
          'kind': draft.kind.name,
          if (draft.body != null) 'body': draft.body,
          'attachments': draft.attachments.length,
          if (draft.contextRef != null)
            'contextRef': draft.contextRef!.kind.name,
        },
      ),
    );

    return id;
  }

  @override
  Future<void> retry(RelationshipRef ref, String msgId) async {
    final thread = _threads[ref.relId];
    final index = thread?.indexWhere((m) => m.id == msgId) ?? -1;
    if (thread == null || index < 0) {
      throw StateError('No message $msgId in ${ref.relId} to retry.');
    }
    _assertWritable(ref, thread[index].senderUid);

    // The same id, so one message exists afterwards rather than two.
    thread[index] = thread[index].withState(MessageDeliveryState.sent);
    intents.add(
      WriteIntent(
        scope: WriteScope.relationshipMessage(ref.relId, msgId),
        data: const <String, Object?>{'retried': true},
      ),
    );
  }

  @override
  Future<List<CoachMessage>> thread(
    RelationshipRef ref, {
    int limit = 30,
  }) async {
    final all = _threads[ref.relId] ?? const <CoachMessage>[];
    // Newest `limit`, oldest first — the order a thread renders in.
    return all.length <= limit ? List.of(all) : all.sublist(all.length - limit);
  }

  @override
  Future<void> markRead(
    RelationshipRef ref,
    String readerUid,
    DateTime at,
  ) async {
    if (!ref.includes(readerUid)) {
      throw StateError('$readerUid is not a party to ${ref.relId}.');
    }
    // Two parties, two distinct keys: a merge, never an overwrite.
    _cursors.putIfAbsent(ref.relId, () => <String, DateTime>{})[readerUid] = at;
  }

  /// The cursor map, for tests that assert delivery states are derived rather
  /// than written per message.
  Map<String, DateTime> cursors(RelationshipRef ref) =>
      Map.unmodifiable(_cursors[ref.relId] ?? const <String, DateTime>{});

  void _assertWritable(RelationshipRef ref, String senderUid) {
    if (closed) {
      throw StateError(
        'This conversation is read-only. New messages are closed.',
      );
    }
    if (!ref.includes(senderUid)) {
      throw StateError('$senderUid is not a party to ${ref.relId}.');
    }
  }
}
