# WO-02c: Chat app data layer: message types, contract mirror, upload and send, controller
Depends on: WO-02a, WO-02b
Size: M
Reads first: `app/lib/features/private_coaching/domain/chat_message.dart` (all), `app/lib/features/private_coaching/domain/coaching_contract.dart` lines 1-100 and 295-320 and 455-465, `app/lib/features/private_coaching/data/chat_repository.dart`, `app/lib/features/private_coaching/data/firestore_coaching_repository.dart` lines 383-400 and 960-1000, `app/lib/features/private_coaching/presentation/chat/chat_thread_controller.dart` lines 262-296, `app/test/contracts/coaching_contract_test.dart` lines 85-110

## Why
The app must know the new message types, upload the file to `chat-media/{relId}/{uid}/`, then write the message line, and show a failure honestly.

## Final result
No screen. `MessageType` has `image`, `video`, `audio`; `ChatThreadRepository` has `sendMedia` and `chatMediaUrl`; the controller has `sendMedia`.

## Files to edit or create
| path | create or edit | what changes |
|---|---|---|
| `app/lib/features/private_coaching/domain/coaching_contract.dart` | edit | 9 limits, enum values |
| `app/lib/features/private_coaching/domain/chat_message.dart` | edit | types and fields |
| `app/lib/features/private_coaching/data/chat_repository.dart` | edit | two methods on `ChatThreadRepository` only (not on `CoachingRepository`, which other fakes implement) |
| `app/lib/features/private_coaching/data/firestore_coaching_repository.dart` | edit | implement them |
| `app/lib/features/private_coaching/presentation/chat/chat_thread_controller.dart` | edit | `sendMedia` |
| `app/test/features/private_coaching/chat/chat_support.dart` | edit | `FakeChatRepository` methods |
| `app/test/features/private_coaching/support/fake_coaching_repository.dart` | edit | `FakeCoachingRepository` methods |
| `app/test/features/private_coaching/chat/chat_controller_test.dart` | edit | new tests |

