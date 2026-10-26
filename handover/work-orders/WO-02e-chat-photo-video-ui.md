# WO-02e: Chat photo and video: "+" for both people, pickers, media bubbles with read ticks, budget test
Depends on: WO-02c (repository and controller), WO-02d (iOS microphone text for video with sound)
Size: L
Reads first: `app/lib/features/private_coaching/presentation/chat/chat_thread_view.dart` lines 215-260 (`_send`), 345-420 (`_item`) and 420-520 (`_composer`), `app/lib/features/private_coaching/presentation/chat/chat_sheets.dart` lines 55-115, `app/lib/features/private_coaching/presentation/chat/chat_bubbles.dart` lines 20-40 and 120-215, `app/lib/features/private_coaching/presentation/apply/apply_photo.dart` (how `image_picker` is called, `ImagePicker().pickImage`), `app/test/features/private_coaching/chat/chat_views_test.dart` lines 1-75

## Why
A coach asks for a form check first. A woman should send a photo or a 30 second clip in two taps: "+" then the choice. Today the "+" exists only for the coach and only for sharing plans. Read receipts already exist (clock, one tick, two ticks; `tickOf` in `chat_logic.dart` line 35); the new bubbles must carry them too.

## Final result
Thread screen, top to bottom (both coach and client): header (back, name, "more" menu), the lines, then the composer row: "+" (48 px), the message field, the send button. That is 5 controls (back, menu, "+", field, send), no filled primary: within the budget (at most 5 other controls, one filled primary).

Tapping "+" opens a bottom sheet (`AppSheet`) with rows, in this order:
1. Take a photo / صوّري صورة
2. Choose a photo / اختاري صورة
3. Record a video (up to 30 seconds) / صوّري فيديو (لحد 30 ثانية)
4. Choose a video / اختاري فيديو
5. (coach only, unchanged) Share a recipe, Share a workout plan, Share a meal plan, Schedule a live session.

Picking a file sends it at once (no extra confirm; the line shows the clock until stored). If the file is too big: a snackbar "That file is too big. A photo can be up to 3 MB and a video up to 25 MB." If the upload fails: snackbar "We could not send that. Try again." A media line is a bubble: photo = rounded image 220 wide (tap opens it full screen with pinch zoom); video = a 220 by 124 tile with a play icon and the length (tap opens a full screen player with its own play and pause); voice = a tile with a mic icon and the length (not playable until WO-02f). Under every media bubble the time and, for her own, the tick (clock, one tick, two blue ticks once the other person opened the chat); a screen reader hears who, the kind ("photo", "video", "voice note"), the time and the tick word.

## Files to edit or create
| path | create or edit | what changes |
|---|---|---|
| `app/lib/features/private_coaching/presentation/chat/chat_sheets.dart` | edit | `ShareChoices` gets photo and video callbacks and `copyWith`; `showShareSheet` shows them |
| `app/lib/features/private_coaching/presentation/chat/chat_media_bubbles.dart` | create | `MediaBubble`, `ChatImageViewer`, `ChatVideoViewer` |
| `app/lib/features/private_coaching/presentation/chat/chat_thread_view.dart` | edit | "+" always, pickers, route media lines |
| `app/test/features/private_coaching/chat/chat_views_test.dart` | edit | new tests; fix the test that says a client has no "+" |
| `app/test/features/private_coaching/chat/chat_budget_test.dart` | create | control budget for the thread |

