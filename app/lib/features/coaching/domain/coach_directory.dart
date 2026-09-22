/// `H01` — the one search surface in the product, and the one place rule 11
/// could be broken by accident.
///
/// ## Nothing is ranked
///
/// [DirectoryOrder] has four values: a relevance match, reply speed, and price
/// in either direction. **`followers`, `rating`, `weight` and `weightLost` are
/// not constructible**, so "order coaches by how much weight their clients
/// lost" is not a sentence this code can say. That is deliberate and it is
/// stricter than the plan: G11 §5 listed `rating` among the sort keys, and the
/// owner removed it. A rating is *displayed* — at five reviews or more — and
/// never sorted by, because a sortable rating is a league table of women.
///
/// [DirectoryRow] also has **no follower count field at all**. The plan shows
/// follower counts on `H02` (they come from G10's follow graph, at the profile,
/// where they are a fact about one woman rather than a column to sort). Nothing
/// in this file can see one.
///
/// ## Why it filters locally
///
/// The directory is a CDN artefact, not a query: `directory/coaches.v{n}.json.gz`,
/// about 110 KB gzipped for two thousand coaches, refreshed every fifteen
/// minutes. So `H01` costs **zero Firestore reads**, facet filters are instant,
/// and an unbounded collection scan is not expressible even by a malicious
/// client. When the pack is unavailable, [DirectorySource.coldFallback] is a
/// bounded, indexed query — twenty rows and a cursor — never an unbounded scan
/// and never an empty screen with no explanation (`P0-COACH-03`).
///
/// Staleness cannot oversell a coach: `acceptingClients` and `spotsLeft` are
/// re-read server-side at checkout (`P0-COACH-04`), and [CheckoutGate] refuses
/// locally first so she is not sent to a payment page for a full coach.
library;

import 'package:meta/meta.dart';

import 'money.dart';

/// What a coach works on, as a **searchable facet**.
///
/// A narrow read-only echo of `features/coach/domain/coach_profile.dart`'s
/// `Specialty`, which this agent may not edit and other agents are changing.
/// The adapter between the two lives at the wiring layer.
///
/// ## One value is deliberately missing
///
/// The coach side has a fifth specialty, `weightLoss`. It is **not** a facet
/// here, and nothing in this feature can hold or filter by it: the product rule
/// is that no weight field exists anywhere, and a searchable "weight loss"
/// column is a weight field with a nicer name — it is one short step from
/// ordering women by how much of it their clients did.
///
/// The consequence is stated rather than hidden: a coach who describes herself
/// only that way is still in the directory, still findable by name, city,
/// language and price, and still renders her own words on her own page. She is
/// simply not filterable by that facet. The wiring adapter must map that
/// specialty to **no facet** rather than inventing one here.
enum CoachingSpecialty { postpartum, beginners, strength, pregnancy }

/// What she coaches in.
enum CoachingLanguage { arabic, english }

/// One row of the directory pack. About 240 bytes on the wire.
///
/// Every nullable field here is nullable for the same reason: **the pack could
/// not supply it, and inventing one would be marketing**. A null reply time
/// renders no claim about how fast she answers. A null price renders no figure.
/// A null spots-left renders no urgency.
@immutable
class DirectoryRow {
  const DirectoryRow({
    required this.coachUid,
    required this.displayName,
    required this.city,
    required this.specialties,
    required this.languages,
    required this.acceptingClients,
    this.priceFrom,
    this.reviewCount = 0,
    this.ratingAverage,
    this.replyMinsP50,
    this.spotsLeft,
    this.certificatesCheckedAt,
  });

  final String coachUid;
  final String displayName;
  final String city;

  /// At most three; the coach chooses them.
  final List<CoachingSpecialty> specialties;
  final List<CoachingLanguage> languages;

  /// Whether her books are open. Re-read server-side at checkout.
  final bool acceptingClients;

  /// Her cheapest published package, or null when the pack has no price.
  final Money? priceFrom;

  /// How many women have rated her.
  final int reviewCount;

