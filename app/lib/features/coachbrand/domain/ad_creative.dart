/// An ad is data, not a bitmap — and exporting one is the irreversible act.
///
/// G13 §1.8: *"It is composed at render time from the theme, the media and — if
/// `resultId` is set — the live result. That is the only way HANDOFF rule 10's
/// 'including inside already-rendered ad creatives' can be literally true. A
/// flattened PNG is produced **only at export**, after a fresh consent check."*
///
/// ## Why export is the one refusal in this group
///
/// Everything else the builder does is reversible inside the product. A
/// withdrawal purges the page, the result object and every ad — within one
/// propagation cycle, everywhere the product controls.
///
/// A flattened file that has left the phone is outside all of it. We cannot
/// recall a JPEG from Instagram. So **export offline is refused**, not queued:
/// offline, the app cannot read the consent document at all, and an export that
/// *might* be carrying a withdrawn woman's face is not a risk worth a
/// convenience. G13 §10 Q5 records the honest limit, and the refusal names the
/// consent reason rather than a network error — a coach told "no signal" would
/// simply try again at the café.
///
/// Every export is recorded, so if a consent is withdrawn afterwards the coach
/// can be told exactly what she needs to take down.
library;

import 'package:meta/meta.dart';

import 'consent.dart';
import 'marketing_claim_policy.dart';

/// At most 20 exports are remembered per ad (G13 §1.8).
const int kMaxAdExports = 20;

enum AdFormat {
  feed('feed'),
  story('story'),
  reelCover('reel-cover');

  const AdFormat(this.wire);
  final String wire;
}

/// G13 §3.4.
enum AdState {
  draft,

  /// The claim check passed.
  ready,

  /// A flattened file exists off-platform.
  exported,

  /// The source result was withdrawn, or the portfolio republished with a
  /// changed theme. The in-app render is already correct, because it composes
  /// from live data; what is stale is any file already exported.
  stale,

  rejected,
}

/// The stamp a claim check leaves.
@immutable
class AdClaimCheck {
  const AdClaimCheck({
    required this.version,
    required this.at,
    required this.pass,
  });

  final int version;
  final DateTime at;
  final bool pass;

  /// Whether this stamp was produced by the current pattern set. A stamp from
  /// an older version is not trusted; the ad is re-checked.
  bool get isCurrent => version == MarketingClaimPolicy.version;

  Map<String, Object?> toJson() => <String, Object?>{
    'v': version,
    'at': at.toIso8601String(),
    'pass': pass,
  };
}

/// One recorded export. The list is what lets a coach be told whom to ask.
@immutable
class AdExport {
  const AdExport({required this.at, required this.deviceId});

  final DateTime at;
  final String deviceId;

  Map<String, Object?> toJson() => <String, Object?>{
    'at': at.toIso8601String(),
    'deviceId': deviceId,
  };
}

/// `coaches/{coachUid}/ads/{adId}`.
@immutable
class AdCreative {
  const AdCreative({
    required this.adId,
    required this.format,
    required this.portfolioVersion,
    this.headline = '',
    this.body = '',
    this.ctaLabel = '',
    this.mediaId,
    this.resultId,
    this.state = AdState.draft,
    this.claimCheck,
    this.exports = const <AdExport>[],
  });

  final String adId;
  final AdFormat format;

  /// The version of the page this creative inherits its look from. Changing
  /// format does not change it — all three sizes are one look.
  final int portfolioVersion;

  /// ≤64 graphemes.
  final String headline;

  /// ≤120 graphemes.
  final String body;

  final String ctaLabel;
  final String? mediaId;

  /// When set, this creative shows a client result — and is consent-gated at
  /// **every** render and at export, never at save.
  final String? resultId;

  final AdState state;

  /// Server-written in production; computed here so B09 can refuse at
  /// authoring, which is what `P0-ADS-03` means by "enforced not just
  /// displayed".
  final AdClaimCheck? claimCheck;

  final List<AdExport> exports;

  /// True once a file exists that we cannot reach.
  bool get hasLeftTheApp => exports.isNotEmpty;

  /// Switching size keeps everything else, including the claim stamp — the
  /// words did not change, so the check has not gone stale.
  AdCreative inFormat(AdFormat next) => _copy(format: next);

  AdCreative withWords({String? headline, String? body, String? ctaLabel}) =>
      _copy(
        headline: headline,
        body: body,
        ctaLabel: ctaLabel,
        // New words, no stamp. Re-check before it can be ready again.
        clearClaimCheck: true,
        state: AdState.draft,
      );

  /// Runs the policy and records the stamp.
  AdCreative checked({
    required DateTime at,
    MarketingClaimPolicy policy = const MarketingClaimPolicy(),
  }) {
    final result = claimViolations(policy);
    return _copy(
      claimCheck: AdClaimCheck(
        version: MarketingClaimPolicy.version,
        at: at,
        pass: result.pass,
      ),
      state: result.pass ? AdState.ready : AdState.draft,
    );
  }