## Steps
1. File `chat_sheets.dart`, class `ShareChoices`: replace the class with
```dart
class ShareChoices {
  const ShareChoices({
    this.onRecipe,
    this.onWorkoutPlan,
    this.onMealPlan,
    this.onSession,
    this.onTakePhoto,
    this.onChoosePhoto,
    this.onRecordVideo,
    this.onChooseVideo,
  });

  final VoidCallback? onRecipe;
  final VoidCallback? onWorkoutPlan;
  final VoidCallback? onMealPlan;
  final VoidCallback? onSession;
  final VoidCallback? onTakePhoto;
  final VoidCallback? onChoosePhoto;
  final VoidCallback? onRecordVideo;
  final VoidCallback? onChooseVideo;

  bool get any =>
      onRecipe != null ||
      onWorkoutPlan != null ||
      onMealPlan != null ||
      onSession != null ||
      onTakePhoto != null ||
      onChoosePhoto != null ||
      onRecordVideo != null ||
      onChooseVideo != null;

  ShareChoices withMedia({
    required VoidCallback onTakePhoto,
    required VoidCallback onChoosePhoto,
    required VoidCallback onRecordVideo,
    required VoidCallback onChooseVideo,
  }) => ShareChoices(
    onRecipe: onRecipe,
    onWorkoutPlan: onWorkoutPlan,
    onMealPlan: onMealPlan,
    onSession: onSession,
    onTakePhoto: onTakePhoto,
    onChoosePhoto: onChoosePhoto,
    onRecordVideo: onRecordVideo,
    onChooseVideo: onChooseVideo,
  );
}
```
In `showShareSheet`, as the first children of the `AppSheet` (before the `onRecipe` row) add:
```dart
        if (choices.onTakePhoto != null)
          SheetAction(
            icon: Icons.photo_camera_outlined,
            label: l10n.takeAPhoto,
            onTap: () => run(sheet, choices.onTakePhoto!),
          ),
        if (choices.onChoosePhoto != null)
          SheetAction(
            icon: Icons.photo_outlined,
            label: l10n.chooseAPhoto,
            onTap: () => run(sheet, choices.onChoosePhoto!),
          ),
        if (choices.onRecordVideo != null)
          SheetAction(
            icon: Icons.videocam_outlined,
            label: l10n.recordAVideoUpTo30Seconds,
            onTap: () => run(sheet, choices.onRecordVideo!),
          ),
        if (choices.onChooseVideo != null)
          SheetAction(
            icon: Icons.video_library_outlined,
            label: l10n.chooseAVideo,
            onTap: () => run(sheet, choices.onChooseVideo!),
          ),
```
(The existing "Schedule a live session" row already uses `Icons.videocam_outlined`; change that one to `Icons.event_outlined` so two rows do not share an icon.)
2. File `chat_media_bubbles.dart` (create). Imports: `dart:async`, `flutter/material.dart`, `package:video_player/video_player.dart`, `../../../../l10n/app_l10n.dart`, `../../../../theme/app_tokens.dart`, `../../domain/chat_message.dart`, `../coaching_when.dart` (for `clockOf`), `chat_bubbles.dart` (for `ChatRow`, `paletteOf`, `TickIcon`, `tickWord`), `chat_logic.dart` (for `ChatTick`). Full code:
```dart
/// Photo, video and voice-note lines of a thread, and their full screen views.
library;

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../../l10n/app_l10n.dart';
import '../../../../theme/app_tokens.dart';
import '../../domain/chat_message.dart';
import '../coaching_when.dart';
import 'chat_bubbles.dart';
import 'chat_logic.dart';

String durationLabel(int? ms) {
  final s = ((ms ?? 0) / 1000).round();
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

class MediaBubble extends StatefulWidget {
  const MediaBubble({
    super.key,
    required this.message,
    required this.mine,
    required this.tail,
    required this.tick,
    required this.who,
    required this.urlOf,
    this.onLongPress,
  });

  final ChatMessage message;
  final bool mine;
  final bool tail;
  final ChatTick tick;
  final String who;
  final Future<String> Function(String path) urlOf;
  final VoidCallback? onLongPress;

  @override
  State<MediaBubble> createState() => _MediaBubbleState();
}

class _MediaBubbleState extends State<MediaBubble> {
  Future<String>? _url;

  @override
  void initState() {
    super.initState();
    final path = widget.message.mediaPath;
    if (path != null && widget.message.type != MessageType.audio) {
      _url = widget.urlOf(path);
    }
  }

  String _kind(AppL10n l10n) => switch (widget.message.type) {
    MessageType.image => l10n.photo,
    MessageType.video => l10n.video,
    _ => l10n.voiceNote,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final m = widget.message;
    final at = m.createdAt;
    final spoken = <String>[
      widget.who,
      _kind(l10n),
      if (m.durationMs != null) durationLabel(m.durationMs),
      ?(at == null ? null : clockOf(l10n, at)),
      if (widget.mine) tickWord(l10n, widget.tick),
    ].join(', ');
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: spoken,
      onLongPress: widget.onLongPress,
      child: GestureDetector(
        onLongPress: widget.onLongPress,
        behavior: HitTestBehavior.opaque,
        child: ChatRow(
          mine: widget.mine,
          tail: widget.tail,
          palette: paletteOf(widget.mine),
          child: IntrinsicWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                _body(context, l10n),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (at != null)
                      Text(
                        clockOf(l10n, at),
                        style: AppText.nav.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    if (widget.mine) ...[
                      const SizedBox(width: 4),
                      TickIcon(widget.tick),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, AppL10n l10n) {
    final m = widget.message;
    if (m.type == MessageType.audio) {
      return SizedBox(
        width: 180,
        height: 48,
        child: Row(
          children: [
            const Icon(Icons.mic, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(durationLabel(m.durationMs), style: AppText.body),
          ],
        ),
      );
    }
    final isVideo = m.type == MessageType.video;
    return FutureBuilder<String>(
      future: _url,
      builder: (context, snap) {
        final url = snap.data;
        Widget face;
        if (isVideo) {
          face = Container(
            width: 220,
            height: 124,
            color: AppColors.surfaceContainer,
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.play_circle_outline, size: 40, color: AppColors.primary),
                Text(durationLabel(m.durationMs), style: AppText.nav),
              ],
            ),
          );
        } else if (url == null) {
          face = Container(
            width: 220,
            height: 220,
            color: AppColors.surfaceContainer,
            alignment: Alignment.center,
            child: snap.hasError
                ? const Icon(Icons.broken_image_outlined)
                : const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
          );
        } else {
          face = Image.network(
            url,
            width: 220,
            height: 220,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(
              width: 220,
              height: 220,
              color: AppColors.surfaceContainer,
              child: const Icon(Icons.broken_image_outlined),
            ),
          );
        }
        return InkWell(
          onTap: url == null
              ? null
              : () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => isVideo
                        ? ChatVideoViewer(url: url)
                        : ChatImageViewer(url: url),
                  ),
                ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: face,
          ),
        );
      },
    );
  }
}

class ChatImageViewer extends StatelessWidget {
  const ChatImageViewer({super.key, required this.url});
  final String url;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      leading: IconButton(
        tooltip: AppL10n.of(context).back,
        icon: const Icon(Icons.close),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
    ),
    body: Center(child: InteractiveViewer(child: Image.network(url))),
  );
}

class ChatVideoViewer extends StatefulWidget {
  const ChatVideoViewer({super.key, required this.url});
  final String url;

  @override
  State<ChatVideoViewer> createState() => _ChatVideoViewerState();
}

class _ChatVideoViewerState extends State<ChatVideoViewer> {
  late final VideoPlayerController _video;

  @override
  void initState() {
    super.initState();
    _video = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() {});
        _video.play();
      });
  }

  @override
  void dispose() {
    _video.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: IconButton(
          tooltip: l10n.back,
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: Center(
        child: _video.value.isInitialized
            ? AspectRatio(
                aspectRatio: _video.value.aspectRatio,
                child: VideoPlayer(_video),
              )
            : const CircularProgressIndicator(),
      ),
      floatingActionButton: _video.value.isInitialized
          ? FloatingActionButton(
              tooltip: _video.value.isPlaying ? l10n.pause : l10n.play,
              onPressed: () => setState(() {
                _video.value.isPlaying ? _video.pause() : _video.play();
              }),
              child: Icon(_video.value.isPlaying ? Icons.pause : Icons.play_arrow),
            )
          : null,
    );
  }
}
```
Before using the getters `l10n.pause`, `l10n.play`, `l10n.back`, run `grep -n "String get pause\b\|String get play\b\|String get back\b" app/lib/l10n/app_l10n.dart`; `back` exists (used in the thread header). If `pause`/`play` do not exist they are added in the strings table below (the add script makes them; if the grep finds them already, delete those two rows from the JSON).
3. File `chat_thread_view.dart`. Imports to add: `dart:typed_data` (not needed if only XFile), `package:image_picker/image_picker.dart`, `chat_media_bubbles.dart`. In `_ChatThreadViewState` add:
```dart
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickMedia({
    required bool video,
    required ImageSource source,
  }) async {
    if (!await _rulesOk() || !mounted) return;
    final l10n = AppL10n.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final file = video
          ? await _picker.pickVideo(
              source: source,
              maxDuration: const Duration(seconds: CoachingLimits.chatVideoMaxSeconds),
            )
          : await _picker.pickImage(
              source: source,
              maxWidth: CoachingLimits.chatImageLongSidePx.toDouble(),
              maxHeight: CoachingLimits.chatImageLongSidePx.toDouble(),
              imageQuality: 80,
            );
      if (file == null || !mounted) return;
      final bytes = await file.readAsBytes();
      final limit = video ? CoachingLimits.chatVideoMaxBytes : CoachingLimits.chatImageMaxBytes;
      if (bytes.length > limit) {
        messenger?.showSnackBar(SnackBar(content: Text(l10n.thatFileIsTooBigAPhotoCanBe)));
        return;
      }
      final ok = await _controller.sendMedia(
        type: video ? MessageType.video : MessageType.image,
        bytes: bytes,
        contentType: video ? 'video/mp4' : 'image/jpeg',
        durationMs: video ? await _videoMs(file.path) : null,
      );
      if (!ok) {
        messenger?.showSnackBar(SnackBar(content: Text(l10n.weCouldNotSendThatTryAgain)));
      } else {
        _toBottom();
      }
    } catch (_) {
      messenger?.showSnackBar(SnackBar(content: Text(l10n.weCouldNotSendThatTryAgain)));
    }
  }
```
`_videoMs(path)`: add
```dart
  Future<int> _videoMs(String path) async {
    final probe = VideoPlayerController.file(File(path));
    try {
      await probe.initialize();
      return probe.value.duration.inMilliseconds.clamp(500, CoachingLimits.chatVideoMaxSeconds * 1000);
    } finally {
      await probe.dispose();
    }
  }
```
with imports `dart:io` and `package:video_player/video_player.dart`. (Server accepts up to 31.5 s, so the clamp keeps an exact 30 s clip legal.) A QuickTime file from an iPhone has content type `video/quicktime`; `image_picker` on iOS returns `.mov` or `.mp4`: send `contentType: file.path.toLowerCase().endsWith('.mov') ? 'video/quicktime' : 'video/mp4'`, and extend the repository map `_chatExt` in WO-02c with `'video/quicktime': 'mov'` (do that edit here too, one line, in `firestore_coaching_repository.dart`). UNVERIFIED on device: record a real clip on both platforms.

