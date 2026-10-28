/// The short sounds that answer what she did: a set logged, a rest ending, the
/// finish, a meal added, the check passed.
///
/// A screen asks for a cue by id and never by file, the way it asks
/// [AppHaptics] for a moment. Every cue pairs with something she can see and
/// usually with a touch, and never carries information alone.
///
/// # Respect for the phone
///
/// - **Silent switch and volume.** The files play on the ambient audio
///   session on iPhone and with the sonification usage on Android, both of
///   which the Silent switch and the volume keys decide.
/// - **Her music.** No audio focus is asked for and nothing is ducked: a
///   podcast keeps playing under a set. Calls and other apps' sound are the
///   system's to arbitrate.
/// - **Foreground only.** Nothing plays unless the app is the one in front.
/// - **Never on its own.** Nothing plays until she has touched the app in
///   this run (a tap, or a screen reader's activation), so a screen that opens
///   by itself, from a notification or a restored session, stays quiet.
/// - **Her switch.** [FeelPrefs.sounds], and [Feature.sounds] for the server.
///   Reduce Motion does not turn sound off, and this does not read it.
/// - **Restraint.** The same cue at most once per [minGap], so a double tap
///   never stutters.
///
/// Nothing is a no-op by accident: until [start] has loaded the files the
/// service plays nothing, which is also what keeps every widget test silent.
library;

import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';

import '../domain/flags/feature_flags.dart';
import '../routing/app_router.dart';
import 'feel_prefs.dart';

/// Every cue a screen may ask for. Each has a row in [kSoundCues].
enum SoundCue {
  /// A set logged (M3). Five pitches, one per set of the move.
  setDone,

  /// One of the last three seconds of a rest (M4).
  restTick,

  /// A rest that ran out in front of her (M4).
  restEnd,

  /// The finish, R10 (M5).
  sessionDone,

  /// The finish, when she really beat a best (M5).
  personalBest,

  /// The week reached its goal (M6). In the library, not yet played.
  weekClosed,

  /// A meal added (M8).
  foodLogged,

  /// A meal taken back inside its five seconds (M8).
  undo,

  /// A real milestone (M9). In the library, not yet played.
  milestone,

  /// The women-only check passed (M10).
  verified,

  /// A small "saved" (M1). In the library, not yet played.
  saved,
}

/// What one cue is made of and the limits its files are held to.
@immutable
class SoundSpec {
  const SoundSpec({
    required this.files,
    required this.lengthCap,
    required this.level,
  });

  /// Bundle keys, as listed in `pubspec.yaml`. A cue with several files picks
  /// one by its variant (set 1 to 5 of a move for [SoundCue.setDone]).
  final List<String> files;

  /// No file of this cue is longer than this.
  final Duration lengthCap;

  /// What the files were set to. See `assets/sounds/SOUNDS.md`.
  final String level;
}

const String _peak12 = 'peak -12 dBFS';

/// The cue table. Files are made by `tool/make_sounds.py`.
const Map<SoundCue, SoundSpec> kSoundCues = <SoundCue, SoundSpec>{
  SoundCue.setDone: SoundSpec(
    files: <String>[
      'assets/sounds/set_done_1.wav',
      'assets/sounds/set_done_2.wav',
      'assets/sounds/set_done_3.wav',
      'assets/sounds/set_done_4.wav',
      'assets/sounds/set_done_5.wav',
    ],
    lengthCap: Duration(milliseconds: 300),
    level: _peak12,
  ),
  SoundCue.restTick: SoundSpec(
    files: <String>['assets/sounds/rest_tick.wav'],
    lengthCap: Duration(milliseconds: 150),
    level: 'peak -18 dBFS',
  ),
  SoundCue.restEnd: SoundSpec(
    files: <String>['assets/sounds/rest_end.wav'],
    lengthCap: Duration(milliseconds: 600),
    level: _peak12,
  ),
  SoundCue.sessionDone: SoundSpec(
    files: <String>['assets/sounds/session_done.wav'],
    lengthCap: Duration(seconds: 2),
    level: _peak12,
  ),
  SoundCue.personalBest: SoundSpec(
    files: <String>['assets/sounds/personal_best.wav'],
    lengthCap: Duration(seconds: 2),
    level: _peak12,
  ),
  SoundCue.weekClosed: SoundSpec(
    files: <String>['assets/sounds/week_closed.wav'],
    lengthCap: Duration(milliseconds: 1500),
    level: _peak12,
  ),
  SoundCue.foodLogged: SoundSpec(
    files: <String>['assets/sounds/food_logged.wav'],
    lengthCap: Duration(milliseconds: 500),
    level: _peak12,
  ),
  SoundCue.undo: SoundSpec(
    files: <String>['assets/sounds/undo.wav'],
    lengthCap: Duration(milliseconds: 500),
    level: _peak12,
  ),
  SoundCue.milestone: SoundSpec(
    files: <String>['assets/sounds/milestone.wav'],
    lengthCap: Duration(milliseconds: 1200),
    level: _peak12,
  ),
  SoundCue.verified: SoundSpec(
    files: <String>['assets/sounds/verified.wav'],
    lengthCap: Duration(milliseconds: 1200),
    level: _peak12,
  ),
  SoundCue.saved: SoundSpec(
    files: <String>['assets/sounds/saved.wav'],
    lengthCap: Duration(milliseconds: 300),
    level: _peak12,
  ),
};