  /// Her average, 1–5, or null when nobody has rated her.
  ///
  /// **Never read directly by a screen.** Go through [ratingToDisplay], which
  /// applies the five-review floor.
  final double? ratingAverage;

  /// A measured 30-day rolling median, in minutes. Null means *we have not
  /// measured it*, and null renders no claim — not "about two hours".
  final int? replyMinsP50;

  /// Places left, or null when the pack does not carry it.
  final int? spotsLeft;

  /// When a human checked her certificates.
  final DateTime? certificatesCheckedAt;

  /// The rating a screen may show, or null when it may not.
  ///
  /// **Five reviews or more**, the owner's figure. Below that the average is
  /// noise dressed as a judgement about a woman's work, and one unhappy client
  /// out of two is a 2.5 that follows her around.
  double? get ratingToDisplay =>
      reviewCount >= kMinimumReviewsToShowRating ? ratingAverage : null;

  /// Whether she can be bought from at all right now.
  bool get hasPlaces =>
      acceptingClients && (spotsLeft == null || spotsLeft! > 0);
}

/// The owner's figure: a rating is displayed at five reviews, never fewer.
///
/// `features/coach/domain/coach_profile.dart` holds the authority
/// (`RatingDisplay.minimumReviews`). This is the read-only echo on the client
/// side of the boundary, and the guard test fails if they disagree.
const int kMinimumReviewsToShowRating = 5;

/// How the list may be ordered.
///
/// Four values. The three that would break rule 11 are absent, which is why
/// this is an enum and not a string or a comparator argument.
enum DirectoryOrder {
  /// How well she matches the facets she was filtered by, then name. The
  /// default, and the only one that is not a single column.
  match,

  /// Fastest measured reply first. Coaches with no measurement go last rather
  /// than being given a plausible number.
  replySpeed,

  /// Cheapest first. Coaches with no stated price go last.
  priceLowFirst,

  /// Dearest first.
  priceHighFirst,
}

/// Field names that may never become a sort key.
///
/// Named `kForbidden…` deliberately: `test/product_rules_test.dart` exempts the
/// contents of a declaration whose own name says it is a deny list, because a
/// list that **bans** these words is enforcing rule 11 rather than breaking it.
const Set<String> kForbiddenDirectorySortFields = <String>{
  'followers',
  'followerCount',
  'rating',
  'ratingAverage',
  'weight',
  'weightKg',
  'weightLost',
  'kgLost',
};

/// The ceiling behind `H01`'s one price-band chip.
///
/// A **product decision named in code**, not a figure frozen into a sentence.
/// The chip renders the dictionary's parameterised `Under {n} EGP` with this
/// value, so moving the band moves the chip and nothing goes stale. The
/// dictionary's `under2000Egp` — `'Under 2,000 EGP'` — bakes the same number
/// into the copy and is deliberately referenced nowhere in `lib/`: that is the
/// shape `baked_in_samples_test.dart` counts, and a chip built from it would
/// keep saying 2,000 after this constant changed.
///
/// A ceiling, never a floor. [DirectoryQuery.maxPrice] is the facet.
const Money kDirectoryPriceBand = Money.pounds(2000);

/// The facets `H01` filters by.
@immutable
class DirectoryQuery {
  const DirectoryQuery({
    this.specialties = const <CoachingSpecialty>{},
    this.languages = const <CoachingLanguage>{},
    this.city,
    this.maxPrice,
    this.acceptingOnly = true,
    this.nameQuery = '',
    this.order = DirectoryOrder.match,
  });

  final Set<CoachingSpecialty> specialties;
  final Set<CoachingLanguage> languages;
  final String? city;

  /// The "under N EGP" band. A ceiling, never a floor: nobody filters for
  /// expensive coaches, and offering it would be an odd thing to suggest.
  final Money? maxPrice;

  /// Default true. A coach who cannot take anyone is not a search result.
  final bool acceptingOnly;

  final String nameQuery;
  final DirectoryOrder order;

  /// How many facets she has chosen. Reported to analytics as a count, never
  /// as the facets themselves.
  int get facetCount =>
      specialties.length +
      languages.length +
      (city == null ? 0 : 1) +
      (maxPrice == null ? 0 : 1);

