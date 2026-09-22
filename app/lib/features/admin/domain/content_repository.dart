/// Where the content library actually lives — the seam D12 has been missing.
///
/// Until this file existed, **nothing in this console could store anything**.
/// `content_form_view.dart` recorded the gap honestly — "Saving emits, it does
/// not write… there is no persistence layer in this repo" — and Z09's commit had
/// the same hole: [ImportPlan.writes] was a list nobody wrote. Two screens
/// produced content and both dropped it.
///
/// ## One store, two writers, or bulk import and Add diverge
///
/// D12 asked for content to be addable "from within the app, with a bulk option
/// for CSVs". Those are two writers — Z03/Z05's form and Z09's commit — and if
/// each kept its own idea of what the library holds, a food added by hand would
/// be invisible to the importer's create-or-update decision and would be
/// duplicated by the next CSV that named it. So both arrive here:
/// [ContentRepository.saveValues] for one authored row, [ContentRepository.saveAll]
/// for a validated batch, and a single [existingIds] that both are judged
/// against.
///
/// ## The document id is the id column, and nothing mints one
///
/// `import_validator.dart` states the rule and this file keeps it: the id in the
/// file **is** the document id, unchanged. Nothing here hashes, generates or
/// auto-increments, so two runs of the same file address the same documents on
/// any device in any release — which is the whole of §3.5's "re-running the same
/// file must not duplicate". A row with a blank id is refused rather than given
/// one, because an invented id is a row that can never be updated again.
///
/// ## Blank and `none` are different facts, and [CollectionStatus] is where it
/// shows
///
/// §3.2: "`none` is valid and means 'this contains no allergens'. Empty is
/// rejected." [CollectionStatus.missingASafetyTag] counts only the blanks.
/// `AllergyGuard` reads a missing tag as *unknown, therefore unsafe* and fails
/// closed, so a blank cell does not make the library smaller — it makes the
/// guard start interrupting women who have no allergy. A row that says `none` is
/// a row somebody checked, and it is not counted.
///
/// ## Shaped for Firestore, implemented in memory
///
/// Every method is asynchronous and nothing here imports Flutter, so the
/// Firestore implementation is a new class beside this one rather than a rewrite
/// of the screens. G16 §8 leaves open whether the commit runs on the device or
/// through a Cloud Function; this interface is indifferent to that — it says
/// what is written, never where the write executes.
///
/// [InMemoryContentRepository] additionally exposes its [ContentStore]
/// synchronously, exactly as `InMemoryCycleRepository` does, because the router
/// renders these screens from cached state rather than awaiting a read on every
/// build.
library;

import 'dart:async';

import 'package:meta/meta.dart';

import 'content_schema.dart';
import 'import_validator.dart';

/// What is known about one collection.
///
/// [missingASafetyTag] leads. [rows] is the *smaller* fact: a food with no
/// allergens value is not a smaller library, it is a guard that fails closed on
/// every woman.
///
/// This lives in `domain/` rather than beside Z01 because the repository is what
/// counts it and a screen may not be the only thing that can say how incomplete
/// the library is. `content_library_view.dart` re-exports it, so Z01 and every
/// test that constructs one are unaffected by the move.
@immutable
class CollectionStatus {
  const CollectionStatus({required this.rows, required this.missingASafetyTag});

  final int rows;

  /// Rows whose mandatory safety column is blank. `SCHEMA-SPINE.md` §1: without
  /// these tags "the safety rules are decorative".
  final int missingASafetyTag;

  @override
  String toString() =>
      'CollectionStatus($rows rows, $missingASafetyTag untagged)';
}

/// Reading and writing the content library — and nothing else.
///
/// Note what this interface cannot express. There is no member, no account and
/// no identifier of a person anywhere in it: every method is keyed by
/// [ContentCollection], an enum with four members, none of which is a woman.
/// D12's "an admin is staff, not a member" is kept by the type rather than by
/// remembering.
abstract class ContentRepository {
  /// Everything in one collection, in insertion order.
  Future<List<ImportRow>> rowsIn(ContentCollection collection);

  /// The ids already in the library.
  ///
  /// This is what `validateImport` takes as `existingIds` to tell a create from
  /// an update. Without it every re-import of the same file would read as a file
  /// full of new rows.
  Future<Set<String>> existingIds(ContentCollection collection);

  /// Z01's count for one collection.
  Future<CollectionStatus> statusOf(ContentCollection collection);

  /// Z01's whole landing tab. Every collection is present, including the empty
  /// ones — "0 rows" is a claim this console can support once it is reading from
  /// a store, whereas an absent entry means nothing is known.
  Future<Map<ContentCollection, CollectionStatus>> status();

  /// One row, already shaped. The document id is [ImportRow.documentId].
  Future<void> save(ImportRow row);

  /// One row as Z03/Z05 emits it — the CSV's own column map.
  ///
  /// The id is read from the collection's id column, never minted. Throws
  /// [ArgumentError] when it is blank, because a row with no id cannot be
  /// updated afterwards by anything, including the next import of the file it
  /// came from.
  Future<void> saveValues({
    required ContentCollection collection,
    required Map<String, String> values,
  });

  /// A whole validated batch — Z09's [ImportPlan.writes], which is empty unless
  /// [ImportPlan.canCommit].
  ///
  /// All or nothing, per §3.1: if any row in the batch is unwritable the store
  /// is left exactly as it was. A half-applied import is the one outcome the
  /// dry run exists to prevent.
  Future<void> saveAll(List<ImportRow> rows);

  /// Emits the collection that changed, so a screen can re-read it.
  Stream<ContentCollection> watch();

  Future<void> dispose();
}

