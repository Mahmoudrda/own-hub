import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:own_hub/features/private_coaching/data/chat_repository.dart';
import 'package:own_hub/features/private_coaching/domain/chat_message.dart';
import 'package:own_hub/features/private_coaching/domain/chat_screen.dart';
import 'package:own_hub/features/private_coaching/domain/coaching_failure.dart';
import 'package:own_hub/features/private_coaching/domain/coaching_contract.dart';
import 'package:own_hub/features/private_coaching/domain/subscription.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';

/// A value that replays its latest state to each new listener.
class Feed<T> {
  Feed(this._value);

  T _value;
  final StreamController<T> _changes = StreamController<T>.broadcast(
    sync: true,
  );

  T get value => _value;

  set value(T next) {
    _value = next;
    _changes.add(next);
  }

  Stream<T> watch() => Stream<T>.multi((controller) {
    controller.add(_value);
    final sub = _changes.stream.listen(controller.add);
    controller.onCancel = sub.cancel;
  });
}

/// The thread's repository: only what a thread calls, with a counted line
/// listener. Anything else is a test mistake and throws.
class FakeChatRepository implements ChatThreadRepository {
  FakeChatRepository({this.uid = 'me'});

  @override
  String? uid;

  final List<(String, Map<String, Object?>)> calls =
      <(String, Map<String, Object?>)>[];
  final Map<String, CoachingFailure> failWith = <String, CoachingFailure>{};
  final Map<String, Feed<List<LiveSession>>> sessions =
      <String, Feed<List<LiveSession>>>{};
  final Map<String, List<ChatMessage>> olderPages =
      <String, List<ChatMessage>>{};
  final Feed<DateTime?> otherRead = Feed<DateTime?>(null);

  List<ChatMessage> current = <ChatMessage>[];
  final StreamController<List<ChatMessage>> _bus =
      StreamController<List<ChatMessage>>.broadcast(sync: true);
  int lineListens = 0;
  int lineCancels = 0;

  void _record(String name, [Map<String, Object?> args = const {}]) {
    calls.add((name, args));
    final failure = failWith[name];
    if (failure != null) throw failure;
  }

  int count(String name) => calls.where((c) => c.$1 == name).length;

  void push(List<ChatMessage> lines) {
    current = lines;
    _bus.add(lines);
  }

  @override
  Stream<List<ChatMessage>> watchMessages(String relId) =>
      Stream<List<ChatMessage>>.multi((c) {
        lineListens++;
        c.add(current);
        final sub = _bus.stream.listen(c.add);
        c.onCancel = () {
          lineCancels++;
          return sub.cancel();
        };
      });

  @override
  Future<List<ChatMessage>> olderMessages(String relId, DateTime before) async {
    _record('olderMessages', {'relId': relId});
    return <ChatMessage>[
      for (final m in olderPages[relId] ?? const <ChatMessage>[])
        if (m.createdAt != null && m.createdAt!.isBefore(before)) m,
    ];
  }

  @override
  Stream<DateTime?> watchOtherReadAt(String relId, String otherUid) =>
      otherRead.watch();

  bool rulesAccepted = true;
  String? rulesText;

  @override
  Future<bool> chatRulesAccepted() async => rulesAccepted;

  @override
  Future<void> acceptChatRules({
    required String rulesText,
    required String locale,
  }) async {
    _record('acceptChatRules', {'locale': locale});
    this.rulesText = rulesText;
    rulesAccepted = true;
  }

  @override
  Future<void> markThreadRead(String relId) async =>
      _record('markThreadRead', {'relId': relId});

  @override
  Future<void> sendText(String relId, String text) async {
    _record('sendText', {'relId': relId, 'text': text});
    final screened = ChatScreen.screen(text.trim());
    if (screened != null) throw CoachingFailure.screened(screened);
  }

  @override
  Future<void> sendMedia(
    String relId, {
    required MessageType type,
    required Uint8List bytes,
    required String contentType,
    int? durationMs,
  }) async => _record('sendMedia', {
    'relId': relId,
    'type': type.wire,
    'bytes': bytes.length,
    'contentType': contentType,
    'durationMs': durationMs,
  });

  @override
  Future<String> chatMediaUrl(String path) async =>
      'https://example.test/$path';

  @override
  Stream<List<LiveSession>> watchSessions(String subId) => sessions
      .putIfAbsent(subId, () => Feed<List<LiveSession>>(<LiveSession>[]))
      .watch();

  @override
  Future<SessionStatus> respondLiveSession({
    required String subId,
    required String sessionId,
    required bool confirm,
  }) async {
    _record('respondLiveSession', {'sessionId': sessionId, 'confirm': confirm});
    return confirm ? SessionStatus.confirmed : SessionStatus.declined;
  }

  @override
  Future<void> reportMessage({
    required String relId,
    required ChatMessage message,
    required String reason,
    String note = '',
    required String locale,
  }) async => _record('reportMessage', {
    'relId': relId,
    'messageId': message.id,
    'senderUid': message.senderUid,
    'reason': reason,
    'note': note,
    'locale': locale,
  });

  @override
  Future<void> reportCoachProfile({
    required String coachUid,
    required String reason,
    String note = '',
    required String locale,
  }) async => _record('reportCoachProfile', {
    'coachUid': coachUid,
    'reason': reason,
    'note': note,
    'locale': locale,
  });

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not a thread call');
}

final DateTime kClock = DateTime(2026, 10, 24, 12, 30);

ChatMessage line(
  String id,
  String sender,
  String text, {
  DateTime? at,
  bool pending = false,
  bool hidden = false,
  MessageType type = MessageType.text,
  SystemMessageKind? systemKind,
  String? planName,
  String? sessionId,
  DateTime? startsAt,
  int? minutes,
  String? recipeId,
}) => ChatMessage(
  id: id,
  senderUid: sender,
  type: type,
  text: text,
  createdAt: pending ? null : (at ?? kClock),
  pending: pending,
  hidden: hidden,
  systemKind: systemKind,
  planName: planName,
  sessionId: sessionId,
  startsAt: startsAt,
  minutes: minutes,
  recipeId: recipeId,
);

Widget app(
  Widget home, {
  Locale locale = const Locale('en'),
  double scale = 1,
}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppL10n.localizationsDelegates,
  supportedLocales: AppL10n.supportedLocales,
  theme: buildTheme(locale),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: home,
);

AppL10n l10nFor(String code) => lookupAppL10n(Locale(code));

Relationship rel({
  String id = 'c1__me',
  String coach = 'c1',
  String client = 'me',
  bool open = true,
  RelationshipStatus status = RelationshipStatus.active,
  LastMessage? last,
  Map<String, int> unread = const <String, int>{},
  DateTime? at,
}) => Relationship(
  id: id,
  coachUid: coach,
  clientUid: client,
  status: status,
  chatOpen: open,
  activeSubId: 'sub1',
  lastMessageAt: at ?? last?.at,
  lastMessage: last,
  unreadFor: unread,
);
