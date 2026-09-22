/// Reading a CSV the way the files staff actually send arrive — G16 §3.
///
/// The importer's whole promise is that it validates the file **in full** before
/// writing anything, and names the row that failed. That promise is only worth
/// something if the reader underneath it is right about what a row *is*. A
/// parser that splits on commas gets koshari's `portions` wrong, loses the last
/// record of a file with no trailing newline, and turns Excel's byte order mark
/// into a column nobody asked for.
///
/// ## What this follows
///
/// RFC 4180, *Common Format and MIME Type for Comma-Separated Values (CSV)
/// Files* — <https://www.rfc-editor.org/rfc/rfc4180.txt>. Its §2 numbers the
/// grammar rules, and the ones that matter here are:
///
///   * **rule 2** — "The last record in the file may or may not have an ending
///     line break." Both forms must yield the same rows; dropping the last
///     record of an unterminated file loses content silently.
///   * **rule 3** — the optional header line. It is not optional here: this
///     importer is built entirely on named columns.
///   * **rule 4** — "Spaces are considered part of a field and should not be
///     ignored." So this parser does not trim. See the note below.
///   * **rule 5** — a field may or may not be quoted.
///   * **rule 6** — "Fields containing line breaks (CRLF), double quotes, and
///     commas should be enclosed in double-quotes."
///   * **rule 7** — a double quote inside a quoted field is escaped by
///     doubling it.
///
/// The ABNF for a quoted field is
/// `escaped = DQUOTE *(TEXTDATA / COMMA / CR / LF / 2DQUOTE) DQUOTE`, which is
/// why a newline inside quotes does not end the record.
///
/// ## Why nothing is trimmed here
///
/// Rule 4 is the specification's reason; §3.2 of the plan is the product's. A
/// mandatory safety column "must carry an **explicit** value… Empty is
/// rejected", and a cell holding one space arrives from a spreadsheet
/// constantly. If this parser tidied it away, the validator could never tell
/// that cell from a deliberate `none`, and the importer would create exactly the
/// ambiguity the plan exists to refuse. Judging whitespace is the validator's
/// job, and it cannot judge what it never sees.
///
/// ## Line endings and the byte order mark
///
/// CRLF, LF and a lone CR all end a record. Files come from Excel on Windows,
/// from a Mac, and from scripts, and a surviving `\r` would make `allergens`
/// read `"none\r"` — which matches nothing, and fails a correct row for a reason
/// invisible on screen.
///
/// A leading U+FEFF is stripped. The Unicode FAQ on UTF-8 and BOM
/// (<https://www.unicode.org/faq/utf_bom.html>) describes the UTF-8 encoded BOM
/// as the bytes `EF BB BF`, "only used as a signature — an indication that an
/// otherwise unmarked text file is in UTF-8", and warns that in 8-bit
/// environments "the use of a BOM will interfere with any protocol or file
/// format that expects specific ASCII characters at the beginning". A CSV header
/// is such a format: Excel's "CSV UTF-8" writes the BOM, it lands on the front
/// of the first header, and without this the first column is named
/// `"﻿foodId"` — reported at once as a missing column *and* an unknown one,
/// failing a file that is completely correct.
///
/// Only the leading one goes. The same FAQ says that away from the start of a
/// stream U+FEFF "should normally not occur" and is to be treated as ZERO WIDTH
/// NON-BREAKING SPACE — it is then content, and stripping it would be this
/// console silently editing her data.
library;

import 'package:meta/meta.dart';

/// U+FEFF. `EF BB BF` once encoded as UTF-8.
const int _bom = 0xFEFF;

/// One record, and the line of the file it starts on.
@immutable
class CsvRow {
  const CsvRow({required this.line, required this.values});

  /// The 1-based **file line** this record begins on, with the header as line 1
  /// — the number the spreadsheet's own row gutter shows.
  ///
  /// Not the index in [CsvTable.rows]. The two come apart the moment any value
  /// contains a line break (rule 6), and then every row number reported after it
  /// points somewhere else, so staff would "fix" a row that was never wrong.
  final int line;

  final List<String> values;

  @override
  String toString() => 'CsvRow($line, $values)';
}