/// Plays one bundled file. A seam so tests count plays without a plugin.
abstract interface class SoundBackend {
  /// Brings every file into memory so the first play is quick.
  Future<void> load(Iterable<String> bundleKeys);

  /// Plays [bundleKey] from the start. Never throws.
  Future<void> play(String bundleKey);
}

/// The real backend: one low-latency player per file, on the ambient session.
class AudioplayersSoundBackend implements SoundBackend {
  final Map<String, AudioPlayer> _players = <String, AudioPlayer>{};

  /// Ambient on iPhone (the Silent switch silences it, other audio is never
  /// interrupted); sonification with no focus request on Android (the system
  /// stream, so silent and vibrate modes silence it, and her music is never
  /// stopped or ducked).
  static final AudioContext _ambient = AudioContext(
    iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
    android: const AudioContextAndroid(
      contentType: AndroidContentType.sonification,
      usageType: AndroidUsageType.assistanceSonification,
      audioFocus: AndroidAudioFocus.none,
    ),
  );

  /// What the video player leaves the iPhone's session in: playback that
  /// mixes, so a muted exercise clip never stops her music and a voice note or
  /// a coach's video still plays with the Silent switch on. It is put back
  /// when the last cue has ended.
  static final AudioContext _afterwards = AudioContext(
    iOS: AudioContextIOS(
      category: AVAudioSessionCategory.playback,
      options: const {AVAudioSessionOptions.mixWithOthers},
    ),
  );

  static bool get _ios => defaultTargetPlatform == TargetPlatform.iOS;

  /// No cue runs longer than two seconds; a cue that never reports its end is
  /// given this long before the session is put back.
  static const Duration _longest = Duration(milliseconds: 2500);

  int _sounding = 0;

  // audioplayers keys assets from `assets/`, and the bundle key is the whole
  // path, so the prefix is taken off once here.
  static String _source(String bundleKey) =>
      bundleKey.substring('assets/'.length);

  @override
  Future<void> load(Iterable<String> bundleKeys) async {
    // The iPhone's session is touched only around a cue, never here: a video
    // that opens at launch sets it for itself.
    if (!_ios) await AudioPlayer.global.setAudioContext(_ambient);
    for (final key in bundleKeys) {
      final player = AudioPlayer();
      await player.setPlayerMode(PlayerMode.lowLatency);
      await player.setReleaseMode(ReleaseMode.stop);
      if (!_ios) await player.setAudioContext(_ambient);
      await player.setSource(AssetSource(_source(key)));
      _players[key] = player;
    }
  }

  @override
  Future<void> play(String bundleKey) async {
    final player = _players[bundleKey];
    if (player == null) return;
    try {
      // Video and voice features change the iPhone's session while she uses
      // them. Ambient is put back before every cue so the Silent switch is
      // always honoured.
      if (_ios) await AudioPlayer.global.setAudioContext(_ambient);
      if (player.state == PlayerState.playing) await player.stop();
      await player.resume();
      _sounding++;
      unawaited(_settle(player));
    } catch (_) {
      // A cue that cannot play is a missing nicety, never an error for her.
    }
  }

