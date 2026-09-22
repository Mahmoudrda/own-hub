/// Reading a published page — where consent is actually checked.
///
/// One renderer, one resolver. B10's preview and G11's H02 both go through
/// [PublishedPortfolio], so there is no second code path where a result could
/// be resolved differently, cached differently, or not checked at all.
///
/// ## Consent is resolved here, on every read
///
/// [PublishedPortfolio.resolve] filters `resultIds` through
/// [ResultVisibility.isPublishable] against the **live** documents and the
/// **current** time. Nothing it computes is stored. A woman who withdraws at
/// 14:00 is gone from the 14:01 read of a page published in March.
///
/// ## Offline, the results block says so rather than guessing
///
/// G13 §4: offline the preview *"renders 'results appear when you're online',
/// never a stale copy — it cannot check consent, so it does not guess."* That
/// is [ResultsRender.waitingForSignal]. Showing a cached result offline would
/// be the one failure mode this whole design exists to prevent: another woman's
/// photograph on screen with no way to know whether she still agrees.
library;

import 'package:meta/meta.dart';

import 'consent.dart';
import 'offers_port.dart';
import 'portfolio.dart';
import 'portfolio_block.dart';

/// What G11 renders. [PortfolioState] is the contract G13 publishes to it.
sealed class PortfolioState {
  const PortfolioState();
}

final class PortfolioLoading extends PortfolioState {
  const PortfolioLoading();
}

/// She has a published page.
final class PortfolioLive extends PortfolioState {
  const PortfolioLive(this.portfolio);
  final PublishedPortfolio portfolio;
}

/// She took it down. **G11 must render this as its own state** — a coach with
/// no visible page is not an error.
final class PortfolioHidden extends PortfolioState {
  const PortfolioHidden();
}

/// She has never published. Also not an error.
final class PortfolioNotBuilt extends PortfolioState {
  const PortfolioNotBuilt();
}

/// The CDN failed and so did the fallback.
final class PortfolioUnavailable extends PortfolioState {
  const PortfolioUnavailable();
}

/// What a `results` block should draw right now.
sealed class ResultsRender {
  const ResultsRender();
}

/// These ids currently resolve. Possibly empty — an empty results block draws
/// nothing rather than a placeholder for a woman who withdrew.
final class ResultsVisible extends ResultsRender {
  const ResultsVisible(this.resultIds);
  final List<String> resultIds;
}

/// Offline. Consent cannot be checked, so nothing is shown and the screen says
/// why.
final class ResultsWaitingForSignal extends ResultsRender {
  const ResultsWaitingForSignal();
}

/// A published page, with its references resolved at read time.
@immutable
class PublishedPortfolio {
  const PublishedPortfolio._({
    required this.page,
    required this.readAt,
    required this.online,
    required this.results,
    required this.offers,
    required this.verifiedCertIds,
  });

  /// Resolves [page] against the live documents.
  ///
  /// [results] are the live result documents — not a copy taken at publish, and
  /// not a cached list. [now] is the moment of the read.
  factory PublishedPortfolio.resolve({
    required Portfolio page,
    required DateTime now,
    bool online = true,
    Map<String, ClientResult> results = const <String, ClientResult>{},
    List<OfferSummary> offers = const <OfferSummary>[],
    Set<String> verifiedCertIds = const <String>{},
  }) => PublishedPortfolio._(
    page: page,
    readAt: now,
    online: online,
    results: Map.unmodifiable(results),
    offers: List.unmodifiable(offers),
    verifiedCertIds: Set.unmodifiable(verifiedCertIds),
  );

  final Portfolio page;
  final DateTime readAt;
  final bool online;

  /// Live documents, keyed by id. Read, never copied into the page.
  final Map<String, ClientResult> results;

  final List<OfferSummary> offers;
  final Set<String> verifiedCertIds;

  /// The blocks a client sees. Hidden blocks are absent — in preview and in
  /// H02, because both call this.
  List<PortfolioBlock> get blocks => page.visibleBlocks;

