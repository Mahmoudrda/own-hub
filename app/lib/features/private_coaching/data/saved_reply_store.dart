/// A coach's saved replies, kept on her phone under one key per coach.
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class SavedReply {
  const SavedReply({required this.id, required this.text});
  final String id;
  final String text;
}

const int kSavedReplyMax = 20;
const int kSavedReplyChars = 300;

class SavedReplyStore {
  // ignore: prefer_initializing_formals
  SavedReplyStore({SharedPreferences? prefs}) : _prefs = prefs;
  SharedPreferences? _prefs;

  Future<SharedPreferences> get _p async =>
      _prefs ??= await SharedPreferences.getInstance();

  static const String _prefix = 'savedReplies.v1.';
  static String _key(String coachUid) => '$_prefix$coachUid';

  /// Every coach's list on this phone, for the wipe after an account is
  /// deleted: the lists are hers and nobody else's, so none may stay behind.
  static Future<void> eraseAll() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys().toList()) {
      if (key.startsWith(_prefix)) await prefs.remove(key);
    }
  }

  /// Her list; the first time ever, [seed] is copied in and stored.
  Future<List<SavedReply>> load(String coachUid, List<String> seed) async {
    final prefs = await _p;
    final raw = prefs.getString(_key(coachUid));
    if (raw == null) {
      final list = <SavedReply>[
        for (var i = 0; i < seed.length; i++)
          SavedReply(id: 's$i', text: seed[i]),
      ];
      await save(coachUid, list);
      return list;
    }
    try {
      final data = jsonDecode(raw) as List<Object?>;
      return <SavedReply>[
        for (final row in data)
          if (row is Map && row['id'] is String && row['text'] is String)
            SavedReply(id: row['id'] as String, text: row['text'] as String),
      ];
    } catch (_) {
      return const <SavedReply>[];
    }
  }

  Future<void> save(String coachUid, List<SavedReply> list) async {
    final prefs = await _p;
    await prefs.setString(
      _key(coachUid),
      jsonEncode(<Object?>[
        for (final r in list) <String, String>{'id': r.id, 'text': r.text},
      ]),
    );
  }
}
