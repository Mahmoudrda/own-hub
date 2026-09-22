// The strict fakes, and the source-level guards.
//
// Two kinds of test here. The first kind drives the in-memory repositories and
// asserts they REFUSE what the security rules refuse — a draft claiming to be
// published, a stale revision, an unblurred upload, a 51st result. A lenient
// fake lets a bug pass in memory and fail on a phone, which is the defect
// `PHASE1-QA-VERDICT` singles out.
//
// The second kind reads this feature's own source. Some invariants are about
// what is NOT there — no coach-facing method that writes a client's content, no
// write method on the offers port, no consecutive-day field, no comparator on
// insights — and an absence cannot be exercised. It can only be scanned for.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/coachbrand/domain/ad_creative.dart';
import 'package:own_hub/features/coachbrand/domain/ads_repository.dart';
import 'package:own_hub/features/coachbrand/domain/coach_media.dart';
import 'package:own_hub/features/coachbrand/domain/coach_media_repository.dart';
import 'package:own_hub/features/coachbrand/domain/consent.dart';
import 'package:own_hub/features/coachbrand/domain/derived_numbers.dart';
import 'package:own_hub/features/coachbrand/domain/offers_port.dart';
import 'package:own_hub/features/coachbrand/domain/portfolio.dart';
import 'package:own_hub/features/coachbrand/domain/portfolio_block.dart';
import 'package:own_hub/features/coachbrand/domain/portfolio_insights.dart';
import 'package:own_hub/features/coachbrand/domain/portfolio_repository.dart';
import 'package:own_hub/features/coachbrand/domain/results_repository.dart';

final _now = DateTime.utc(2026, 3, 10);

PortfolioBlock _cover() => PortfolioBlock(
  id: 'b1',
  payload: const CoverPayload(
    layout: CoverLayout.noPhoto,
    headline: 'Back to lifting',
  ),
);

CoachMediaItem _media(
  String id, {
  bool blurApplied = true,
  CoachMediaState state = CoachMediaState.blurredLocal,
  List<String> usedBy = const [],
}) => CoachMediaItem(
  mediaId: id,
  kind: CoachMediaKind.photo,
  state: state,
  createdAt: _now,
  blurApplied: blurApplied,
  usedBy: usedBy,
);

/// Code lines of a source file under this feature, comments removed.
List<String> _codeLines(String path) => File(path).readAsLinesSync().where((l) {
  final t = l.trimLeft();
  return !t.startsWith('//') && !t.startsWith('*') && !t.startsWith('/*');
}).toList();

