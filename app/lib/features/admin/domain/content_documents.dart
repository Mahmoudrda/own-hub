/// The seam between the content library and Firestore.
///
/// Four collections and three recipe-library documents, addressed by path:
/// `exercises/{id}`, `foods/{id}`, `programs/{id}`, `recipes/{id}`,
/// `recipeIndex/{locale}_v{n}` and `meta/recipes`. All of them are
/// `allow write: if isAdmin()` in `firestore.rules`, so the same calls that
/// work from the owner's account are refused from any other.
///
/// An interface, so [RemoteContentRepository] is tested end to end against
/// [InMemoryContentDocuments] and the Firestore class beside it stays a thin
/// adapter with nothing in it to get wrong.
library;

abstract class ContentDocuments {
  /// Every document in [collection], by id.
  Future<Map<String, Map<String, Object?>>> readCollection(String collection);

  /// One document, or null when it does not exist.
  Future<Map<String, Object?>?> read(String path);

  /// Writes every document in [writes] (path to body), replacing what was
  /// there, all or nothing.
  Future<void> commit(Map<String, Map<String, Object?>> writes);
}

/// [ContentDocuments] in memory: tests, and the round trip into the member
/// app's recipe reader.
class InMemoryContentDocuments implements ContentDocuments {
  final Map<String, Map<String, Object?>> docs = {};

  /// Every commit, in order, as its list of paths.
  final List<List<String>> commits = [];

  /// When set, every commit throws it. A refused write, as the rules would.
  Object? refuseWith;

  @override
  Future<Map<String, Map<String, Object?>>> readCollection(
    String collection,
  ) async => {
    for (final entry in docs.entries)
      if (entry.key.startsWith('$collection/') &&
          !entry.key.substring(collection.length + 1).contains('/'))
        entry.key.substring(collection.length + 1): Map.of(entry.value),
  };

  @override
  Future<Map<String, Object?>?> read(String path) async {
    final doc = docs[path];
    return doc == null ? null : Map.of(doc);
  }

  @override
  Future<void> commit(Map<String, Map<String, Object?>> writes) async {
    final refusal = refuseWith;
    if (refusal != null) throw refusal;
    for (final entry in writes.entries) {
      docs[entry.key] = Map.of(entry.value);
    }
    commits.add(writes.keys.toList());
  }
}
