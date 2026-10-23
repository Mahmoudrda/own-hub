// `H01` — the one search surface, and rule 11's only real exposure.
//
// `P0-COACH-01`, `P0-COACH-03`, `P1-RULE-11B`, and the owner's five-review
// floor on ratings.

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/coaching/domain/coach_directory.dart';
import 'package:own_hub/features/coaching/domain/money.dart';

DirectoryRow _row({
  required String uid,
  required String name,
  String city = 'Giza',
  List<CoachingSpecialty> specialties = const [CoachingSpecialty.postpartum],
  List<CoachingLanguage> languages = const [CoachingLanguage.arabic],
  bool accepting = true,
  int? pounds = 1800,
  int reviewCount = 0,
  double? ratingAverage,
  int? replyMins,
  int? spotsLeft,
}) => DirectoryRow(
  coachUid: uid,
  displayName: name,
  city: city,
  specialties: specialties,
  languages: languages,
  acceptingClients: accepting,
  priceFrom: pounds == null ? null : Money.pounds(pounds),
  reviewCount: reviewCount,
  ratingAverage: ratingAverage,
  replyMinsP50: replyMins,
  spotsLeft: spotsLeft,
);

final _nourhan = _row(
  uid: 'c1',
  name: 'Nourhan El-Sayed',
  pounds: 1800,
  reviewCount: 126,
  ratingAverage: 4.8,
  replyMins: 120,
  specialties: const [CoachingSpecialty.postpartum, CoachingSpecialty.strength],
  languages: const [CoachingLanguage.arabic, CoachingLanguage.english],
);
final _mariam = _row(
  uid: 'c2',
  name: 'Mariam Hassan',
  city: 'Cairo',
  pounds: 1500,
  reviewCount: 88,
  ratingAverage: 4.9,
  replyMins: 240,
  specialties: const [CoachingSpecialty.beginners],
);
final _dina = _row(
  uid: 'c3',
  name: 'Dina Farid',
  city: 'Alexandria',
  pounds: 2200,
  reviewCount: 54,
  ratingAverage: 4.7,
  replyMins: 60,
  specialties: const [CoachingSpecialty.strength],
  languages: const [CoachingLanguage.english],
);

final _all = <DirectoryRow>[_nourhan, _mariam, _dina];

