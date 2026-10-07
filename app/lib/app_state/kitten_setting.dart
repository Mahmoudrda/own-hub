/// Whether the kitten moves, chosen in Profile.
///
/// On until she turns it off. Off, the kitten still shows her where to go but
/// never moves. One SharedPreferences key on this phone; nothing about it
/// goes to the server.
library;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The SharedPreferences key holding her choice. Cleared with everything else
/// on the phone when she deletes her data.
const String kKittenMovesKey = 'own_hub.kitten_moves';

class KittenSetting {
  KittenSetting._();

  static final KittenSetting instance = KittenSetting._();

  bool _moves = true;

  bool get moves => _moves;

  /// Reads the stored choice. Called once at start-up.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _moves = prefs.getBool(kKittenMovesKey) ?? true;
    } catch (_) {
      _moves = true;
    }
  }

  Future<void> set(bool moves) async {
    _moves = moves;
    try {
      await (await SharedPreferences.getInstance()).setBool(
        kKittenMovesKey,
        moves,
      );
    } catch (_) {
      // The in-memory value is what the screens read for the rest of this run.
    }
  }

  /// Back to the default, and the key gone.
  Future<void> erase() async {
    _moves = true;
    try {
      await (await SharedPreferences.getInstance()).remove(kKittenMovesKey);
    } catch (_) {}
  }

  @visibleForTesting
  void resetForTest({bool moves = true}) {
    _moves = moves;
  }
}
