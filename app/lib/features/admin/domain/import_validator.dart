/// The dry run — G16 §3.1, and the whole reason this console exists.
///
/// > "`Z08` → `Z09` → commit. The file is parsed and validated **in full**
/// > before anything is written. If any row fails, nothing is written at all."
///
/// ## Why it is all-or-nothing, and why that is not fastidiousness
///
/// §3.1 again: "A half-imported food library, where some rows lack
/// `allergens[]`, is **worse than no import**: the gaps are invisible in the UI,
/// and `AllergyGuard` reads a missing tag as *unknown, therefore unsafe*, so it
/// fails closed and starts interrupting women who have no allergy. An import
/// that stops and names its bad rows is recoverable; one that half-succeeded is
/// not."
///
/// So there is deliberately no way to commit part of a batch. [ImportPlan.writes]
/// — the only list a caller may write from — is **empty** whenever anything
/// failed, rather than a filtered subset of the good rows. Exposing the good
/// rows separately and letting a screen decide is exactly how "just import the
/// ones that passed" gets added six months from now.
///
/// ## Re-running the same file must not duplicate anything
///
/// The document id **is** the id column, unchanged. Nothing is minted, hashed or
/// generated, so two runs of the same file address the same documents on any
/// device in any release. An id already present is an update; a new one is a
/// create; and §3.5's warning that "an id that moves repoints every reference to
/// it" is why this is never derived from the row's content.
///
/// ## Header problems stop the row pass
///
/// If the header is wrong, every row is judged against the wrong contract — a
/// single mistyped `allergen` would otherwise report a blank safety tag on all
/// 118 rows, burying the one finding that matters. So a header fault is reported
/// alone, against line 1, and the rows are left for the next run.
// `prefer_initializing_formals` asks for `required this._values` and
// `required this._rows`, which Dart forbids outright: a named parameter cannot
// begin with an underscore. The only way to satisfy the lint is to make both
// fields public — and `_rows` is private deliberately. A public `rows` is a
// list that anything could write from, which is precisely the all-or-nothing
// rule this file exists to enforce. [ImportPlan.writes] is the only way out,
// and it is empty unless the whole batch passed.
//
// Scoped to the file rather than the line for the reason `user_roles.dart`
// records against this same lint: `dart format` reflows a constructor across
// lines, which silently detaches a line-scoped ignore from the initializer it
// was meant to cover.
// ignore_for_file: prefer_initializing_formals
library;

import 'package:meta/meta.dart';

import 'content_schema.dart';
import 'csv_parser.dart';

/// Why a row, or a header, was refused.
///
/// Each of these is a *fact about the file*, not a sentence to show. The copy
/// that names them belongs to the dictionary; this layer stays in the vocabulary
/// of the CSV so the same finding can be reported in either language.
enum ImportProblemCode {
  /// The file has no header line at all.
  noHeader,

  /// A header this contract does not define. §3.5: "unknown columns rejected,
  /// not ignored — a typo in a header silently dropping `allergens` is the exact
  /// failure this console exists to prevent."
  unknownColumn,

  /// A column the contract requires, absent from the header.
  missingColumn,

  /// The same header twice. One of the two is silently discarded by any reader,
  /// and nobody can say which.
  duplicateColumn,

  /// The row has a different number of cells than the header.
  wrongFieldCount,

  /// A required cell is blank.
  blankRequired,

  /// A **safety** cell is blank. §3.2: "`none` is valid and means 'this contains
  /// no allergens'. Empty is rejected."
  blankSafetyTag,

  /// This id already appeared earlier in the same file.
  duplicateId,

  /// The row names a media file that is not in the upload.
  missingMedia,

  /// A numeric cell that is not a whole number.
  notANumber,

  /// A numeric cell below zero.
  negativeNumber,

  /// A boolean cell that is neither `true` nor `false`.
  notABoolean,
}

/// One finding, tied to the line of the file it is about.
@immutable
class ImportProblem {
  const ImportProblem({
    required this.row,
    required this.column,
    required this.code,
    this.value = '',
  });

  /// The file line, with the header as line 1 — the number the spreadsheet's own
  /// gutter shows. Header findings are reported against line 1.
  final int row;

  /// The column this is about, named as the file names it. Empty when the
  /// finding is about the row as a whole.
  final String column;

  final ImportProblemCode code;

  /// The offending cell, when quoting it back helps — the name of a media file
  /// that was never uploaded, for instance.
  final String value;

  @override
  String toString() => 'ImportProblem(row $row, $column, ${code.name})';
}

/// A row that passed, ready to be written.
@immutable
class ImportRow {
  const ImportRow({
    required this.collection,
    required this.id,
    required this.isUpdate,
    required Map<String, String> values,
  }) : _values = values;

  final ContentCollection collection;

