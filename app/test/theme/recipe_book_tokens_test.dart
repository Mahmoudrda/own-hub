// The one colour in Rahma's book that cannot ship, measured rather than argued.
//
// The book now uses the app's own Linen, Petrol and Pale Pink. Dark petrol ink
// on the white card is 11.34:1, and `AppColors.primary` on `AppColors.surface`
// is 6.94:1, so the book is still the more readable surface.
//
// The exception is the divider's huge stacked section title, `#D3737E`. It
// fails AA at any size on both grounds it is drawn over. It is replaced, and the replacement is
// measured here rather than trusted to a comment, because a designer adjusting
// a hex by eye is exactly how a 3.0 becomes a 2.9.

import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/coachbrand/domain/contrast.dart';
import 'package:own_hub/theme/recipe_book_tokens.dart';

/// The colour the book actually prints its section titles in. Never imported
/// into `lib/`; it exists here so the measurement that rejected it is on the
/// record.
const Color _bookRose = Color(0xFFD3737E);
// The book's own paper, before it took the app's palette: a before-value,
// kept so the title is measured on the page it was designed for.
const Color _bookPaper = Color(0xFFFBDCD9);

void main() {
  group('her palette is more readable than ours', () {
    test('her ink on her paper clears AA twice over', () {
      expect(
        contrastRatio(BookInk.ink, BookInk.paper),
        greaterThanOrEqualTo(7.0),
        reason: 'this is the body text of every card',
      );
    });

    test('the PS line is the darkest thing on the page, as she set it', () {
      expect(
        contrastRatio(BookInk.inkSoft, BookInk.paper),
        greaterThanOrEqualTo(7.0),
      );
    });

    test('her ink also holds on the soft pink ground', () {
      // Used for anything drawn straight onto the page rather than onto a card.
      expect(contrastRatio(BookInk.ink, BookInk.bg), greaterThanOrEqualTo(4.5));
    });
  });

  group('the section title is replaced, and the replacement is measured', () {
    test('the book own rose fails AA on both grounds', () {
      // 2.51:1 on the book's own paper, 2.53:1 on the soft pink it is drawn
      // over. The large-text carve-out is 3:1 and it does not reach that either.
      expect(contrastRatio(_bookRose, _bookPaper), lessThan(3.0));
      expect(contrastRatio(_bookRose, BookInk.bg), lessThan(3.0));
    });

    test(
      'the replacement clears normal text on paper and large text on pink',
      () {
        expect(
          contrastRatio(BookInk.roseTitle, BookInk.paper),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          contrastRatio(BookInk.roseTitle, BookInk.bg),
          greaterThanOrEqualTo(3.0),
        );
      },
    );

    test('nothing in lib/ draws the failing colour', () {
      // The belt to the braces above. A hex copied out of the PDF by hand would
      // pass every test in this file and fail every woman reading the divider.
      // Comment-filtered, like `i18n_guard_test.dart`, and for the same reason:
      // the token file names the colour it replaced, in writing, so the next
      // reader knows why `roseTitle` is not the hex in the PDF. A guard that
      // punished explaining itself would get the explanation deleted.
      final offenders = <String>[];
      for (final file
          in Directory('lib')
              .listSync(recursive: true)
              .whereType<File>()
              .where((f) => f.path.endsWith('.dart'))) {
        for (final line in file.readAsLinesSync()) {
          final trimmed = line.trimLeft();
          if (trimmed.startsWith('//') || trimmed.startsWith('*')) continue;
          if (RegExp('D3737E', caseSensitive: false).hasMatch(line)) {
            offenders.add('${file.path}: ${line.trim()}');
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'that is the book section title at 1.68:1 on its own ground. Use '
            'BookInk.roseTitle.',
      );
    });
  });

  group('no dark mode is invented for one tab', () {
    test('the app still has no dark theme at all', () {
      // The reason this file has no `Brightness` branch. A dark Eat tab inside a
      // light app is worse than no dark mode; the inversion that would work is
      // recorded in the token file as a comment and deliberately not wired.
      final tokens = File('lib/theme/app_tokens.dart').readAsStringSync();
      expect(tokens.contains('ColorScheme.dark'), isFalse);
      expect(
        tokens.contains('darkTheme'),
        isFalse,
        reason: 'MaterialApp has no dark theme to switch to',
      );
      expect(tokens.contains('ThemeMode'), isFalse);
      // `Brightness.dark` does appear once, on `statusBarIconBrightness`, which
      // describes the ICONS over a light bar rather than a dark theme. Asserting
      // its absence would be asserting the wrong thing.
      final book = File('lib/theme/recipe_book_tokens.dart').readAsStringSync();
      final code = book
          .split('\n')
          .where((l) => !l.trimLeft().startsWith('///'))
          .join('\n');
      expect(
        code.contains('Brightness'),
        isFalse,
        reason: 'the dark palette is a note, not a wiring',
      );
    });
  });
}
