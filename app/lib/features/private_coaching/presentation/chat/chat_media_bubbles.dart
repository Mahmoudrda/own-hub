/// Photo, video and voice-note lines of a thread, and their full screen views.
library;

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../../l10n/app_l10n.dart';
import '../../../../theme/app_tokens.dart';
import '../../domain/chat_message.dart';
import 'chat_bubbles.dart';
import 'chat_logic.dart';
import 'voice_bubble.dart';

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
    if (widget.message.type == MessageType.audio) {
      return VoiceBubble(
        message: widget.message,
        mine: widget.mine,
        tail: widget.tail,
        tick: widget.tick,
        who: widget.who,
        urlOf: widget.urlOf,
        onLongPress: widget.onLongPress,
      );
    }
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
                const Icon(
                  Icons.play_circle_outline,
                  size: 40,
                  color: AppColors.primary,
                ),
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
              child: Icon(
                _video.value.isPlaying ? Icons.pause : Icons.play_arrow,
              ),
            )
          : null,
    );
  }
}
