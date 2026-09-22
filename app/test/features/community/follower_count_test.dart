// Rule 11's Dart half: a follower count that cannot be ranked.
//
// The figures here are deliberately unlike the prototype's 612/208/4,210 — a
// test that reuses the mockup's numbers cannot tell a real value from a
// leftover sample.

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/community/domain/follower_count.dart';

void main() {
  group('it cannot be ordered', () {
    test('it does not implement Comparable', () {
      const count = FollowerCount(7331);

      expect(
        count,
        isNot(isA<Comparable<dynamic>>()),
        reason:
            'G10 §5: FollowerCount "does not implement Comparable and has no > '
            'operator, so a ranking cannot be written in Dart". The moment it '
            'is Comparable, List.sort() ranks women by followers with no '
            'argument at all.',
      );
    });

    test('the guard would bite — a bare int IS orderable', () {
      // A positive control. Without this, "isNot(Comparable)" could pass
      // because the matcher is wrong rather than because the type is right.
      expect(
        7331,
        isA<Comparable<dynamic>>(),
        reason:
            'if this fails the matcher above proves nothing, and the wrapper '
            'is not demonstrably buying anything',
      );
    });

    test('a list of them cannot be sorted without writing a comparator', () {
      // The realistic failure is not someone calling compareTo; it is someone
      // calling sort() on a list and it simply working. It must not.
      final counts = <FollowerCount>[
        const FollowerCount(88),
        const FollowerCount(7331),
      ];

      expect(
        () => (counts as List<dynamic>).sort(),
        throwsA(isA<TypeError>()),
        reason:
            'sort() with no comparator casts elements to Comparable at '
            'runtime. That cast must fail — this is the keystroke rule 11 '
            'exists to remove.',
      );
    });
  });

  group('what it still does', () {
    test('two counts of the same size are equal', () {
      // Equality is kept on purpose: "did it change" is not a ranking.
      expect(const FollowerCount(19), const FollowerCount(19));
      expect(const FollowerCount(19), isNot(const FollowerCount(20)));
      expect(
        const FollowerCount(19).hashCode,
        const FollowerCount(19).hashCode,
      );
    });

    test('it labels itself in Western digits with a separator', () {
      // P0-A11Y-01: Western numerals in Arabic too. A numeral is a value, not
      // copy, so this does not go through the dictionary.
      expect(const FollowerCount(7331).label, '7,331');
      expect(const FollowerCount(88).label, '88');
      expect(FollowerCount.none.label, '0');
    });

    test('nobody and not-yet-read are different things', () {
      // A profile rendered from a post's authorCard has no follower figure in
      // it. Showing 0 there would be a lie about a woman rather than an
      // absence of information.
      expect(FollowerCount.none.value, 0);
      expect(FollowerCount.unknown, isNull);
    });

    test('a negative count is not constructible', () {
      expect(() => FollowerCount(-1), throwsA(isA<AssertionError>()));
    });
  });
}
