/// Z11 — the export. **Content only. Never her.**
///
/// This is the constraint `DECISIONS.md` D12 states in the strongest terms of
/// any decision in that document, and G16 §5 repeats it:
///
/// > "No export path may reach `users/**`, cycle data, check-ins, measurements,
/// > progress photos, meal or session logs, phone numbers, names, or
/// > verification results."
///
/// > "This product tells her that her ID photo and selfie are deleted and that
/// > her logs are never shown to members. An admin bulk-export of user media
/// > would make both statements false. Under PDPL it is also the difference
/// > between exporting a content catalogue and exporting regulated personal
/// > data, some of it biometric."
///
/// ## How that is kept
///
/// §5 also says *how*: "A test asserts the export manifest contains no `users/`
/// path, **in the same spirit as the guard that makes a daily streak
/// unstorable: the rule is enforced by the code being unable to express the
/// violation**, not by remembering."
///
/// So [ExportManifest.of] validates by **allowing**, never by forbidding. A
/// media path must begin with `content/` and contain no `..`; everything else is
/// refused. A blacklist of the words D12 names would be the weaker design twice
/// over — it would need updating whenever a new collection appeared, and it
/// would be a list of the things we happened to think of.
///
/// If an export of a woman's own data is ever genuinely needed — a data-subject
/// request under PDPL — that is `A02`'s "download everything", it belongs to
/// her, and it is not an admin feature. `firebase/storage.rules` puts it under a
/// different prefix, written by a Cloud Function, readable only by her.
///
/// ## The round trip
///
/// §5: "one CSV per collection, in exactly the import schema — so an export can
/// be edited and re-imported". [writeCsv] therefore writes the schema's columns
/// in the schema's order, and quotes exactly as RFC 4180 rule 6 requires, using
/// the same escaping helper the reader uses.
library;

import 'package:meta/meta.dart';

import 'content_schema.dart';
import 'csv_parser.dart';
import 'import_validator.dart';
import 'media_bundle.dart';

/// Everything one export would contain, and nothing it may not.
@immutable
class ExportManifest {
  const ExportManifest._({required this.csvPaths, required this.mediaPaths});

  /// Validates on the way in. See the file note on why this allows rather than
  /// forbids.
  factory ExportManifest.of({
    required List<String> csvPaths,
    required List<String> mediaPaths,
  }) {
    for (final path in csvPaths) {
      if (path.isEmpty || path.contains('/')) {
        throw ArgumentError.value(
          path,
          'csvPaths',
          'a CSV sits at the root of the bundle under its own file name',
        );
      }
    }

    for (final path in mediaPaths) {
      if (!path.startsWith('content/') || path.contains('..')) {
        throw ArgumentError.value(
          path,
          'mediaPaths',
          'an export may only reach the content library',
        );
      }
    }

    return ExportManifest._(
      csvPaths: List.unmodifiable(csvPaths),
      mediaPaths: List.unmodifiable(mediaPaths),
    );
  }

  /// One per chosen collection, at the root of the bundle.
  final List<String> csvPaths;

  /// The media those rows reference, and only that.
  final List<String> mediaPaths;

  List<String> get allPaths => [...csvPaths, ...mediaPaths];

  bool get isEmpty => csvPaths.isEmpty && mediaPaths.isEmpty;
}

/// What an export of [rowsByCollection] would contain.
///
/// Collections are emitted in [ContentCollection.values] order so two exports of
/// the same library are byte-identical — a bundle that reordered itself between
/// runs would show spurious differences to anyone diffing one.
ExportManifest buildExportManifest(
  Map<ContentCollection, List<ImportRow>> rowsByCollection,
) {
  final csvPaths = <String>[];
  final mediaPaths = <String>[];

  for (final collection in ContentCollection.values) {
    final rows = rowsByCollection[collection];
    if (rows == null) continue;

    final schema = ContentSchema.of(collection);
    csvPaths.add(schema.fileName);

    for (final row in rows) {
      for (final column in schema.mediaColumns) {
        final fileName = row.value(column);
        if (fileName.isEmpty) continue;

        mediaPaths.add(
          storagePathFor(
            collection: collection,
            documentId: row.documentId,
            fileName: fileName,
          ),
        );
      }
    }
  }

  return ExportManifest.of(csvPaths: csvPaths, mediaPaths: mediaPaths);
}

/// Writes [rows] back out in exactly the shape the importer reads.
///
/// ## Line endings
///
/// RFC 4180 §2 spells records as separated by CRLF. This writes **LF**, which
/// Excel and every spreadsheet in use read without complaint, and which
/// [parseCsv] accepts alongside CRLF and a lone CR. The deviation is recorded
/// here rather than left to be discovered: a bundle full of CRLF is noisier in
/// version control for no benefit to the one program that cares.
///
/// ## The byte order mark
///
/// [byteOrderMark] is off by default and exists for one real case. The Unicode
/// FAQ (<https://www.unicode.org/faq/utf_bom.html>) describes the UTF-8 BOM as a
/// signature "that an otherwise unmarked text file is in UTF-8". Excel needs
/// that signature: without it, a double-clicked CSV is read in the system
/// codepage and every `name_ar` opens as mojibake. Turning it on costs nothing
/// on re-import, because [parseCsv] strips a leading U+FEFF.
String writeCsv(
  ContentCollection collection,
  List<ImportRow> rows, {
  bool byteOrderMark = false,
}) {
  final schema = ContentSchema.of(collection);
  final out = StringBuffer();

  if (byteOrderMark) out.writeCharCode(0xFEFF);

  out.writeln(
    [for (final name in schema.columnNames) csvField(name)].join(','),
  );

  for (final row in rows) {
    out.writeln(
      [for (final name in schema.columnNames) csvField(row.value(name))]
          .join(','),
    );
  }

  return out.toString();
}

/// One export, as far as this build can actually take it.
///
/// `pubspec.yaml` carries nothing that writes a file and nothing that zips one,
/// so an export cannot land in her downloads. What it can do is hand the whole
/// bundle over in one piece — the clipboard — and say plainly that saving is
/// not connected. That is the same arrangement [UnavailableMediaPicker] makes
/// for uploading, one step further along: the work is real, only the last hop
/// is missing.
///
/// [manifest] is built first and by the same function a real export would use,
/// so the "content only, never her" guarantee runs here too: a path outside
/// `content/` throws before anything reaches the clipboard.
@immutable
class ExportBundle {
  const ExportBundle({required this.manifest, required this.text});

  final ExportManifest manifest;

  /// Every chosen collection's CSV, each under its own file name.
  ///
  /// The file name is data, not copy: it is [ContentSchema.fileName], the same
  /// name the importer reads back. Pasted into an editor and split on those
  /// lines, this is the bundle.
  final String text;

  /// How many CSVs it holds. One per chosen collection.
  int get csvCount => manifest.csvPaths.length;
}

/// The bundle for [rowsByCollection]. Its keys are the collections she chose.
///
/// Emitted in [ContentCollection.values] order for the same reason
/// [buildExportManifest] is: two exports of the same library must be identical,
/// or every diff of one is noise.
ExportBundle buildExportBundle(
  Map<ContentCollection, List<ImportRow>> rowsByCollection,
) {
  final manifest = buildExportManifest(rowsByCollection);
  final out = StringBuffer();

  for (final collection in ContentCollection.values) {
    final rows = rowsByCollection[collection];
    if (rows == null) continue;
    if (out.isNotEmpty) out.writeln();
    out
      ..writeln(ContentSchema.of(collection).fileName)
      ..write(writeCsv(collection, rows));
  }

  return ExportBundle(manifest: manifest, text: out.toString());
}
