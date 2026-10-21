/// Whether the kitten moves. Always on: the phone's Reduce Motion setting is
/// the only thing that holds it still.
library;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The SharedPreferences key an earlier version stored her choice under.
/// Cleared with everything else on the phone when she deletes her data.
const String kKittenMovesKey = 'own_hub.kitten_moves';

class KittenSetting extends ChangeNotifier {
  KittenSetting._();

  static final KittenSetting instance = KittenSetting._();

  bool get moves => true;

  /// The old key gone.
  Future<void> erase() async {
    try {
      await (await SharedPreferences.getInstance()).remove(kKittenMovesKey);
    } catch (_) {}
  }
}
