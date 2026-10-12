/// The switches a member's app takes from the server.
///
/// Feature flags are compiled in (`FeatureFlags.shipped`). Two things need an
/// answer that does not wait for a release, and `meta/features` gives it: a
/// verified woman reads it once a launch, and only an admin writes it
/// (firestore.rules, `meta/{docId}`). Each key is a [Feature]'s name.
///
///  * **Off, when something breaks.** `{recipes: false}` takes recipes out
///    of every member's app at her next launch, and nothing else. Any feature
///    whose [Feature.serverMayTurnOff] is true can be stopped this way.
///  * **On, for what the owner runs herself.** `{events: true}`. Only a
///    feature whose [Feature.serverMayTurnOn] is true can be switched on from
///    the document; `true` on any other key only lifts an earlier `false`,
///    back to what the build ships.
///
/// What the document can never do is the point of it. It cannot switch on
/// the community, the coach side or the assistant, which wait for a release
/// that has their back ends, and it cannot switch off the whole-app gate,
/// sign-up, verification, Home or the privacy centre. A remote document that
/// could would be a way round every safety argument this product has made.
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
  /// Whether `meta/features` can move [feature] in either direction.
  static bool isSwitchable(Feature feature) =>
      feature.serverMayTurnOff || feature.serverMayTurnOn;

  /// What the document said at the last read, for `Z14`. Empty until then.
  static Map<Feature, bool> lastRead = const {};

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

  /// The overrides [data] is allowed to make. Every other key, and every
  /// value that is not a bool, is ignored.
  static Map<Feature, bool> overridesFrom(Map<String, Object?> data) => {
    for (final f in Feature.values)
      if (data[f.name] case final bool on)
        if (on ? f.serverMayTurnOn : f.serverMayTurnOff) f: on,
  };

  /// Lays the server's answer over [AppRouter.featureFlags]. Never throws; on
  /// any failure the compiled-in values stand.
  static Future<void> load() async {
    if (!AppRouter.isVerified) return;
    final source = store();
    if (source == null) return;
    try {
      final data = await source.read();
      if (data == null) return;
      lastRead = {
        for (final f in Feature.values)
          if (data[f.name] case final bool on) f: on,
      };
      final overrides = overridesFrom(data);
      if (overrides.isEmpty) return;
      AppRouter.featureFlags = AppRouter.featureFlags.with_(overrides);
      AppChanges.bump();
    } catch (_) {
      // Offline, or not allowed to read: the shipped values are the answer.
    }
  }

  /// `Z14`: writes the owner's switch for every member. True when it landed.
  ///
  /// Refuses what the document could not act on: switching on a feature the
  /// server may not turn on is allowed only as lifting a stop, so it needs
  /// [Feature.serverMayTurnOff]; switching off needs it too.
  static Future<bool> publish(Feature feature, bool on) async {
    final allowed = on
        ? feature.serverMayTurnOn || feature.serverMayTurnOff
        : feature.serverMayTurnOff;
    if (!allowed) return false;
    final source = store();
    if (source == null) return false;
    try {
      await source.write(feature.name, on);
      lastRead = {...lastRead, feature: on};
      return true;
    } catch (_) {
      return false;
    }
  }
}
