/// When each account on this phone first landed, for the getting started tips.
///
/// The tips run once per woman, over the fortnight after she first lands
/// (`features/train/domain/getting_started_tips.dart`). Sign-out resets the
/// reminders with everything else she set, and the series used to go with
/// them, so a woman who had used the app for months signed back in to all
/// seven tips again. Kept here, under its own key and by uid, the day she
/// first landed survives a sign-out and a change of account on the phone; an
/// old anchor ends the series by itself, and a new account has none.
///
/// Nothing here leaves the phone. Deleting her data erases it.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'local_persistence.dart';

/// The SharedPreferences key the anchors live under.
const String kTipAnchorsKey = 'own_hub.tip_anchors';

class TipAnchors {
  TipAnchors._();

  static final TipAnchors instance = TipAnchors._();

  /// Where the anchors are kept. Replaceable so a test can hold them in memory.
  SnapshotStorage storage = const PreferencesSnapshotStorage(
    key: kTipAnchorsKey,
  );

  final Map<String, DateTime> _byUid = <String, DateTime>{};

  /// Writes and erases, one after another in the order they were asked for.
  /// Two calls into preferences can otherwise land out of order, and an
  /// erase overtaken by an earlier write would leave the anchors behind.
  Future<void> _last = Future<void>.value();

  Future<void> _then(Future<void> Function() step) =>
      _last = _last.then((_) => step()).catchError((Object _) {});

  /// Reads the stored anchors. Called once at start-up. Never throws: an
  /// unreadable store reads as none.
  Future<void> load() async {
    try {
      final raw = await storage.read();
      _byUid.clear();
      if (raw == null) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      for (final entry in decoded.entries) {
        final at = entry.value is String
            ? DateTime.tryParse(entry.value as String)
            : null;
        if (entry.key is String && at != null) {
          _byUid[entry.key as String] = at;
        }
      }
    } catch (_) {
      _byUid.clear();
    }
  }

  /// When [uid] first landed, or null for an account new to this phone.
  DateTime? anchorFor(String uid) => _byUid[uid];

  /// Records [anchor] for [uid] unless it already has one.
  void rememberIfAbsent(String uid, DateTime anchor) {
    if (uid.isEmpty || _byUid.containsKey(uid)) return;
    _byUid[uid] = anchor;
    unawaited(_save());
  }

  /// Forgets every anchor. Deleting her data calls it.
  Future<void> erase() {
    _byUid.clear();
    return _then(storage.erase);
  }

  Future<void> _save() {
    final document = jsonEncode(<String, String>{
      for (final entry in _byUid.entries)
        entry.key: entry.value.toIso8601String(),
    });
    // A failed write leaves the in-memory anchor for the rest of this run.
    return _then(() => storage.write(document));
  }

  @visibleForTesting
  void resetForTest() {
    _byUid.clear();
    _last = Future<void>.value();
    storage = const PreferencesSnapshotStorage(key: kTipAnchorsKey);
  }
}
