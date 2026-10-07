/// The few switches a member's app takes from the server.
///
/// Feature flags are compiled in (`FeatureFlags.shipped`), so a switch the
/// owner flips on Z14 changes only the phone she is holding. For a feature the
/// owner runs herself, like events, that is the wrong answer: she should be
/// able to turn it on for everyone without a release. So the switches named in
/// [RemoteFeatures.switchable], and only those, are also kept in
/// `meta/features` (`{events: true}`), which a verified woman reads once a
/// launch and only an admin writes (firestore.rules, `meta/{docId}`).
///
/// Everything else stays compiled in. A remote document that could switch on
/// the community, or switch off the whole-app gate, would be a way round every
/// safety argument this product has made, so the list is short on purpose and
/// a test holds it to exactly one entry.
library;

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../domain/flags/feature_flags.dart';
import '../routing/app_router.dart';
import 'app_changes.dart';
import 'firebase_boot.dart';

/// Reads and writes `meta/features`.
abstract class FeatureSwitchStore {
  Future<Map<String, Object?>?> read();
  Future<void> write(String key, bool on);
}

class FirestoreFeatureSwitchStore implements FeatureSwitchStore {
  FirestoreFeatureSwitchStore(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> get _doc => _db.doc('meta/features');

  @override
  Future<Map<String, Object?>?> read() async =>
      (await _doc.get().timeout(const Duration(seconds: 8))).data();

  @override
  Future<void> write(String key, bool on) => _doc
      .set(<String, Object?>{key: on}, SetOptions(merge: true))
      .timeout(const Duration(seconds: 10));
}

abstract final class RemoteFeatures {
  /// The only switches the server may move, by their key in `meta/features`.
  static const Map<Feature, String> switchable = {Feature.events: 'events'};

  static bool isSwitchable(Feature feature) => switchable.containsKey(feature);

  /// Where the document is read from. Null when no read could succeed.
  static FeatureSwitchStore? Function() store = _liveStore;

  static FeatureSwitchStore? _liveStore() {
    try {
      if (!FirebaseBoot.isReady) return null;
      if (FirebaseAuth.instance.currentUser == null) return null;
      return FirestoreFeatureSwitchStore(FirebaseFirestore.instance);
    } catch (_) {
      return null;
    }
  }

  /// Lays the server's answer over [AppRouter.featureFlags]. Never throws; on
  /// any failure the compiled-in value stands, which for events is off.
  static Future<void> load() async {
    if (!AppRouter.isVerified) return;
    final source = store();
    if (source == null) return;
    try {
      final data = await source.read();
      if (data == null) return;
      final overrides = <Feature, bool>{
        for (final entry in switchable.entries)
          if (data[entry.value] case final bool on) entry.key: on,
      };
      if (overrides.isEmpty) return;
      AppRouter.featureFlags = AppRouter.featureFlags.with_(overrides);
      AppChanges.bump();
    } catch (_) {
      // Offline, or not allowed to read: the shipped value is the answer.
    }
  }

  /// Z14: writes the owner's switch for every member. True when it landed.
  static Future<bool> publish(Feature feature, bool on) async {
    final key = switchable[feature];
    if (key == null) return false;
    final source = store();
    if (source == null) return false;
    try {
      await source.write(key, on);
      return true;
    } catch (_) {
      return false;
    }
  }
}
