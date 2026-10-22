/// One move's clip, full screen.
///
/// Opened from the expand badge on the clip frame (R04, R06, R07, R15). It
/// builds its own player from the same factory, so the page's loop and this
/// view never share one: the page's frame lets go of its player while this
/// route covers it. Tap the picture, or the big button, to play or pause;
/// restart and half speed are offered when the player can do them. Under
/// Reduce Motion the clip waits for her first tap.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/hand/hand.dart';
import '../data/exercise_media_store.dart';
import '../domain/exercise_library.dart';
import 'exercise_clip_player.dart';

enum _State { loading, ready, failed }

class ClipFullscreen extends StatefulWidget {
  const ClipFullscreen({
    super.key,
    required this.exercise,
    required this.media,
    required this.players,
    this.angle = 0,
  });

  final LibraryExercise exercise;
  final ExerciseMediaStore media;
  final ExerciseClipPlayerFactory players;
  final int angle;

  /// Pushes the full-screen view over the current page.
  static Future<void> open(
    BuildContext context, {
    required LibraryExercise exercise,
    required ExerciseMediaStore media,
    required ExerciseClipPlayerFactory players,
    int angle = 0,
  }) => Navigator.of(context).push<void>(
    // Not a fullscreen dialog: that kind does not move the page beneath it, so
    // the page could not tell it had been covered.
    MaterialPageRoute<void>(
      builder: (_) => ClipFullscreen(
        exercise: exercise,
        media: media,
        players: players,
        angle: angle,
      ),
    ),
  );

  @override
  State<ClipFullscreen> createState() => _ClipFullscreenState();
}

class _ClipFullscreenState extends State<ClipFullscreen> {
  ExerciseClipPlayer? _player;
  _State _state = _State.loading;
  bool _playing = false;
  bool _half = false;
  int _generation = 0;

  int get _angle =>
      widget.angle < widget.exercise.clips.length ? widget.angle : 0;

  ExerciseClipControls? get _controls {
    final player = _player;
    if (player is ExerciseClipControls) return player as ExerciseClipControls;
    return null;
  }

  @override
  void initState() {
    super.initState();
    unawaited(_open());
  }

  Future<void> _open() async {
    final generation = ++_generation;
    final previous = _player;
    _player = null;
    unawaited(previous?.dispose());
    if (mounted) setState(() => _state = _State.loading);
    final file = await widget.media.fetch(widget.exercise.clips[_angle].media);
    if (!mounted || generation != _generation) return;
    if (file == null) {
      setState(() => _state = _State.failed);
      return;
    }
    final player = widget.players();
    final opened = await player.open(file);
    if (!mounted || generation != _generation) {
      unawaited(player.dispose());
      return;
    }
    if (!opened) {
      unawaited(player.dispose());
      setState(() => _state = _State.failed);
      return;
    }
    _player = player;
    final still = handMotionOff(context);
    if (!still) await player.play();
    if (!mounted || generation != _generation) return;
    setState(() {
      _state = _State.ready;
      _playing = !still;
      _half = false;
    });
  }

  Future<void> _toggle() async {
    final player = _player;
    if (player == null || _state != _State.ready) return;
    if (_playing) {
      await player.pause();
    } else {
      await player.play();
    }
    if (mounted) setState(() => _playing = !_playing);
  }

  Future<void> _restart() async {
    final controls = _controls;
    if (controls == null || _state != _State.ready) return;
    await controls.restart();
    if (mounted) setState(() => _playing = true);
  }

  Future<void> _speed({required bool half}) async {
    final controls = _controls;
    if (controls == null || _state != _State.ready || half == _half) return;
    await controls.setSpeed(half ? 0.5 : 1.0);
    if (mounted) setState(() => _half = half);
  }

