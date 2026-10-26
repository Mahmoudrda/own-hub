/// Rahma's welcome: a short video and a note from her, shown before sign-up.
///
/// Not a route of its own. It is pushed over whatever she was looking at, from
/// the "Sign in / Join" pill or from the first thing she tries that needs an
/// account, and it never traps her: the close button and Back both leave.
///
/// The video does not start by itself and nothing is fetched until she taps
/// play, so there is never sound she did not ask for. The note is the
/// founder's, in English and in Egyptian Arabic, and reads right to left in
/// Arabic because the page follows the app's language.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../config/founder_video.dart';
import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/hand/draw_on.dart';
import 'founder_video_player.dart';

class FounderWelcomeView extends StatefulWidget {
  const FounderWelcomeView({
    super.key,
    required this.onContinue,
    required this.onClose,
    this.onDismissed,
    this.signIn = false,
    this.videoUrl = kFounderVideoUrl,
    this.playerFactory = VideoPlayerFounder.new,
  });

  /// "Continue to sign up", or "Sign in" when [signIn].
  final VoidCallback onContinue;

  /// The close button.
  final VoidCallback onClose;

  /// Called when the page is left by closing or Back, and not when she goes
  /// on to sign up.
  final VoidCallback? onDismissed;

  final bool signIn;
  final String videoUrl;

  /// Injectable so a widget test never reaches the platform player.
  final FounderVideoPlayerFactory playerFactory;

  @override
  State<FounderWelcomeView> createState() => _FounderWelcomeViewState();
}

enum _VideoState { poster, loading, ready, unavailable }

class _FounderWelcomeViewState extends State<FounderWelcomeView> {
  FounderVideoPlayer? _player;
  bool _continued = false;
  late _VideoState _state = widget.videoUrl.isEmpty
      ? _VideoState.unavailable
      : _VideoState.poster;
  bool _muted = false;

  @override
  void dispose() {
    final player = _player;
    _player = null;
    if (player != null) unawaited(player.dispose());
    super.dispose();
  }

  Future<void> _start() async {
    if (_state == _VideoState.loading) return;
    final existing = _player;
    if (existing != null && _state == _VideoState.ready) {
      await (existing.playing ? existing.pause() : existing.play());
      if (mounted) setState(() {});
      return;
    }
    setState(() => _state = _VideoState.loading);
    final player = _player ??= widget.playerFactory();
    final opened = await player.open(widget.videoUrl);
    if (!mounted) return;
    if (!opened) {
      setState(() => _state = _VideoState.unavailable);
      return;
    }
    await player.setMuted(_muted);
    await player.play();
    if (mounted) setState(() => _state = _VideoState.ready);
  }

  Future<void> _toggleMute() async {
    final player = _player;
    if (player == null) return;
    _muted = !_muted;
    await player.setMuted(_muted);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final player = _player;
    final playing = _state == _VideoState.ready && (player?.playing ?? false);
    final fade = handMotionOff(context) ? Duration.zero : AppMotion.short;

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop && !_continued) widget.onDismissed?.call();
      },
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                  child: IconButton(
                    key: const ValueKey('founder-close'),
                    tooltip: l10n.close,
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                    color: AppColors.onSurface,
                    icon: const Icon(Icons.close),
                    onPressed: widget.onClose,
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _card(l10n, player, playing, fade),
                      const SizedBox(height: 24),
                      Text(
                        l10n.aNoteFromRahma,
                        style: AppText.bodyM.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.rahmaMohsen,
                        key: const ValueKey('founder-name'),
                        style: AppText.display,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.heySoHappyYoureHereThankYou,
                        key: const ValueKey('founder-note'),
                        style: AppText.body.copyWith(height: 1.5),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: AppButton(
                  widget.signIn ? l10n.signIn : l10n.continueToSignUp,
                  onPressed: () {
                    _continued = true;
                    widget.onContinue();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card(
    AppL10n l10n,
    FounderVideoPlayer? player,
    bool playing,
    Duration fade,
  ) {
    final ready = _state == _VideoState.ready && player != null;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: AspectRatio(
        aspectRatio: 4 / 5,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.primarySoft, AppColors.pinkShade],
                ),
              ),
            ),
            AnimatedSwitcher(
              duration: fade,
              child: ready
                  ? FittedBox(
                      key: const ValueKey('founder-video'),
                      fit: BoxFit.cover,
                      clipBehavior: Clip.hardEdge,
                      child: SizedBox(
                        width: 100 * player.aspectRatio,
                        height: 100,
                        child: player.view(),
                      ),
                    )
                  : const SizedBox.expand(key: ValueKey('founder-poster')),
            ),
            if (_state == _VideoState.unavailable)
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    l10n.rahmasVideoWillBeHereSoon,
                    key: const ValueKey('founder-video-unavailable'),
                    textAlign: TextAlign.center,
                    style: AppText.bodyM.copyWith(color: AppColors.onSurface),
                  ),
                ),
              ),
            if (ready)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: _start,
                  child: const SizedBox.expand(),
                ),
              ),
            if (!playing && _state != _VideoState.unavailable)
              Center(
                child: _RoundButton(
                  key: const ValueKey('founder-play'),
                  icon: _state == _VideoState.loading
                      ? Icons.hourglass_empty
                      : Icons.play_arrow_rounded,
                  label: l10n.playTheVideo,
                  size: 64,
                  onTap: _start,
                ),
              ),
            if (ready && playing)
              Align(
                alignment: AlignmentDirectional.bottomStart,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: _RoundButton(
                    key: const ValueKey('founder-pause'),
                    icon: Icons.pause_rounded,
                    label: l10n.pauseTheVideo,
                    onTap: _start,
                  ),
                ),
              ),
            if (ready)
              Align(
                alignment: AlignmentDirectional.bottomEnd,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: _RoundButton(
                    key: const ValueKey('founder-mute'),
                    icon: _muted
                        ? Icons.volume_off_rounded
                        : Icons.volume_up_rounded,
                    label: _muted ? l10n.turnSoundOn : l10n.turnSoundOff,
                    onTap: _toggleMute,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.size = 44,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: AppColors.surface.withValues(alpha: 0.9),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(icon, color: AppColors.onSurface, size: size * 0.5),
          ),
        ),
      ),
    );
  }
}
