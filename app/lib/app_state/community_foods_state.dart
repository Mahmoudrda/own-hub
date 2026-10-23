/// The community foods on this phone, and her choice to share her own.
///
/// ## Receiving
///
/// The shared list is read from the cache at once and from Firestore when
/// due (`CommunityFoodsSync`), and merged into the food library
/// (`eatSampleLibrary`). Offline, or never published, the list is empty and
/// search is exactly what it was.
///
/// ## Giving
///
/// When she logs a checked photo meal, its dish name and numbers are offered
/// to the owner's review through `submit_community_food`, only if she turned
/// "Help other women log this dish" on. It is fire and forget: the log never
/// waits for it and never learns of a refusal. The switch is a preference on
/// this phone, off by default (she opts in), and E13 explains it until she has seen it once.
library;

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/eat/data/community_food_client.dart';
import '../features/eat/data/community_foods_sync.dart';
import '../features/eat/domain/community_foods.dart';
import '../features/eat/domain/food_library.dart';
import 'app_changes.dart';
import 'firebase_boot.dart';

/// Whether her confirmed dishes are offered to the shared list. Absent means on.
const String kShareDishesKey = 'own_hub.share_dishes';

/// Set once E13 has shown her the switch.
const String kShareDishesSeenKey = 'own_hub.share_dishes_seen';

/// Every preference this file keeps besides the cached list.
const List<String> kShareDishesKeys = <String>[
  kShareDishesKey,
  kShareDishesSeenKey,
];

class CommunityFoodsState extends ChangeNotifier {
  CommunityFoodsState._();

  static final CommunityFoodsState instance = CommunityFoodsState._();

  CommunityFoodsSync sync = CommunityFoodsSync(source: _liveSource);

  /// The callable. Replaced in tests.
  CommunityFoodClient client = CallableCommunityFoodClient();

  CommunityFoods list = CommunityFoods.empty;

  /// Off until she turns it on, like every sharing switch in the app.
  bool _sharing = false;
  bool _noticeSeen = false;
  Future<void>? _loadedList;
  Future<void>? _loadedSettings;

  /// Whether her confirmed dishes are offered. On until she turns it off.
  bool get sharing => _sharing;

  /// Whether E13 has already shown her the switch.
  bool get noticeSeen => _noticeSeen;

  static CommunityFoodsRemoteSource? _liveSource() {
    try {
      if (!FirebaseBoot.isReady) return null;
      return FirestoreCommunityFoodsSource(FirebaseFirestore.instance);
    } catch (_) {
      return null;
    }
  }

  /// The cache, then the server when due. Never throws.
  Future<void> refresh() async {
    try {
      _loadedList ??= sync.load().then(_adopt);
      await _loadedList;
      final (_, updated) = await sync.refresh();
      if (updated != null) _adopt(updated);
    } catch (_) {
      // The cached list, or none, is already the answer.
    }
  }

  void _adopt(CommunityFoods next) {
    if (next.version < list.version) return;
    list = next;
    AppChanges.bump();
  }

  /// The shared foods for search, named in her language.
  List<Food> foodsFor({required bool arabic}) => [
    for (final food in list.foods) food.toFood(arabic: arabic),
  ];

  /// Reads her two preferences once. Never throws.
  Future<void> loadSettings() => _loadedSettings ??= _readSettings();

  Future<void> _readSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _sharing = prefs.getBool(kShareDishesKey) ?? false;
      _noticeSeen = prefs.getBool(kShareDishesSeenKey) ?? false;
      notifyListeners();
    } catch (_) {
      // A store that cannot be read means the default: off, and explained.
    }
  }

  Future<void> setSharing(bool on) async {
    await loadSettings();
    _sharing = on;
    notifyListeners();
    try {
      await (await SharedPreferences.getInstance()).setBool(
        kShareDishesKey,
        on,
      );
    } catch (_) {}
  }

  /// E13 showed her the switch; it is not shown again.
  Future<void> markNoticeSeen() async {
    if (_noticeSeen) return;
    _noticeSeen = true;
    try {
      await (await SharedPreferences.getInstance()).setBool(
        kShareDishesSeenKey,
        true,
      );
    } catch (_) {}
  }

  /// Offers [dish] (see `MealCheck.communityDish`) when she shares. Her choice
  /// is read first, so a dish logged before the preference loaded is never
  /// sent on the default after she turned sharing off. Never throws and never
  /// waits for the server.
  Future<void> offer(Map<String, Object?>? dish) async {
    if (dish == null) return;
    await loadSettings();
    if (!_sharing) return;
    unawaited(_send(dish));
  }

  Future<void> _send(Map<String, Object?> dish) async {
    try {
      await client.submit(dish);
    } catch (error) {
      if (kDebugMode) debugPrint('Community food not shared: $error');
    }
  }

  /// Deleting her data on this phone: the cached list, its check time and
  /// her two preferences.
  Future<void> erase() async {
    list = CommunityFoods.empty;
    _sharing = false;
    _noticeSeen = false;
    _loadedList = null;
    _loadedSettings = null;
    sync = CommunityFoodsSync(source: _liveSource);
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final key in [...kCommunityFoodsCacheKeys, ...kShareDishesKeys]) {
        await prefs.remove(key);
      }
    } catch (_) {}
  }

  @visibleForTesting
  void reset() {
    list = CommunityFoods.empty;
    _sharing = false;
    _noticeSeen = false;
    _loadedList = null;
    _loadedSettings = null;
    sync = CommunityFoodsSync(source: _liveSource);
    client = CallableCommunityFoodClient();
  }
}
