/// The content library, kept in Firestore and cached on the owner's phone.
///
/// [InMemoryContentRepository] is the cache the console's screens draw from
/// synchronously; this adds the server behind it. A save is written to
/// Firestore first and to the cache only once the server took it, so the
/// console never shows a row as saved that the library does not hold. With no
/// server reachable (no Firebase, nobody signed in) a save stays on this phone
/// and says so, rather than pretending.
///
/// Exercises and foods are written as typed documents (`exercises/{id}` and so
/// on): lists as arrays, numbers as numbers, the two booleans as booleans.
///
/// **A recipe** must reach the member app in the shape
/// `eat/data/recipe_sync.dart` reads and pass the rules it holds every recipe
/// to, and the library's index and version must move with it. So a recipe
/// save writes, in one batch: `recipes/{id}`, a new `recipeIndex/en_v{N}` and
/// `recipeIndex/ar_v{N}` carrying every row of the previous index plus this
/// one, and `meta/recipes = {version: N}`. A bulk import publishes every
/// recipe row the same way, in the same single batch.
///
/// **A programme** carries its sessions (`workout_library.dart`). Saving one
/// writes `programs/{id}` with them, and a new `workoutLibrary/v{N}` holding
/// every published programme with `meta/workouts = {version: N}`, again in one
/// batch. Each move takes its name, flags and contraindication tags from the
/// exercise library at that moment, so the phone can check a pregnancy
/// session for itself.
///
/// Anything the member app would refuse is refused here with
/// [RecipeNotReady] or [WorkoutNotReady], and nothing at all is written: one
/// bad document would otherwise make every phone refuse the whole library.
/// A draft is written and stays out of every member's library.
library;

import '../../train/domain/workout_library.dart';
import 'content_documents.dart';
import 'content_repository.dart';
import 'content_schema.dart';
import 'import_validator.dart';
import 'recipe_publishing.dart';

enum ContentSaveOutcome {
  /// In the library, for every device.
  saved,

  /// On this phone only: no server could be reached.
  savedHereOnly,
}

/// The member app would refuse this recipe. Nothing was written.
class RecipeNotReady implements Exception {
  const RecipeNotReady(this.problems);

  final List<String> problems;

  @override
  String toString() => 'RecipeNotReady(${problems.join('; ')})';
}

/// The member app would refuse this programme. Nothing was written.
class WorkoutNotReady implements Exception {
  const WorkoutNotReady(this.problems);

  final List<String> problems;

  @override
  String toString() => 'WorkoutNotReady(${problems.join('; ')})';
}

const String kRecipeMetaPath = 'meta/recipes';
const String kWorkoutMetaPath = 'meta/workouts';

String recipeIndexPath(String locale, int version) =>
    'recipeIndex/${locale}_v$version';

String workoutLibraryPath(int version) => 'workoutLibrary/v$version';

/// `exercises`, `foods`, `recipes`, `programs`, read off the contract.
String collectionName(ContentCollection collection) =>
    ContentSchema.of(collection).storagePrefix.split('/').last;

int _int(Object? v) => (v as num?)?.toInt() ?? 0;

class RemoteContentRepository extends InMemoryContentRepository {
  RemoteContentRepository({
    required this.documents,
    required this.seedRecipes,
    super.store,
    super.rows,
  });

  /// The server, or null when none can be reached right now.
  final ContentDocuments? Function() documents;

  /// The bundled recipe seed, as its JSON: `contentVersion` and `sections`.
  final Future<Map<String, Object?>> Function() seedRecipes;

  final Map<String, List<AuthoredSession>> _sessions = {};
  final Map<String, ProgrammeStatus> _programmeStatus = {};
  final Map<String, int> _programmeVersion = {};

  /// The sessions saved with programme [id], for Z13 to open on.
  List<AuthoredSession> sessionsFor(String id) =>
      List.unmodifiable(_sessions[id] ?? const <AuthoredSession>[]);

