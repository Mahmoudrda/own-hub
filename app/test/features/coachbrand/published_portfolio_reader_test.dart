// P0-PORT-05 and P0-PORT-10, and the offline rule from G13 §4.
//
// One renderer and one resolver. Preview and H02 both go through
// PublishedPortfolio, which is why "the hidden block appears in neither" is a
// property of the type rather than of two screens agreeing.

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/coachbrand/domain/consent.dart';
import 'package:own_hub/features/coachbrand/domain/offers_port.dart';
import 'package:own_hub/features/coachbrand/domain/portfolio.dart';
import 'package:own_hub/features/coachbrand/domain/portfolio_block.dart';
import 'package:own_hub/features/coachbrand/domain/published_portfolio_reader.dart';

final _now = DateTime.utc(2026, 3, 10);

ClientResult _granted(String id, {DateTime? at}) =>
    ClientResult.fromRequest(
      ResultRequest(
        resultId: id,
        clientUid: 'c-$id',
        relationshipId: 'rel',
        requestedAt: DateTime.utc(2026, 3, 1),
      ),
    ).grantedByClient(
      at: at ?? DateTime.utc(2026, 3, 2),
      scope: const ConsentScope(photos: true, quote: true),
      mediaIds: const ['m1'],
      quote: 'Carried both kids up the stairs.',
    );

Portfolio _live({List<PortfolioBlock>? blocks, bool hidden = false}) {
  var page = Portfolio.newDraft(now: _now);
  for (final b
      in blocks ??
          [
            PortfolioBlock(
              id: 'b1',
              payload: const CoverPayload(
                layout: CoverLayout.noPhoto,
                headline: 'Back to lifting',
              ),
            ),
          ]) {
    page = page.addBlock(b);
  }
  final published = page
      .savedBy('a')
      .publishedAs(version: 3, at: _now, validation: page.theme.validation);
  return hidden ? published.withHidden(true) : published;
}

