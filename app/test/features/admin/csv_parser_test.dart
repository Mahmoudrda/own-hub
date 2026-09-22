// The CSV reader, against the specification rather than against our own parser.
//
// Written before `csv_parser.dart` existed. Every case here comes from RFC 4180
// or the Unicode FAQ, quoted in the test that checks it, because a parser tested
// only against files we wrote ourselves passes on exactly the inputs we already
// thought of — and the file that breaks this console will be one Excel wrote.
//
// RFC 4180 (Common Format and MIME Type for Comma-Separated Values Files),
// https://www.rfc-editor.org/rfc/rfc4180.txt — §2 numbers its grammar rules, and
// the rule numbers below are that document's.
//
// The BOM cases come from the Unicode FAQ on UTF-8 and BOM,
// https://www.unicode.org/faq/utf_bom.html.

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/admin/domain/csv_parser.dart';

void main() {
  group('the shape of a file', () {
    test('rule 3 — the first line is the header', () {
      // RFC 4180 §2 rule 3: "There maybe an optional header line appearing as
      // the first line of the file with the same format as normal record
      // lines." This importer REQUIRES it — the whole console is built on
      // named columns — so the first record is always read as the header.
      final table = parseCsv('foodId,name_en\nkoshari,Koshari\n');

      expect(table.headers, ['foodId', 'name_en']);
      expect(table.rows, hasLength(1));
      expect(table.rows.single.values, ['koshari', 'Koshari']);
    });

    test('rule 2 — the last record may have no trailing line break', () {
      // "The last record in the file may or may not have an ending line break."
      // Both forms must produce the same two rows. A parser that drops the last
      // record when the file has no final newline loses one row silently, which
      // is the worst possible failure for an importer.
      const withBreak = 'id,name_en\na,A\nb,B\n';
      const without = 'id,name_en\na,A\nb,B';

      expect(parseCsv(withBreak).rows, hasLength(2));
      expect(parseCsv(without).rows, hasLength(2));
      expect(
        parseCsv(without).rows.last.values,
        parseCsv(withBreak).rows.last.values,
      );
    });

    test('a trailing newline does not invent an empty final row', () {
      final table = parseCsv('id,name_en\na,A\n');
      expect(table.rows, hasLength(1));
    });

    test('CRLF, LF and a lone CR are all record separators', () {
      // The ABNF in §2 spells records as separated by CRLF, and Excel on Windows
      // writes CRLF. Files edited on a Mac or by a script arrive with LF. If CR
      // survived into a value, `allergens` would read "none\r" and never match
      // "none" — a blank-versus-none failure caused entirely by the line ending.
      for (final source in [
        'id,allergens\r\nkoshari,none\r\n',
        'id,allergens\nkoshari,none\n',
        'id,allergens\rkoshari,none\r',
      ]) {
        final table = parseCsv(source);
        expect(table.headers, ['id', 'allergens']);
        expect(table.rows.single.values, ['koshari', 'none']);
      }
    });

    test('an empty file has no headers and no rows, and does not throw', () {
      // Rejecting an empty file is the validator's job, and it can say something
      // useful about it. Throwing here would turn a recoverable mistake into a
      // crash on the import screen.
      final table = parseCsv('');
      expect(table.headers, isEmpty);
      expect(table.rows, isEmpty);
    });
  });

  group('quoting, per rules 5, 6 and 7', () {
    test('rule 5 — a field may or may not be quoted', () {
      // "Each field may or may not be enclosed in double quotes (however some
      // programs, such as Microsoft Excel, do not use double quotes at all)."
      final table = parseCsv('id,name_en\n"koshari",Koshari\n');
      expect(table.rows.single.values, ['koshari', 'Koshari']);
    });

    test('rule 6 — a quoted field may contain a comma', () {
      // "Fields containing line breaks (CRLF), double quotes, and commas should
      // be enclosed in double-quotes." A comma inside quotes is data, not a
      // separator — `portions` and `ingredients` are full of them.
      final table = parseCsv('id,ingredients\nsoup,"lentils, onion, cumin"\n');
      expect(table.rows.single.values, ['soup', 'lentils, onion, cumin']);
    });

    test('rule 6 — a quoted field may contain a line break', () {
      // The ABNF: escaped = DQUOTE *(TEXTDATA / COMMA / CR / LF / 2DQUOTE)
      // DQUOTE. A newline inside quotes does NOT end the record.
      final table = parseCsv('id,name_en\na,"two\nlines"\nb,B\n');

      expect(table.rows, hasLength(2));
      expect(table.rows.first.values, ['a', 'two\nlines']);
      expect(table.rows.last.values, ['b', 'B']);
    });

    test('rule 7 — a doubled quote is one literal quote', () {
      // "If double-quotes are used to enclose fields, then a double-quote
      // appearing inside a field must be escaped by preceding it with another
      // double quote."
      final table = parseCsv('id,name_en\na,"she said ""yes"""\n');
      expect(table.rows.single.values, ['a', 'she said "yes"']);
    });

    test('a field that is only a doubled quote pair is one quote', () {
      final table = parseCsv('id,name_en\na,""""\n');
      expect(table.rows.single.values, ['a', '"']);
    });

    test('an empty quoted field is an empty string, not a missing value', () {
      // This is the distinction §3.2 of the plan is built on: an empty
      // `allergens` cell must reach the validator as "present and blank" so it
      // can be REJECTED, rather than vanishing.
      final table = parseCsv('id,allergens\na,""\n');
      expect(table.rows.single.values, ['a', '']);
      expect(table.rows.single.values, hasLength(2));
    });

    test('an unterminated quoted field is a format error naming its line', () {
      // A file that ends mid-quote is truncated. Guessing where the field ended
      // would import half a library from a half-downloaded file.
      expect(
        () => parseCsv('id,name_en\na,"never closed\n'),
        throwsA(isA<CsvFormatException>().having((e) => e.line, 'line', 2)),
      );
    });
  });

  group('rule 4 — spaces are part of a field', () {
    test('leading and trailing spaces in an unquoted field are kept', () {
      // "Spaces are considered part of a field and should not be ignored."
      //
      // Kept by the PARSER, deliberately. Trimming here would hide " " — a cell
      // holding only a space — from the validator, and a space is exactly how a
      // blank `allergens` cell arrives from a spreadsheet. The validator is what
      // decides that a whitespace-only mandatory cell is blank; it cannot make
      // that call on data the parser already tidied away.
      final table = parseCsv('id,allergens\na, none \n');
      expect(table.rows.single.values, ['a', ' none ']);
    });

    test('a whitespace-only cell survives parsing as whitespace', () {
      final table = parseCsv('id,allergens\na,   \n');
      expect(table.rows.single.values.last, '   ');
    });
  });

  group('the UTF-8 BOM Excel writes', () {
    // Unicode FAQ, UTF-8 and BOM: the UTF-8 encoded BOM is the byte sequence
    // EF BB BF, which decodes to U+FEFF, and it is "only used as a
    // signature — an indication that an otherwise unmarked text file is in
    // UTF-8". Excel writes it when saving "CSV UTF-8", and it lands on the
    // front of the FIRST HEADER.
    //
    // The FAQ also warns that "where UTF-8 is used transparently in 8-bit
    // environments, the use of a BOM will interfere with any protocol or file
    // format that expects specific ASCII characters at the beginning". A CSV
    // header is exactly such a format.

    test('a leading U+FEFF is stripped from the first header', () {
      // Without this, the first column is named "﻿foodId", the importer
      // reports `foodId` as a missing column AND `﻿foodId` as an unknown
      // one, and every row fails — on a file that is completely correct. This
      // is the single most likely real-world failure of this console.
      final table = parseCsv('﻿foodId,name_en\nkoshari,Koshari\n');

      expect(table.headers, ['foodId', 'name_en']);
      expect(table.headers.first.codeUnits, isNot(contains(0xFEFF)));
    });

    test('only one leading BOM is stripped, and only at the very start', () {
      // The FAQ: "in the absence of a protocol supporting its use as a BOM and
      // when not at the beginning of a text stream, U+FEFF should normally not
      // occur" and should be treated as ZERO WIDTH NON-BREAKING SPACE. So a
      // U+FEFF inside a value is data and is left alone — stripping it
      // everywhere would silently edit her content.
      final table = parseCsv('﻿id,name_en\na,we﻿ird\n');

      expect(table.headers.first, 'id');
      expect(table.rows.single.values.last, 'we﻿ird');
    });

    test('a file with no BOM is unchanged', () {
      final table = parseCsv('id,name_en\na,A\n');
      expect(table.headers, ['id', 'name_en']);
    });
  });

  group('line numbers, because a rejected row has to be findable', () {
    // Z09 names the failing row. The number has to be the one she can find in
    // the spreadsheet, so it counts FILE LINES from 1 with the header as line 1
    // — which is what Excel's row gutter shows.

    test('the first data row is line 2, because the header is line 1', () {
      final table = parseCsv('id,name_en\na,A\nb,B\n');
      expect(table.rows.map((r) => r.line), [2, 3]);
    });

    test('a record with an embedded newline shifts the lines after it', () {
      // The naive implementation — index in the row list, plus two — is wrong
      // the moment one value contains a line break, and then every reported row
      // number after it points at the wrong line. She would "fix" a good row.
      final table = parseCsv('id,name_en\na,"two\nlines"\nb,B\n');

      expect(table.rows.first.line, 2);
      expect(
        table.rows.last.line,
        4,
        reason: 'the two-line record occupies lines 2 and 3, so b starts at 4',
      );
    });
  });
}
