/// Her two switches for how the app answers a touch: sounds and haptics.
///
/// Both start on and are hers to turn off from Profile. They belong to this
/// phone and not to an account, so they live in their own two keys, are read
/// before the first screen, and are left alone by signing out or deleting her
/// data: a woman who silenced the app at the gym should not find it loud again
/// because she signed in.
library;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String kSoundsOnKey = 'own_hub.sounds_on';
const String kHapticsOnKey = 'own_hub.haptics_on';

class FeelPrefs extends ChangeNotifier {
  FeelPrefs._();

  static final FeelPrefs instance = FeelPrefs._();

  bool _sounds = true;
  bool _haptics = true;

  /// Whether the cues in `sound.dart` may play. Her switch only: the phone's
  /// Reduce Motion setting does not turn sound off.
  bool get sounds => _sounds;

  /// Whether `AppHaptics` may touch her. The phone's own setting still wins.
  bool get haptics => _haptics;

  /// Reads both from the phone. A phone that cannot be read leaves both on.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _sounds = prefs.getBool(kSoundsOnKey) ?? true;
      _haptics = prefs.getBool(kHapticsOnKey) ?? true;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> setSounds(bool on) async {
    if (_sounds == on) return;
    _sounds = on;
    notifyListeners();
    await _write(kSoundsOnKey, on);
  }

  Future<void> setHaptics(bool on) async {
    if (_haptics == on) return;
    _haptics = on;
    notifyListeners();
    await _write(kHapticsOnKey, on);
  }

  Future<void> _write(String key, bool value) async {
    try {
      await (await SharedPreferences.getInstance()).setBool(key, value);
    } catch (_) {}
  }

  /// Both back on, in memory only. For tests.
  @visibleForTesting
  void debugReset() {
    _sounds = true;
    _haptics = true;
  }
}
