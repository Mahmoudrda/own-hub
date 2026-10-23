/// The two small first-time moments of setup, each shown once on a phone: the
/// deep breath before the questions and the tick she draws to promise herself
/// her plan.
///
/// Nothing is due until [load] has read the phone, so a screen built on its
/// own never plays one.
library;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String kBreathSeenKey = 'own_hub.breath_seen';
const String kTickPromiseSeenKey = 'own_hub.tick_promise_seen';

class FirstRunMoments {
  FirstRunMoments._();

  static final FirstRunMoments instance = FirstRunMoments._();

  bool _loaded = false;
  bool _breathSeen = false;
  bool _tickSeen = false;

  /// True on the very first launch, until the breath has been shown once.
  bool get breathDue => _loaded && !_breathSeen;

  /// True until she has been asked to draw the tick once.
  bool get tickDue => _loaded && !_tickSeen;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _breathSeen = prefs.getBool(kBreathSeenKey) ?? false;
      _tickSeen = prefs.getBool(kTickPromiseSeenKey) ?? false;
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

  Future<void> _write(String key) async {
    try {
      await (await SharedPreferences.getInstance()).setBool(key, true);
    } catch (_) {}
  }

  /// Both gone, as when she deletes everything. Treated as seen until the next
  /// [load], so nothing replays inside the same run.
  Future<void> erase() async {
    _breathSeen = true;
    _tickSeen = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(kBreathSeenKey);
      await prefs.remove(kTickPromiseSeenKey);
    } catch (_) {}
  }

  @visibleForTesting
  void debugSet({
    bool loaded = true,
    bool breathSeen = false,
    bool tickSeen = false,
  }) {
    _loaded = loaded;
    _breathSeen = breathSeen;
    _tickSeen = tickSeen;
  }
}
