/// Keeps the screen on while a workout is live.
///
/// A phone set down between sets used to lock itself, and the next set meant a
/// passcode with chalk on her hands. The workout asks for the screen to stay
/// awake when it starts and lets go when it ends, and this also lets go while
/// the app is in the background and takes hold again when she comes back.
///
/// No package: Android sets the window flag through the `keepScreenOn` method
/// on the settings channel, iOS turns its idle timer off through its own
/// channel. A phone that refuses, or a platform with neither, changes nothing:
/// a failure here must never touch a workout.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

const MethodChannel _androidChannel = MethodChannel('com.ownhub.app/settings');
const MethodChannel _iosChannel = MethodChannel('com.ownhub.app/screen');

Future<void> _platformKeepOn(bool on) async {
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      await _androidChannel.invokeMethod<void>('keepScreenOn', on);
    case TargetPlatform.iOS:
      await _iosChannel.invokeMethod<void>('keepScreenOn', on);
    default:
      break;
  }
}

class ScreenAwake with WidgetsBindingObserver {
  /// [apply] does the platform work. Tests hand in their own.
  ScreenAwake({Future<void> Function(bool on)? apply})
    : _apply = apply ?? _platformKeepOn;

  /// The one the workout uses. Tests replace it.
  static ScreenAwake instance = ScreenAwake();

  final Future<void> Function(bool on) _apply;
  bool _wanted = false;
  bool _applied = false;
  bool _observing = false;

  /// Asks for the screen to stay on ([on]) or to go back to its own timeout.
  void set(bool on) {
    _wanted = on;
    if (on) _observe();
    _push(on);
  }

  void _observe() {
    if (_observing) return;
    try {
      WidgetsBinding.instance.addObserver(this);
      _observing = true;
    } catch (_) {
      // No binding yet (a plain unit test): the lifecycle is not ours to watch.
    }
  }

  void _push(bool on) {
    if (_applied == on) return;
    _applied = on;
    unawaited(_run(on));
  }

  Future<void> _run(bool on) async {
    try {
      await _apply(on);
    } catch (_) {
      // The screen may lock; the workout carries on.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_wanted) return;
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        _push(false);
      case AppLifecycleState.resumed:
        _push(true);
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }
}