  /// Every claim violation across the creative's own words.
  ClaimCheck claimViolations([
    MarketingClaimPolicy policy = const MarketingClaimPolicy(),
  ]) {
    final all = <ClaimViolation>[
      ...policy.check(headline).violations,
      ...policy.check(body).violations,
      ...policy.check(ctaLabel).violations,
    ];
    return ClaimCheck(List.unmodifiable(all));
  }

  /// The source result was withdrawn, or the theme moved underneath it.
  AdCreative markedStale() => _copy(state: AdState.stale);

  /// Records an export. Caps at [kMaxAdExports], oldest dropped.
  AdCreative exportedOn(AdExport export) {
    final next = [...exports, export];
    return _copy(
      exports: next.length <= kMaxAdExports
          ? next
          : next.sublist(next.length - kMaxAdExports),
      state: AdState.exported,
    );
  }

  AdCreative _copy({
    AdFormat? format,
    String? headline,
    String? body,
    String? ctaLabel,
    AdState? state,
    AdClaimCheck? claimCheck,
    bool clearClaimCheck = false,
    List<AdExport>? exports,
  }) => AdCreative(
    adId: adId,
    format: format ?? this.format,
    portfolioVersion: portfolioVersion,
    headline: headline ?? this.headline,
    body: body ?? this.body,
    ctaLabel: ctaLabel ?? this.ctaLabel,
    mediaId: mediaId,
    resultId: resultId,
    state: state ?? this.state,
    claimCheck: clearClaimCheck ? null : (claimCheck ?? this.claimCheck),
    exports: List.unmodifiable(exports ?? this.exports),
  );

  /// The stored document.
  ///
  /// **No consent field appears here**, and none can: this class has no field
  /// that holds one. `resultId` is a pointer, resolved live at every render.
  Map<String, Object?> toJson() => <String, Object?>{
    'portfolioRef': <String, Object?>{'version': portfolioVersion},
    'format': format.wire,
    'headline': headline,
    'body': body,
    'cta': ctaLabel,
    if (mediaId != null) 'media': mediaId,
    if (resultId != null) 'resultId': resultId,
    'state': state.name,
    if (claimCheck != null) 'claimCheck': claimCheck!.toJson(),
    'exports': [for (final e in exports) e.toJson()],
  };

  @override
  String toString() => 'AdCreative($adId, ${format.wire}, ${state.name})';
}

/// Why an export was refused.
enum AdExportRefusal {
  /// No signal, so the consent document cannot be read.
  ///
  /// Named for the consent, not the network, because the screen must say *"we
  /// check her consent before it leaves the app"* rather than *"you are
  /// offline"*. The second sentence invites her to try again somewhere with
  /// signal; the first explains why that is not the point.
  offlineCannotCheckConsent,

  /// The result this creative shows is not currently consented.
  consentNotCurrent,

  /// The creative is marked stale and has not been re-checked.
  staleNeedsRecheck,

  /// The claim check has not passed, or its stamp is from an older pattern set.
  claimCheckFailed,
}

/// The verdict. Sealed, so a caller cannot forget the refusal branch.
sealed class AdExportDecision {
  const AdExportDecision();

  bool get isAllowed => this is AdExportAllowed;
}

final class AdExportAllowed extends AdExportDecision {
  const AdExportAllowed();
}

final class AdExportRefused extends AdExportDecision {
  const AdExportRefused(this.reason);
  final AdExportRefusal reason;

  @override
  String toString() => 'AdExportRefused(${reason.name})';
}

/// The check that runs at the moment of export, every time.
abstract final class AdExportPolicy {
  /// Whether this creative may be flattened to a file right now.
  ///
  /// Order matters. Offline is checked **first**: offline we do not know
  /// whether [result] is current, and a `null` result offline is
  /// indistinguishable from a withdrawn one. Refusing first is what stops the
  /// caller from reasoning about a document it could not read.
  ///
  /// [result] is the live document, fetched now — not a copy taken at publish.
  static AdExportDecision decide({
    required AdCreative ad,
    required bool online,
    required DateTime now,
    ClientResult? result,
    MarketingClaimPolicy policy = const MarketingClaimPolicy(),
  }) {
    if (!online) {
      return const AdExportRefused(AdExportRefusal.offlineCannotCheckConsent);
    }

    if (ad.state == AdState.stale || ad.state == AdState.rejected) {
      return const AdExportRefused(AdExportRefusal.staleNeedsRecheck);
    }

    final stamp = ad.claimCheck;
    if (stamp == null ||
        !stamp.isCurrent ||
        !stamp.pass ||
        !ad.claimViolations(policy).pass) {
      return const AdExportRefused(AdExportRefusal.claimCheckFailed);
    }

    if (ad.resultId != null) {
      // Read-time check, at the moment of export. Never a stored flag.
      if (result == null ||
          result.resultId != ad.resultId ||
          !ResultVisibility.isPublishable(result, now)) {
        return const AdExportRefused(AdExportRefusal.consentNotCurrent);
      }
    }

    return const AdExportAllowed();
  }
}
