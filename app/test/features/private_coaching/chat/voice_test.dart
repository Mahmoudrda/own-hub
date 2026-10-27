import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/features/private_coaching/domain/chat_message.dart';
import 'package:own_hub/features/private_coaching/presentation/chat/chat_logic.dart';
import 'package:own_hub/features/private_coaching/presentation/chat/chat_thread_view.dart';
import 'package:own_hub/features/private_coaching/presentation/chat/voice_recorder.dart';

import 'chat_support.dart';

class FakeVoiceRecorder implements VoiceRecorder {
  FakeVoiceRecorder({this.allowed = true, Uint8List? bytes, this.startGate})
    : bytes = bytes ?? Uint8List.fromList(<int>[1, 2, 3]);

  final bool allowed;

  /// When set, `start()` waits for it: the microphone prompt, or a slow start.
  final Completer<void>? startGate;
  final Uint8List? bytes;
  bool started = false;
  bool stopped = false;
  bool cancelled = false;
  bool disposed = false;

  @override
  Future<bool> start() async {
    await startGate?.future;
    if (!allowed) return false;
    started = true;
    return true;
  }

  @override
  Future<Uint8List?> stop() async {
    stopped = true;
    return bytes;
  }

  @override
  Future<void> cancel() async {
    cancelled = true;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

const ChatPerson _coach = ChatPerson(
  uid: 'c1',
  name: 'Coach Sara',
  subtitle: 'Your coach',
);

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

Future<FakeChatRepository> _thread(
  WidgetTester tester, {
  List<ChatMessage>? lines,
  VoiceRecorder? recorder,
}) async {
  _phone(tester);
  final r = FakeChatRepository();
  r.current = lines ?? r.current;
  final rec = recorder ?? FakeVoiceRecorder();
  await tester.pumpWidget(
    app(
      ChatThreadView(
        repository: r,
        relId: 'c1__me',
        myUid: 'me',
        person: _coach,
        otherIsCoach: false,
        subId: 'sub1',
        recorderBuilder: () => rec,
        now: () => kClock,
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  return r;
}

void main() {
  testWidgets('holding the mic for 2 seconds sends a voice note', (
    tester,
  ) async {
    final rec = FakeVoiceRecorder();
    final repo = await _thread(tester, recorder: rec);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byIcon(Icons.mic)),
    );
    await tester.pump(const Duration(seconds: 2));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(repo.count('sendMedia'), 1);
    final sent = repo.calls.singleWhere((c) => c.$1 == 'sendMedia').$2;
    expect(sent['type'], 'audio');
    expect(sent['contentType'], 'audio/mp4');
    expect(sent['durationMs'], inInclusiveRange(1900, 2600));
  });

  testWidgets('a hold under one second sends nothing and says how', (
    tester,
  ) async {
    final rec = FakeVoiceRecorder();
    final repo = await _thread(tester, recorder: rec);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byIcon(Icons.mic)),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(repo.count('sendMedia'), 0);
    expect(find.text('Hold the mic and speak'), findsOneWidget);
  });

  testWidgets('sliding away cancels', (tester) async {
    final rec = FakeVoiceRecorder();
    final repo = await _thread(tester, recorder: rec);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byIcon(Icons.mic)),
    );
    await tester.pump(const Duration(seconds: 2));
    await gesture.moveBy(const Offset(-120, 0));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(repo.count('sendMedia'), 0);
    expect(rec.cancelled, isTrue);
  });

  testWidgets(
    'a refused microphone shows the settings message and nothing else',
    (tester) async {
      final rec = FakeVoiceRecorder(allowed: false);
      final repo = await _thread(tester, recorder: rec);
      final gesture = await tester.startGesture(
        tester.getCenter(find.byIcon(Icons.mic)),
      );
      await tester.pump(const Duration(seconds: 1));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(repo.count('sendMedia'), 0);
      expect(
        find.text('Allow the microphone in Settings to send voice notes.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'letting go while the recorder is still starting sends and keeps nothing',
    (tester) async {
      final gate = Completer<void>();
      final rec = FakeVoiceRecorder(startGate: gate);
      final repo = await _thread(tester, recorder: rec);
      final gesture = await tester.startGesture(
        tester.getCenter(find.byIcon(Icons.mic)),
      );
      await tester.pump(const Duration(seconds: 1));
      await gesture.up();
      await tester.pump();
      gate.complete();
      await tester.pump();
      await tester.pump(const Duration(seconds: 130));
      expect(repo.count('sendMedia'), 0);
      expect(rec.cancelled, isTrue);
      expect(rec.stopped, isFalse);
    },
  );

  testWidgets('a prompt that takes the touch leaves no recording running', (
    tester,
  ) async {
    final gate = Completer<void>();
    final rec = FakeVoiceRecorder(startGate: gate);
    final repo = await _thread(tester, recorder: rec);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byIcon(Icons.mic)),
    );
    await tester.pump(const Duration(seconds: 1));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    gate.complete();
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 130));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(repo.count('sendMedia'), 0);
    expect(rec.cancelled, isTrue);
    expect(rec.stopped, isFalse);
  });

  testWidgets('the two-minute limit stops the recording and waits for her', (
    tester,
  ) async {
    final rec = FakeVoiceRecorder();
    final repo = await _thread(tester, recorder: rec);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byIcon(Icons.mic)),
    );
    await tester.pump(const Duration(seconds: 125));
    expect(rec.stopped, isTrue);
    expect(repo.count('sendMedia'), 0);
    expect(find.text('2:00'), findsOneWidget);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(repo.count('sendMedia'), 1);
    final sent = repo.calls.singleWhere((c) => c.$1 == 'sendMedia').$2;
    expect(sent['durationMs'], 120000);
  });

  testWidgets('the limit then sliding away sends nothing', (tester) async {
    final rec = FakeVoiceRecorder();
    final repo = await _thread(tester, recorder: rec);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byIcon(Icons.mic)),
    );
    await tester.pump(const Duration(seconds: 125));
    await gesture.moveBy(const Offset(-120, 0));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(repo.count('sendMedia'), 0);
  });

  testWidgets('the mic turns into send when she types', (tester) async {
    await _thread(tester);
    expect(find.byIcon(Icons.mic), findsOneWidget);
    expect(find.byIcon(Icons.send), findsNothing);
    await tester.enterText(find.byType(TextField), 'hi');
    await tester.pump();
    expect(find.byIcon(Icons.mic), findsNothing);
    expect(find.byIcon(Icons.send), findsOneWidget);
    await tester.enterText(find.byType(TextField), '');
    await tester.pump();
    expect(find.byIcon(Icons.mic), findsOneWidget);
  });

  testWidgets('a voice line shows play and its length', (tester) async {
    await _thread(
      tester,
      lines: [
        ChatMessage(
          id: 'a',
          senderUid: 'c1',
          type: MessageType.audio,
          mediaPath: 'chat-media/c1__me/c1/a.m4a',
          durationMs: 65000,
          createdAt: DateTime(2026, 10, 24, 11, 1),
        ),
      ],
    );
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    expect(find.text('1:05'), findsOneWidget);
  });
}
