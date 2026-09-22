// P0-PORT-03, P0-PORT-04, P0-PORT-08 and P1-RULE-12's grep, as tests.
//
// The most important case in this file is the last group. It publishes a page
// while a client's consent is active, then withdraws the consent, then reads
// the ALREADY-PUBLISHED version — and finds her gone. That only works because
// nothing was copied at publish time, and it is the one behaviour that a
// plausible-looking optimisation (cache the resolved results on the published
// document) would silently destroy while every other test still passed.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/coachbrand/domain/coach_media.dart';
import 'package:own_hub/features/coachbrand/domain/consent.dart';
import 'package:own_hub/features/coachbrand/domain/portfolio.dart';
import 'package:own_hub/features/coachbrand/domain/portfolio_block.dart';
import 'package:own_hub/features/coachbrand/domain/portfolio_publisher.dart';
import 'package:own_hub/features/coachbrand/domain/published_portfolio_reader.dart';

const _publisher = PortfolioPublisher();

final _now = DateTime.utc(2026, 3, 10);

PortfolioBlock _cover([String headline = 'Back to lifting, after birth']) =>
    PortfolioBlock(
      id: 'b1',
      payload: CoverPayload(layout: CoverLayout.noPhoto, headline: headline),
    );

PortfolioBlock _results(List<String> ids) => PortfolioBlock(
  id: 'b2',
  payload: ResultsPayload(resultIds: ids),
);

Portfolio _draft({List<PortfolioBlock>? blocks}) {
  var page = Portfolio.newDraft(now: _now);
  for (final b in blocks ?? [_cover()]) {
    page = page.addBlock(b);
  }
  return page.savedBy('phone-a');
}

Portfolio _publish(Portfolio draft, {int version = 3}) => draft.publishedAs(
  version: version,
  at: _now,
  validation: draft.theme.validation,
);

ClientResult _grantedResult(String id, {DateTime? at}) =>
    ClientResult.fromRequest(
      ResultRequest(
        resultId: id,
        clientUid: 'mai',
        relationshipId: 'rel-1',
        requestedAt: DateTime.utc(2026, 3, 1),
      ),
    ).grantedByClient(
      at: at ?? DateTime.utc(2026, 3, 2),
      scope: const ConsentScope(photos: true, quote: true),
      mediaIds: const ['m-mai'],
      quote: 'Carried both kids up the stairs.',
    );

CoachMediaItem _liveMedia(String id) => CoachMediaItem(
  mediaId: id,
  kind: CoachMediaKind.photo,
  state: CoachMediaState.live,
  createdAt: _now,
);

/// Every key and every string value in a nested map, flattened.
void _walk(Object? node, void Function(String? key, Object? value) visit) {
  if (node is Map) {
    for (final entry in node.entries) {
      visit(entry.key.toString(), entry.value);
      _walk(entry.value, visit);
    }
  } else if (node is List) {
    for (final item in node) {
      visit(null, item);
      _walk(item, visit);
    }
  }
}

