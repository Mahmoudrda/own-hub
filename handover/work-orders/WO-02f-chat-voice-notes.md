# WO-02f: Chat voice notes: hold to record, release to send, play back in the thread
Depends on: WO-02c, WO-02d (the `record` package and permissions), WO-02e (media bubble)
Size: L
Reads first: `app/lib/features/private_coaching/presentation/chat/chat_thread_view.dart` composer (about lines 420-520), `app/lib/features/private_coaching/presentation/chat/chat_media_bubbles.dart` (created by WO-02e), `app/lib/app_state/haptics.dart` (find the light-impact helper: `grep -n "static\|void " app/lib/app_state/haptics.dart | head`), `app/lib/features/private_coaching/data/firestore_coaching_repository.dart` lines 383-440

## Why
A coach explains a correction in 20 seconds of voice faster than in 200 typed words, and many women find it easier in Egyptian Arabic out loud. Hold to record is the pattern every messaging app uses.

## Final result
Composer row stays 3 controls: "+" , the field, and ONE button on the end. With the field empty that button is a mic; with text it is send (same slot, so the screen keeps 5 controls).
- Hold the mic: the phone gives one light tap, the field row is replaced while she holds by a bar: a red dot, the time counting up "0:07", and the words "Slide away to cancel" / "اسحبي بعيد عشان تلغي". Release sends. Slide the finger more than 80 px toward the start side (left in English, right in Arabic) and release: cancelled, nothing is sent. A hold shorter than 1 second is cancelled with a snackbar "Hold the mic and speak" / "اضغطي على الميكروفون وفضلي ضاغطة وإتكلمي". At 120 seconds it sends by itself.
- A quick tap on the mic (not a hold) shows that same snackbar (this is also what a screen-reader user hears; her long-press gesture works with TalkBack and VoiceOver).
- If the microphone is refused: a snackbar "Allow the microphone in Settings to send voice notes." / "اسمحي بالميكروفون من الإعدادات عشان تبعتي رسايل صوتية." No crash, text still works.
- A voice line in the thread: a tile 180 wide: play or pause button (48 px), a progress bar, the length. Tap play to listen; tapping another line stops the first. Two blue ticks as for any line.

## Files to edit or create
| path | create or edit | what changes |
|---|---|---|
| `app/lib/features/private_coaching/presentation/chat/voice_recorder.dart` | create | thin wrapper over `record` |
| `app/lib/features/private_coaching/presentation/chat/voice_bubble.dart` | create | the playable tile |
| `app/lib/features/private_coaching/presentation/chat/chat_media_bubbles.dart` | edit | audio goes to `VoiceBubble` |
| `app/lib/features/private_coaching/presentation/chat/chat_thread_view.dart` | edit | mic/send slot, hold gesture, recording bar |
| `app/test/features/private_coaching/chat/voice_test.dart` | create | tests with a fake recorder |
| `app/test/features/private_coaching/chat/chat_budget_test.dart` | edit | still within budget with the mic |

