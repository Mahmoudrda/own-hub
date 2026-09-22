// P0-ADS-01, 02 and 03.
//
// P0-ADS-02 is the one that matters: "export re-checks consent at the moment of
// export". Offline export is refused rather than queued, because a flattened
// file that has left the phone is the only thing in this flow the product
// cannot take back. Every other refusal in the builder is a nudge; this one is
// a no.

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/coachbrand/domain/ad_creative.dart';
import 'package:own_hub/features/coachbrand/domain/consent.dart';
import 'package:own_hub/features/coachbrand/domain/marketing_claim_policy.dart';

final _now = DateTime.utc(2026, 3, 10);

AdCreative _ad({
  String headline = 'Six weeks after birth, on the floor',
  String? resultId,
  AdFormat format = AdFormat.feed,
}) => AdCreative(
  adId: 'a1',
  format: format,
  portfolioVersion: 3,
  headline: headline,
  body: 'Nourhan · Giza',
  ctaLabel: 'Ask me',
  mediaId: 'm1',
  resultId: resultId,
);

ClientResult _granted({DateTime? at}) =>
    ClientResult.fromRequest(
      ResultRequest(
        resultId: 'r1',
        clientUid: 'mai',
        relationshipId: 'rel-1',
        requestedAt: DateTime.utc(2026, 3, 1),
      ),
    ).grantedByClient(
      at: at ?? DateTime.utc(2026, 3, 2),
      scope: const ConsentScope(photos: true),
      mediaIds: const ['m-mai'],
    );

