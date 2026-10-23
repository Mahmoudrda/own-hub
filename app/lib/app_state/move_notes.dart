/// A short note she keeps for a move ("seat 4, pin 3").
///
/// Phone only: it is kept in the local snapshot, is in no cloud document and is
/// never sent to analytics, and Delete everything clears it.
library;

import 'app_changes.dart';

/// The longest note, in characters.
const int kMoveNoteMaxLength = 80;

class MoveNotes {
  MoveNotes._();

  static final MoveNotes instance = MoveNotes._();

  final Map<String, String> _notes = <String, String>{};

  /// True once she has written a note for any move.
  bool get touched => _notes.isNotEmpty;

  /// The note for [exerciseId], or null when there is none.
  String? forMove(String? exerciseId) =>
      exerciseId == null ? null : _notes[exerciseId];

  /// Keeps [text] as [exerciseId]'s note: trimmed and cut at
  /// [kMoveNoteMaxLength]. Empty removes it.
  void setFor(String exerciseId, String text) {
    if (exerciseId.isEmpty) return;
    final clean = _clean(text);
    if (clean.isEmpty) {
      if (_notes.remove(exerciseId) != null) AppChanges.bump();
      return;
    }
    if (_notes[exerciseId] == clean) return;
    _notes[exerciseId] = clean;
    AppChanges.bump();
  }

  static String _clean(String text) {
    final trimmed = text.trim();
    if (trimmed.length <= kMoveNoteMaxLength) return trimmed;
    return trimmed.substring(0, kMoveNoteMaxLength).trim();
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