  /// Whether programme [id] is published to members.
  bool isPublished(String id) =>
      _programmeStatus[id] == ProgrammeStatus.published;

  /// Reads the four collections into the cache. False when no server could be
  /// reached or a read failed; the cache is then what it was.
  Future<bool> loadFromServer() async {
    final docs = documents();
    if (docs == null) return false;
    try {
      final loaded = <ContentCollection, Map<String, Map<String, Object?>>>{
        for (final collection in ContentCollection.values)
          collection: await docs.readCollection(collectionName(collection)),
      };
      for (final MapEntry(key: collection, value: byId) in loaded.entries) {
        for (final MapEntry(key: id, value: data) in byId.entries) {
          final values = collection == ContentCollection.recipes
              ? _recipeRow(data)
              : rowValuesOf(collection, data);
          if (values == null) continue;
          if (collection == ContentCollection.programmes) {
            _rememberProgramme(id, data);
          }
          store.rows[collection]![id] = ImportRow(
            collection: collection,
            id: id,
            isUpdate: true,
            values: values,
          );
        }
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  void _rememberProgramme(String id, Map<String, Object?> data) {
    final programme = AuthoredProgramme.fromJson({...data, 'programId': id});
    _sessions[id] = programme.sessions;
    _programmeStatus[id] = programme.status;
    _programmeVersion[id] = _int(data['version']);
  }

  Map<String, String>? _recipeRow(Map<String, Object?> data) {
    final row = data['adminRow'];
    if (row is! Map) return null;
    return {for (final e in row.entries) '${e.key}': '${e.value ?? ''}'};
  }

  /// One row, into the library. [sessions] and [published] are a programme's
  /// and are ignored for every other collection.
  Future<ContentSaveOutcome> saveToLibrary({
    required ContentCollection collection,
    required Map<String, String> values,
    List<AuthoredSession>? sessions,
    bool published = false,
  }) async {
    final schema = ContentSchema.of(collection);
    final id = (values[schema.idColumn] ?? '').trim();
    final docs = documents();
    if (docs == null || id.isEmpty) {
      // With no id this throws, exactly as the cache always has.
      await saveValues(collection: collection, values: values);
      if (collection == ContentCollection.programmes && sessions != null) {
        _sessions[id] = List.of(sessions);
        _programmeStatus[id] = published
            ? ProgrammeStatus.published
            : ProgrammeStatus.draft;
      }
      return ContentSaveOutcome.savedHereOnly;
    }
    switch (collection) {
      case ContentCollection.recipes:
        await docs.commit(await _recipeWrites(docs, [values]));
      case ContentCollection.programmes:
        await _publishProgramme(
          docs,
          values,
          sessions ?? _sessions[id] ?? const [],
          published,
        );
      case ContentCollection.exercises || ContentCollection.foods:
        await docs.commit({
          '${collectionName(collection)}/$id': typedDocument(
            collection,
            values,
          ),
        });
    }
    await saveValues(collection: collection, values: values);
    return ContentSaveOutcome.saved;
  }

  // ------------------------------------------------------------- recipes

  /// Every write a set of recipe rows needs, checked in full first. Throws
  /// [RecipeNotReady] when any row on its way to members breaks a rule.
  Future<Map<String, Map<String, Object?>>> _recipeWrites(
    ContentDocuments docs,
    List<Map<String, String>> rows,
  ) async {
    final seed = await seedRecipes();
    final seedVersion = _int(seed['contentVersion']);
    final sections = (seed['sections'] as List?) ?? const <Object?>[];
    final sectionIds = {
      for (final s in sections)
        if (s is Map && s['sectionId'] is String) s['sectionId']! as String,
    };

    final publications = <RecipePublication>[];
    final problems = <String>[];
    for (final values in rows) {
      final id = (values['recipeId'] ?? '').trim();
      final existing = id.isEmpty ? null : await docs.read('recipes/$id');
      final publication = publishRecipe(
        values: values,
        version: _int(existing?['version']) + 1,
        sectionIds: sectionIds,
      );
      // A draft is not read by any member, so only a recipe on its way to
      // them has to pass their rules. The id is checked either way.
      if (publication.problems.isNotEmpty &&
          (!publication.isDraft || id.isEmpty)) {
        problems.addAll(publication.problems);
      }
      publications.add(publication);
    }
    if (problems.isNotEmpty) throw RecipeNotReady(problems);

    final meta = await docs.read(kRecipeMetaPath);
    final current = _int(meta?['version']);
    final previousIndex = current > 0
        ? await docs.read(recipeIndexPath('en', current))
        : null;
    final ids = {for (final p in publications) p.document['recipeId']};
    final indexRows = <Map<String, Object?>>[
      for (final row in (previousIndex?['rows'] as List?) ?? const <Object?>[])
        if (row is Map && !ids.contains(row['recipeId']))
          row.cast<String, Object?>(),
      for (final p in publications) p.indexRow,
    ];
    final next = (current > seedVersion ? current : seedVersion) + 1;

    Map<String, Object?> index(String locale) => {
      'version': next,
      'locale': locale,
      'sections': sections,
      'rows': indexRows,
    };

    return {
      for (final p in publications)
        'recipes/${p.document['recipeId']}': p.document,
      recipeIndexPath('en', next): index('en'),
      recipeIndexPath('ar', next): index('ar'),
      kRecipeMetaPath: {'version': next},
    };
  }

  // ---------------------------------------------------------- programmes

  /// The sessions with each move completed from the exercise library: its
  /// names when the form left them blank, its flags, and its tags.
  List<AuthoredSession> _withExerciseFacts(
    List<AuthoredSession> sessions,
    List<String> problems,
  ) {
    final exercises = {
      for (final row in rowsNow(ContentCollection.exercises)) row.id: row,
    };
    return [
      for (final s in sessions)
        AuthoredSession(
          sessionId: s.sessionId,
          titleEn: s.titleEn,
          titleAr: s.titleAr,
          minutes: s.minutes,
          lifeStages: s.lifeStages,
          moves: [
            for (final m in s.moves)
              if (exercises[m.exerciseId] case final row?)
                AuthoredMove(
                  exerciseId: m.exerciseId,
                  nameEn: m.nameEn.trim().isEmpty
                      ? row.value('name_en')
                      : m.nameEn,
                  nameAr: m.nameAr.trim().isEmpty
                      ? row.value('name_ar')
                      : m.nameAr,
                  sets: m.sets,
                  reps: m.reps,
                  holdSeconds: m.holdSeconds,
                  restSeconds: m.restSeconds,
                  notesEn: m.notesEn,
                  notesAr: m.notesAr,
                  safetyEn: m.safetyEn,
                  safetyAr: m.safetyAr,
                  contraindications: row.list('contraindicationTags'),
                  quiet: row.boolean('quiet') ?? false,
                  floorOnly: row.boolean('floorOnly') ?? false,
                  needsEquipment: row
                      .list('equipment')
                      .any((e) => e.toLowerCase() != 'none'),
                )
              else
                () {
                  problems.add(
                    'session ${s.sessionId}: ${m.exerciseId} is not in the '
                    'exercise library',
                  );
                  return m;
                }(),
          ],
        ),
    ];
  }

  Future<void> _publishProgramme(
    ContentDocuments docs,
    Map<String, String> values,
    List<AuthoredSession> sessions,
    bool published,
  ) async {
    final id = values['programId']!.trim();
    final problems = <String>[];
    final completed = _withExerciseFacts(sessions, problems);
    final existing = await docs.read('programs/$id');
    final programme = AuthoredProgramme(
      programId: id,
      titleEn: (values['name_en'] ?? '').trim(),
      titleAr: (values['name_ar'] ?? '').trim(),
      status: published ? ProgrammeStatus.published : ProgrammeStatus.draft,
      version: _int(existing?['version']) + 1,
      sessions: completed,
    );
    if (published) problems.addAll(workoutProblems(programme));
    if (problems.isNotEmpty && published) throw WorkoutNotReady(problems);

    final meta = await docs.read(kWorkoutMetaPath);
    final current = _int(meta?['version']);
    final previous = current > 0
        ? await docs.read(workoutLibraryPath(current))
        : null;
    final next = current + 1;
    final programmes = <Map<String, Object?>>[
      for (final p in (previous?['programmes'] as List?) ?? const <Object?>[])
        if (p is Map && p['programId'] != id) p.cast<String, Object?>(),
      if (published) programme.toJson(),
    ];

    await docs.commit({
      'programs/$id': {
        ...typedDocument(ContentCollection.programmes, values),
        'status': programme.status.name,
        'version': programme.version,
        'sessions': [for (final s in completed) s.toJson()],
      },
      workoutLibraryPath(next): {'version': next, 'programmes': programmes},
      kWorkoutMetaPath: {'version': next},
    });
    _sessions[id] = completed;
    _programmeStatus[id] = programme.status;
    _programmeVersion[id] = programme.version;
  }

  /// A bulk import, in one commit. Exercises and foods are written as they
  /// are; a programme keeps the sessions it already has; every recipe row is
  /// published exactly as a single save would publish it, and one recipe the
  /// member app would refuse writes nothing at all.
  @override
  Future<void> saveAll(List<ImportRow> rows) async {
    final docs = documents();
    if (docs != null) {
      final recipes = [
        for (final row in rows)
          if (row.collection == ContentCollection.recipes) row.values,
      ];
      final writes = <String, Map<String, Object?>>{
        for (final row in rows)
          if (row.collection != ContentCollection.recipes &&
              row.documentId.trim().isNotEmpty)
            '${collectionName(row.collection)}/${row.documentId}': {
              ...typedDocument(row.collection, row.values),
              if (row.collection == ContentCollection.programmes) ...{
                'status':
                    (_programmeStatus[row.documentId] ?? ProgrammeStatus.draft)
                        .name,
                'version': _programmeVersion[row.documentId] ?? 0,
                'sessions': [
                  for (final s in _sessions[row.documentId] ?? const [])
                    s.toJson(),
                ],
              },
            },
        if (recipes.isNotEmpty) ...await _recipeWrites(docs, recipes),
      };
      if (writes.isNotEmpty) await docs.commit(writes);
    }
    await super.saveAll(rows);
  }
}

/// A CSV row as a typed document: list columns as arrays, numeric columns as
/// whole numbers (or null when blank), boolean columns as booleans.
Map<String, Object?> typedDocument(
  ContentCollection collection,
  Map<String, String> values,
) {
  final schema = ContentSchema.of(collection);
  return {
    for (final column in schema.columns)
      column.name: switch (values[column.name]?.trim() ?? '') {
        final v when column.list => [
          for (final part in v.split('|'))
            if (part.trim().isNotEmpty) part.trim(),
        ],
        final v when column.numeric => int.tryParse(v),
        final v when column.boolean => v.toLowerCase() == 'true',
        final v => v,
      },
  };
}

/// A typed document back as the CSV row the console edits. Null when it is
/// not a row this contract can describe (no id).
Map<String, String>? rowValuesOf(
  ContentCollection collection,
  Map<String, Object?> data,
) {
  final schema = ContentSchema.of(collection);
  final values = <String, String>{
    for (final column in schema.columns)
      column.name: switch (data[column.name]) {
        null => '',
        final List<Object?> list => list.join('|'),
        final bool b => b ? 'true' : 'false',
        final Object other => '$other',
      },
  };
  return values[schema.idColumn]!.trim().isEmpty ? null : values;
}
