/// Plays one exercise clip from a file on the phone, inside the page.
///
/// No player of its own: no controls bar, no scrubber, no full-screen button.
/// The clip is drawn inside R15's [AppMedia] frame like any picture on the
/// page, muted and looping, and a tap pauses it. Muted, because the clips are
/// silent by design (the owner removed their sound), and mixed with others,
/// because a silent clip must never stop the music she is training to.
///
/// The only file that imports `video_player`, so a test can hand R15 a fake
/// and never touch a platform channel.
library;

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:video_player/video_player.dart';

abstract class ExerciseClipPlayer {
  /// Loads [clip]. False when it cannot be played. Never throws.
  Future<bool> open(File clip);

  Future<void> play();
  Future<void> pause();
  bool get playing;

  /// Width over height of the clip, once open.
  double get aspectRatio;

  /// The picture itself, once open.
  Widget view();

  Future<void> dispose();
}

typedef ExerciseClipPlayerFactory = ExerciseClipPlayer Function();

class VideoPlayerClipPlayer implements ExerciseClipPlayer {
  VideoPlayerController? _controller;

  @override
  Future<bool> open(File clip) async {
    try {
      final controller = VideoPlayerController.file(
        clip,
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      _controller = controller;
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(0);
      return controller.value.isInitialized && !controller.value.hasError;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> play() async {
    try {
      await _controller?.play();
    } catch (_) {}
  }

  @override
  Future<void> pause() async {
    try {
      await _controller?.pause();
    } catch (_) {}
  }

  @override
  bool get playing => _controller?.value.isPlaying ?? false;

  @override
  double get aspectRatio {
    final ratio = _controller?.value.aspectRatio ?? 0;
    return ratio > 0 ? ratio : 9 / 16;
  }

  @override
  Widget view() {
    final controller = _controller;
    if (controller == null) return const SizedBox.shrink();
    return VideoPlayer(controller);
  }

  @override
  Future<void> dispose() async {
    final controller = _controller;
    _controller = null;
    try {
      await controller?.dispose();
    } catch (_) {}
  }
}
