/// [ContentDocuments] over Firestore. A thin adapter: paths in, plain maps out.
///
/// Every write here is refused by `firestore.rules` unless the signed-in
/// account holds the `admin` claim, so this class needs no check of its own.
/// A commit is one batch, which Firestore applies all or nothing; a batch is
/// capped at 500 writes, so a larger import is split and each part is atomic
/// on its own.
library;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/content_documents.dart';

class FirestoreContentDocuments implements ContentDocuments {
  FirestoreContentDocuments(this._db);

  final FirebaseFirestore _db;

  static const int _batchLimit = 450;

  static Object? _plain(Object? value) => switch (value) {
    Timestamp() => value.toDate().toUtc().toIso8601String(),
    Map() => {for (final e in value.entries) '${e.key}': _plain(e.value)},
    List() => [for (final v in value) _plain(v)],
    _ => value,
  };

  static Map<String, Object?> _plainDoc(Map<String, dynamic> data) => {
    for (final e in data.entries) e.key: _plain(e.value),
  };

  @override
  Future<Map<String, Map<String, Object?>>> readCollection(
    String collection,
  ) async {
    final snapshot = await _db
        .collection(collection)
        .get()
        .timeout(const Duration(seconds: 30));
    return {for (final doc in snapshot.docs) doc.id: _plainDoc(doc.data())};
  }

  @override
  Future<Map<String, Object?>?> read(String path) async {
    final doc = await _db
        .doc(path)
        .get(const GetOptions(source: Source.server))
        .timeout(const Duration(seconds: 15));
    final data = doc.data();
    return data == null ? null : _plainDoc(data);
  }

  @override
  Future<void> commit(Map<String, Map<String, Object?>> writes) async {
    final entries = writes.entries.toList();
    for (var start = 0; start < entries.length; start += _batchLimit) {
      final batch = _db.batch();
      for (final entry in entries.skip(start).take(_batchLimit)) {
        batch.set(_db.doc(entry.key), entry.value);
      }
      await batch.commit().timeout(const Duration(seconds: 30));
    }
  }
}
