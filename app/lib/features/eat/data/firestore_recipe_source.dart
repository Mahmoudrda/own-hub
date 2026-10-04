/// [RecipeRemoteSource] over Firestore.
///
/// Reads `meta/recipes`, `recipeIndex/{locale}_v{N}` and `recipes/{id}`. All
/// three are readable by a verified account under `firestore.rules` and
/// written only by an admin. Every read asks the server: the Firestore offline
/// cache could otherwise answer with an older document, and the seed or the
/// recipe cache is the offline answer here.
library;

import 'package:cloud_firestore/cloud_firestore.dart';

import 'recipe_sync.dart';

class FirestoreRecipeSource implements RecipeRemoteSource {
  FirestoreRecipeSource(this._db);

  final FirebaseFirestore _db;

  static const GetOptions _server = GetOptions(source: Source.server);

  @override
  Future<int?> readVersion() async {
    final doc = await _db.doc('meta/recipes').get(_server);
    final version = doc.data()?['version'];
    return version is int ? version : null;
  }

  @override
  Future<Map<String, Object?>?> readIndex(int version) async {
    final doc = await _db
        .doc('recipeIndex/${kRecipeIndexLocale}_v$version')
        .get(_server);
    final data = doc.data();
    return data == null ? null : plainFirestoreData(data);
  }

  @override
  Future<Map<String, Object?>?> readRecipe(String recipeId) async {
    final doc = await _db.collection('recipes').doc(recipeId).get(_server);
    final data = doc.data();
    return data == null ? null : plainFirestoreData(data);
  }
}

/// A Firestore document as the plain JSON the seed is written in.
///
/// The only change is the representation of a [Timestamp], which becomes the
/// ISO 8601 string `Recipe.fromJson` reads. Strings, her text included, pass
/// through untouched.
Map<String, Object?> plainFirestoreData(Map<String, Object?> data) =>
    data.map((key, value) => MapEntry(key, _plain(value)));

Object? _plain(Object? value) => switch (value) {
  Timestamp() => value.toDate().toUtc().toIso8601String(),
  Map() => {
    for (final entry in value.entries) '${entry.key}': _plain(entry.value),
  },
  List() => [for (final item in value) _plain(item)],
  _ => value,
};