void main() {
  group('P0-ADS-01 — her look in three sizes, composed from data', () {
    test('switching format changes nothing but the format', () {
      final feed = _ad().checked(at: _now);
      final story = feed.inFormat(AdFormat.story);
      final reel = feed.inFormat(AdFormat.reelCover);

      for (final ad in [story, reel]) {
        expect(ad.headline, feed.headline);
        expect(ad.body, feed.body);
        expect(ad.mediaId, feed.mediaId);
        expect(ad.portfolioVersion, feed.portfolioVersion);
        expect(
          ad.claimCheck?.pass,
          isTrue,
          reason: 'the words did not change, so the check has not gone stale',
        );
      }
      expect({feed.format, story.format, reel.format}.length, 3);
    });

    test('no flattened bitmap is stored as the source of truth', () {
      final json = _ad(resultId: 'r1').toJson();
      for (final forbidden in const [
        'png',
        'bitmap',
        'renderedUrl',
        'image',
        'flattened',
      ]) {
        expect(json.containsKey(forbidden), isFalse, reason: forbidden);
      }
      // A pointer, not a copy.
      expect(json['resultId'], 'r1');
      expect(json['media'], 'm1');
    });

    test('the stored ad carries no consent field', () {
      final json = _ad(resultId: 'r1').toJson();
      for (final forbidden in const [
        'consentState',
        'consentedAt',
        'quote',
        'mediaIds',
        'scope',
      ]) {
        expect(json.containsKey(forbidden), isFalse, reason: forbidden);
      }
    });
  });

  group('P0-ADS-03 — the claim rules are enforced, not displayed', () {
    test(
      'an English weight-and-timeline headline is rejected at authoring',
      () {
        final ad = _ad(headline: 'Lose 10 kg in 30 days').checked(at: _now);

        expect(ad.claimCheck!.pass, isFalse);
        expect(ad.state, AdState.draft, reason: 'it never becomes ready');

        final violations = ad.claimViolations();
        expect(violations.has(ClaimKind.weightLoss), isTrue);
        expect(violations.has(ClaimKind.timeline), isTrue);
      },
    );

    test('the Arabic version is rejected the same way', () {
      final ad = _ad(headline: 'تخسيس في 30 يوم').checked(at: _now);
      expect(ad.claimCheck!.pass, isFalse);
      expect(ad.claimViolations().has(ClaimKind.weightLoss), isTrue);
      expect(ad.claimViolations().has(ClaimKind.timeline), isTrue);
    });

    test('the mockup\'s own headline passes', () {
      final ad = _ad().checked(at: _now);
      expect(ad.claimCheck!.pass, isTrue);
      expect(ad.state, AdState.ready);
    });

    test('rewriting the words drops the stamp', () {
      final ready = _ad().checked(at: _now);
      expect(ready.state, AdState.ready);

      final rewritten = ready.withWords(headline: 'Something new');
      expect(rewritten.claimCheck, isNull);
      expect(rewritten.state, AdState.draft);
    });

    test('a stamp from an older pattern set is not trusted', () {
      expect(AdClaimCheck(version: 0, at: _now, pass: true).isCurrent, isFalse);
      expect(
        AdClaimCheck(
          version: MarketingClaimPolicy.version,
          at: _now,
          pass: true,
        ).isCurrent,
        isTrue,
      );
    });

    test('an ad carrying a stale stamp is refused at export', () {
      // A "pass" from a pattern set that has since been updated is not a pass.
      // Remote Config can roll a new `ad_claim_patterns_version`, and every
      // creative stamped before it has to be looked at again.
      final ad = AdCreative(
        adId: 'a1',
        format: AdFormat.feed,
        portfolioVersion: 3,
        headline: 'Six weeks after birth, on the floor',
        claimCheck: AdClaimCheck(version: 0, at: _now, pass: true),
        state: AdState.ready,
      );

      expect(
        (AdExportPolicy.decide(
          ad: ad,
          online: true,
          now: _now,
        ) as AdExportRefused).reason,
        AdExportRefusal.claimCheckFailed,
      );
    });

    test('the export check refuses an unstamped ad', () {
      expect(
        AdExportPolicy.decide(ad: _ad(), online: true, now: _now),
        isA<AdExportRefused>().having(
          (r) => r.reason,
          'reason',
          AdExportRefusal.claimCheckFailed,
        ),
      );
    });
  });

  group('P0-ADS-02 — export re-checks consent at the moment of export', () {
    test('offline, the export is refused — and for the consent reason', () {
      final ad = _ad(resultId: 'r1').checked(at: _now);

      final decision = AdExportPolicy.decide(
        ad: ad,
        online: false,
        now: _now,
        result: _granted(),
      );

      expect(decision, isA<AdExportRefused>());
      expect(
        (decision as AdExportRefused).reason,
        AdExportRefusal.offlineCannotCheckConsent,
        reason:
            'the screen says "we check her consent before it leaves the '
            'app", not "you are offline" — the second sentence invites her to '
            'try again at the café, which is exactly the wrong lesson',
      );
    });

    test('offline refuses even an ad with no client in it', () {
      // Uniform, because the refusal is about not being able to check, and a
      // rule with an exception is a rule people learn to route around.
      final ad = _ad().checked(at: _now);
      expect(
        AdExportPolicy.decide(ad: ad, online: false, now: _now),
        isA<AdExportRefused>().having(
          (r) => r.reason,
          'reason',
          AdExportRefusal.offlineCannotCheckConsent,
        ),
      );
    });

    test('online with a current consent, it is allowed', () {
      final ad = _ad(resultId: 'r1').checked(at: _now);
      expect(
        AdExportPolicy.decide(
          ad: ad,
          online: true,
          now: _now,
          result: _granted(),
        ),
        isA<AdExportAllowed>(),
      );
    });

    test('after withdrawal the export is refused', () {
      final ad = _ad(resultId: 'r1').checked(at: _now);
      expect(
        (AdExportPolicy.decide(
          ad: ad,
          online: true,
          now: _now,
          result: _granted().withdrawnByClient(at: _now),
        ) as AdExportRefused).reason,
        AdExportRefusal.consentNotCurrent,
      );
    });

    test('a missing result document is refused, not assumed fine', () {
      final ad = _ad(resultId: 'r1').checked(at: _now);
      expect(
        (AdExportPolicy.decide(
          ad: ad,
          online: true,
          now: _now,
        ) as AdExportRefused).reason,
        AdExportRefusal.consentNotCurrent,
      );
    });

    test('the wrong result document is refused', () {
      final ad = _ad(resultId: 'r1').checked(at: _now);
      final other = ClientResult.fromRequest(
        ResultRequest(
          resultId: 'r2',
          clientUid: 'hala',
          relationshipId: 'rel-2',
          requestedAt: _now,
        ),
      ).grantedByClient(at: _now, scope: const ConsentScope(numbers: true));

      expect(
        (AdExportPolicy.decide(
          ad: ad,
          online: true,
          now: _now,
          result: other,
        ) as AdExportRefused).reason,
        AdExportRefusal.consentNotCurrent,
      );
    });

    test('an expired grant is refused as firmly as a withdrawn one', () {
      final ad = _ad(resultId: 'r1').checked(at: _now);
      expect(
        (AdExportPolicy.decide(
          ad: ad,
          online: true,
          now: DateTime.utc(2027, 6, 1),
          result: _granted(at: DateTime.utc(2026, 1, 1)),
        ) as AdExportRefused).reason,
        AdExportRefusal.consentNotCurrent,
      );
    });

    test('a stale ad cannot be exported until it is re-checked', () {
      final stale = _ad(resultId: 'r1').checked(at: _now).markedStale();
      expect(
        (AdExportPolicy.decide(
          ad: stale,
          online: true,
          now: _now,
          result: _granted(),
        ) as AdExportRefused).reason,
        AdExportRefusal.staleNeedsRecheck,
      );
    });

    test('every export is recorded, so she can be told what to take down', () {
      var ad = _ad(resultId: 'r1').checked(at: _now);
      expect(ad.hasLeftTheApp, isFalse);

      ad = ad.exportedOn(AdExport(at: _now, deviceId: 'phone-a'));

      expect(ad.state, AdState.exported);
      expect(ad.hasLeftTheApp, isTrue);
      expect(ad.exports.single.deviceId, 'phone-a');
    });

    test('the export log is capped and keeps the most recent', () {
      var ad = _ad().checked(at: _now);
      for (var i = 0; i < kMaxAdExports + 5; i++) {
        ad = ad.exportedOn(
          AdExport(
            at: _now.add(Duration(minutes: i)),
            deviceId: 'd$i',
          ),
        );
      }
      expect(ad.exports.length, kMaxAdExports);
      expect(ad.exports.last.deviceId, 'd${kMaxAdExports + 4}');
    });
  });

  group('withdrawal marks the creative stale rather than rewriting it', () {
    test('an ad composed from live data is already correct on screen', () {
      final ad = _ad(resultId: 'r1').checked(at: _now).markedStale();

      expect(ad.state, AdState.stale);
      expect(
        ad.resultId,
        'r1',
        reason:
            'still a pointer — the renderer resolves it live and draws '
            'nothing, which is why the in-app view needs no rewrite',
      );
    });
  });
}