## Steps
1. File `voice_recorder.dart` (create). The wrapper lets tests replace the plugin:
```dart
/// Hold-to-record over the `record` package (AAC in an .m4a file).
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

abstract interface class VoiceRecorder {
  /// False when the microphone is refused.
  Future<bool> start();

  /// Stops and returns the bytes, or null when nothing was recorded.
  Future<Uint8List?> stop();

  /// Stops and throws the recording away.
  Future<void> cancel();

  Future<void> dispose();
}

class PluginVoiceRecorder implements VoiceRecorder {
  final AudioRecorder _rec = AudioRecorder();
  String? _path;

  @override
  Future<bool> start() async {
    if (!await _rec.hasPermission()) return false;
    final dir = await getTemporaryDirectory();
    _path = '${dir.path}/voice_${DateTime.now().microsecondsSinceEpoch}.m4a';
    await _rec.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 48000,
        sampleRate: 22050,
        numChannels: 1,
      ),
      path: _path!,
    );
    return true;
  }

  @override
  Future<Uint8List?> stop() async {
    final path = await _rec.stop() ?? _path;
    _path = null;
    if (path == null) return null;
    final file = File(path);
    try {
      return await file.readAsBytes();
    } finally {
      try {
        await file.delete();
      } catch (_) {}
    }
  }

  @override
  Future<void> cancel() async {
    final path = _path;
    _path = null;
    await _rec.cancel();
    if (path != null) {
      try {
        await File(path).delete();
      } catch (_) {}
    }
  }

  @override
  Future<void> dispose() => _rec.dispose();
}
```
48 kbps mono AAC is about 6 KB per second, so 120 s is about 720 KB, under the 2 MB limit. UNVERIFIED API names of `record` (version in WO-02d): after `flutter pub get`, open `~/.pub-cache/hosted/pub.dev/record-*/lib/src/record.dart` and confirm `AudioRecorder`, `hasPermission`, `start(config, path:)`, `stop()`, `cancel()`, `dispose()`, `RecordConfig` named parameters; adjust only the names, not the design.
2. File `chat_thread_view.dart`. Add a constructor parameter `this.recorderBuilder,` with field `final VoiceRecorder Function()? recorderBuilder;` and in the state `late final VoiceRecorder _recorder = (widget.recorderBuilder ?? PluginVoiceRecorder.new)();` (dispose it in `dispose()` with `unawaited(_recorder.dispose());`). State fields and methods:
```dart
  bool _recording = false;
  bool _cancelArmed = false;
  DateTime? _recordStart;
  Timer? _ticker;
  double _dragX = 0;

  Future<void> _recordStartHold() async {
    if (_recording || !widget.open) return;
    if (!await _rulesOk() || !mounted) return;
    final ok = await _recorder.start();
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(AppL10n.of(context).allowTheMicrophoneInSettingsToSendVoice)),
      );
      return;
    }
    Haptics.light();
    setState(() {
      _recording = true;
      _cancelArmed = false;
      _dragX = 0;
      _recordStart = DateTime.now();
    });
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted) return;
      if (_elapsedMs >= CoachingLimits.chatAudioMaxSeconds * 1000) {
        unawaited(_recordEnd(send: true));
      } else {
        setState(() {});
      }
    });
  }

  int get _elapsedMs => _recordStart == null
      ? 0
      : DateTime.now().difference(_recordStart!).inMilliseconds;

  void _recordDrag(double dx) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final toward = rtl ? dx : -dx;
    setState(() {
      _dragX = dx;
      _cancelArmed = toward > 80;
    });
  }

  Future<void> _recordEnd({required bool send}) async {
    if (!_recording) return;
    final ms = _elapsedMs;
    final cancel = !send || _cancelArmed;
    _ticker?.cancel();
    setState(() => _recording = false);
    final l10n = AppL10n.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (cancel) {
      await _recorder.cancel();
      return;
    }
    if (ms < 1000) {
      await _recorder.cancel();
      messenger?.showSnackBar(SnackBar(content: Text(l10n.holdTheMicAndSpeak)));
      return;
    }
    final bytes = await _recorder.stop();
    if (bytes == null || bytes.isEmpty || !mounted) return;
    final ok = await _controller.sendMedia(
      type: MessageType.audio,
      bytes: bytes,
      contentType: 'audio/mp4',
      durationMs: ms.clamp(1000, CoachingLimits.chatAudioMaxSeconds * 1000),
    );
    if (!ok) {
      messenger?.showSnackBar(SnackBar(content: Text(l10n.weCouldNotSendThatTryAgain)));
    } else {
      _toBottom();
    }
  }
```
Replace `Haptics.light()` with the real helper found by the Reads-first grep (UNVERIFIED name; if none gives a light impact, use `HapticFeedback.lightImpact()` from `package:flutter/services.dart`).
3. Same file, `_composer`. Replace the send `IconButton` (the last child of the row) with:
```dart
                if (_text.text.trim().isNotEmpty)
                  IconButton(
                    tooltip: l10n.send,
                    constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                    icon: const Icon(Icons.send),
                    color: AppColors.primary,
                    onPressed: () => unawaited(_send()),
                  )
                else
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                      SnackBar(content: Text(l10n.holdTheMicAndSpeak)),
                    ),
                    onLongPressStart: (_) => unawaited(_recordStartHold()),
                    onLongPressMoveUpdate: (d) => _recordDrag(d.offsetFromOrigin.dx),
                    onLongPressEnd: (_) => unawaited(_recordEnd(send: true)),
                    onLongPressCancel: () => unawaited(_recordEnd(send: false)),
                    child: Semantics(
                      button: true,
                      label: l10n.voiceNote,
                      hint: l10n.holdTheMicAndSpeak,
                      excludeSemantics: true,
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: Icon(Icons.mic, color: AppColors.primary),
                      ),
                    ),
                  ),
```
(Budget: the counter counts a `GestureDetector` with `onTap` as one control, and the `IconButton` branch is not shown at the same time, so the row stays at "+", field, one end button.) While `_recording` is true, replace the whole `Row(children: [...])` of the composer with the recording bar:
```dart
Row(
  children: [
    const SizedBox(width: 12),
    Icon(Icons.fiber_manual_record, color: _cancelArmed ? AppColors.onSurfaceVariant : Colors.red, size: 16),
    const SizedBox(width: 8),
    Text(durationLabel(_elapsedMs), style: AppText.body.copyWith(color: AppColors.ink)),
    const SizedBox(width: 12),
    Expanded(
      child: Transform.translate(
        offset: Offset(_dragX.clamp(-120.0, 120.0), 0),
        child: Text(
          _cancelArmed ? l10n.releaseToCancel : l10n.slideAwayToCancel,
          style: AppText.nav.copyWith(color: AppColors.onSurfaceVariant),
        ),
      ),
    ),
    const SizedBox(width: 48, height: 48, child: Icon(Icons.mic, color: AppColors.primary)),
  ],
)
```
It must stay inside the same `GestureDetector` tree: simplest is to keep the mic `GestureDetector` mounted (so the gesture is not cancelled) and only swap the field area: put the `if (_recording)` choice around the `Expanded(TextField)` and the `+` only, not around the mic. Write it that way: children `[ if (_recording) ...barChildren else ...[plusButton, Expanded(textField)], micOrSend ]`. Import `chat_media_bubbles.dart` for `durationLabel`.
4. File `voice_bubble.dart` (create): a `StatefulWidget` `VoiceBubble` taking the same arguments as `MediaBubble`. It builds the same bubble frame (copy the `Semantics` + `GestureDetector` + `ChatRow` + stamp from `MediaBubble.build`, label kind `l10n.voiceNote`), and the body:
```dart
Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    IconButton(
      tooltip: _playing ? l10n.pause : l10n.play,
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      icon: Icon(_playing ? Icons.pause : Icons.play_arrow, color: AppColors.primary),
      onPressed: _toggle,
    ),
    SizedBox(
      width: 90,
      child: LinearProgressIndicator(value: _progress, minHeight: 3),
    ),
    const SizedBox(width: 8),
    Text(durationLabel(widget.message.durationMs), style: AppText.nav),
  ],
)
```
with `_toggle`: on first press `final url = await widget.urlOf(widget.message.mediaPath!); _player = VideoPlayerController.networkUrl(Uri.parse(url)); await _player.initialize(); _player.addListener(_onTick); await _player.play();`, `_onTick` sets `_playing = _player.value.isPlaying`, `_progress = position/duration`, and when `position >= duration` seeks to zero and sets `_playing = false`. A static `ValueNotifier<VoiceBubbleState?> _current` (a file-level `VideoPlayerController? _activePlayer`) pauses the previously playing controller when a new one starts. `dispose` disposes the controller. Wrap errors: any exception shows the snackbar `weCouldNotSendThatTryAgain`? No: use "We could not play that voice note." (string below).
5. File `chat_media_bubbles.dart`: at the top of `MediaBubble.build`, `if (widget.message.type == MessageType.audio) return VoiceBubble(...)` with the same arguments; delete the temporary audio branch in `_body` (keep nothing unused). In `_item` of the view nothing changes (it already routes `isMedia` to `MediaBubble`).
6. Add the strings, run `add_strings.py` as in WO-02e (JSON `app/tool/strings_wo02f.json`, delete afterwards).
7. Tests (below), then Verify.