## Steps
1. File `coaching_contract.dart`, class `CoachingLimits`, after `static const int pushThrottleMinutes = 3;` add:
```dart
  static const int chatImageMaxBytes = 3000000;
  static const int chatImageLongSidePx = 1600;
  static const int chatVideoMaxBytes = 25000000;
  static const int chatVideoMaxSeconds = 30;
  static const int chatAudioMaxBytes = 2000000;
  static const int chatAudioMaxSeconds = 120;
  static const int chatMessagesPerMinute = 20;
  static const int chatMediaPerHour = 30;
  static const int reportsPerDay = 10;
```
Add the same nine entries to the `all` map in that class (copy the style of the entry for `pushThrottleMinutes`, e.g. `'chatImageMaxBytes': chatImageMaxBytes,`). In `CoachingEnums` (line ~305) change `messageTypeClient` to `<String>['text', 'recipe', 'image', 'video', 'audio']`.
2. File `chat_message.dart`. Replace the enum with:
```dart
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
```
In `ChatMessage` add constructor params `this.mediaPath, this.durationMs, this.bytes,` and fields `final String? mediaPath; final int? durationMs; final int? bytes;`; in `fromMap` add `mediaPath: readStringOrNull(map['mediaPath']), durationMs: readIntOrNull(map['durationMs']), bytes: readIntOrNull(map['bytes']),`. Add after `recipeFields`:
```dart
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
```
3. File `chat_repository.dart`, inside `ChatThreadRepository` add (add `import 'dart:typed_data';` and `import '../domain/chat_message.dart';` already present):
```dart
  /// Uploads [bytes] to `chat-media/{relId}/{uid}/` and writes the line.
  /// [contentType] is `image/jpeg`, `video/mp4` or `audio/mp4`. Throws
  /// [CoachingFailure] (`imageInvalid` for a file over the limit).
  Future<void> sendMedia(
    String relId, {
    required MessageType type,
    required Uint8List bytes,
    required String contentType,
    int? durationMs,
  });

  /// A download address for a media line's file (either party of the thread).
  Future<String> chatMediaUrl(String path);
```
4. File `firestore_coaching_repository.dart`, after `sendRecipe` add:
```dart
  static const Map<String, String> _chatExt = <String, String>{
    'image/jpeg': 'jpg',
    'video/mp4': 'mp4',
    'audio/mp4': 'm4a',
  };

  @override
  Future<void> sendMedia(
    String relId, {
    required MessageType type,
    required Uint8List bytes,
    required String contentType,
    int? durationMs,
  }) async {
    final me = _requireUid();
    final ext = _chatExt[contentType];
    final limit = switch (type) {
      MessageType.image => CoachingLimits.chatImageMaxBytes,
      MessageType.video => CoachingLimits.chatVideoMaxBytes,
      MessageType.audio => CoachingLimits.chatAudioMaxBytes,
      _ => 0,
    };
    final clean = contentType == 'image/jpeg' ? stripJpegMetadata(bytes) : bytes;
    if (ext == null || clean.isEmpty || clean.length > limit) {
      throw const CoachingFailure(CoachingRefusal.imageInvalid);
    }
    final path = 'chat-media/$relId/$me/${_randomToken()}.$ext';
    try {
      await _storage
          .ref(path)
          .putData(clean, SettableMetadata(contentType: contentType));
    } on FirebaseException catch (error) {
      throw CoachingFailure.fromStore(error.code);
    }
    await _addLine(
      relId,
      ChatMessage.mediaFields(me, type, path, clean.length, durationMs: durationMs),
    );
  }

  @override
  Future<String> chatMediaUrl(String path) async {
    try {
      return await _storage.ref(path).getDownloadURL();
    } on FirebaseException catch (error) {
      throw CoachingFailure.fromStore(error.code);
    }
  }
```
(`stripJpegMetadata`, `_randomToken`, `_storage` already exist in this file; `Uint8List` is already imported because `uploadCoachDoc` uses it.)
5. Both fakes: add to `FakeChatRepository` (`chat_support.dart`, next to `sendText` about line 118) and `FakeCoachingRepository` (`fake_coaching_repository.dart`, next to `sendRecipe` about line 387):
```dart
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
  Future<String> chatMediaUrl(String path) async => 'https://example.test/$path';
```
(add `import 'dart:typed_data';` and the `MessageType` import if missing; both files already import `chat_message.dart` UNVERIFIED: `grep -n "chat_message" <file>`).
6. File `chat_thread_controller.dart`, after `takeSendFailure` area add:
```dart
  /// Sends a photo, a clip or a voice note. True when the line was written.
  Future<bool> sendMedia({
    required MessageType type,
    required Uint8List bytes,
    required String contentType,
    int? durationMs,
  }) async {
    if (_disposed || bytes.isEmpty) return false;
    try {
      await repository.sendMedia(
        relId,
        type: type,
        bytes: bytes,
        contentType: contentType,
        durationMs: durationMs,
      );
      return true;
    } on CoachingFailure {
      return false;
    }
  }
```
and `import 'dart:typed_data';` at the top.
7. File `app/test/contracts/coaching_contract_test.dart`: no code change expected (it reads the JSON and `CoachingLimits.all`). Run it; if it lists a missing key, add that key to `all`.
8. Add the controller tests below to `chat_controller_test.dart`.

## Strings to add
None.

## Tests to add or change
| file | test name | exact arrange, act and assert |
|---|---|---|
| `chat_controller_test.dart` | `sendMedia records an upload and returns true` | `FakeChatRepository` (see the file's existing setup); `await controller.sendMedia(type: MessageType.image, bytes: Uint8List.fromList([1,2,3]), contentType: 'image/jpeg')`; assert returns true and `repo.calls.last` is `sendMedia` with `bytes: 3` (UNVERIFIED call-log getter name: `grep -n "_record" chat_support.dart`) |
| same | `sendMedia returns false when the repository throws a CoachingFailure` | make the fake throw `CoachingFailure(CoachingRefusal.imageInvalid)` (add a `Object? mediaFailure` field to the fake) ; assert false |
| same | `sendMedia of zero bytes sends nothing` | assert false and no `sendMedia` call |
| `chat_message` parse test (add to `chat_logic_test.dart`) | `a media line parses` | `ChatMessage.fromMap('m', {'senderUid':'u','type':'audio','mediaPath':'chat-media/a__b/u/x.m4a','durationMs':4000,'bytes':900})` has `type == MessageType.audio`, `durationMs == 4000`; unknown type `'gif'` still returns null |

## Verify
- `cd app && flutter test test/contracts/coaching_contract_test.dart test/features/private_coaching/chat/` : `All tests passed!`
- `cd app && flutter analyze lib/features/private_coaching test/features/private_coaching` : `No issues found!`

## Do not
- Do not add methods to `CoachingRepository` (other fakes implement it).
- Do not add a caption or text to a media line. Do not skip `stripJpegMetadata`.

## Done checklist
- [ ] contract mirror and parity test green
- [ ] types and fields
- [ ] repository, both fakes, controller
- [ ] tests pass

## If stuck
Anchor not found or a test fails twice: stop, write the question to `handover/QUESTIONS.md` with file:line and what you saw, and move to the next work order that does not depend on this one.
