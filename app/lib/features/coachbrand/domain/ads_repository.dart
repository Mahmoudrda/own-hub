/// `coaches/{coachUid}/ads/*`, and the three fields a coach may not write.
///
/// The rule says `!keys().hasAny(['claimCheck','state','exports'])`. Rather
/// than a repository that accepts an [AdCreative] and strips three fields, the
/// write method takes an [AdDraft] — which does not have them. A coach cannot
/// mark her own ad `ready`, cannot stamp her own claim check, and cannot forge
/// an export record, because there is no field to put them in.
library;

import 'dart:async';

import 'ad_creative.dart';

/// At most 50 ads per coach (G13 §9). A purge set has to stay bounded.
const int kMaxAdsPerCoach = 50;

class AdWriteRejected implements Exception {
  AdWriteRejected(this.reason);
  final String reason;

  @override
  String toString() => 'AdWriteRejected: $reason';
}

/// Everything B09 may write. Note the three absences.
class AdDraft {
  const AdDraft({
    required this.adId,
    required this.format,
    required this.portfolioVersion,
    this.headline = '',
    this.body = '',
    this.ctaLabel = '',
    this.mediaId,
    this.resultId,
  });

  final String adId;
  final AdFormat format;
  final int portfolioVersion;
  final String headline;
  final String body;
  final String ctaLabel;
  final String? mediaId;

  /// A pointer, never a copy. Resolved live at every render and at export.
  final String? resultId;
}

abstract class AdsRepository {
  Future<List<AdCreative>> ads();
  Stream<List<AdCreative>> watchAds();
  Future<AdCreative?> byId(String adId);

  /// Creates or replaces the coach-writable fields.
  Future<AdCreative> save(AdDraft draft);
}

class AdsStore {
  AdsStore({Map<String, AdCreative>? ads}) : ads = {...?ads};
  final Map<String, AdCreative> ads;
}

class InMemoryAdsRepository implements AdsRepository {
  InMemoryAdsRepository({AdsStore? store}) : store = store ?? AdsStore();

  final AdsStore store;
  final StreamController<List<AdCreative>> _changes =
      StreamController<List<AdCreative>>.broadcast();

  List<AdCreative> get _all => List.unmodifiable(store.ads.values);

  @override
  Future<List<AdCreative>> ads() async => _all;

  @override
  Stream<List<AdCreative>> watchAds() async* {
    yield _all;
    yield* _changes.stream;
  }

  @override
  Future<AdCreative?> byId(String adId) async => store.ads[adId];

  @override
  Future<AdCreative> save(AdDraft draft) async {
    final existing = store.ads[draft.adId];
    if (existing == null && store.ads.length >= kMaxAdsPerCoach) {
      throw AdWriteRejected('A coach holds at most $kMaxAdsPerCoach ads.');
    }

    // The coach's fields replace; the server's fields are preserved or reset by
    // the domain type, never taken from the caller.
    final next = existing == null
        ? AdCreative(
            adId: draft.adId,
            format: draft.format,
            portfolioVersion: draft.portfolioVersion,
            headline: draft.headline,
            body: draft.body,
            ctaLabel: draft.ctaLabel,
            mediaId: draft.mediaId,
            resultId: draft.resultId,
          )
        : AdCreative(
            adId: existing.adId,
            format: draft.format,
            portfolioVersion: draft.portfolioVersion,
            headline: draft.headline,
            body: draft.body,
            ctaLabel: draft.ctaLabel,
            mediaId: draft.mediaId,
            resultId: draft.resultId,
            // Preserved from the server's copy, not from the caller.
            state: existing.state,
            claimCheck: existing.claimCheck,
            exports: existing.exports,
          );

    store.ads[draft.adId] = next;
    _emit();
    return next;
  }

  // ──────────────────────────────────────────── the server's three fields

  /// Stamps the claim check. Server-only.
  AdCreative functionChecked(String adId, DateTime at) {
    final ad = _require(adId);
    final next = ad.checked(at: at);
    store.ads[adId] = next;
    _emit();
    return next;
  }

  /// Records that a file left the app. Server-only, and the list is what lets a
  /// coach be told exactly what to take down if consent is withdrawn later.
  AdCreative functionRecordedExport(String adId, AdExport export) {
    final next = _require(adId).exportedOn(export);
    store.ads[adId] = next;
    _emit();
    return next;
  }

  /// `onResultConsentChanged` step 3: every ad referencing [resultId] is marked
  /// stale and re-rendered without the media.
  ///
  /// The set is bounded by the coach's own ads (≤50), never by her audience.
  List<AdCreative> functionMarkedStaleForResult(String resultId) {
    final touched = <AdCreative>[];
    for (final entry in store.ads.entries.toList()) {
      if (entry.value.resultId != resultId) continue;
      final next = entry.value.markedStale();
      store.ads[entry.key] = next;
      touched.add(next);
    }
    if (touched.isNotEmpty) _emit();
    return List.unmodifiable(touched);
  }

  AdCreative _require(String adId) {
    final ad = store.ads[adId];
    if (ad == null) throw AdWriteRejected('No ad $adId.');
    return ad;
  }

  void _emit() => _changes.add(_all);

  Future<void> dispose() => _changes.close();
}