In `_composer`, replace the `if (widget.share.any) IconButton(... onPressed: () => showShareSheet(context, widget.share))` with an always-present button and compute the choices:
```dart
                IconButton(
                  tooltip: l10n.shareSomething,
                  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                  icon: const Icon(Icons.add_circle_outline),
                  color: AppColors.primary,
                  onPressed: () => showShareSheet(
                    context,
                    widget.share.withMedia(
                      onTakePhoto: () => unawaited(_pickMedia(video: false, source: ImageSource.camera)),
                      onChoosePhoto: () => unawaited(_pickMedia(video: false, source: ImageSource.gallery)),
                      onRecordVideo: () => unawaited(_pickMedia(video: true, source: ImageSource.camera)),
                      onChooseVideo: () => unawaited(_pickMedia(video: true, source: ImageSource.gallery)),
                    ),
                  ),
                ),
```
In `_item`, change the final branch: before `return CardBubble(`, add
```dart
        if (message.type.isMedia) {
          return MediaBubble(
            message: message,
            mine: mine,
            tail: tail,
            tick: tick,
            who: who,
            urlOf: widget.repository.chatMediaUrl,
            onLongPress: press,
          );
        }
```
4. Fix tests: `grep -n "shareSomething\|ShareChoices()" app/test/features/private_coaching/chat/chat_views_test.dart`. Any test that expects no "+" for a client (or empty share) must now expect one "+". Change only those expectations.
5. File `chat_budget_test.dart` (create) using the `_thread` pattern from `chat_views_test.dart` (copy `_phone`, `_thread` and imports; the physical size 1170x2532 at ratio 3.0 is 390x844). Tests below.
6. Add strings (table) and run the commands.
7. Run Verify.