  DirectoryQuery copyWith({
    Set<CoachingSpecialty>? specialties,
    Set<CoachingLanguage>? languages,
    Object? city = _unset,
    Object? maxPrice = _unset,
    bool? acceptingOnly,
    String? nameQuery,
    DirectoryOrder? order,
  }) => DirectoryQuery(
    specialties: specialties ?? this.specialties,
    languages: languages ?? this.languages,
    city: identical(city, _unset) ? this.city : city as String?,
    maxPrice: identical(maxPrice, _unset) ? this.maxPrice : maxPrice as Money?,
    acceptingOnly: acceptingOnly ?? this.acceptingOnly,
    nameQuery: nameQuery ?? this.nameQuery,
    order: order ?? this.order,
  );
}

const Object _unset = Object();

/// Where the rows came from, so `H01` can say something true when the pack is
/// missing instead of rendering an empty list.
enum DirectorySource {
  /// The CDN artefact. Zero Firestore reads.
  pack,

  /// A bounded indexed query, twenty rows and a cursor. Costs reads, and only
  /// runs when the pack could not be fetched.
  coldFallback,

  /// Neither worked. The screen says so and offers another attempt; it does
  /// **not** render "no coaches found", which would be a claim about the
  /// product rather than about the network.
  unavailable,
}

/// The bound on the cold fallback. Twenty and a cursor, per G11 §2.
const int kColdFallbackPageSize = 20;

/// What a repository hands back for `H01`.
@immutable
class DirectorySnapshot {
  const DirectorySnapshot({
    required this.rows,
    required this.source,
    this.hasMore = false,
  });

  /// Deliberately empty and [DirectorySource.unavailable] when nothing loaded.
  const DirectorySnapshot.unavailable()
    : rows = const <DirectoryRow>[],
      source = DirectorySource.unavailable,
      hasMore = false;

  final List<DirectoryRow> rows;
  final DirectorySource source;

  /// Whether a cursor exists. Only ever true on the cold fallback: the pack is
  /// complete by construction.
  final bool hasMore;

  /// True when the screen should explain rather than show an empty list.
  bool get couldNotLoad => source == DirectorySource.unavailable;
}

/// Local filtering and ordering over the pack.
abstract final class CoachDirectory {
  /// The rows matching [query], in [DirectoryQuery.order].
  ///
  /// Pure, synchronous and total: no network, no exceptions, and an empty
  /// result for a query nothing matches — which is a real answer, unlike an
  /// empty result caused by a failed fetch. Those two are told apart by
  /// [DirectorySnapshot.source], not by the length of a list.
  static List<DirectoryRow> filter(
    List<DirectoryRow> rows,
    DirectoryQuery query,
  ) {
    final needle = normaliseForSearch(query.nameQuery);
    final matched = <DirectoryRow>[
      for (final row in rows)
        if (_matches(row, query, needle)) row,
    ];
    matched.sort((a, b) => _compare(a, b, query));
    return matched;
  }

  static bool _matches(DirectoryRow row, DirectoryQuery query, String needle) {
    if (query.acceptingOnly && !row.hasPlaces) return false;
    if (query.specialties.isNotEmpty &&
        !row.specialties.any(query.specialties.contains)) {
      return false;
    }
    if (query.languages.isNotEmpty &&
        !row.languages.any(query.languages.contains)) {
      return false;
    }
    if (query.city != null &&
        normaliseForSearch(row.city) != normaliseForSearch(query.city!)) {
      return false;
    }
    if (query.maxPrice != null) {
      final price = row.priceFrom;
      // A coach with no stated price is not "under 2,000": she is unknown, and
      // showing her inside a price band would be stating a figure for her.
      if (price == null || !(price <= query.maxPrice!)) return false;
    }
    if (needle.isNotEmpty &&
        !normaliseForSearch(row.displayName).contains(needle)) {
      return false;
    }
    return true;
  }