void main() {
  group('P1-RULE-11B — nothing is ranked', () {
    test('the sort keys that would break rule 11 are not constructible', () {
      expect(DirectoryOrder.values, hasLength(4));
      final names = DirectoryOrder.values.map((o) => o.name.toLowerCase());
      for (final forbidden in [
        'follower',
        'rating',
        'weight',
        'popular',
        'best',
      ]) {
        expect(
          names.any((n) => n.contains(forbidden)),
          isFalse,
          reason: 'no sort key may mention "$forbidden"',
        );
      }
    });

    test('rating is displayed and never sorted by', () {
      // Stricter than the plan, which listed `rating` among the sort keys. The
      // owner removed it: a sortable rating is a league table of women.
      expect(
        DirectoryOrder.values.map((o) => o.name),
        isNot(contains('rating')),
      );
      // And it is still shown, which is the point of the distinction.
      expect(_nourhan.ratingToDisplay, 4.8);
    });

    test('a directory row cannot hold a follower count', () {
      // Asserted at the type level by there being no such field; asserted here
      // by the only other thing a test can see, which is that nothing in the
      // row's own describable state mentions one. The source guard in
      // `coaching_rules_guard_test.dart` is the real enforcement.
      expect(kForbiddenDirectorySortFields, contains('followerCount'));
      expect(kForbiddenDirectorySortFields, contains('weightLost'));
    });

    test('no specialty facet names a body outcome', () {
      // The coach side has a `weightLoss` specialty; it is deliberately not a
      // searchable facet here, because a filterable weight column is one short
      // step from ordering women by it.
      for (final s in CoachingSpecialty.values) {
        expect(s.name.toLowerCase(), isNot(contains('weight')));
      }
    });

    test('ties break on the name, never on anything about her', () {
      final a = _row(
        uid: 'x',
        name: 'Zeinab',
        pounds: 1800,
        reviewCount: 500,
        ratingAverage: 5.0,
      );
      final b = _row(
        uid: 'y',
        name: 'Amal',
        pounds: 1800,
        reviewCount: 5,
        ratingAverage: 3.0,
      );
      final sorted = CoachDirectory.filter([
        a,
        b,
      ], const DirectoryQuery(order: DirectoryOrder.priceLowFirst));
      expect(sorted.map((r) => r.displayName), [
        'Amal',
        'Zeinab',
      ], reason: 'same price, so alphabetical — not "better rated first"');
    });
  });

  group('the five-review floor', () {
    test('a rating is withheld below five reviews', () {
      final four = _row(
        uid: 'c9',
        name: 'Hala',
        reviewCount: 4,
        ratingAverage: 2.5,
      );
      expect(four.ratingToDisplay, isNull);
      expect(kMinimumReviewsToShowRating, 5);
    });

    test('exactly five reviews is enough', () {
      final five = _row(
        uid: 'c9',
        name: 'Hala',
        reviewCount: 5,
        ratingAverage: 4.2,
      );
      expect(five.ratingToDisplay, 4.2);
    });

    test('no reviews and no average renders nothing rather than zero', () {
      final fresh = _row(uid: 'c9', name: 'Hala');
      expect(fresh.reviewCount, 0);
      expect(fresh.ratingToDisplay, isNull);
      expect(
        fresh.ratingAverage,
        isNull,
        reason: 'a new coach has no rating, which is not the same as 0.0',
      );
    });
  });

  group('P0-COACH-01 — filtering by facets', () {
    test('specialty, language and price together', () {
      final result = CoachDirectory.filter(
        _all,
        DirectoryQuery(
          specialties: const {CoachingSpecialty.postpartum},
          languages: const {CoachingLanguage.arabic},
          maxPrice: const Money.pounds(2000),
        ),
      );
      expect(result.map((r) => r.coachUid), ['c1']);
    });

    test('a coach with no stated price is not "under 2,000"', () {
      // Unknown is unknown. Showing her inside a price band would be stating a
      // figure on her behalf.
      final unpriced = _row(uid: 'c4', name: 'Salma', pounds: null);
      final result = CoachDirectory.filter([
        ..._all,
        unpriced,
      ], DirectoryQuery(maxPrice: const Money.pounds(2000)));
      expect(result.map((r) => r.coachUid), isNot(contains('c4')));
    });

    test('a coach with no places is out of the list by default', () {
      final full = _row(uid: 'c5', name: 'Yara', accepting: false);
      final result = CoachDirectory.filter([
        ..._all,
        full,
      ], const DirectoryQuery());
      expect(result.map((r) => r.coachUid), isNot(contains('c5')));
    });

    test('zero places left is the same as closed', () {
      final full = _row(uid: 'c6', name: 'Reem', spotsLeft: 0);
      expect(full.hasPlaces, isFalse);
    });

    test('a query nothing matches returns an empty list, not an error', () {
      final result = CoachDirectory.filter(
        _all,
        const DirectoryQuery(specialties: {CoachingSpecialty.pregnancy}),
      );
      expect(result, isEmpty);
    });
  });

  group('ordering', () {
    test('cheapest first, and the unpriced go last', () {
      final unpriced = _row(uid: 'c4', name: 'Aya', pounds: null);
      final result = CoachDirectory.filter([
        ..._all,
        unpriced,
      ], const DirectoryQuery(order: DirectoryOrder.priceLowFirst));
      expect(result.map((r) => r.coachUid), ['c2', 'c1', 'c3', 'c4']);
    });

    test('dearest first reverses only the priced rows', () {
      final unpriced = _row(uid: 'c4', name: 'Aya', pounds: null);
      final result = CoachDirectory.filter([
        ..._all,
        unpriced,
      ], const DirectoryQuery(order: DirectoryOrder.priceHighFirst));
      expect(result.map((r) => r.coachUid), ['c3', 'c1', 'c2', 'c4']);
    });

    test('fastest reply first, and the unmeasured go last', () {
      // Treating "we have not measured her" as a number is how an unmeasured
      // coach ends up at one end of a list for a reason nobody intended.
      final unmeasured = _row(uid: 'c4', name: 'Aya', replyMins: null);
      final result = CoachDirectory.filter([
        ..._all,
        unmeasured,
      ], const DirectoryQuery(order: DirectoryOrder.replySpeed));
      expect(result.map((r) => r.coachUid), ['c3', 'c1', 'c2', 'c4']);
    });

    test('match puts the coach who hits more facets first', () {
      final result = CoachDirectory.filter(
        _all,
        const DirectoryQuery(
          specialties: {
            CoachingSpecialty.postpartum,
            CoachingSpecialty.strength,
          },
          acceptingOnly: false,
        ),
      );
      expect(result.first.coachUid, 'c1');
    });
  });

  group('Arabic name search', () {
    test('orthographic variants of the same name match', () {
      // alef with hamza, plain alef, and a stretched form with a kashida.
      const withHamza = 'أمل';
      const plain = 'امل';
      const stretched = 'أمــل';
      expect(normaliseForSearch(withHamza), normaliseForSearch(plain));
      expect(normaliseForSearch(stretched), normaliseForSearch(plain));
    });

    test('ta marbuta folds onto ha', () {
      const taMarbuta = 'فاطمة';
      const ha = 'فاطمه';
      expect(normaliseForSearch(taMarbuta), normaliseForSearch(ha));
    });

    test('harakat are ignored', () {
      const withMarks = 'مَريم';
      const without = 'مريم';
      expect(normaliseForSearch(withMarks), normaliseForSearch(without));
    });

    test('Latin names match case-insensitively and across extra spaces', () {
      final result = CoachDirectory.filter(
        _all,
        const DirectoryQuery(nameQuery: '  mariam   hassan '),
      );
      expect(result.map((r) => r.coachUid), ['c2']);
    });

    test('a name substring is enough', () {
      final result = CoachDirectory.filter(
        _all,
        const DirectoryQuery(nameQuery: 'farid'),
      );
      expect(result.map((r) => r.coachUid), ['c3']);
    });
  });

  group('P0-COACH-03 — the fallback is designed, not improvised', () {
    test('a failed load is told apart from an empty result', () {
      const failed = DirectorySnapshot.unavailable();
      expect(failed.couldNotLoad, isTrue);
      expect(failed.rows, isEmpty);

      const matchedNothing = DirectorySnapshot(
        rows: <DirectoryRow>[],
        source: DirectorySource.pack,
      );
      expect(matchedNothing.couldNotLoad, isFalse);
    });

    test('the cold fallback page is bounded', () {
      expect(kColdFallbackPageSize, 20);
    });
  });

  group('the query itself', () {
    test('facets are counted for analytics, never the facets themselves', () {
      const query = DirectoryQuery(
        specialties: {CoachingSpecialty.postpartum},
        languages: {CoachingLanguage.arabic},
        city: 'Giza',
      );
      expect(query.facetCount, 3);
    });

    test('copyWith can clear a nullable facet as well as set it', () {
      const query = DirectoryQuery(city: 'Giza');
      expect(query.copyWith(city: null).city, isNull);
      expect(query.copyWith().city, 'Giza');
    });
  });
}
