// statedLine — the helper that stops a dictionary string stating somebody
// else's number as her own.
//
// This is a tiny function with an outsized job, and it needs a POSITIVE CONTROL
// more than most: a guard that always returns its argument is indistinguishable
// from one that works, and PHASE1-FIXES.md §14 records this codebase shipping
// exactly that — a rule-7 scan whose regex could never match. So the important
// test here is not "it returns the line", it is "it returns NULL when the figure
// is not hers".

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/rewards/stated_figure.dart';

void main() {
  group('it shows a line only to the woman it is true of', () {
    test('the figure is hers, so the sentence is shown', () {
      expect(
        statedLine<int>('Your 14 weeks are safe', states: 14, hers: 14),
        'Your 14 weeks are safe',
      );
    });

    test('the figure is not hers, so the screen says nothing', () {
      // The control. If this ever returns the line, every call site in the app
      // is back to stating the prototype's numbers as her personal facts —
      // which is the defect PHASE1-QA-VERDICT calls blocking.
      expect(
        statedLine<int>('Your 14 weeks are safe', states: 14, hers: 9),
        isNull,
      );
      expect(
        statedLine<int>('Your 14 weeks are safe', states: 14, hers: 0),
        isNull,
      );
      expect(
        statedLine<int>('Your 14 weeks are safe', states: 14, hers: 15),
        isNull,
      );
    });

    test('a woman with no data at all is told nothing', () {
      // The callers pass a sentinel that cannot equal a real count, so an
      // unwired screen renders nothing rather than the mockup's figure.
      expect(statedLine<int>('Level 7', states: 7, hers: -1), isNull);
    });
  });

  group('it works for any figure with value equality', () {
    test('a pair of numbers, both of which must match', () {
      const line = '14 weeks counted · best run 9';
      expect(
        statedLine<(int, int)>(line, states: (14, 9), hers: (14, 9)),
        line,
      );
      expect(
        statedLine<(int, int)>(line, states: (14, 9), hers: (14, 5)),
        isNull,
        reason: 'the right counted weeks but the wrong run is still not hers',
      );
      expect(
        statedLine<(int, int)>(line, states: (14, 9), hers: (11, 9)),
        isNull,
      );
    });

    test('a date', () {
      expect(
        statedLine<DateTime>(
          '3 Jun',
          states: DateTime(2026, 6, 3),
          hers: DateTime(2026, 6, 3),
        ),
        '3 Jun',
      );
      expect(
        statedLine<DateTime>(
          '3 Jun',
          states: DateTime(2026, 6, 3),
          hers: DateTime(2026, 6, 4),
        ),
        isNull,
      );
    });

    test('a nullable measurement', () {
      expect(
        statedLine<num?>('Waist 82 cm', states: 82, hers: 82),
        'Waist 82 cm',
      );
      expect(statedLine<num?>('Waist 82 cm', states: 82, hers: 76), isNull);
      expect(
        statedLine<num?>('Waist 82 cm', states: 82, hers: null),
        isNull,
        reason: 'nothing recorded is not the same as the mockup\'s figure',
      );
    });
  });

  group('the predicate form agrees with the string form', () {
    test('they cannot drift apart', () {
      for (final pair in const [(14, 14), (14, 9), (0, 0), (7, 8)]) {
        final shown = statedLine<int>('x', states: pair.$1, hers: pair.$2);
        final allowed = statesHerFigure<int>(states: pair.$1, hers: pair.$2);
        expect(shown != null, allowed, reason: 'for $pair');
      }
    });
  });
}
