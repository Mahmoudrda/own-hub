/// One line in a coach and client chat.
library;

import 'coaching_contract.dart';
import 'parse.dart';

/// Text and recipe are written by the app; the rest only by the server.
enum MessageType with WireEnum {
  text('text'),
  recipe('recipe'),
  image('image'),
  video('video'),
  audio('audio'),
  workoutPlan('workoutPlan'),
  mealPlan('mealPlan'),
  session('session'),
  system('system');

  const MessageType(this.wire);
  @override
  final String wire;

  bool get writtenByApp =>
      this == text || this == recipe || isMedia;

  bool get isMedia => this == image || this == video || this == audio;

  static MessageType? fromWire(Object? value) => enumFromWire(values, value);
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderUid,
    required this.type,
    this.text = '',
    this.recipeId,
    this.mediaPath,
    this.durationMs,
    this.bytes,
    this.planId,
    this.planKind,
    this.planName,
    this.sessionId,
    this.startsAt,
    this.minutes,
    this.systemKind,
    this.weekKey,
    this.hidden = false,
    this.createdAt,
    this.pending = false,
  });

  final String id;
  final String senderUid;
  final MessageType type;
  final String text;
  final String? recipeId;
  final String? mediaPath;
  final int? durationMs;
  final int? bytes;
  final String? planId;
  final PlanKind? planKind;
  final String? planName;
  final String? sessionId;
  final DateTime? startsAt;
  final int? minutes;
  final SystemMessageKind? systemKind;
  final String? weekKey;

  /// Hidden by the server after its screen or a staff decision.
  final bool hidden;

  /// Null while the server has not stamped it yet (her own new message).
  final DateTime? createdAt;

  /// Written on this phone and not yet confirmed by the server.
  final bool pending;

  bool isMine(String uid) => senderUid == uid;

  /// What the thread shows for the line: text of a hidden one is dropped.
  bool get showsText => !hidden && type == MessageType.text;

  /// Null for a type this build does not know, so a newer server never breaks
  /// the thread: the line is skipped.
  static ChatMessage? fromMap(String id, Object? raw, {bool pending = false}) {
    final map = asMap(raw);
    if (map == null || id.isEmpty) return null;
    final type = MessageType.fromWire(map['type']);
    if (type == null) return null;
    final system = SystemMessageKind.fromWire(map['systemKind']);
    return ChatMessage(
      id: id,
      senderUid: readString(map['senderUid']),
      type: type,
      text: readString(map['text']),
      recipeId: readStringOrNull(map['recipeId']),
      mediaPath: readStringOrNull(map['mediaPath']),
      durationMs: readIntOrNull(map['durationMs']),
      bytes: readIntOrNull(map['bytes']),
      planId: readStringOrNull(map['planId']),
      planKind: PlanKind.fromWire(map['planKind']),
      planName: readStringOrNull(map['planName']),
      sessionId: readStringOrNull(map['sessionId']),
      startsAt: readTime(map['startsAt']),
      minutes: readIntOrNull(map['minutes']),
      systemKind: system,
      weekKey: readStringOrNull(map['weekKey']),
      hidden: readBool(map['hidden']) || system == SystemMessageKind.hidden,
      createdAt: readTime(map['createdAt']),
      pending: pending,
    );
  }

  /// The fields she writes for a text line, besides `createdAt`, which the
  /// repository sets from the server clock.
  static Json textFields(String senderUid, String text) => <String, Object?>{
    'senderUid': senderUid,
    'type': MessageType.text.wire,
    'text': text,
  };

  static Json recipeFields(String senderUid, String recipeId) =>
      <String, Object?>{
        'senderUid': senderUid,
        'type': MessageType.recipe.wire,
        'recipeId': recipeId,
      };

  static Json mediaFields(
    String senderUid,
    MessageType type,
    String mediaPath,
    int bytes, {
    int? durationMs,
  }) => <String, Object?>{
    'senderUid': senderUid,
    'type': type.wire,
    'mediaPath': mediaPath,
    'bytes': bytes,
    'durationMs': ?durationMs,
  };

  /// Why [text] cannot be sent, else null. Empty and over-long texts count.
  static MessageProblem? problemWith(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return MessageProblem.empty;
    if (trimmed.length > CoachingLimits.messageMaxChars) {
      return MessageProblem.tooLong;
    }
    return null;
  }
}

enum MessageProblem { empty, tooLong }