  /// The result ids a `results` block should draw, checked now.
  ResultsRender resultsFor(ResultsPayload payload) {
    if (!online) return const ResultsWaitingForSignal();
    return ResultsVisible(
      ResultVisibility.resolveIds(payload.resultIds, results, readAt),
    );
  }

  /// A testimonial carrying a `resultId` is gated exactly like a result.
  List<Testimonial> testimonialsFor(TestimonialsPayload payload) {
    if (!online) {
      return List.unmodifiable(payload.items.where((t) => t.resultId == null));
    }
    return List.unmodifiable(
      payload.items.where((t) {
        final id = t.resultId;
        if (id == null) return true;
        final result = results[id];
        return result != null && ResultVisibility.isPublishable(result, readAt);
      }),
    );
  }

  /// Offers, resolved through K04's port. A retired offer drops out.
  List<OfferSummary> offersFor(OffersPayload payload) {
    final wanted = payload.offerIds.toSet();
    return List.unmodifiable(
      offers.where((o) => o.isActive && wanted.contains(o.offerId)),
    );
  }

  /// Certificates, dropped unless currently verified.
  List<String> certificatesFor(CertificatesPayload payload) =>
      List.unmodifiable(payload.certIds.where(verifiedCertIds.contains));

  /// The CDN object: `p/{coachUid}/live.json`.
  ///
  /// **Result ids only.** Each result is its own object whose *existence* is
  /// the gate — withdrawal deletes it, the CDN 404s, and the renderer omits the
  /// item. That is how C10 survives a cache.
  Map<String, Object?> toCdnJson() => page.toJson();

  @override
  String toString() =>
      'PublishedPortfolio(v${page.version}, ${blocks.length} blocks)';
}

/// CDN-first, Firestore fallback, with a short in-process cache.
///
/// G13 §7.1 publishes this to G11. The cache is 60 seconds so H01 → H02 → back
/// costs nothing; correctness comes from purge-by-URL on publish, rollback,
/// hide and **every consent withdrawal**, not from a short TTL.
class PublishedPortfolioReader {
  PublishedPortfolioReader({this.cacheFor = const Duration(seconds: 60)});

  final Duration cacheFor;
  final Map<String, _CacheEntry> _cache = <String, _CacheEntry>{};

  /// Resolves the state G11 renders.
  ///
  /// [live] is the published document, [results] the live result documents.
  /// Both are passed rather than fetched so this stays testable without a
  /// network — the fetching belongs to the data layer.
  PortfolioState stateFor({
    required String coachUid,
    required DateTime now,
    Portfolio? live,
    bool online = true,
    Map<String, ClientResult> results = const <String, ClientResult>{},
    List<OfferSummary> offers = const <OfferSummary>[],
    Set<String> verifiedCertIds = const <String>{},
  }) {
    if (live == null) return const PortfolioNotBuilt();
    if (live.hidden || live.suspended) return const PortfolioHidden();
    if (!live.published) return const PortfolioNotBuilt();

    final resolved = PublishedPortfolio.resolve(
      page: live,
      now: now,
      online: online,
      results: results,
      offers: offers,
      verifiedCertIds: verifiedCertIds,
    );

    _cache[coachUid] = _CacheEntry(resolved, now);
    return PortfolioLive(resolved);
  }

  /// A cached page, if it is still fresh.
  ///
  /// Returns null past [cacheFor] **and** whenever [purge] has been called for
  /// this coach — which is what every consent withdrawal does.
  PublishedPortfolio? cached(String coachUid, DateTime now) {
    final entry = _cache[coachUid];
    if (entry == null) return null;
    if (now.difference(entry.at) > cacheFor) {
      _cache.remove(coachUid);
      return null;
    }
    return entry.portfolio;
  }

  /// Purge-by-URL, as the Function does it: `live.json`, the one
  /// `r/{resultId}.json` and each affected `ads/*.json`. Bounded by the coach's
  /// own content, never by how many women have seen the page.
  void purge(String coachUid) => _cache.remove(coachUid);

  void purgeAll() => _cache.clear();
}

class _CacheEntry {
  _CacheEntry(this.portfolio, this.at);
  final PublishedPortfolio portfolio;
  final DateTime at;
}