  /// The value of the id column, and the document id. See the file note.
  final String id;

  /// Whether this id is already in the library.
  final bool isUpdate;

  final Map<String, String> _values;

  /// Deliberately identical to [id]. A named getter exists so call sites read as
  /// what they mean, and so the claim "the document id is the id column,
  /// unchanged" is written down somewhere a test can hold on to.
  String get documentId => id;

  String value(String column) => _values[column] ?? '';

  /// A pipe-separated column, split. Empty entries are dropped so `a||b` is two
  /// values rather than three.
  List<String> list(String column) => [
    for (final part in value(column).split('|'))
      if (part.trim().isNotEmpty) part.trim(),
  ];

  /// Null when the cell is blank or not numeric — which, for a required numeric
  /// column, cannot happen on a row that reached here.
  int? number(String column) => int.tryParse(value(column));

  /// Null when the cell is neither `true` nor `false`.
  bool? boolean(String column) => switch (value(column).toLowerCase()) {
    'true' => true,
    'false' => false,
    _ => null,
  };

  Map<String, String> get values => Map.unmodifiable(_values);
}

/// What the file would do, before it does any of it.
@immutable
class ImportPlan {
  const ImportPlan({
    required this.collection,
    required List<ImportRow> rows,
    required this.problems,
    required this.rowsMissingASafetyTag,
  }) : _rows = rows;

  final ContentCollection collection;
  final List<ImportRow> _rows;

  /// Every finding, ordered by line so the list reads like the file.
  final List<ImportProblem> problems;

  /// How many rows in the file lack an explicit safety tag — counted across the
  /// **whole** file, including rows that failed for other reasons.
  ///
  /// This is the number Z01 leads with. Z01's note: it "leads with how many rows
  /// lack a mandatory safety tag rather than how many rows exist… a food with no
  /// allergens value is not a smaller library, it is a guard that fails closed
  /// on every woman."
  final int rowsMissingASafetyTag;

  /// Rows that passed, in file order. New ones.
  List<ImportRow> get creates => [
    for (final r in _rows)
      if (!r.isUpdate) r,
  ];

  /// Rows that passed whose id is already in the library.
  List<ImportRow> get updates => [
    for (final r in _rows)
      if (r.isUpdate) r,
  ];

  int get rowsReady => _rows.length;

  /// How many distinct rows have at least one problem. A row with two faults is
  /// one row to fix, and reporting it as two would overstate the work.
  int get rowsWithProblems =>
      problems.where((p) => p.row > 1).map((p) => p.row).toSet().length;

  /// §3.1. One failure anywhere refuses the batch.
  bool get canCommit => problems.isEmpty;

  /// **The only list anything may write from.** Empty unless [canCommit].
  ///
  /// In file order, creates and updates together, because a caller writing them
  /// has no reason to care which is which and an order that depended on it would
  /// be one more thing to get wrong.
  List<ImportRow> get writes => canCommit ? List.unmodifiable(_rows) : const [];
}

/// Whole numbers only, and ASCII digits only.
///
/// Dart's `\d` is `[0-9]`, so Eastern Arabic numerals do not match and are
/// reported as not-a-number rather than silently misread. That is the right
/// answer twice over: the product writes Western digits everywhere
/// (`P0-A11Y-01`), and guessing at a calorie figure would put an unverifiable
/// number in front of a woman.
final RegExp _wholeNumber = RegExp(r'^-?\d+$');

