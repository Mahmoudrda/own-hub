/// Plays Rahma's welcome video from its address, inside the page.
///
/// The only file in the signup feature that imports `video_player`, so a test
/// can hand the welcome a fake and never touch a platform channel. The
/// controller is created when she taps play, not when the page opens: nothing
/// is fetched, and no sound is possible, until she asks.
library;

import 'package:flutter/widgets.dart';
import 'package:video_player/video_player.dart';

abstract class FounderVideoPlayer {
  /// Loads the video. False when it cannot be played. Never throws.
  Future<bool> open(String url);

  Future<void> play();
  Future<void> pause();
  Future<void> setMuted(bool muted);

  bool get playing;

  /// Width over height, once open.
  double get aspectRatio;

  /// The picture, once open.
  Widget view();

  Future<void> dispose();
}

typedef FounderVideoPlayerFactory = FounderVideoPlayer Function();

class VideoPlayerFounder implements FounderVideoPlayer {
  VideoPlayerController? _controller;

  @override
  Future<bool> open(String url) async {
    try {
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(url),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      _controller = controller;
      await controller.initialize();
      await controller.setLooping(true);
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
  Future<void> setMuted(bool muted) async {
    try {
      await _controller?.setVolume(muted ? 0 : 1);
    } catch (_) {}
  }

  @override
  bool get playing => _controller?.value.isPlaying ?? false;

  @override
  double get aspectRatio {
    final ratio = _controller?.value.aspectRatio ?? 9 / 16;
    return ratio > 0 ? ratio : 9 / 16;
  }

  @override
  Widget view() {
    final controller = _controller;
    return controller == null
        ? const SizedBox.shrink()
        : VideoPlayer(controller);
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