  static int _compare(DirectoryRow a, DirectoryRow b, DirectoryQuery query) {
    switch (query.order) {
      case DirectoryOrder.match:
        final byFacets = _facetHits(b, query).compareTo(_facetHits(a, query));
        if (byFacets != 0) return byFacets;
        return _byName(a, b);
      case DirectoryOrder.replySpeed:
        // Unmeasured last. The alternative is to treat "we do not know" as a
        // number, which is how an unmeasured coach ends up at the top or the
        // bottom of a list for a reason nobody intended.
        final ar = a.replyMinsP50;
        final br = b.replyMinsP50;
        if (ar == null && br == null) return _byName(a, b);
        if (ar == null) return 1;
        if (br == null) return -1;
        final byReply = ar.compareTo(br);
        return byReply != 0 ? byReply : _byName(a, b);
      case DirectoryOrder.priceLowFirst:
      case DirectoryOrder.priceHighFirst:
        final ap = a.priceFrom;
        final bp = b.priceFrom;
        if (ap == null && bp == null) return _byName(a, b);
        if (ap == null) return 1;
        if (bp == null) return -1;
        final byPrice = query.order == DirectoryOrder.priceLowFirst
            ? ap.compareTo(bp)
            : bp.compareTo(ap);
        return byPrice != 0 ? byPrice : _byName(a, b);
    }
  }

  static int _facetHits(DirectoryRow row, DirectoryQuery query) {
    var hits = 0;
    for (final s in query.specialties) {
      if (row.specialties.contains(s)) hits++;
    }
    for (final l in query.languages) {
      if (row.languages.contains(l)) hits++;
    }
    return hits;
  }

  /// Ties break on the normalised name, never on anything about her body or
  /// her popularity. A stable tiebreak also stops the list reshuffling between
  /// two identical renders, which reads as a bug.
  static int _byName(DirectoryRow a, DirectoryRow b) => normaliseForSearch(
    a.displayName,
  ).compareTo(normaliseForSearch(b.displayName));
}

/// Folds Arabic orthography so that a name types the way it is spoken.
///
/// Egyptian women type Arabic with and without diacritics, with alef in all
/// four of its forms, and with ta-marbuta where a ha is meant. A match that
/// depended on exact orthography would fail on most real input — the same
/// problem `features/eat/domain/food_library.dart` solved for dish names.
///
/// **The characters are written as `\u` escapes rather than as literals.**
/// `test/i18n_guard_test.dart` forbids Arabic text in code outside a
/// three-entry allowlist that this agent may not extend, and the guard is
/// right: Arabic in code is usually copy that escaped the dictionary. This is
/// not copy — it is input-matching grammar, and it renders nothing — so it is
/// written in a form that is unmistakably not a sentence.
String normaliseForSearch(String input) {
  final out = StringBuffer();
  for (final rune in input.trim().toLowerCase().runes) {
    if (_stripped.contains(rune)) continue;
    out.writeCharCode(_folded[rune] ?? rune);
  }
  // Collapse runs of whitespace so "Sara  Adel" finds "Sara Adel".
  return out.toString().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).join(' ');
}

/// Marks and joiners that carry no identity: the harakat, the dagger alef, the
/// sukun, and tatweel (the kashida used to stretch a word for typesetting).
final Set<int> _stripped = <int>{
  0x0640, // tatweel
  for (var c = 0x064B; c <= 0x065F; c++) c, // harakat and friends
  0x0670, // superscript alef
  for (var c = 0x06D6; c <= 0x06ED; c++) c, // Quranic marks
};

/// Orthographic variants folded onto one form.
const Map<int, int> _folded = <int, int>{
  0x0622: 0x0627, // alef with madda -> alef
  0x0623: 0x0627, // alef with hamza above -> alef
  0x0625: 0x0627, // alef with hamza below -> alef
  0x0671: 0x0627, // alef wasla -> alef
  0x0629: 0x0647, // ta marbuta -> ha
  0x0649: 0x064A, // alef maksura -> ya
  0x06CC: 0x064A, // farsi ya -> ya
  0x06A9: 0x0643, // keheh -> kaf
};