## Strings to add
| key | English | Egyptian Arabic |
|---|---|---|
| takeAPhoto | Take a photo | صوّري صورة |
| chooseAPhoto | Choose a photo | اختاري صورة |
| recordAVideoUpTo30Seconds | Record a video (up to 30 seconds) | صوّري فيديو (لحد 30 ثانية) |
| chooseAVideo | Choose a video | اختاري فيديو |
| thatFileIsTooBigAPhotoCanBe | That file is too big. A photo can be up to 3 MB and a video up to 25 MB. | الملف ده كبير أوي. الصورة لحد 3 ميجا والفيديو لحد 25 ميجا. |
| weCouldNotSendThatTryAgain | We could not send that. Try again. | معرفناش نبعت ده. جرّبي تاني. |
| photo | Photo | صورة |
| video | Video | فيديو |
| voiceNote | Voice note | رسالة صوتية |
| pause | Pause | وقّفي |
| play | Play | شغّلي |

The English text is the key in `strings.json` (see `app/tool/add_strings.py` header): create `app/tool/strings_wo02e.json` as `{"strings": {"Take a photo": "صوّري صورة", "Choose a photo": "اختاري صورة", "Record a video (up to 30 seconds)": "صوّري فيديو (لحد 30 ثانية)", "Choose a video": "اختاري فيديو", "That file is too big. A photo can be up to 3 MB and a video up to 25 MB.": "الملف ده كبير أوي. الصورة لحد 3 ميجا والفيديو لحد 25 ميجا.", "We could not send that. Try again.": "معرفناش نبعت ده. جرّبي تاني.", "Photo": "صورة", "Video": "فيديو", "Voice note": "رسالة صوتية", "Pause": "وقّفي", "Play": "شغّلي"}}`, then `python3 app/tool/add_strings.py app/tool/strings_wo02e.json` (it takes the lock, regenerates and prints the getter name each string got; use the printed names in the code, they may differ from the table, which is a guess). Then `cd app && flutter gen-l10n`. Delete the JSON afterwards. Skip any string the script reports as already present (reuse its getter).

