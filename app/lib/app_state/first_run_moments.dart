/// The small first-time moments, each shown once on a phone: the deep breath
/// before the questions, the tick she draws to promise herself her plan, and
/// the sentence on E03 that says who turns her voice into text.
///
/// Nothing is due until [load] has read the phone, so a screen built on its
/// own never plays one.
library;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String kBreathSeenKey = 'own_hub.breath_seen';
const String kTickPromiseSeenKey = 'own_hub.tick_promise_seen';
const String kVoiceExplainedKey = 'own_hub.voice_explained';

class FirstRunMoments {
  FirstRunMoments._();

  static final FirstRunMoments instance = FirstRunMoments._();

  bool _loaded = false;
  bool _breathSeen = false;
  bool _tickSeen = false;
  bool _voiceSeen = false;

  /// True on the very first launch, until the breath has been shown once.
  bool get breathDue => _loaded && !_breathSeen;

  /// True until she has been asked to draw the tick once.
  bool get tickDue => _loaded && !_tickSeen;

  /// True once she has tapped the microphone on E03 after reading who turns
  /// her words into text. Until then E03 never starts listening by itself,
  /// whatever the phone has already allowed.
  bool get voiceExplained => _loaded && _voiceSeen;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _breathSeen = prefs.getBool(kBreathSeenKey) ?? false;
      _tickSeen = prefs.getBool(kTickPromiseSeenKey) ?? false;
      _voiceSeen = prefs.getBool(kVoiceExplainedKey) ?? false;
      _loaded = true;
    } catch (_) {
      _loaded = false;
    }
  }

  void markBreathSeen() {
    _breathSeen = true;
    _write(kBreathSeenKey);
  }

  void markTickSeen() {
    _tickSeen = true;
    _write(kTickPromiseSeenKey);
  }

  void markVoiceExplained() {
    _voiceSeen = true;
    _write(kVoiceExplainedKey);
  }

  Future<void> _write(String key) async {
    try {
      await (await SharedPreferences.getInstance()).setBool(key, true);
    } catch (_) {}
  }

  /// All gone, as when she deletes everything. The two setup moments are
  /// treated as seen until the next [load], so nothing replays inside the same
  /// run; the voice sentence is owed again.
  Future<void> erase() async {
    _breathSeen = true;
    _tickSeen = true;
    _voiceSeen = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(kBreathSeenKey);
      await prefs.remove(kTickPromiseSeenKey);
      await prefs.remove(kVoiceExplainedKey);
    } catch (_) {}
  }

  @visibleForTesting
  void debugSet({
    bool loaded = true,
    bool breathSeen = false,
    bool tickSeen = false,
    bool voiceSeen = false,
  }) {
    _loaded = loaded;
    _breathSeen = breathSeen;
    _tickSeen = tickSeen;
    _voiceSeen = voiceSeen;
  }
}