  Future<void> _settle(AudioPlayer player) async {
    try {
      await player.onPlayerComplete.first.timeout(_longest);
    } catch (_) {}
    _sounding--;
    if (_sounding > 0 || !_ios) return;
    try {
      await AudioPlayer.global.setAudioContext(_afterwards);
    } catch (_) {}
  }
}

abstract final class AppSound {
  /// The same cue is never played twice inside this.
  static const Duration minGap = Duration(milliseconds: 400);

  static SoundBackend? _backend;
  static bool _touched = false;
  static final Map<SoundCue, DateTime> _last = <SoundCue, DateTime>{};
  static final Set<Object> _onceKeys = <Object>{};

  /// The time the rate limit reads. Tests replace it.
  static DateTime Function() clock = DateTime.now;

  /// Whether her switch and the server allow sound. Tests replace it.
  static bool Function() enabled = () =>
      AppRouter.featureFlags.isOn(Feature.sounds) && FeelPrefs.instance.sounds;

  /// Loads the files and starts listening for her first touch. Call once,
  /// after the first frame is queued. Safe to call again.
  static Future<void> start({SoundBackend? backend}) async {
    if (_backend != null) return;
    _watchForTouch();
    final loading = backend ?? AudioplayersSoundBackend();
    try {
      await loading.load(<String>{
        for (final spec in kSoundCues.values) ...spec.files,
      });
      _backend = loading;
    } catch (_) {
      // No sound this run. Nothing else depends on it.
    }
  }

  /// Plays [cue], or does nothing. [variant] picks among a cue's files and is
  /// held to the ones it has.
  static Future<void> play(SoundCue cue, {int variant = 0}) async {
    final backend = _backend;
    if (backend == null || !_allowed(cue)) return;
    final files = kSoundCues[cue]!.files;
    final file = files[variant.clamp(0, files.length - 1)];
    _last[cue] = clock();
    await backend.play(file);
  }

  /// Plays [cue] the first time [key] is seen in this run, and never again.
  static Future<void> playOnce(
    SoundCue cue,
    Object key, {
    int variant = 0,
  }) async {
    if (_backend == null || _onceKeys.contains(key) || !_allowed(cue)) return;
    _onceKeys.add(key);
    await play(cue, variant: variant);
  }

  /// Whether a cue would play right now, for callers that would otherwise do
  /// work to decide (a meal's size) only to find it silent.
  static bool get active => _backend != null && _gates();

  static bool _gates() {
    if (!_touched || !enabled()) return false;
    final state = WidgetsBinding.instance.lifecycleState;
    return state == null || state == AppLifecycleState.resumed;
  }

  static bool _allowed(SoundCue cue) {
    if (!_gates()) return false;
    final last = _last[cue];
    return last == null || clock().difference(last) >= minGap;
  }

  static bool _watching = false;

  // A tap, or a screen reader's activation, which arrives as a semantics
  // action and not as a pointer.
  static void _watchForTouch() {
    if (_watching || _touched) return;
    _watching = true;
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onPointer);
    SemanticsBinding.instance.addSemanticsActionListener(_onAction);
  }

  static void _onPointer(PointerEvent event) {
    if (event is PointerDownEvent) _touch();
  }

  static void _onAction(Object _) => _touch();

  static void _touch() {
    if (_touched) return;
    _touched = true;
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_onPointer);
    SemanticsBinding.instance.removeSemanticsActionListener(_onAction);
  }

  /// Puts a recording backend in and marks her as having touched the app.
  @visibleForTesting
  static void debugUse(SoundBackend? backend, {bool touched = true}) {
    _backend = backend;
    _touched = touched;
    _watching = false;
    _last.clear();
    _onceKeys.clear();
  }

  /// Back to the state before [start]. Leaves the touch watch alone.
  @visibleForTesting
  static void debugReset() {
    debugUse(null, touched: false);
    clock = DateTime.now;
    enabled = () =>
        AppRouter.featureFlags.isOn(Feature.sounds) &&
        FeelPrefs.instance.sounds;
  }
}
