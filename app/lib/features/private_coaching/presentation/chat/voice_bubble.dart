/// Playable voice-note bubble in a coaching thread.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../../l10n/app_l10n.dart';
import '../../../../theme/app_tokens.dart';
import '../../domain/chat_message.dart';
import 'chat_bubbles.dart';
import 'chat_logic.dart';
import 'chat_media_bubbles.dart';

VideoPlayerController? _activePlayer;

class VoiceBubble extends StatefulWidget {
  const VoiceBubble({
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
  State<VoiceBubble> createState() => _VoiceBubbleState();
}

class _VoiceBubbleState extends State<VoiceBubble> {
  VideoPlayerController? _player;
  bool _playing = false;
  double _progress = 0;

  @override
  void dispose() {
    final p = _player;
    if (p != null) {
      if (_activePlayer == p) _activePlayer = null;
      p.removeListener(_onTick);
      unawaited(p.dispose());
    }
    super.dispose();
  }

  void _onTick() {
    final p = _player;
    if (p == null || !mounted) return;
    final val = p.value;
    final total = val.duration.inMilliseconds;
    final pos = val.position.inMilliseconds;
    if (total > 0 && pos >= total) {
      unawaited(p.seekTo(Duration.zero));
      unawaited(p.pause());
      setState(() {
        _playing = false;
        _progress = 0;
      });
      return;
    }
    setState(() {
      _playing = val.isPlaying;
      _progress = total > 0 ? (pos / total).clamp(0.0, 1.0) : 0;
    });
  }

  Future<void> _toggle() async {
    final l10n = AppL10n.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final existing = _player;
      if (existing != null && existing.value.isInitialized) {
        if (existing.value.isPlaying) {
          await existing.pause();
        } else {
          if (_activePlayer != null && _activePlayer != existing) {
            await _activePlayer!.pause();
          }
          _activePlayer = existing;
          await existing.play();
        }
        return;
      }
      final path = widget.message.mediaPath;
      if (path == null) return;
      final url = await widget.urlOf(path);
      if (!mounted) return;
      final controller = VideoPlayerController.networkUrl(Uri.parse(url));
      _player = controller;
      await controller.initialize();
      if (!mounted) return;
      if (_activePlayer != null && _activePlayer != controller) {
        await _activePlayer!.pause();
      }
      _activePlayer = controller;
      controller.addListener(_onTick);
      await controller.play();
    } catch (_) {
      messenger?.showSnackBar(
        SnackBar(content: Text(l10n.weCouldNotPlayThatVoiceNote)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final m = widget.message;
    final at = m.createdAt;
    final spoken = <String>[
      widget.who,
      l10n.voiceNote,
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
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: _playing ? l10n.pause : l10n.play,
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      icon: Icon(
                        _playing ? Icons.pause : Icons.play_arrow,
                        color: AppColors.primary,
                      ),
                      onPressed: _toggle,
                    ),
                    SizedBox(
                      width: 90,
                      child: LinearProgressIndicator(
                        value: _progress,
                        minHeight: 3,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(durationLabel(m.durationMs), style: AppText.nav),
                  ],
                ),
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
}