/// A parsed file: its header line, and every record after it.
@immutable
class CsvTable {
  const CsvTable({required this.headers, required this.rows});

  /// The first record. Empty for an empty file — rejecting that is the
  /// validator's job, which can say something useful about it.
  final List<String> headers;

  final List<CsvRow> rows;
}

/// A file this parser cannot read at all, as opposed to one it read and
/// disliked. Only unterminated quoting reaches here; everything else is a
/// validation problem with a row number.
@immutable
class CsvFormatException implements Exception {
  const CsvFormatException({required this.line, required this.detail});

  /// The line the unterminated field **opened** on, which is where the missing
  /// quote belongs — not the end of the file, where the symptom appeared.
  final int line;

  final String detail;

  @override
  String toString() => 'CsvFormatException(line $line: $detail)';
}

/// Parses [source] into a header and its records.
///
/// Throws [CsvFormatException] only for a quoted field that is never closed,
/// which means the file is truncated. Guessing where such a field ended would
/// import half a library from half a download.
CsvTable parseCsv(String source) {
  final text = _withoutLeadingBom(source);

  final records = <CsvRow>[];
  var values = <String>[];
  final field = StringBuffer();

  var line = 1;
  var recordLine = 1;
  var quoteOpenedOn = 1;
  var inQuotes = false;
  var index = 0;

  void endField() {
    values.add(field.toString());
    field.clear();
  }

  void endRecord() {
    endField();
    records.add(CsvRow(line: recordLine, values: values));
    values = <String>[];
  }

  while (index < text.length) {
    final ch = text[index];

    if (inQuotes) {
      if (ch == '"') {
        // Rule 7: a doubled quote is one literal quote; a single one closes.
        if (index + 1 < text.length && text[index + 1] == '"') {
          field.write('"');
          index += 2;
          continue;
        }
        inQuotes = false;
        index++;
        continue;
      }

      // Rule 6 / the ABNF: CR and LF inside quotes are data, not separators.
      // Normalised to a single \n so a value does not carry the file's line
      // ending into the library.
      if (ch == '\r') {
        field.write('\n');
        index += (index + 1 < text.length && text[index + 1] == '\n') ? 2 : 1;
        line++;
        continue;
      }
      if (ch == '\n') {
        field.write('\n');
        index++;
        line++;
        continue;
      }

      field.write(ch);
      index++;
      continue;
    }

    if (ch == '"') {
      quoteOpenedOn = line;
      inQuotes = true;
      index++;
      continue;
    }

    if (ch == ',') {
      endField();
      index++;
      continue;
    }

    if (ch == '\r' || ch == '\n') {
      index +=
          (ch == '\r' && index + 1 < text.length && text[index + 1] == '\n')
          ? 2
          : 1;
      endRecord();
      line++;
      recordLine = line;
      continue;
    }

    field.write(ch);
    index++;
  }

  if (inQuotes) {
    throw CsvFormatException(
      line: quoteOpenedOn,
      detail: 'a quoted field was never closed',
    );
  }

  // Rule 2: a final record with no trailing line break still counts. The guard
  // is on content rather than on position, so a file ending in a newline does
  // not gain a phantom empty row.
  if (field.isNotEmpty || values.isNotEmpty) endRecord();

  if (records.isEmpty) {
    return const CsvTable(headers: [], rows: []);
  }

  return CsvTable(
    headers: records.first.values,
    rows: records.skip(1).toList(),
  );
}

/// Drops one U+FEFF from the very front, and nowhere else. See the file note.
String _withoutLeadingBom(String source) =>
    source.isNotEmpty && source.codeUnitAt(0) == _bom
    ? source.substring(1)
    : source;

/// Renders one field back out, quoting it only when rule 6 requires.
///
/// Lives beside the reader on purpose: the escaping rule and the unescaping rule
/// are the same rule, and §5's promise that "an export can be edited and
/// re-imported" is only true while they agree. Two copies in two files is how
/// they stop agreeing.
String csvField(String value) {
  final needsQuotes =
      value.contains(',') ||
      value.contains('"') ||
      value.contains('\n') ||
      value.contains('\r');

  if (!needsQuotes) return value;

  // Rule 7: double every quote, then wrap.
  return '"${value.replaceAll('"', '""')}"';
}
