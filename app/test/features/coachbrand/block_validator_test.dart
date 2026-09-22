// Every limit in G13 §1.3, and the seven surfaces the claim policy runs over.
//
// The six block surfaces are here. The seventh — the ad — is in ads_test.dart,
// because an ad is not a block. The three the OWNER added beyond G13 §5 get
// their own group, because "we extended the coverage" is the kind of decision
// that quietly gets reverted by somebody tidying up.

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/coachbrand/domain/block_validator.dart';
import 'package:own_hub/features/coachbrand/domain/marketing_claim_policy.dart';
import 'package:own_hub/features/coachbrand/domain/overlay_floor.dart';
import 'package:own_hub/features/coachbrand/domain/portfolio_block.dart';

const _validator = BlockValidator();

/// "Lose 10 kg in 30 days" — a weight-loss claim and a timeline in one line.
const _claim = 'Lose 10 kg in 30 days';

BlockValidation _check(BlockPayload payload, {OverlayDecision? floor}) =>
    _validator.validate(
      PortfolioBlock(id: 'b1', payload: payload),
      overlayFloor: floor,
    );

String _long(int n) => 'a' * n;

void main() {
  group('lengths are counted in grapheme clusters', () {
    test('a reader counts characters, not UTF-16 units', () {
      expect(graphemeLength('hello'), 5);
      expect(graphemeLength('مرحبا'), 5);
      // A flag is two code points and one character.
      expect(graphemeLength('🇪🇬'), 1);
      expect(
        '🇪🇬'.length,
        4,
        reason: 'which is why .length is the wrong count',
      );
    });

    test('a headline of 64 emoji flags is 64 characters, and allowed', () {
      final v = _check(
        CoverPayload(layout: CoverLayout.noPhoto, headline: '🇪🇬' * 64),
      );
      expect(
        v.problems.where((p) => p.kind == BlockProblemKind.tooLong),
        isEmpty,
      );
    });
  });

  group('cover', () {
    test('headline ≤64, subline ≤80', () {
      expect(
        _check(CoverPayload(layout: CoverLayout.noPhoto, headline: _long(64)))
            .isValid,
        isTrue,
      );
      final over = _check(
        CoverPayload(layout: CoverLayout.noPhoto, headline: _long(65)),
      );
      expect(over.problems.single.kind, BlockProblemKind.tooLong);
      expect(over.problems.single.field, 'headline');
      expect(over.problems.single.limit, 64);
      expect(over.problems.single.actual, 65);

      expect(
        _check(CoverPayload(layout: CoverLayout.noPhoto, subline: _long(81)))
            .problems
            .single
            .field,
        'subline',
      );
    });

    test('a photo layout needs a photo', () {
      for (final layout in [
        CoverLayout.textOverPhoto,
        CoverLayout.photoAbove,
      ]) {
        expect(
          _check(CoverPayload(layout: layout)).problems.single.kind,
          BlockProblemKind.missingMedia,
          reason: layout.name,
        );
      }
      expect(
        _check(const CoverPayload(layout: CoverLayout.noPhoto)).isValid,
        isTrue,
      );
    });

    test(
      'P0-PORT-07 — the darken slider cannot go below the computed floor',
      () {
        const payload = CoverPayload(
          layout: CoverLayout.textOverPhoto,
          mediaId: 'm1',
          overlay: 0.2,
        );

        expect(
          _check(payload, floor: const OverlayDecision.allowed(0.1)).isValid,
          isTrue,
        );

        final below = _check(
          payload,
          floor: const OverlayDecision.allowed(0.62),
        );
        expect(below.problems.single.kind, BlockProblemKind.overlayBelowFloor);
        expect(below.problems.single.limit, 0.62);
        expect(below.problems.single.actual, 0.2);
      },
    );

    test('when even 0.9 fails, the layout itself is refused', () {
      final refused = _check(
        const CoverPayload(
          layout: CoverLayout.textOverPhoto,
          mediaId: 'm1',
          overlay: 0.9,
        ),
        floor: const OverlayDecision.refusedLayout(),
      );
      expect(refused.problems.single.kind, BlockProblemKind.layoutRefused);
      expect(refused.problems.single.field, 'layout');
    });

    test('no floor computed yet is not a failure — that is offline', () {
      expect(
        _check(
          const CoverPayload(
            layout: CoverLayout.textOverPhoto,
            mediaId: 'm1',
            overlay: 0.0,
          ),
        ).isValid,
        isTrue,
      );
    });

    test('the scrim never goes past 0.9', () {
      expect(
        _check(const CoverPayload(layout: CoverLayout.noPhoto, overlay: 0.95))
            .problems
            .single
            .field,
        'overlay',
      );
    });

    test('claims are rejected in both cover strings', () {
      expect(
        _check(
          const CoverPayload(layout: CoverLayout.noPhoto, headline: _claim),
        ).hasClaimProblem,
        isTrue,
      );
      expect(
        _check(const CoverPayload(layout: CoverLayout.noPhoto, subline: _claim))
            .hasClaimProblem,
        isTrue,
      );
    });
  });

  group('the owner\'s extension — about, method and faq prose', () {
    // G13 §5 names cover, ad, numbers and testimonial. Those three were added
    // because they are the longest free text on the page: a coach who cannot
    // promise "10 kg in 30 days" in a headline can put the same sentence in
    // paragraph two and reach the same woman.

    test('about paragraphs are checked', () {
      final v = _check(
        const AboutPayload(paragraphs: ['I am a coach.', _claim]),
      );
      expect(v.hasClaimProblem, isTrue);
      final claim = v.problems.firstWhere(
        (p) => p.kind == BlockProblemKind.claim,
      );
      expect(claim.field, 'paragraphs');
      expect(claim.index, 1, reason: 'the editor focuses the right paragraph');
    });

    test('method steps are checked, title and body', () {
      expect(
        _check(
          const MethodPayload(
            steps: [MethodStep(title: _claim, body: 'ok')],
          ),
        ).hasClaimProblem,
        isTrue,
      );
      expect(
        _check(
          const MethodPayload(
            steps: [MethodStep(title: 'ok', body: _claim)],
          ),
        ).hasClaimProblem,
        isTrue,
      );
    });

    test('faq questions and answers are checked', () {
      expect(
        _check(
          const FaqPayload(
            items: [FaqItem(question: 'How fast?', answer: _claim)],
          ),
        ).hasClaimProblem,
        isTrue,
      );
      expect(
        _check(
          const FaqPayload(
            items: [FaqItem(question: _claim, answer: 'no')],
          ),
        ).hasClaimProblem,
        isTrue,
      );
    });

    test('the honest version of the same block passes', () {
      expect(
        _check(
          const AboutPayload(
            paragraphs: [
              'I take women from six weeks after birth back to lifting, '
                  'slowly.',
            ],
          ),
        ).isValid,
        isTrue,
      );
    });
  });

  group('the four surfaces G13 §5 already named', () {
    test('testimonial quotes are checked', () {
      expect(
        _check(const TestimonialsPayload(items: [Testimonial(quote: _claim)]))
            .hasClaimProblem,
        isTrue,
      );
    });

    test('numbers are checked with checkStat, so a ranking is caught too', () {
      final ranking = _check(
        const NumbersPayload(
          stats: [NumberStat(value: '#1', label: 'coach in Cairo')],
        ),
      );
      expect(ranking.hasClaimProblem, isTrue);
      expect(
        ranking.problems
            .where((p) => p.claim?.kind == ClaimKind.ranking)
            .isNotEmpty,
        isTrue,
      );
    });

    test('an honest figure passes', () {
      expect(
        _check(
          const NumbersPayload(
            stats: [
              NumberStat(value: '24', label: 'sessions'),
              NumberStat(value: '8', label: 'counted weeks'),
            ],
          ),
        ).isValid,
        isTrue,
      );
    });
  });

  group('counts', () {
    test('about ≤4 paragraphs of ≤400', () {
      expect(
        _check(AboutPayload(paragraphs: List.filled(5, 'x')))
            .problems
            .single
            .kind,
        BlockProblemKind.tooMany,
      );
      expect(
        _check(AboutPayload(paragraphs: [_long(401)])).problems.single.kind,
        BlockProblemKind.tooLong,
      );
    });

    test('method needs at least one step and allows at most eight', () {
      expect(
        _check(const MethodPayload()).problems.single.kind,
        BlockProblemKind.tooFew,
      );
      expect(
        _check(
          MethodPayload(
            steps: List.filled(9, const MethodStep(title: 't', body: 'b')),
          ),
        ).problems.single.kind,
        BlockProblemKind.tooMany,
      );
    });

    test('offers ≤6, results ≤12, gallery ≤12, testimonials ≤8, faq ≤10', () {
      expect(
        _check(OffersPayload(offerIds: List.filled(7, 'o'))).isValid,
        isFalse,
      );
      expect(
        _check(ResultsPayload(resultIds: List.filled(13, 'r'))).isValid,
        isFalse,
      );
      expect(
        _check(GalleryPayload(mediaIds: List.filled(13, 'm'))).problems
            .map((p) => p.kind),
        contains(BlockProblemKind.tooMany),
      );
      expect(
        _check(
          TestimonialsPayload(
            items: List.filled(9, const Testimonial(quote: 'q')),
          ),
        ).isValid,
        isFalse,
      );
      expect(
        _check(
          FaqPayload(
            items: List.filled(11, const FaqItem(question: 'q', answer: 'a')),
          ),
        ).isValid,
        isFalse,
      );
    });

    test('availability ≤7 rows', () {
      expect(
        _check(
          AvailabilityPayload(
            hours: List.filled(
              8,
              const AvailabilityRow(day: 1, from: '09:00', to: '17:00'),
            ),
          ),
        ).isValid,
        isFalse,
      );
    });

    test('no block may reference more than 12 media items', () {
      final v = _check(GalleryPayload(mediaIds: List.filled(13, 'm')));
      expect(
        v.problems.map((p) => p.kind),
        contains(BlockProblemKind.tooManyMediaIds),
      );
    });

    test('a payload over 8 KB is refused', () {
      final v = _check(AboutPayload(paragraphs: [_long(20000)]));
      expect(
        v.problems.map((p) => p.kind),
        contains(BlockProblemKind.payloadTooLarge),
      );
    });
  });

  group('certificates are ids only — there is no free text to type', () {
    test('the payload has no name, body or issuer field', () {
      const payload = CertificatesPayload(certIds: ['c1', 'c2']);
      expect(payload.toJson().keys.toSet(), {'certIds', 'showCheckedDate'});
      for (final forbidden in const ['name', 'body', 'issuer', 'title']) {
        expect(payload.toJson().containsKey(forbidden), isFalse);
      }
    });

    test('so there is nothing for the claim policy to catch here', () {
      expect(
        _check(const CertificatesPayload(certIds: ['c1'])).isValid,
        isTrue,
      );
    });
  });

  group('a freebie cannot harvest a phone number', () {
    test('the payload has no email or phone field', () {
      const payload = FreebiePayload(title: 'A week of floor work');
      final keys = payload.toJson().keys.toSet();
      for (final forbidden in const [
        'email',
        'phone',
        'mobile',
        'capture',
        'leadEmail',
      ]) {
        expect(keys.contains(forbidden), isFalse, reason: forbidden);
      }
      expect(keys.contains('deliver'), isTrue);
    });
  });

  group('cta urls', () {
    CtaPayload cta(String? url) =>
        CtaPayload(label: 'Ask me', action: CtaAction.external, url: url);

    test('https with a host is allowed', () {
      expect(_check(cta('https://example.com/plan')).isValid, isTrue);
    });

    test('anything that can execute is refused', () {
      for (final bad in const [
        'javascript:alert(1)',
        'data:text/html,<script>',
        'http://example.com',
        'https://',
        'not a url at all',
      ]) {
        expect(
          _check(cta(bad)).problems.map((p) => p.kind),
          contains(BlockProblemKind.invalidUrl),
          reason: bad,
        );
      }
    });

    test('an external action with no url is refused', () {
      expect(
        _check(cta(null)).problems.single.kind,
        BlockProblemKind.invalidUrl,
      );
    });

    test('a message action needs no url', () {
      expect(_check(const CtaPayload(label: 'Ask me')).isValid, isTrue);
    });
  });

  group('validating a whole page', () {
    test('problems are reported per block, and all at once', () {
      final page = [
        PortfolioBlock(
          id: 'b1',
          payload: CoverPayload(
            layout: CoverLayout.noPhoto,
            headline: _long(65),
          ),
        ),
        PortfolioBlock(id: 'b2', payload: const MethodPayload()),
      ];

      final v = _validator.validateAll(page);
      expect(v.problems.length, 2);
      expect(v.forBlock('b1').single.kind, BlockProblemKind.tooLong);
      expect(v.forBlock('b2').single.kind, BlockProblemKind.tooFew);
    });

    test('a valid page is valid', () {
      expect(
        _validator.validateAll([
          PortfolioBlock(
            id: 'b1',
            payload: const CoverPayload(
              layout: CoverLayout.noPhoto,
              headline: 'Back to lifting, after birth',
              subline: 'Giza · at home · 20 minutes',
            ),
          ),
        ]).isValid,
        isTrue,
      );
    });
  });
}
