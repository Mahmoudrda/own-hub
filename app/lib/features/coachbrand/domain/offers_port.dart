/// B06 reads offers. It does not write them.
///
/// ## The seam, stated
///
/// G13 §10 Q1 records the defect: *"Offers are authored in three unreconciled
/// places — K04, B06 and K18"*, and the spine assigns the collection's writes
/// elsewhere. **The owner has settled it: K04 (`lib/features/coach/`) is the
/// single writer of `coaches/{coachUid}/offers/{offerId}`. B06 reads them.**
///
/// That interface does not exist yet — K04 is another agent's folder and is
/// being written in parallel — so this file declares the **narrowest possible
/// read-only port** in G13's own folder, plus a strict fake to build and test
/// against. When K04 lands, the expected change is one line: an adapter class
/// implementing [CoachOffersPort] over K04's repository. Nothing else in this
/// flow moves, because nothing else in this flow knows what an offer is.
///
/// ## Why the port has no write method at all
///
/// Not "has a write method B06 does not call" — **has none**. Two screens
/// writing the same field is a rejected plan under spine §2, and the way to
/// make that impossible is to give the second screen nothing to call.
/// `offers_port_test.dart` asserts this file declares no `upsert`, `save`,
/// `create`, `update` or `delete` by scanning its own source, because an
/// interface can always grow a method in a hurry.
library;

import 'dart:async';

import 'package:meta/meta.dart';

/// At most six offers on one `offers` block (G13 §1.3).
const int kMaxOfferIdsPerBlock = 6;

/// What B06 needs to draw an offer, and nothing more.
///
/// Deliberately not "K04's offer model": a port carries the *reading* side's
/// requirements, so K04 can change how an offer is stored without this flow
/// noticing. Price is carried as minor units plus a currency code rather than a
/// formatted string, because formatting is the reader's job and a pre-formatted
/// "1,800 EGP" would render Eastern digits under an Arabic locale.
@immutable
class OfferSummary {
  const OfferSummary({
    required this.offerId,
    required this.title,
    this.summary = '',
    this.priceMinor,
    this.currency = 'EGP',
    this.lines = const <String>[],
    this.spotsLeft,
    this.isActive = true,
  });

  final String offerId;

  /// Her own name for the package. "Monthly coaching", not "Tier 2".
  final String title;

  final String summary;

  /// Minor units — piastres for EGP. Null when she has not priced it yet.
  final int? priceMinor;

  final String currency;

  /// The bullet lines she wrote.
  final List<String> lines;

  /// Read from the coach root at render, never copied onto the page.
  final int? spotsLeft;

  /// False for an offer K04 has retired. A block holding its id renders
  /// nothing rather than a dead price.
  final bool isActive;

  @override
  String toString() => 'OfferSummary($offerId, $title)';
}

/// Read-only. K04 is the single writer.
///
/// There is no `upsert`, no `delete`, and there will not be one: if B06 ever
/// needs to author an offer, it calls K04's repository through a *separate*
/// port with its own name, so the addition is visible in a diff.
abstract class CoachOffersPort {
  /// Up to [kMaxOfferIdsPerBlock] offers, in K04's order.
  Future<List<OfferSummary>> offersFor(String coachUid);

  /// The same list, live. B06 redraws when K04 writes.
  Stream<List<OfferSummary>> watchOffers(String coachUid);

  /// Resolves the ids on an `offers` block, dropping anything that no longer
  /// exists or is no longer active.
  ///
  /// **Resolution happens at read time**, like every other id on this page. A
  /// retired offer disappears from a published page without republishing it.
  Future<List<OfferSummary>> resolve(String coachUid, List<String> offerIds);
}

/// A strict fake. Refuses what the real collection refuses.
///
/// The strictness is the point (`PHASE1-QA-VERDICT`): a lenient fake lets a bug
/// pass in memory and fail on a phone. So this one caps at
/// [kMaxOfferIdsPerBlock], preserves K04's order rather than the block's, and
/// drops inactive offers exactly as the render path will.
class InMemoryCoachOffersPort implements CoachOffersPort {
  InMemoryCoachOffersPort({Map<String, List<OfferSummary>>? offers})
    : _offers = {...?offers};

  final Map<String, List<OfferSummary>> _offers;
  final StreamController<String> _changes =
      StreamController<String>.broadcast();

  /// **Stands in for K04's writes.** Named so it can never be mistaken for a
  /// method on the port: a G13 screen calling `k04Wrote` in production code
  /// would not compile against [CoachOffersPort].
  void k04Wrote(String coachUid, List<OfferSummary> offers) {
    if (offers.length > kMaxOfferIdsPerBlock) {
      throw ArgumentError.value(
        offers.length,
        'offers',
        'A coach has at most $kMaxOfferIdsPerBlock offers (G13 §2, B06 reads '
            'with limit 6).',
      );
    }
    _offers[coachUid] = List.unmodifiable(offers);
    _changes.add(coachUid);
  }

  @override
  Future<List<OfferSummary>> offersFor(String coachUid) async =>
      List.unmodifiable(_offers[coachUid] ?? const <OfferSummary>[]);

  @override
  Stream<List<OfferSummary>> watchOffers(String coachUid) async* {
    yield await offersFor(coachUid);
    await for (final changed in _changes.stream) {
      if (changed == coachUid) yield await offersFor(coachUid);
    }
  }

  @override
  Future<List<OfferSummary>> resolve(
    String coachUid,
    List<String> offerIds,
  ) async {
    final all = await offersFor(coachUid);
    final wanted = offerIds.toSet();
    return List.unmodifiable(
      all.where((o) => o.isActive && wanted.contains(o.offerId)),
    );
  }

  Future<void> dispose() => _changes.close();
}
