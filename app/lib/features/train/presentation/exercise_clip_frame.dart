/// One move's clip inside the page's own media frame, shared by R15 and R04.
///
/// The poster is there at once and the clip takes its place when it is ready,
/// muted and looping with no controls; a tap pauses it under the same ringed
/// play mark the app draws everywhere else. Under Reduce Motion it waits for
/// that tap. The first time a clip is shown it is fetched; after that it is on
/// her phone (D42). If it cannot be fetched she is told it needs a connection
/// once, and offered to try again.
library;

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_media.dart';
import '../../../ui/app_sage_note.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/hand/hand.dart';
import '../data/exercise_media_store.dart';
import '../domain/clock_label.dart';
import '../domain/exercise_library.dart';
import 'exercise_clip_player.dart';

enum _Clip { loading, ready, failed }

/// The exact filename of the files a move shows, so a library update that keeps
/// the id and changes the files starts again.
String _mediaOf(LibraryExercise e) =>
    [e.poster.path, for (final c in e.clips) c.media.path].join('|');

class ExerciseClipFrame extends StatefulWidget {
  const ExerciseClipFrame({
    super.key,
    required this.exercise,
    required this.media,
    this.players,
    this.angle = 0,
    this.tallest = 0.55,
    this.clipKey,
    this.maxHeight,
    this.onFailed,
  });

  final LibraryExercise exercise;
  final ExerciseMediaStore media;

  /// Makes the player. Null draws the poster alone, as tests do.
  final ExerciseClipPlayerFactory? players;

  /// Which of the move's clips to show.
  final int angle;

  /// The tallest the frame grows, as a share of the screen's height.
  final double tallest;

  /// Keys the tappable frame.
  final Key? clipKey;

  /// The tallest the frame grows, in pixels, when the page gives it a fixed
  /// band rather than a share of the screen.
  final double? maxHeight;

  /// Told once when the clip cannot be played. When given, the frame draws
  /// nothing for the failure itself, so the page can show its own stand-in
  /// rather than a player that will not play.
  final VoidCallback? onFailed;

  /// How long the clip may be loading before the frame says the connection is
  /// slow, so a long wait is explained rather than looking frozen.
  static const Duration slowAfter = Duration(seconds: 12);

  @override
  State<ExerciseClipFrame> createState() => _ExerciseClipFrameState();
}

class _ExerciseClipFrameState extends State<ExerciseClipFrame> {
  File? _poster;

  /// The poster is being fetched; the shimmer shows only while it is.
  bool _posterLoading = false;
  ExerciseClipPlayer? _player;
  _Clip _clip = _Clip.loading;
  bool _playing = false;

  /// True once the clip has been loading longer than
  /// [ExerciseClipFrame.slowAfter].
  bool _slow = false;
  Timer? _slowTimer;

  /// Bumped whenever what is being loaded changes, so a slow load for the
  /// previous angle or move never lands on this one.
  int _generation = 0;

  /// The same, for the poster alone: changing angle keeps the move's poster,
  /// but a different move, or different files, drops a slow poster load.
  int _posterGeneration = 0;

  int get _angle =>
      widget.angle < widget.exercise.clips.length ? widget.angle : 0;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(ExerciseClipFrame old) {
    super.didUpdateWidget(old);
    // The page redraws whenever shared state changes; only a different move,
    // or different files for the same move, starts again.
    if (_mediaOf(old.exercise) != _mediaOf(widget.exercise)) {
      _poster = null;
      _start();
    } else if (old.angle != widget.angle) {
      unawaited(_open(widget.exercise, _angle));
    }
  }

  void _start() {
    final exercise = widget.exercise;
    _posterLoading = true;
    unawaited(_open(exercise, _angle));
    unawaited(_loadPoster(exercise, ++_posterGeneration));
  }

  Future<void> _loadPoster(LibraryExercise exercise, int generation) async {
    final file =
        await widget.media.local(exercise.poster) ??
        await widget.media.fetch(exercise.poster);
    if (!mounted || generation != _posterGeneration) return;
    setState(() {
      _posterLoading = false;
      if (file != null) _poster = file;
    });
  }