/// The library, held in memory.
///
/// Separate from the repository for the reason `CycleStore` records: tests
/// assert against [writes] rather than against a callback argument, because a
/// screen whose test asserted the callback once shipped having written nothing
/// at all.
class ContentStore {
  /// Keyed by collection, then by document id — so an id can only ever appear
  /// once per collection. That is not a convention this class has to remember:
  /// a second write to the same id *replaces*, and duplication is not a state
  /// the structure can hold.
  final Map<ContentCollection, Map<String, ImportRow>> rows = {
    for (final collection in ContentCollection.values)
      collection: <String, ImportRow>{},
  };

  /// Every document written, in order, as `collection/id`.
  ///
  /// The collection name is the last segment of [ContentSchema.storagePrefix] —
  /// `programmes` is spelled `programs` there, in `firebase/firestore.rules`
  /// and in the CSV's file name, and reading it off the contract is what stops
  /// this file inventing a fifth spelling of it.
  final List<String> writes = <String>[];
}

/// An in-memory [ContentRepository]. Real behaviour, no storage.
///
/// **It bakes in no content.** An empty library is the honest state of this
/// product today and the reason the console was commissioned; seeding it with
/// three sample foods here would put a number on Z01 that no woman's app would
/// ever show. [rows] exists for tests and for a caller restoring a snapshot, and
/// seeding is deliberately not recorded as a write.
class InMemoryContentRepository implements ContentRepository {
  InMemoryContentRepository({
    ContentStore? store,
    List<ImportRow> rows = const [],
  }) : store = store ?? ContentStore() {
    for (final row in rows) {
      this.store.rows[row.collection]![row.documentId] = row;
    }
  }

  final ContentStore store;

  final StreamController<ContentCollection> _changes =
      StreamController<ContentCollection>.broadcast();

  // ------------------------------------------------------------------ reads

  @override
  Future<List<ImportRow>> rowsIn(ContentCollection collection) async =>
      rowsNow(collection);

  @override
  Future<Set<String>> existingIds(ContentCollection collection) async =>
      existingIdsNow(collection);

  @override
  Future<CollectionStatus> statusOf(ContentCollection collection) async =>
      statusNowOf(collection);

  @override
  Future<Map<ContentCollection, CollectionStatus>> status() async =>
      statusNow();

  /// The same reads, synchronously, for a caller rendering from cache.
  ///
  /// `InMemoryCycleRepository` exposes its store for exactly this: the screens
  /// draw from the last snapshot rather than awaiting a read on every build. A
  /// Firestore implementation would cache a snapshot and answer the async
  /// methods from it the same way.
  List<ImportRow> rowsNow(ContentCollection collection) =>
      List.unmodifiable(store.rows[collection]!.values);

  Set<String> existingIdsNow(ContentCollection collection) =>
      Set.unmodifiable(store.rows[collection]!.keys);

  CollectionStatus statusNowOf(ContentCollection collection) {
    final held = store.rows[collection]!.values;
    return CollectionStatus(
      rows: held.length,
      missingASafetyTag: held.where((row) => _isUntagged(row)).length,
    );
  }

  Map<ContentCollection, CollectionStatus> statusNow() => {
    for (final collection in ContentCollection.values)
      collection: statusNowOf(collection),
  };

  /// Blank, not `none`. See the file note — and note that whitespace is blank:
  /// a cell holding one space arrives from a spreadsheet constantly, and the
  /// guard reading it cannot tell it from an answer.
  bool _isUntagged(ImportRow row) =>
      ContentSchema.of(row.collection).safetyTagColumns
          .any((column) => row.value(column).trim().isEmpty);

  // ----------------------------------------------------------------- writes

  @override
  Future<void> save(ImportRow row) async {
    _requireId(row.documentId, row.collection);
    _put(row);
    _changes.add(row.collection);
  }

  @override
  Future<void> saveValues({
    required ContentCollection collection,
    required Map<String, String> values,
  }) async {
    final schema = ContentSchema.of(collection);
    final id = (values[schema.idColumn] ?? '').trim();
    _requireId(id, collection);

    _put(
      ImportRow(
        collection: collection,
        id: id,
        // Read from the store rather than taken on trust: the form does not
        // know whether this id is already in the library, and a create that
        // claimed to be one would quietly overwrite a row somebody else
        // authored.
        isUpdate: store.rows[collection]!.containsKey(id),
        values: Map<String, String>.from(values),
      ),
    );
    _changes.add(collection);
  }

  @override
  Future<void> saveAll(List<ImportRow> rows) async {
    // Checked in full before anything lands, so a batch carrying one unwritable
    // row leaves the library exactly as it was. §3.1: "If any row fails, nothing
    // is written at all."
    for (final row in rows) {
      _requireId(row.documentId, row.collection);
    }

    final touched = <ContentCollection>{};
    for (final row in rows) {
      _put(row);
      touched.add(row.collection);
    }
    for (final collection in touched) {
      _changes.add(collection);
    }
  }

  void _put(ImportRow row) {
    store.rows[row.collection]![row.documentId] = row;
    store.writes.add('${_collectionName(row.collection)}/${row.documentId}');
  }

  /// Never minted. See the file note.
  void _requireId(String id, ContentCollection collection) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(
        id,
        ContentSchema.of(collection).idColumn,
        'the document id is the id column and is never generated',
      );
    }
  }

  /// `exercises`, `foods`, `recipes`, `programs` — read off the contract rather
  /// than typed here. See [ContentStore.writes].
  String _collectionName(ContentCollection collection) =>
      ContentSchema.of(collection).storagePrefix.split('/').last;

  @override
  Stream<ContentCollection> watch() => _changes.stream;

  @override
  Future<void> dispose() => _changes.close();
}