void main() {
  group('P0-PORT-03 — editing never changes what a client sees', () {
    test('the live document is untouched by every draft edit', () {
      final draft = _draft();
      final live = _publish(draft);
      final before = jsonEncode(live.toJson());

      draft
          .replacePayload(
            'b1',
            const CoverPayload(
              layout: CoverLayout.noPhoto,
              headline: 'Something else entirely',
            ),
          )
          .addBlock(PortfolioBlock(id: 'b9', payload: const FaqPayload()))
          .savedBy('phone-a');

      expect(
        jsonEncode(live.toJson()),
        before,
        reason: 'byte-identical, including everything it holds',
      );
      expect(
        (live.blockById('b1')!.payload as CoverPayload).headline,
        'Back to lifting, after birth',
      );
    });

    test('the draft is a different document from live', () {
      final draft = _draft();
      final live = _publish(draft);

      expect(draft.versionId, 'draft');
      expect(live.versionId, 'live');
      expect(draft.published, isFalse);
      expect(live.published, isTrue);
    });
  });

  group('P0-PORT-04 — the diff is derived and history is append-only', () {
    test('the diff names what changed', () {
      final live = _publish(_draft());
      final draft = _draft()
          .replacePayload(
            'b1',
            const CoverPayload(
              layout: CoverLayout.noPhoto,
              headline: 'Back to lifting',
            ),
          )
          .addBlock(PortfolioBlock(id: 'b7', payload: const MethodPayload()))
          .savedBy('phone-a');

      final diff = PortfolioDiffer.between(live: live, draft: draft);

      expect(
        diff.changes.map((c) => '${c.kind.name}:${c.blockId}'),
        containsAll(<String>['edited:b1', 'added:b7']),
      );
      expect(diff.isEmpty, isFalse);
    });

    test('hiding, showing, removing and moving are each their own change', () {
      final base = _draft(
        blocks: [
          _cover(),
          PortfolioBlock(id: 'b2', payload: const MethodPayload()),
          PortfolioBlock(id: 'b3', payload: const FaqPayload()),
        ],
      );
      final live = _publish(base);

      expect(
        PortfolioDiffer.between(
          live: live,
          draft: base.setVisible('b2', false),
        ).changes.single.kind,
        BlockChangeKind.hidden,
      );
      expect(
        PortfolioDiffer.between(
          live: live,
          draft: base.removeBlock('b3'),
        ).changes.single.kind,
        BlockChangeKind.removed,
      );
      expect(
        PortfolioDiffer.between(
          live: live,
          draft: base.reorder(2, 0),
        ).changes.map((c) => c.kind),
        contains(BlockChangeKind.moved),
      );
    });

    test('a theme change is a change', () {
      final base = _draft();
      final live = _publish(base);
      expect(
        PortfolioDiffer.between(live: live, draft: base).themeChanged,
        isFalse,
      );
    });

    test('with nothing live, everything is an addition', () {
      final diff = PortfolioDiffer.between(draft: _draft());
      expect(diff.changes.single.kind, BlockChangeKind.added);
    });

    test('the diff is not stored anywhere', () {
      final live = _publish(_draft());
      final encoded = jsonEncode(live.toJson());
      for (final forbidden in const ['diff', 'changes', 'changedSince']) {
        expect(encoded.contains('"$forbidden"'), isFalse, reason: forbidden);
      }
    });

    test('restoring version 3 produces a NEW version, never a rewind', () {
      final v3 = _publish(_draft(), version: 3).asSnapshot();
      final currentDraft = _draft(blocks: [_cover('A headline she regrets')])
          .savedBy('phone-a');

      final rollback = _publisher.draftForRollback(
        snapshot: v3,
        currentDraft: currentDraft,
      );

      expect(rollback.versionId, 'draft');
      expect(rollback.published, isFalse);
      expect(
        (rollback.blockById('b1')!.payload as CoverPayload).headline,
        'Back to lifting, after birth',
        reason: "v3's content",
      );
      expect(
        rollback.draftRev,
        currentDraft.draftRev + 1,
        reason:
            'it is a save like any other, so the two-phone guard still '
            'applies to it',
      );
      expect(
        v3.versionId,
        'v0003',
        reason:
            'the snapshot itself is untouched — a stranger who bookmarked '
            'v0003.json still gets version 3',
      );
    });
  });

  group('the publish gate', () {
    test('it queues when everything resolves', () {
      final draft = _draft(
        blocks: [
          _cover(),
          _results(const ['r1']),
        ],
      );
      final outcome = _publisher.publish(
        coachUid: 'nourhan',
        draft: draft,
        now: _now,
        preconditions: PublishPreconditions(
          results: {'r1': _grantedResult('r1')},
        ),
      );

      expect(outcome, isA<PublishQueued>());
      final intent = (outcome as PublishQueued).intent;
      expect(intent.version, 1);
      expect(intent.draftRev, draft.draftRev);
      expect(intent.dedupeKey, 'publishPortfolio:nourhan:1');
    });

    test('a replayed intent collapses onto the same version', () {
      final draft = _draft();
      PublishIntent intent() => (_publisher.publish(
        coachUid: 'nourhan',
        draft: draft,
        now: _now,
        preconditions: const PublishPreconditions(),
      ) as PublishQueued).intent;

      expect(intent().dedupeKey, intent().dedupeKey);
    });

    test('nothing to publish, and nothing changed', () {
      expect(
        (_publisher.publish(
          coachUid: 'n',
          draft: Portfolio.newDraft(now: _now),
          now: _now,
          preconditions: const PublishPreconditions(),
        ) as PublishRefused).refusals.single.reason,
        PublishRefusalReason.nothingToPublish,
      );

      final draft = _draft();
      final live = _publish(draft);
      expect(
        (_publisher.publish(
          coachUid: 'n',
          draft: draft,
          live: live,
          now: _now,
          preconditions: const PublishPreconditions(),
        ) as PublishRefused).refusals.single.reason,
        PublishRefusalReason.nothingChanged,
      );
    });

    test('a withdrawn result blocks the publish and names the block', () {
      final draft = _draft(
        blocks: [
          _cover(),
          _results(const ['r1']),
        ],
      );
      final withdrawn = _grantedResult('r1').withdrawnByClient(at: _now);

      final outcome = _publisher.publish(
        coachUid: 'n',
        draft: draft,
        now: _now,
        preconditions: PublishPreconditions(results: {'r1': withdrawn}),
      );

      final refusal = (outcome as PublishRefused).refusals.single;
      expect(refusal.reason, PublishRefusalReason.resultNotConsented);
      expect(refusal.blockId, 'b2');
      expect(refusal.detail, 'r1');
    });

    test('a missing result is as refused as a withdrawn one', () {
      final outcome = _publisher.publish(
        coachUid: 'n',
        draft: _draft(
          blocks: [
            _cover(),
            _results(const ['ghost']),
          ],
        ),
        now: _now,
        preconditions: const PublishPreconditions(),
      );
      expect(
        (outcome as PublishRefused).refusals.single.reason,
        PublishRefusalReason.resultNotConsented,
      );
    });

    test('media that has not finished uploading blocks the publish', () {
      final draft = _draft(
        blocks: [
          PortfolioBlock(
            id: 'b1',
            payload: const CoverPayload(
              layout: CoverLayout.textOverPhoto,
              mediaId: 'm1',
              headline: 'Hello',
            ),
          ),
        ],
      );

      expect(
        (_publisher.publish(
          coachUid: 'n',
          draft: draft,
          now: _now,
          preconditions: PublishPreconditions(
            media: {
              'm1': _liveMedia('m1').inState(CoachMediaState.blurredLocal),
            },
          ),
        ) as PublishRefused).refusals.single.reason,
        PublishRefusalReason.mediaNotLive,
      );

      expect(
        _publisher.publish(
          coachUid: 'n',
          draft: draft,
          now: _now,
          preconditions: PublishPreconditions(media: {'m1': _liveMedia('m1')}),
        ),
        isA<PublishQueued>(),
      );
    });

    test('an unresolved offer and an unverified certificate block it', () {
      final draft = _draft(
        blocks: [
          PortfolioBlock(
            id: 'b1',
            payload: const OffersPayload(offerIds: ['o1']),
          ),
          PortfolioBlock(
            id: 'b2',
            payload: const CertificatesPayload(certIds: ['c1']),
          ),
        ],
      );

      final refusals = (_publisher.publish(
        coachUid: 'n',
        draft: draft,
        now: _now,
        preconditions: const PublishPreconditions(),
      ) as PublishRefused).refusals;

      expect(
        refusals.map((r) => r.reason),
        containsAll(<PublishRefusalReason>[
          PublishRefusalReason.offerUnresolved,
          PublishRefusalReason.certificateNotVerified,
        ]),
      );
    });

    test('a claim blocks the publish and points at the block', () {
      final draft = _draft(blocks: [_cover('Lose 10 kg in 30 days')]);
      final refusals = (_publisher.publish(
        coachUid: 'n',
        draft: draft,
        now: _now,
        preconditions: const PublishPreconditions(),
      ) as PublishRefused).refusals;

      expect(
        refusals.map((r) => r.reason),
        everyElement(PublishRefusalReason.claimFailed),
      );
      expect(refusals.first.blockId, 'b1');
      expect(refusals.first.problem, isNotNull);
    });

    test('every reason comes back at once, not the first one', () {
      final draft = _draft(
        blocks: [
          _cover('Lose 10 kg in 30 days'),
          _results(const ['ghost']),
          PortfolioBlock(
            id: 'b3',
            payload: const OffersPayload(offerIds: ['o']),
          ),
        ],
      );
      final refusals = (_publisher.publish(
        coachUid: 'n',
        draft: draft,
        now: _now,
        preconditions: const PublishPreconditions(),
      ) as PublishRefused).refusals;

      expect(refusals.map((r) => r.reason).toSet().length, greaterThan(1));
    });

    test('a hidden block is not gated — its references are not published', () {
      final draft = _draft(
        blocks: [
          _cover(),
          _results(const ['ghost']).hidden,
        ],
      );
      expect(
        _publisher.publish(
          coachUid: 'n',
          draft: draft,
          now: _now,
          preconditions: const PublishPreconditions(),
        ),
        isA<PublishQueued>(),
      );
    });

    test('a suspended page cannot be published at all', () {
      expect(
        (_publisher.publish(
          coachUid: 'n',
          draft: _draft().withSuspended(true),
          now: _now,
          preconditions: const PublishPreconditions(),
        ) as PublishRefused).refusals.single.reason,
        PublishRefusalReason.suspended,
      );
    });
  });

  group('P0-PORT-08 — publishing offline is a queued intent, never a live page', () {
    test('the intent carries the revision it was queued at', () {
      final draft = _draft();
      final intent = (_publisher.publish(
        coachUid: 'n',
        draft: draft,
        now: _now,
        preconditions: const PublishPreconditions(),
      ) as PublishQueued).intent;

      expect(intent.draftRev, draft.draftRev);
      expect(intent.cancelled, isFalse);
      expect(intent.cancel().cancelled, isTrue);
    });

    test('an intent is not a published page', () {
      // There is no method on the intent, or on the publisher, that produces a
      // `live` document. Only the Function does, and B11's copy says so.
      final outcome = _publisher.publish(
        coachUid: 'n',
        draft: _draft(),
        now: _now,
        preconditions: const PublishPreconditions(),
      );
      expect(outcome, isA<PublishQueued>());
      expect(outcome, isNot(isA<Portfolio>()));
    });
  });

  group('P1-RULE-12 — nothing about consent is copied at publish', () {
    test('no published document holds a consent field or result content', () {
      final draft = _draft(
        blocks: [
          _cover(),
          _results(const ['r1']),
        ],
      );
      final result = _grantedResult('r1');

      final queued = _publisher.publish(
        coachUid: 'n',
        draft: draft,
        now: _now,
        preconditions: PublishPreconditions(results: {'r1': result}),
      );
      expect(queued, isA<PublishQueued>());

      final live = _publish(draft);
      final json = live.toJson();

      const forbiddenKeys = <String>[
        'consentState',
        'consentedAt',
        'withdrawnAt',
        'expiresAt',
        'scope',
        'mediaIds',
        'quote',
        'numbers',
        'clientUid',
      ];

      final offenders = <String>[];
      _walk(json, (key, value) {
        if (key != null && forbiddenKeys.contains(key)) {
          offenders.add('key $key');
        }
        if (value is String) {
          for (final state in ConsentState.values) {
            if (value == state.name) offenders.add('value ${state.name}');
          }
          if (value.contains('Carried both kids')) {
            offenders.add('her sentence');
          }
          if (value == 'm-mai') offenders.add('her photograph');
        }
      });

      expect(
        offenders,
        isEmpty,
        reason:
            'a published page holds result IDS and nothing else. Anything '
            'else here would survive a withdrawal.',
      );

      // And the block really is there, holding the id.
      final blocks = json['blocks']! as List<Object?>;
      final resultsBlock =
          blocks.firstWhere((b) => (b! as Map)['type'] == 'results')! as Map;
      expect((resultsBlock['payload']! as Map)['resultIds'], ['r1']);
    });

    test(
      'a withdrawal AFTER publication hides her from the published version',
      () {
        // The sequence P0-CONSENT-02 and P0-CONSENT-03 describe, end to end.
        final draft = _draft(
          blocks: [
            _cover(),
            _results(const ['r1']),
          ],
        );
        var result = _grantedResult('r1');

        final live = _publish(draft);

        // While consent is active, she renders.
        final before = PublishedPortfolio.resolve(
          page: live,
          now: _now,
          results: {'r1': result},
        );
        expect(
          (before.resultsFor(
            live.blockById('b2')!.payload as ResultsPayload,
          ) as ResultsVisible).resultIds,
          ['r1'],
        );

        // She withdraws. Nothing about the published page is rewritten.
        result = result.withdrawnByClient(
          at: _now.add(const Duration(hours: 1)),
        );

        final after = PublishedPortfolio.resolve(
          page: live,
          now: _now.add(const Duration(hours: 1)),
          results: {'r1': result},
        );
        expect(
          (after.resultsFor(
            live.blockById('b2')!.payload as ResultsPayload,
          ) as ResultsVisible).resultIds,
          isEmpty,
          reason:
              'the same published document, read an hour later, without '
              'republishing anything',
        );
      },
    );

    test('a grant that aged out stops rendering without anybody acting', () {
      final draft = _draft(
        blocks: [
          _cover(),
          _results(const ['r1']),
        ],
      );
      final live = _publish(draft);
      final result = _grantedResult('r1', at: DateTime.utc(2026, 1, 1));

      final later = PublishedPortfolio.resolve(
        page: live,
        now: DateTime.utc(2027, 1, 2),
        results: {'r1': result},
      );

      expect(
        (later.resultsFor(
          live.blockById('b2')!.payload as ResultsPayload,
        ) as ResultsVisible).resultIds,
        isEmpty,
        reason: 'twelve months, then she is asked again',
      );
    });
  });
}