  @override
  void dispose() {
    _generation++;
    unawaited(_player?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final player = _player;
    final ready = _state == _State.ready && player != null;
    final controls = _controls;

    return Scaffold(
      key: const ValueKey('clip-fullscreen'),
      backgroundColor: AppColors.inverseSurface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 4, end: 16),
              child: Row(
                children: [
                  IconButton(
                    key: const ValueKey('clip-fullscreen-close'),
                    onPressed: () => Navigator.of(context).maybePop(),
                    tooltip: l10n.closeVideo,
                    iconSize: 28,
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    color: AppColors.inverseOnSurface,
                    icon: const Icon(Icons.close),
                  ),
                  Expanded(
                    child: Text(
                      widget.exercise.name(language),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.titleM.copyWith(
                        color: AppColors.inverseOnSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: switch (_state) {
                _State.failed => _Failed(
                  message: l10n.thisVideoNeedsAConnectionTheFirst,
                  retry: l10n.tryAgain,
                  onRetry: _open,
                ),
                _ when !ready => Center(
                  child: Text(
                    l10n.gettingTheVideo,
                    style: AppText.bodyM.copyWith(
                      color: AppColors.inverseOnSurface,
                    ),
                  ),
                ),
                _ => Semantics(
                  button: true,
                  label: _playing ? l10n.pause : l10n.play,
                  child: GestureDetector(
                    key: const ValueKey('clip-fullscreen-picture'),
                    behavior: HitTestBehavior.opaque,
                    onTap: _toggle,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Center(
                          child: AspectRatio(
                            aspectRatio: player.aspectRatio,
                            child: player.view(),
                          ),
                        ),
                        if (!_playing)
                          const ExcludeSemantics(
                            child: Icon(
                              Icons.play_circle_outline,
                              size: 72,
                              color: AppColors.inverseOnSurface,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  if (controls != null)
                    _Control(
                      key: const ValueKey('clip-fullscreen-restart'),
                      icon: Icons.replay,
                      label: l10n.restart,
                      onTap: ready ? _restart : null,
                    ),
                  _Control(
                    key: const ValueKey('clip-fullscreen-play'),
                    icon: _playing ? Icons.pause : Icons.play_arrow,
                    label: _playing ? l10n.pause : l10n.play,
                    onTap: ready ? _toggle : null,
                  ),
                  if (controls != null) ...[
                    _Control(
                      key: const ValueKey('clip-fullscreen-half'),
                      text: '0.5x',
                      label: l10n.halfSpeed,
                      selected: _half,
                      onTap: ready ? () => _speed(half: true) : null,
                    ),
                    _Control(
                      key: const ValueKey('clip-fullscreen-normal'),
                      text: '1x',
                      label: l10n.normalSpeed,
                      selected: !_half,
                      onTap: ready ? () => _speed(half: false) : null,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A round control on the dark ground: an icon or a short figure, named for a
/// screen reader by [label], at least 48 px to tap.
class _Control extends StatelessWidget {
  const _Control({
    super.key,
    this.icon,
    this.text,
    required this.label,
    this.selected,
    this.onTap,
  });

  final IconData? icon;
  final String? text;
  final String label;

  /// Null for a plain button; a value for one of a pair of choices.
  final bool? selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final on = selected ?? false;
    final enabled = onTap != null;
    final foreground = on
        ? AppColors.inverseSurface
        : AppColors.inverseOnSurface;
    return Semantics(
      button: true,
      selected: selected == null ? null : on,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: InkResponse(
        onTap: onTap,
        radius: 32,
        child: Container(
          constraints: const BoxConstraints(minWidth: 56, minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on
                ? AppColors.primaryContainer
                : AppColors.inverseOnSurface.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(28),
          ),
          child: icon != null
              ? Icon(
                  icon,
                  size: 28,
                  color: enabled
                      ? foreground
                      : foreground.withValues(alpha: 0.4),
                )
              : Text(
                  text!,
                  style: AppText.label.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: enabled
                        ? foreground
                        : foreground.withValues(alpha: 0.4),
                  ),
                ),
        ),
      ),
    );
  }
}

class _Failed extends StatelessWidget {
  const _Failed({
    required this.message,
    required this.retry,
    required this.onRetry,
  });

  final String message;
  final String retry;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppText.bodyM.copyWith(color: AppColors.inverseOnSurface),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: onRetry,
            child: Text(
              retry,
              style: AppText.label.copyWith(
                fontSize: 16,
                color: AppColors.primaryContainer,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