## Tests to add or change
| file | test name | exact arrange, act and assert |
|---|---|---|
| `chat_views_test.dart` | `a client sees the plus and the media rows` | `_thread(tester, otherIsCoach: true)`, tap `find.byTooltip('Share something')` (UNVERIFIED exact English text: `grep -n "shareSomething" app/lib/l10n/app_l10n_en.dart`), pump; expect texts `Take a photo`, `Choose a photo`, `Record a video (up to 30 seconds)`, `Choose a video`; expect no `Share a recipe` |
| same | `a coach sees the media rows first and then the share rows` | `share: ShareChoices(onRecipe: () {})`; open sheet; `tester.getTopLeft(find.text('Take a photo')).dy < tester.getTopLeft(find.text('Share a recipe')).dy` |
| same | `a photo line draws a bubble with a tick and a spoken label` | `lines: [ChatMessage(id:'p', senderUid:'me', type: MessageType.image, mediaPath:'chat-media/c1__me/me/a.jpg', createdAt: DateTime(2026,10,24,11))]`; expect `find.byType(MediaBubble)` one; `find.bySemanticsLabel(RegExp('Photo'))` found; `find.byIcon(Icons.done)` found (UNVERIFIED: `FakeChatRepository` other read marker null means one tick) |
| same | `a video and a voice line show their length` | video `durationMs: 12000` shows `0:12`; audio `durationMs: 65000` shows `1:05` |
| same | `a two tick shows once the other person read it` | set the fake's other read time after `createdAt` (copy the existing read-tick test in this file; `grep -n "Icons.done_all" chat_views_test.dart`) with an image line; expect `Icons.done_all` |
| `chat_budget_test.dart` | `the thread has at most 5 controls and no filled primary, as a client` | `_thread(tester, otherIsCoach: true, lines: _sample())` (copy the sample); `countControlsAboveFold(tester, includeChrome: false) <= 5`; `find.byType(FilledButton), findsNothing` |
| same | `the thread has at most 5 controls with every share on, as a coach` | `share: ShareChoices(onRecipe: () {}, onWorkoutPlan: () {}, onMealPlan: () {}, onSession: () {})`, `otherIsCoach: false`; count `<= 5` |

## Verify
- `cd app && flutter test test/features/private_coaching/chat/` : `All tests passed!`
- `cd app && flutter analyze lib/features/private_coaching test/features/private_coaching` : `No issues found!`
- Manual (owner's device, not an agent): send a photo and a video on the Android emulator `ownhub_pixel8` between a coach and a client account; see the two ticks turn blue when the other opens the chat.

## Do not
- Do not add a caption box or a preview step. Do not add a second filled button. Do not add controls to the composer row (budget).
- Do not call `Image.network` on a path; always on the URL from `chatMediaUrl`.
- Do not request photo-library permission (system picker only).

## Done checklist
- [ ] ShareChoices and sheet rows
- [ ] media bubbles and viewers
- [ ] pickers wired, errors shown
- [ ] strings added, gen-l10n run
- [ ] chat tests and budget test green

## If stuck
Anchor not found or a test fails twice: stop, write the question to `handover/QUESTIONS.md` with file:line and what you saw, and move to the next work order that does not depend on this one.