  Future<void> _open(LibraryExercise exercise, int angle) async {
    final generation = ++_generation;
    final previous = _player;
    _player = null;
    unawaited(previous?.dispose());
    if (mounted) {
      setState(() {
        _clip = _Clip.loading;
        _playing = false;
        _slow = false;
      });
    }
    _slowTimer?.cancel();
    _slowTimer = Timer(ExerciseClipFrame.slowAfter, () {
      if (mounted && generation == _generation && _clip == _Clip.loading) {
        setState(() => _slow = true);
      }
    });
    final make = widget.players;
    final file = await widget.media.fetch(exercise.clips[angle].media);
    _slowTimer?.cancel();
    if (!mounted || generation != _generation) return;
    if (file == null) {
      setState(() => _clip = _Clip.failed);
      widget.onFailed?.call();
      return;
    }
    if (make == null) return;
    final player = make();
    final opened = await player.open(file);
    if (!mounted || generation != _generation) {
      unawaited(player.dispose());
      return;
    }
    if (!opened) {
      unawaited(player.dispose());
      setState(() => _clip = _Clip.failed);
      widget.onFailed?.call();
      return;
    }
    _player = player;
    final still = handMotionOff(context);
    if (!still) await player.play();
    if (!mounted || generation != _generation) return;
    setState(() {
      _clip = _Clip.ready;
      _playing = !still;
    });
  }

  Future<void> _toggle() async {
    final player = _player;
    if (player == null || _clip != _Clip.ready) return;
    if (_playing) {
      await player.pause();
    } else {
      await player.play();
    }
    if (mounted) setState(() => _playing = !_playing);
  }

  @override
  void dispose() {
    _generation++;
    _posterGeneration++;
    _slowTimer?.cancel();
    unawaited(_player?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final clip = widget.exercise.clips[_angle];

    final frame = LayoutBuilder(
      builder: (context, constraints) {
        // The frame takes the clip's own shape, so the whole picture shows
        // with nothing cut from it and no bars beside it.
        final ratio = _player?.aspectRatio ?? 9 / 16;
        final tallest = MediaQuery.sizeOf(context).height * widget.tallest;
        var height = math.min(constraints.maxWidth / ratio, tallest);
        if (widget.maxHeight case final cap?) height = math.min(height, cap);
        var width = height * ratio;
        if (width > constraints.maxWidth) {
          width = constraints.maxWidth;
          height = width / ratio;
        }
        final ready = _clip == _Clip.ready && _player != null;
        return Center(
          child: Semantics(
            button: ready,
            label: ready ? (_playing ? l10n.pause : l10n.play) : null,
            child: GestureDetector(
              key: widget.clipKey,
              behavior: HitTestBehavior.opaque,
              onTap: ready ? _toggle : null,
              child: AppMedia(
                width: width,
                height: height,
                playOverChild: ready && !_playing,
                badge: clockLabel(
                  Duration(milliseconds: (clip.seconds * 1000).round()),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (_poster == null &&
                        _posterLoading &&
                        _clip == _Clip.loading)
                      const Skeleton(radius: 0),
                    if (_poster case final poster?)
                      ExcludeSemantics(
                        child: Image.file(
                          poster,
                          fit: BoxFit.contain,
                          // Decoded at the size it is drawn, not at the size
                          // it was exported: a full-size poster is megabytes
                          // of pixels on a phone with little memory.
                          cacheWidth: width > 0
                              ? math.max(
                                  1,
                                  (width *
                                          MediaQuery.devicePixelRatioOf(
                                            context,
                                          ))
                                      .round(),
                                )
                              : null,
                          errorBuilder: (_, _, _) => const SizedBox.shrink(),
                        ),
                      ),
                    if (ready)
                      FittedBox(
                        fit: BoxFit.contain,
                        child: SizedBox(
                          width: 100 * ratio,
                          height: 100,
                          child: _player!.view(),
                        ),
                      ),
                    if (_clip == _Clip.loading)
                      PositionedDirectional(
                        start: 10,
                        bottom: 8,
                        child: _Tag(
                          _slow
                              ? l10n.slowConnectionStillGettingTheVideo
                              : l10n.gettingTheVideo,
                        ),
                      ),
                    if (_clip == _Clip.loading)
                      PositionedDirectional(
                        start: 0,
                        end: 0,
                        bottom: 0,
                        child: ValueListenableBuilder<double?>(
                          valueListenable: widget.media.progressOf(clip.media),
                          builder: (context, value, _) => ExcludeSemantics(
                            child: LinearProgressIndicator(
                              key: const ValueKey('clip-progress'),
                              // A bar at rest while the size is unknown: an indeterminate
                              // one would animate for ever.
                              value: value ?? 0,
                              minHeight: 3,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    if (_clip != _Clip.failed || widget.onFailed != null) return frame;
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
          onPressed: () => _open(widget.exercise, _angle),
        ),
      ],
    );
  }
}

/// A small label on the frame, in the badge's own style.
class _Tag extends StatelessWidget {
  const _Tag(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    height: 26,
    padding: const EdgeInsets.symmetric(horizontal: 9),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: AppColors.surfaceLowest,
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      text,
      style: AppText.label.copyWith(fontSize: 13, fontWeight: FontWeight.w600),
    ),
  );
}