void main() {
  group('P0-PORT-05 — one renderer, one list', () {
    test('a hidden block is absent from what anybody sees', () {
      final page = _live(
        blocks: [
          PortfolioBlock(
            id: 'b1',
            payload: const CoverPayload(layout: CoverLayout.noPhoto),
          ),
          PortfolioBlock(id: 'b2', payload: const FaqPayload()).hidden,
          PortfolioBlock(id: 'b3', payload: const MethodPayload()),
        ],
      );

      final resolved = PublishedPortfolio.resolve(page: page, now: _now);

      expect(resolved.blocks.map((b) => b.id), ['b1', 'b3']);
      expect(
        page.blockById('b2')!.payload,
        isA<FaqPayload>(),
        reason: 'hidden, not deleted — her words are still there',
      );
    });

    test('preview and the published read are the same object', () {
      // B10 previews the DRAFT through the same type H02 renders the live page
      // through. There is no second layout to keep in sync, which is the whole
      // of "one renderer, no drift".
      final page = _live();
      final preview = PublishedPortfolio.resolve(page: page, now: _now);
      final render = PublishedPortfolio.resolve(page: page, now: _now);

      expect(preview.blocks.map((b) => b.id), render.blocks.map((b) => b.id));
      expect(preview.runtimeType, render.runtimeType);
    });

    test('a type appearing twice renders twice, in array order', () {
      final page = _live(
        blocks: [
          PortfolioBlock(id: 'b1', payload: const MethodPayload()),
          PortfolioBlock(id: 'b2', payload: const MethodPayload()),
        ],
      );
      expect(
        PublishedPortfolio.resolve(
          page: page,
          now: _now,
        ).blocks.map((b) => b.id),
        ['b1', 'b2'],
      );
    });
  });

  group('results are resolved at read time, every time', () {
    const payload = ResultsPayload(resultIds: ['r1', 'r2', 'r3']);

    test('only currently-consented ids come back', () {
      final resolved = PublishedPortfolio.resolve(
        page: _live(),
        now: _now,
        results: {
          'r1': _granted('r1'),
          'r2': _granted('r2').withdrawnByClient(at: _now),
          // r3 has no document at all.
        },
      );

      final render = resolved.resultsFor(payload) as ResultsVisible;
      expect(render.resultIds, ['r1']);
    });

    test('an empty result block draws nothing, not a placeholder', () {
      final resolved = PublishedPortfolio.resolve(page: _live(), now: _now);
      expect(
        (resolved.resultsFor(payload) as ResultsVisible).resultIds,
        isEmpty,
      );
    });

    test('offline it says so rather than showing a stale copy', () {
      // G13 §4: it cannot check consent, so it does not guess. A cached result
      // shown offline is another woman's photograph on screen with no way to
      // know whether she still agrees.
      final resolved = PublishedPortfolio.resolve(
        page: _live(),
        now: _now,
        online: false,
        results: {'r1': _granted('r1')},
      );

      expect(resolved.resultsFor(payload), isA<ResultsWaitingForSignal>());
    });

    test(
      'a testimonial carrying a resultId is gated exactly like a result',
      () {
        const testimonials = TestimonialsPayload(
          items: [
            Testimonial(
              quote: 'She changed how I train.',
              attribution: 'Mai',
              resultId: 'r1',
            ),
            Testimonial(quote: 'A free-text one.', attribution: 'Hala'),
          ],
        );

        final withdrawn = PublishedPortfolio.resolve(
          page: _live(),
          now: _now,
          results: {'r1': _granted('r1').withdrawnByClient(at: _now)},
        );
        expect(
          withdrawn.testimonialsFor(testimonials).map((t) => t.attribution),
          ['Hala'],
        );

        final active = PublishedPortfolio.resolve(
          page: _live(),
          now: _now,
          results: {'r1': _granted('r1')},
        );
        expect(active.testimonialsFor(testimonials).length, 2);
      },
    );

    test('offline, a consent-gated testimonial is withheld too', () {
      const testimonials = TestimonialsPayload(
        items: [
          Testimonial(quote: 'q', attribution: 'Mai', resultId: 'r1'),
          Testimonial(quote: 'q', attribution: 'Hala'),
        ],
      );
      final offline = PublishedPortfolio.resolve(
        page: _live(),
        now: _now,
        online: false,
        results: {'r1': _granted('r1')},
      );
      expect(offline.testimonialsFor(testimonials).map((t) => t.attribution), [
        'Hala',
      ]);
    });
  });

  group('offers and certificates resolve live too', () {
    test('a retired offer drops out of an already-published page', () {
      const payload = OffersPayload(offerIds: ['o1', 'o2']);
      final resolved = PublishedPortfolio.resolve(
        page: _live(),
        now: _now,
        offers: const [
          OfferSummary(offerId: 'o1', title: 'Monthly'),
          OfferSummary(offerId: 'o2', title: 'Retired', isActive: false),
        ],
      );

      expect(resolved.offersFor(payload).map((o) => o.offerId), ['o1']);
    });

    test('an unverified certificate is dropped at render', () {
      const payload = CertificatesPayload(certIds: ['c1', 'c2']);
      final resolved = PublishedPortfolio.resolve(
        page: _live(),
        now: _now,
        verifiedCertIds: const {'c1'},
      );

      expect(resolved.certificatesFor(payload), ['c1']);
    });
  });

  group('the states G11 renders', () {
    final reader = PublishedPortfolioReader();

    test('a coach with no page is notBuilt, not an error', () {
      expect(
        reader.stateFor(coachUid: 'n', now: _now),
        isA<PortfolioNotBuilt>(),
      );
    });

    test('a page she took down is hidden, not an error either', () {
      expect(
        reader.stateFor(coachUid: 'n', now: _now, live: _live(hidden: true)),
        isA<PortfolioHidden>(),
      );
    });

    test('a suspended page reads as hidden to a stranger', () {
      expect(
        reader.stateFor(
          coachUid: 'n',
          now: _now,
          live: _live().withSuspended(true),
        ),
        isA<PortfolioHidden>(),
      );
    });

    test('a published page is live', () {
      final state = reader.stateFor(coachUid: 'n', now: _now, live: _live());
      expect(state, isA<PortfolioLive>());
      expect((state as PortfolioLive).portfolio.page.version, 3);
    });
  });

  group('P0-PORT-10 — a stranger\'s read is cheap and purgeable', () {
    test('the second read inside the window comes from the cache', () {
      final reader = PublishedPortfolioReader();
      reader.stateFor(coachUid: 'n', now: _now, live: _live());

      expect(
        reader.cached('n', _now.add(const Duration(seconds: 30))),
        isNotNull,
      );
      expect(
        reader.cached('n', _now.add(const Duration(seconds: 61))),
        isNull,
        reason: 'the window is short, but correctness comes from the purge',
      );
    });

    test('a withdrawal purges the entry by name, not by waiting', () {
      final reader = PublishedPortfolioReader();
      reader.stateFor(coachUid: 'n', now: _now, live: _live());
      expect(reader.cached('n', _now), isNotNull);

      reader.purge('n');

      expect(
        reader.cached('n', _now),
        isNull,
        reason:
            'purge-by-URL on every consent withdrawal — a short TTL would '
            'leave her photograph up for up to a minute',
      );
    });

    test('the CDN object is the page, and the page holds ids', () {
      final page = _live(
        blocks: [
          PortfolioBlock(
            id: 'b1',
            payload: const ResultsPayload(resultIds: ['r1']),
          ),
        ],
      );
      final json = PublishedPortfolio.resolve(
        page: page,
        now: _now,
        results: {'r1': _granted('r1')},
      ).toCdnJson();

      final blocks = json['blocks']! as List<Object?>;
      final payload = (blocks.single! as Map)['payload']! as Map;

      expect(payload['resultIds'], ['r1']);
      expect(payload.containsKey('mediaIds'), isFalse);
      expect(payload.containsKey('quote'), isFalse);
      expect(json.toString().contains('Carried both kids'), isFalse);
      expect(json.toString().contains('granted'), isFalse);
    });
  });
}
