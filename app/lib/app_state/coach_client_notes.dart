/// The private note a coach keeps about each client ("knee, ask about
/// Thursday").
///
/// Phone only: it lives in the local snapshot, is in no cloud document and is
/// never sent to analytics, and Delete everything clears it. It is keyed by the
/// client's uid so it survives a renewed package.
library;

import 'app_changes.dart';

/// The longest note, in characters.
const int kCoachClientNoteMaxLength = 500;

class CoachClientNotes {
  CoachClientNotes._();

  static final CoachClientNotes instance = CoachClientNotes._();

  final Map<String, String> _notes = <String, String>{};

  /// True once she has written a note for any client.
  bool get touched => _notes.isNotEmpty;

  /// The note for [clientUid], or empty when there is none.
  String forClient(String? clientUid) =>
      clientUid == null ? '' : (_notes[clientUid] ?? '');

  /// Keeps [text] as [clientUid]'s note: trimmed and cut at
  /// [kCoachClientNoteMaxLength]. Empty removes it.
  void setFor(String clientUid, String text) {
    if (clientUid.isEmpty) return;
    final clean = _clean(text);
    if (clean.isEmpty) {
      if (_notes.remove(clientUid) != null) AppChanges.bump();
      return;
    }
    if (_notes[clientUid] == clean) return;
    _notes[clientUid] = clean;
    AppChanges.bump();
  }

  static String _clean(String text) {
    final trimmed = text.trim();
    if (trimmed.length <= kCoachClientNoteMaxLength) return trimmed;
    return trimmed.substring(0, kCoachClientNoteMaxLength).trim();
  }

  /// For the snapshot.
  Map<String, String> toJson() => Map<String, String>.of(_notes);

  /// Puts back what the snapshot held; empty notes and ids are dropped.
  void restore(Map<String, String> saved) {
    _notes
      ..clear()
      ..addEntries([
        for (final entry in saved.entries)
          if (entry.key.isNotEmpty && _clean(entry.value).isNotEmpty)
            MapEntry(entry.key, _clean(entry.value)),
      ]);
  }

  /// Back to no notes. Delete everything, and tests.
  void reset() => _notes.clear();
}