/// Validates [table] as [collection] without writing anything.
///
/// [uploadedMedia] is the set of file names in the media upload, which every
/// media column is checked against. [existingIds] is what is already in the
/// library, which decides create from update.
ImportPlan validateImport({
  required ContentCollection collection,
  required CsvTable table,
  required Set<String> uploadedMedia,
  required Set<String> existingIds,
}) {
  final schema = ContentSchema.of(collection);
  final problems = <ImportProblem>[];

  // ---------------------------------------------------------------- header
  if (table.headers.isEmpty) {
    return ImportPlan(
      collection: collection,
      rows: const [],
      problems: const [
        ImportProblem(row: 1, column: '', code: ImportProblemCode.noHeader),
      ],
      rowsMissingASafetyTag: 0,
    );
  }

  final headers = [for (final h in table.headers) h.trim()];
  final seenHeaders = <String>{};

  for (final header in headers) {
    if (!seenHeaders.add(header)) {
      problems.add(
        ImportProblem(
          row: 1,
          column: header,
          code: ImportProblemCode.duplicateColumn,
        ),
      );
    }
    if (schema.column(header) == null) {
      problems.add(
        ImportProblem(
          row: 1,
          column: header,
          code: ImportProblemCode.unknownColumn,
        ),
      );
    }
  }

  for (final column in schema.columns) {
    final name = column.name;
    if (!headers.contains(name) && !column.mayBeAbsent) {
      problems.add(
        ImportProblem(
          row: 1,
          column: name,
          code: ImportProblemCode.missingColumn,
        ),
      );
    }
  }

  if (problems.isNotEmpty) {
    // See the file note: judging rows against a broken contract buries the one
    // finding that matters under a hundred consequences of it.
    return ImportPlan(
      collection: collection,
      rows: const [],
      problems: List.unmodifiable(problems),
      rowsMissingASafetyTag: 0,
    );
  }

  // ------------------------------------------------------------------ rows
  final rows = <ImportRow>[];
  final seenIds = <String>{};
  var missingSafetyTag = 0;

  for (final row in table.rows) {
    // A spreadsheet leaves blank lines behind constantly. Reporting one as a bad
    // row would make a correct file unimportable for a cosmetic reason.
    if (row.values.length <= 1 && row.values.every((v) => v.trim().isEmpty)) {
      continue;
    }

    if (row.values.length != headers.length) {
      // Padding a short row with blanks would turn a truncated line into a row
      // with a blank safety tag — the exact failure §3.2 is about, arriving
      // through the back door.
      problems.add(
        ImportProblem(
          row: row.line,
          column: '',
          code: ImportProblemCode.wrongFieldCount,
        ),
      );
      continue;
    }

    final cells = <String, String>{
      for (var i = 0; i < headers.length; i++) headers[i]: row.values[i].trim(),
    };

    // Counted before validity, because Z01's number is about the file as a
    // whole — a row that also has a bad macro is still a row with no allergens.
    if (schema.safetyTagColumns.any((name) => (cells[name] ?? '').isEmpty)) {
      missingSafetyTag++;
    }

    final before = problems.length;

    for (final column in schema.columns) {
      final cell = cells[column.name] ?? '';

      if (cell.isEmpty) {
        if (column.safetyTag) {
          problems.add(
            ImportProblem(
              row: row.line,
              column: column.name,
              code: ImportProblemCode.blankSafetyTag,
            ),
          );
        } else if (column.required) {
          problems.add(
            ImportProblem(
              row: row.line,
              column: column.name,
              code: ImportProblemCode.blankRequired,
            ),
          );
        }
        continue;
      }

      if (column.numeric) {
        if (!_wholeNumber.hasMatch(cell)) {
          problems.add(
            ImportProblem(
              row: row.line,
              column: column.name,
              code: ImportProblemCode.notANumber,
              value: cell,
            ),
          );
        } else if (cell.startsWith('-')) {
          problems.add(
            ImportProblem(
              row: row.line,
              column: column.name,
              code: ImportProblemCode.negativeNumber,
              value: cell,
            ),
          );
        }
      }

      if (column.boolean &&
          !const ['true', 'false'].contains(cell.toLowerCase())) {
        problems.add(
          ImportProblem(
            row: row.line,
            column: column.name,
            code: ImportProblemCode.notABoolean,
            value: cell,
          ),
        );
      }

      if (column.media && !uploadedMedia.contains(cell)) {
        problems.add(
          ImportProblem(
            row: row.line,
            column: column.name,
            code: ImportProblemCode.missingMedia,
            value: cell,
          ),
        );
      }
    }

    // A recipe on its way to members needs its method: the member app cannot
    // show a recipe with no steps, and refuses the whole library if one
    // arrives that way. A draft may be imported without one.
    if (collection == ContentCollection.recipes &&
        (cells['status'] ?? '').isNotEmpty &&
        cells['status'] != 'draft' &&
        (cells['method_ar'] ?? '').isEmpty) {
      problems.add(
        ImportProblem(
          row: row.line,
          column: 'method_ar',
          code: ImportProblemCode.blankRequired,
        ),
      );
    }

    final id = cells[schema.idColumn] ?? '';
    if (id.isNotEmpty && !seenIds.add(id)) {
      // The SECOND occurrence is the problem. The first row was fine until this
      // one contradicted it, and sending staff to the wrong line is worse than
      // saying nothing.
      problems.add(
        ImportProblem(
          row: row.line,
          column: schema.idColumn,
          code: ImportProblemCode.duplicateId,
          value: id,
        ),
      );
    }

    // Every fault on the row is reported, not just the first. She has to fix the
    // file once; an importer that stopped at one fault per row would turn a
    // single round trip into four.
    if (problems.length == before) {
      rows.add(
        ImportRow(
          collection: collection,
          id: id,
          isUpdate: existingIds.contains(id),
          values: cells,
        ),
      );
    }
  }

  return ImportPlan(
    collection: collection,
    rows: List.unmodifiable(rows),
    problems: List.unmodifiable(problems),
    rowsMissingASafetyTag: missingSafetyTag,
  );
}