## Strings to add
| key (English) | Egyptian Arabic |
|---|---|
| Hold the mic and speak | اضغطي على الميكروفون وفضلي ضاغطة وإتكلمي |
| Slide away to cancel | اسحبي بعيد عشان تلغي |
| Release to cancel | سيبي الزرار عشان تلغي |
| Allow the microphone in Settings to send voice notes. | اسمحي بالميكروفون من الإعدادات عشان تبعتي رسايل صوتية. |
| We could not play that voice note. | معرفناش نشغّل الرسالة الصوتية دي. |


## Tests to add or change
| file | test name | exact arrange, act and assert |
|---|---|---|
| `voice_test.dart` | `holding the mic for 2 seconds sends a voice note` | `FakeVoiceRecorder` (defined in the test: `start()` returns true, `stop()` returns `Uint8List.fromList([1,2,3])`) passed as `recorderBuilder`; pump `ChatThreadView` as in `chat_views_test.dart`; `tester.startGesture` on `find.byIcon(Icons.mic)`; `await tester.pump(const Duration(seconds: 2))`; release; assert the fake repo logged `sendMedia` with `type: audio`, `contentType: audio/mp4`, `durationMs` between 1900 and 2600 |
| same | `a hold under one second sends nothing and says how` | hold 300 ms; no `sendMedia` call; snackbar text `Hold the mic and speak` found |
| same | `sliding away cancels` | hold 2 s, `gesture.moveBy(const Offset(-120, 0))`, pump, `up()`; no `sendMedia`; fake recorder `cancelled == true` |
| same | `a refused microphone shows the settings message and nothing else` | fake `start()` returns false; long press; snackbar `Allow the microphone in Settings to send voice notes.`; no call |
| same | `the mic turns into send when she types` | `enterText(find.byType(TextField), 'hi')`; `find.byIcon(Icons.mic)` none, `find.byIcon(Icons.send)` one; clear text; mic returns |
| same | `a voice line shows play and its length` | audio line `durationMs: 65000`: `find.byIcon(Icons.play_arrow)` one, text `1:05` |
| `chat_budget_test.dart` | existing two tests | still pass (mic replaces send, not added) |

## Verify
- `cd app && flutter test test/features/private_coaching/chat/` : `All tests passed!`
- `cd app && flutter analyze lib test` limited: `flutter analyze lib/features/private_coaching test/features/private_coaching` : `No issues found!`
- Manual (owner, device): hold, speak, release on the Android emulator `ownhub_pixel8` (enable the emulator microphone in its extended controls) and a real iPhone; play the note on the other account in both. This confirms the UNVERIFIED claim that `video_player` plays `.m4a`; if it does not, write it to `handover/QUESTIONS.md` and stop (the fallback is `just_audio`, a new dependency that needs the owner's OK).

## Do not
- Do not record while the app is in the background. Do not keep the temp file after send or cancel.
- Do not add controls to the row (budget). Do not add speech-to-text.
- Do not send a recording under 1 second.

## Done checklist
- [ ] recorder wrapper and bubble
- [ ] mic/send slot and hold gesture, cancel, limits
- [ ] strings
- [ ] tests and budget test green
- [ ] playback checked on a device or reported as failed

## If stuck
Anchor not found or a test fails twice: stop, write the question to `handover/QUESTIONS.md` with file:line and what you saw, and move to the next work order that does not depend on this one.
