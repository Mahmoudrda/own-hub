/// An event's pictures and clips, as T09 shows them.
///
/// The pictures page sideways with a dot per page; the clip is one muted
/// preview that waits for her tap, so nothing is downloaded or played before
/// she asks, on any connection and under Reduce Motion alike.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_media.dart';
import '../../../ui/app_sage_note.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/content_image.dart';
import '../../train/presentation/exercise_clip_player.dart';
import '../data/event_clip_cache.dart';

const double kEventPictureHeight = 180;

class EventGallery extends StatefulWidget {
  const EventGallery({super.key, required this.paths});

  /// `content/events/{id}/{file}`, in the order to show them.
  final List<String> paths;

  @override
  State<EventGallery> createState() => _EventGalleryState();
}

class _EventGalleryState extends State<EventGallery> {
  final PageController _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final paths = widget.paths;
    if (paths.isEmpty) return const SizedBox.shrink();
    const placeholder = AppMedia(
      height: kEventPictureHeight,
      kind: AppMediaKind.photo,
      showPlayButton: false,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: kEventPictureHeight,
          child: PageView.builder(
            controller: _controller,
            itemCount: paths.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, i) => Semantics(
              image: true,
              label: l10n.photoNumberOfTotal('${i + 1}', '${paths.length}'),
              child: ContentImage(
                path: paths[i],
                height: kEventPictureHeight,
                placeholder: placeholder,
              ),
            ),
          ),
        ),
        if (paths.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: ExcludeSemantics(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < paths.length; i++)
                    Container(
                      key: ValueKey('event-dot-$i'),
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == _page
                            ? AppColors.primary
                            : AppColors.outline,
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

enum _Clip { idle, loading, ready, failed }

class EventClipPreview extends StatefulWidget {
  const EventClipPreview({
    super.key,
    required this.path,
    this.fetch = fetchEventClip,
    this.players,
  });

  /// `content/events/{id}/{file}`.
  final String path;

  final EventClipFetcher fetch;

  /// Makes the player. Null fetches nothing and plays nothing, as tests do.
  final ExerciseClipPlayerFactory? players;

  @override
  State<EventClipPreview> createState() => _EventClipPreviewState();
}

class _EventClipPreviewState extends State<EventClipPreview> {
  ExerciseClipPlayer? _player;
  _Clip _clip = _Clip.idle;
  bool _playing = false;
  int _generation = 0;

  @override
  void dispose() {
    _generation++;
    unawaited(_player?.dispose());
    super.dispose();
  }

  Future<void> _open() async {
    final make = widget.players;
    if (make == null) return;
    final generation = ++_generation;
    setState(() => _clip = _Clip.loading);
    final File? file = await widget.fetch(widget.path);
    if (!mounted || generation != _generation) return;
    if (file == null) {
      setState(() => _clip = _Clip.failed);
      return;
    }
    final player = make();
    final opened = await player.open(file);
    if (!mounted || generation != _generation) {
      unawaited(player.dispose());
      return;
    }
    if (!opened) {
      unawaited(player.dispose());
      setState(() => _clip = _Clip.failed);
      return;
    }
    _player = player;
    await player.play();
    if (!mounted || generation != _generation) return;
    setState(() {
      _clip = _Clip.ready;
      _playing = true;
    });
  }

  Future<void> _toggle() async {
    final player = _player;
    if (player == null) return;
    if (_playing) {
      await player.pause();
    } else {
      await player.play();
    }
    if (mounted) setState(() => _playing = !_playing);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final ready = _clip == _Clip.ready && _player != null;
    final ratio = ready ? _player!.aspectRatio : 16 / 9;
    final frame = LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = ready ? width / ratio : kEventPictureHeight;
        return Semantics(
          button: true,
          label: ready && _playing ? l10n.pause : l10n.play,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: ready
                ? _toggle
                : (_clip == _Clip.loading ? null : () => unawaited(_open())),
            child: AppMedia(
              width: width,
              height: height,
              playOverChild: ready && !_playing,
              child: ready
                  ? FittedBox(
                      fit: BoxFit.contain,
                      child: SizedBox(
                        width: 100 * ratio,
                        height: 100,
                        child: _player!.view(),
                      ),
                    )
                  : (_clip == _Clip.loading
                        ? const Center(child: CircularProgressIndicator())
                        : null),
            ),
          ),
        );
      },
    );
    if (_clip != _Clip.failed) return frame;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        frame,
        const SizedBox(height: kStackGap),
        AppSageNote(l10n.thisVideoNeedsAConnectionTheFirst),
        const SizedBox(height: kStackGap),
        AppButton(
          l10n.tryAgain,
          variant: AppButtonVariant.outlined,
          height: 48,
          fontSize: 15,
          onPressed: () => unawaited(_open()),
        ),
      ],
    );
  }
}