void main() {
  group('the portfolio repository writes one document: the draft', () {
    test('there is no method that writes live', () {
      // HANDOFF rule 2 by absence. A `publishLive` on this interface would be
      // the whole of versioning undone, and a reviewer is not a reliable guard
      // against one appearing.
      final source = _codeLines(
        'lib/features/coachbrand/domain/portfolio_repository.dart',
      ).join('\n');
      final interface = source.substring(
        source.indexOf('abstract class PortfolioRepository'),
        source.indexOf('class PortfolioStore'),
      );

      for (final forbidden in const [
        'publishLive',
        'writeLive',
        'saveLive',
        'setLive',
        'writeVersion',
      ]) {
        expect(interface.contains(forbidden), isFalse, reason: forbidden);
      }
    });

    test('a first draft must have draftRev 1', () async {
      final repo = InMemoryPortfolioRepository();
      addTearDown(repo.dispose);

      await expectLater(
        repo.saveDraft(
          Portfolio.newDraft(now: _now).addBlock(_cover()).savedBy('a'),
          deviceId: 'a',
        ),
        throwsA(isA<PortfolioWriteRejected>()),
      );

      expect(
        await repo.saveDraft(
          Portfolio.newDraft(now: _now).addBlock(_cover()),
          deviceId: 'a',
        ),
        DraftSaveOutcome.accepted,
      );
    });

    test('a stale revision is refused rather than overwriting', () async {
      final repo = InMemoryPortfolioRepository();
      addTearDown(repo.dispose);

      final first = Portfolio.newDraft(now: _now).addBlock(_cover());
      await repo.saveDraft(first, deviceId: 'phone-a');
      await repo.saveDraft(first.savedBy('phone-a'), deviceId: 'phone-a');

      expect(
        await repo.saveDraft(first.savedBy('phone-b'), deviceId: 'phone-b'),
        DraftSaveOutcome.staleRevision,
      );
      expect((await repo.draft())!.draftDeviceId, 'phone-a');
    });

    test('the fake refuses everything the rule refuses', () async {
      final repo = InMemoryPortfolioRepository();
      addTearDown(repo.dispose);

      final live = Portfolio.newDraft(now: _now)
          .addBlock(_cover())
          .publishedAs(
            version: 1,
            at: _now,
            validation: Portfolio.newDraft(now: _now).theme.validation,
          );

      // She may not write `live`.
      await expectLater(
        repo.saveDraft(live, deviceId: 'a'),
        throwsA(isA<PortfolioWriteRejected>()),
      );
    });

    test('publishing is the Function, and it writes three documents', () async {
      final repo = InMemoryPortfolioRepository();
      addTearDown(repo.dispose);

      final draft = Portfolio.newDraft(now: _now).addBlock(_cover());
      await repo.saveDraft(draft, deviceId: 'a');

      final published = repo.functionPublished(
        at: _now,
        validation: draft.theme.validation,
      );

      expect(published.version, 1);
      expect((await repo.live())!.version, 1);
      expect((await repo.version(1))!.versionId, 'v0001');
      expect(await repo.versions(), [1]);

      // And the draft is untouched.
      expect((await repo.draft())!.versionId, 'draft');
      expect((await repo.draft())!.published, isFalse);
    });

    test('history is append-only — publishing again keeps version 1', () async {
      final repo = InMemoryPortfolioRepository();
      addTearDown(repo.dispose);

      final draft = Portfolio.newDraft(now: _now).addBlock(_cover());
      await repo.saveDraft(draft, deviceId: 'a');
      repo.functionPublished(at: _now, validation: draft.theme.validation);

      await repo.saveDraft(draft.savedBy('a'), deviceId: 'a');
      repo.functionPublished(at: _now, validation: draft.theme.validation);

      expect(await repo.versions(), [2, 1]);
      expect((await repo.version(1))!.version, 1);
    });
  });

  group('the results repository has nothing a coach could author with', () {
    test('the coach interface names no client-owned field', () {
      final source = _codeLines(
        'lib/features/coachbrand/domain/results_repository.dart',
      ).join('\n');
      final interface = source.substring(
        source.indexOf('abstract class ResultsRepository'),
        source.indexOf('abstract class ClientConsentPort'),
      );

      for (final forbidden in const [
        'mediaIds',
        'quote',
        'numbers',
        'scope',
        'consentState',
        'grant',
        'withdraw',
      ]) {
        expect(
          interface.contains(forbidden),
          isFalse,
          reason:
              'ResultsRepository must not mention $forbidden — the coach '
              'path needs nothing to call, not a method she is asked not to',
        );
      }
    });

    test('she asks, and the document holds nothing', () async {
      final repo = InMemoryResultsRepository();
      addTearDown(repo.dispose);

      await repo.requestResult(
        ResultRequest(
          resultId: 'r1',
          clientUid: 'mai',
          relationshipId: 'rel-1',
          requestedAt: _now,
        ),
      );

      final result = (await repo.results()).single;
      expect(result.consentState, ConsentState.requested);
      expect(result.mediaIds, isEmpty);
      expect(result.quote, isNull);
      expect(result.numbers, isEmpty);
    });

    test('a replayed request collides with itself', () async {
      final repo = InMemoryResultsRepository();
      addTearDown(repo.dispose);

      final request = ResultRequest(
        resultId: 'r1',
        clientUid: 'mai',
        relationshipId: 'rel-1',
        requestedAt: _now,
      );
      await repo.requestResult(request);
      await repo.requestResult(request);

      expect((await repo.results()).length, 1);
    });

    test('the collection is capped at 50', () async {
      final repo = InMemoryResultsRepository();
      addTearDown(repo.dispose);

      for (var i = 0; i < kMaxResultsPerCoach; i++) {
        await repo.requestResult(
          ResultRequest(
            resultId: 'r$i',
            clientUid: 'c$i',
            relationshipId: 'rel',
            requestedAt: _now,
          ),
        );
      }

      await expectLater(
        repo.requestResult(
          ResultRequest(
            resultId: 'r51',
            clientUid: 'c51',
            relationshipId: 'rel',
            requestedAt: _now,
          ),
        ),
        throwsA(isA<ResultWriteRejected>()),
      );
    });

    test('the client grants, and the Function derives her figures', () async {
      final repo = InMemoryResultsRepository(
        bests: const {
          'mai': [
            ClientBest(measureId: 'plankSec', from: 20, to: 75, unit: 's'),
            ClientBest(measureId: 'weightKg', from: 82, to: 62, unit: 'kg'),
          ],
        },
      );
      addTearDown(repo.dispose);

      await repo.requestResult(
        ResultRequest(
          resultId: 'r1',
          clientUid: 'mai',
          relationshipId: 'rel-1',
          requestedAt: _now,
        ),
      );

      final granted = await repo.grant(
        resultId: 'r1',
        scope: const ConsentScope(numbers: true, quote: true),
        at: _now,
        quote: 'Carried both kids up the stairs.',
      );

      expect(granted.numbers.keys, ['plankSec']);
      expect(granted.quote, 'Carried both kids up the stairs.');
      expect(
        granted.numbers.containsKey('weightKg'),
        isFalse,
        reason: 'not derivable, so not derived, even by the Function',
      );
    });

    test('only a requested result can be granted', () async {
      final repo = InMemoryResultsRepository();
      addTearDown(repo.dispose);

      await repo.requestResult(
        ResultRequest(
          resultId: 'r1',
          clientUid: 'mai',
          relationshipId: 'rel-1',
          requestedAt: _now,
        ),
      );
      await repo.grant(
        resultId: 'r1',
        scope: const ConsentScope(numbers: true),
        at: _now,
      );

      await expectLater(
        repo.grant(
          resultId: 'r1',
          scope: const ConsentScope(photos: true),
          at: _now,
        ),
        throwsA(isA<ResultWriteRejected>()),
      );
    });

    test('an unconfirmed withdrawal does nothing', () async {
      final repo = InMemoryResultsRepository();
      addTearDown(repo.dispose);

      await repo.requestResult(
        ResultRequest(
          resultId: 'r1',
          clientUid: 'mai',
          relationshipId: 'rel-1',
          requestedAt: _now,
        ),
      );
      await repo.grant(
        resultId: 'r1',
        scope: const ConsentScope(numbers: true),
        at: _now,
      );

      await expectLater(
        repo.withdraw(
          WithdrawalIntent(resultId: 'r1', requestedAt: _now, online: true),
        ),
        throwsA(isA<ResultWriteRejected>()),
      );

      final withdrawn = await repo.withdraw(
        WithdrawalIntent(
          resultId: 'r1',
          requestedAt: _now,
          online: true,
        ).confirm(),
      );
      expect(withdrawn.consentState, ConsentState.withdrawn);
    });

    test('a deleted account orphans every result she gave', () async {
      final repo = InMemoryResultsRepository();
      addTearDown(repo.dispose);

      for (final id in const ['r1', 'r2']) {
        await repo.requestResult(
          ResultRequest(
            resultId: id,
            clientUid: 'mai',
            relationshipId: 'rel-1',
            requestedAt: _now,
          ),
        );
        await repo.grant(
          resultId: id,
          scope: const ConsentScope(numbers: true),
          at: _now,
        );
      }

      final orphaned = repo.functionOrphanedFor('mai', _now);
      expect(orphaned.length, 2);
      expect(
        (await repo.results()).every(
          (r) => r.consentState == ConsentState.orphaned,
        ),
        isTrue,
      );
    });
  });

  group('the offers port is read-only, and K04 is the single writer', () {
    test('the port declares no write method', () {
      final source = _codeLines(
        'lib/features/coachbrand/domain/offers_port.dart',
      ).join('\n');
      final interface = source.substring(
        source.indexOf('abstract class CoachOffersPort'),
        source.indexOf('class InMemoryCoachOffersPort'),
      );

      for (final forbidden in const [
        'upsert',
        'save',
        'create',
        'update',
        'delete',
        'write',
        'OfferDraft',
      ]) {
        expect(
          interface.contains(forbidden),
          isFalse,
          reason:
              'B06 reads offers. K04 writes them. $forbidden on this port '
              'would be two screens writing one field, which the spine rejects',
        );
      }
    });

    test('B06 reads what K04 wrote', () async {
      final port = InMemoryCoachOffersPort();
      addTearDown(port.dispose);

      port.k04Wrote('nourhan', const [
        OfferSummary(
          offerId: 'o1',
          title: 'Monthly coaching',
          summary: 'Plan, weekly review, chat',
          priceMinor: 180000,
        ),
        OfferSummary(offerId: 'o2', title: 'Plan only', priceMinor: 90000),
      ]);

      final offers = await port.offersFor('nourhan');
      expect(offers.map((o) => o.title), ['Monthly coaching', 'Plan only']);
    });

    test('a retired offer drops out at read time', () async {
      final port = InMemoryCoachOffersPort();
      addTearDown(port.dispose);

      port.k04Wrote('n', const [
        OfferSummary(offerId: 'o1', title: 'Monthly'),
        OfferSummary(offerId: 'o2', title: 'Retired', isActive: false),
      ]);

      expect(
        (await port.resolve('n', const ['o1', 'o2'])).map((o) => o.offerId),
        ['o1'],
      );
    });

    test('at most six offers, as the query limit has it', () {
      final port = InMemoryCoachOffersPort();
      addTearDown(port.dispose);

      expect(
        () => port.k04Wrote('n', [
          for (var i = 0; i < 7; i++)
            OfferSummary(offerId: 'o$i', title: 'Offer $i'),
        ]),
        throwsArgumentError,
      );
    });

    test('price travels as minor units, never as a formatted string', () {
      // A pre-formatted "1,800 EGP" renders Eastern digits under an Arabic
      // locale, and P0-A11Y-01 requires Western numerals throughout.
      const offer = OfferSummary(
        offerId: 'o1',
        title: 'Monthly coaching',
        priceMinor: 180000,
      );
      expect(offer.priceMinor, isA<int>());
      expect(offer.currency, 'EGP');
    });
  });

  group('the media library keeps blur at the door', () {
    test('an unblurred item is refused', () async {
      final repo = InMemoryCoachMediaRepository();
      addTearDown(repo.dispose);

      await expectLater(
        repo.add(_media('m1', blurApplied: false)),
        throwsA(isA<BlurNotAppliedError>()),
      );
    });

    test('nothing leaves blurredLocal without blur', () {
      expect(
        () => _media('m1', blurApplied: false).queuedForUpload(),
        throwsA(isA<BlurNotAppliedError>()),
      );
      expect(_media('m1').queuedForUpload().state, CoachMediaState.queued);
    });

    test('a delete is refused while a block still points at it', () async {
      final repo = InMemoryCoachMediaRepository();
      addTearDown(repo.dispose);

      await repo.add(_media('m1'));
      await repo.markUsedBy('m1', 'b1');

      await expectLater(repo.delete('m1'), throwsA(isA<MediaInUseError>()));

      await repo.releaseFrom('m1', 'b1');
      await repo.delete('m1');
      expect(await repo.byId('m1'), isNull);
    });

    test('the library is paged, never unbounded', () async {
      final repo = InMemoryCoachMediaRepository();
      addTearDown(repo.dispose);

      for (var i = 0; i < 40; i++) {
        await repo.add(
          CoachMediaItem(
            mediaId: 'm$i',
            kind: CoachMediaKind.photo,
            state: CoachMediaState.live,
            createdAt: _now.add(Duration(minutes: i)),
          ),
        );
      }

      expect((await repo.page()).length, kMediaPageSize);
      await expectLater(
        repo.page(limit: 100),
        throwsA(isA<MediaWriteRejected>()),
      );
    });

    test('blur is required unless this client offered her own face', () {
      final granted =
          ClientResult.fromRequest(
            ResultRequest(
              resultId: 'r1',
              clientUid: 'mai',
              relationshipId: 'rel',
              requestedAt: _now,
            ),
          ).grantedByClient(
            at: _now,
            scope: const ConsentScope(photos: true, faceVisible: true),
          );

      expect(CoachMediaPolicy.blurRequired(now: _now), isTrue);
      expect(
        CoachMediaPolicy.blurRequired(clientResult: granted, now: _now),
        isFalse,
      );
      expect(
        CoachMediaPolicy.blurRequired(
          clientResult: granted.withdrawnByClient(at: _now),
          now: _now,
        ),
        isTrue,
        reason: 'a face shown under a withdrawn grant is the exact failure',
      );
      expect(
        CoachMediaPolicy.blurRequired(
          clientResult: granted,
          now: DateTime.utc(2028),
        ),
        isTrue,
        reason: 'and under an expired one',
      );
    });

    test('a withdrawal purges only that result\'s files', () async {
      final repo = InMemoryCoachMediaRepository();
      addTearDown(repo.dispose);

      await repo.add(_media('mine'));
      await repo.add(
        CoachMediaItem(
          mediaId: 'hers',
          kind: CoachMediaKind.photo,
          state: CoachMediaState.live,
          createdAt: _now,
          clientResultId: 'r1',
        ),
      );

      expect(repo.functionPurgedForResult('r1'), ['hers']);
      expect((await repo.byId('mine'))!.state, CoachMediaState.blurredLocal);
      expect((await repo.byId('hers'))!.state, CoachMediaState.purged);
    });
  });

  group('the ads repository gives a coach no server field to write', () {
    test('the draft type has no state, claimCheck or exports', () {
      const draft = AdDraft(
        adId: 'a1',
        format: AdFormat.feed,
        portfolioVersion: 3,
      );
      expect(draft.adId, 'a1');

      final source = _codeLines(
        'lib/features/coachbrand/domain/ads_repository.dart',
      ).join('\n');
      final type = source.substring(
        source.indexOf('class AdDraft'),
        source.indexOf('abstract class AdsRepository'),
      );
      for (final forbidden in const ['claimCheck', 'state', 'exports']) {
        expect(type.contains(forbidden), isFalse, reason: forbidden);
      }
    });

    test(
      'saving preserves the server fields rather than taking them',
      () async {
        final repo = InMemoryAdsRepository();
        addTearDown(repo.dispose);

        await repo.save(
          const AdDraft(adId: 'a1', format: AdFormat.feed, portfolioVersion: 3),
        );
        repo.functionChecked('a1', _now);
        expect((await repo.byId('a1'))!.state, AdState.ready);

        await repo.save(
          const AdDraft(
            adId: 'a1',
            format: AdFormat.story,
            portfolioVersion: 3,
            headline: 'Six weeks after birth',
          ),
        );

        final saved = (await repo.byId('a1'))!;
        expect(saved.format, AdFormat.story);
        expect(saved.claimCheck, isNotNull, reason: 'the server\'s, preserved');
      },
    );

    test('a withdrawal marks every ad that pointed at that result', () async {
      final repo = InMemoryAdsRepository();
      addTearDown(repo.dispose);

      await repo.save(
        const AdDraft(
          adId: 'a1',
          format: AdFormat.feed,
          portfolioVersion: 3,
          resultId: 'r1',
        ),
      );
      await repo.save(
        const AdDraft(adId: 'a2', format: AdFormat.feed, portfolioVersion: 3),
      );

      expect(repo.functionMarkedStaleForResult('r1').length, 1);
      expect((await repo.byId('a1'))!.state, AdState.stale);
      expect((await repo.byId('a2'))!.state, AdState.draft);
    });

    test(
      'the ads collection is capped, so a purge set stays bounded',
      () async {
        final repo = InMemoryAdsRepository();
        addTearDown(repo.dispose);

        for (var i = 0; i < kMaxAdsPerCoach; i++) {
          await repo.save(
            AdDraft(adId: 'a$i', format: AdFormat.feed, portfolioVersion: 1),
          );
        }
        await expectLater(
          repo.save(
            const AdDraft(
              adId: 'over',
              format: AdFormat.feed,
              portfolioVersion: 1,
            ),
          ),
          throwsA(isA<AdWriteRejected>()),
        );
      },
    );
  });

  group('nothing is ranked, and there is no streak', () {
    test('no consecutive-day field exists anywhere in this feature', () {
      // "Live 14 days in a row" must be unstorable. portfolio_insights.dart is
      // the one file allowed to NAME these keys, because what it holds is the
      // ban list G8's noStreak() rule reads.
      final offenders = <String>[];

      for (final file in Directory(
        'lib/features/coachbrand',
      ).listSync(recursive: true).whereType<File>()) {
        if (!file.path.endsWith('.dart')) continue;
        if (file.path.endsWith('portfolio_insights.dart')) continue;

        final lines = _codeLines(file.path);
        for (final line in lines) {
          for (final key in kForbiddenStreakKeys) {
            if (line.contains(key)) offenders.add('${file.path}: $line');
          }
        }
      }

      expect(offenders, isEmpty);
    });

    test('the ban list is the one G8\'s rule enforces', () {
      expect(
        kForbiddenStreakKeys,
        containsAll(<String>[
          'streak',
          'consecutiveDays',
          'daysInARow',
          'currentStreak',
          'missedDays',
        ]),
      );
    });

    test('insights has no comparator and nothing to sort by', () {
      const insights = PortfolioInsights.deferred;
      expect(insights, isNot(isA<Comparable<Object>>()));

      final source = _codeLines(
        'lib/features/coachbrand/domain/portfolio_insights.dart',
      ).join('\n');
      for (final forbidden in const [
        'compareTo',
        'Comparable',
        'rank',
        'leaderboard',
        'orderBy',
      ]) {
        expect(source.contains(forbidden), isFalse, reason: forbidden);
      }
    });

    test('nothing in this feature sorts by views, enquiries or followers', () {
      final offenders = <String>[];
      for (final file in Directory(
        'lib/features/coachbrand',
      ).listSync(recursive: true).whereType<File>()) {
        if (!file.path.endsWith('.dart')) continue;
        for (final line in _codeLines(file.path)) {
          if (!line.contains('sort')) continue;
          for (final metric in const [
            'views',
            'enquiries',
            'opens',
            'followers',
            'followerCount',
          ]) {
            if (line.contains(metric)) offenders.add('${file.path}: $line');
          }
        }
      }
      expect(offenders, isEmpty);
    });

    test('B12 is deferred and fabricates nothing', () {
      expect(kPortfolioInsightsEnabled, isFalse);
      expect(
        PortfolioInsights.deferred.availability,
        InsightsAvailability.notMeasuredYet,
      );
      expect(PortfolioInsights.deferred.hasFigures, isFalse);
      expect(
        PortfolioInsights.deferred.enquiryRate,
        isNull,
        reason:
            'a rate over zero views is unknown, not zero — and a screen '
            'that draws 0% tells a coach something untrue about her work',
      );
    });
  });
}
