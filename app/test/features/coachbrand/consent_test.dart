// Another woman's photograph. This is the file that has to be right.
//
// P0-CONSENT-01 … 06, as executable cases. The assertions that matter most are
// the ones about what CANNOT be done: a coach authoring a result, a figure
// being typed, a weight being derivable, a consent flag being copied onto a
// page. Each of those is tested by reaching for the thing and finding it is
// not there.
//
// `results_repository_test.dart` carries the source-level half — the proof that
// the coach-facing interface has no method that could accept a client's
// content. Here the subject is the domain types.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/coachbrand/domain/consent.dart';
import 'package:own_hub/features/coachbrand/domain/derived_numbers.dart';

final _requestedAt = DateTime.utc(2026, 3, 1, 9);

ResultRequest _request({String id = 'r1', int order = 0}) => ResultRequest(
  resultId: id,
  clientUid: 'mai',
  relationshipId: 'rel-1',
  requestedAt: _requestedAt,
  order: order,
);

ClientResult _granted({
  DateTime? at,
  ConsentScope scope = const ConsentScope(
    photos: true,
    numbers: true,
    quote: true,
  ),
  List<String> mediaIds = const ['m1'],
  String? quote = 'Carried both kids up the stairs.',
}) => ClientResult.fromRequest(_request()).grantedByClient(
  at: at ?? DateTime.utc(2026, 3, 2, 10),
  scope: scope,
  mediaIds: mediaIds,
  quote: quote,
);

void main() {
  group(
    'P0-CONSENT-01 — she agrees in the app, and the coach cannot answer',
    () {
      test('a coach creates a result with no content whatsoever', () {
        final result = ClientResult.fromRequest(_request());

        expect(result.consentState, ConsentState.requested);
        expect(result.mediaIds, isEmpty);
        expect(result.quote, isNull);
        expect(result.numbers, isEmpty);
        expect(result.scope.isEmpty, isTrue);
        expect(result.scope.faceVisible, isFalse);
        expect(result.consentedAt, isNull);
        expect(result.expiresAt, isNull);
      });

      test('the type a coach writes has no field to put content in', () {
        // Not "she must not" — there is nowhere for it to go. ResultRequest's
        // JSON is exactly the coach key set from G13 §6.
        final json = _request().toJson();
        expect(json.keys.toSet(), {
          'clientUid',
          'relationshipId',
          'requestedAt',
          'order',
          'consentState',
        });
        expect(json['consentState'], 'requested');
        for (final forbidden in const [
          'mediaIds',
          'quote',
          'numbers',
          'scope',
          'consentedAt',
          'withdrawnAt',
        ]) {
          expect(json.containsKey(forbidden), isFalse, reason: forbidden);
        }
      });

      test('blur is on unless she turned it off for her own face', () {
        expect(_granted().blurred, isTrue);
        expect(
          _granted(scope: const ConsentScope(photos: true, faceVisible: true))
              .blurred,
          isFalse,
        );
      });

      test('what she did not tick is not stored, not merely hidden', () {
        final numbersOnly = _granted(
          scope: const ConsentScope(numbers: true),
          mediaIds: const ['m1', 'm2'],
          quote: 'a sentence she did not agree to publish',
        );

        expect(numbersOnly.mediaIds, isEmpty);
        expect(numbersOnly.quote, isNull);
      });

      test('a client may attach at most six pictures', () {
        expect(
          () => _granted(mediaIds: const ['1', '2', '3', '4', '5', '6', '7']),
          throwsArgumentError,
        );
      });

      test('the coach may change one thing about a result: where it sits', () {
        final moved = _granted().reorderedByCoach(3);
        expect(moved.order, 3);
        expect(moved.quote, _granted().quote, reason: 'nothing else moved');
        expect(moved.consentState, ConsentState.granted);
      });
    },
  );

  group('P0-CONSENT-04 — the numbers are hers, and weight is not derivable', () {
    test('weight and weight-lost are not on the allowlist', () {
      for (final id in const [
        'weightKg',
        'weightLostKg',
        'bodyWeightKg',
        'startWeight',
        'bmi',
        'bodyFatPct',
        'waistCm',
        'dressSize',
      ]) {
        expect(
          DerivableMeasures.isDerivable(id),
          isFalse,
          reason: '$id must never reach a coach\'s page',
        );
        expect(DerivableMeasures.allowed.contains(id), isFalse, reason: id);
      }
    });

    test(
      'the allowlist and the pattern guard do not contradict each other',
      () {
        // Two halves, neither sufficient. If somebody adds a weight measure to
        // the list in a hurry, this is what catches it.
        expect(
          DerivableMeasures.allowedButGuarded,
          isEmpty,
          reason:
              'an allowlisted id that the guard would refuse is a '
              'contradiction somebody will eventually resolve the wrong way',
        );
      },
    );

    test('a lifted load is a personal best, not a weight from a scale', () {
      expect(DerivableMeasures.isDerivable('squatLoadKg'), isTrue);
      expect(DerivableMeasures.isDerivable('deadliftLoadKg'), isTrue);
      expect(DerivableMeasures.isDerivable('plankSec'), isTrue);
    });

    test('derivation drops what is not derivable', () {
      final numbers = ResultNumbers.derive(
        bests: const [
          ClientBest(measureId: 'plankSec', from: 20, to: 75, unit: 's'),
          ClientBest(measureId: 'weightKg', from: 82, to: 62, unit: 'kg'),
        ],
        scopeNumbers: true,
      );

      expect(numbers.keys, ['plankSec']);
      expect(numbers['plankSec']!.from, 20);
      expect(numbers['plankSec']!.to, 75);
    });

    test('the Function fails loudly rather than silently dropping', () {
      expect(
        () => ResultNumbers.derive(
          bests: const [ClientBest(measureId: 'weightLostKg', from: 0, to: 20)],
          scopeNumbers: true,
          strict: true,
        ),
        throwsA(isA<NumbersNotDerivableError>()),
      );
    });

    test('no figures at all when she did not grant numbers', () {
      expect(
        ResultNumbers.derive(
          bests: const [ClientBest(measureId: 'plankSec', from: 20, to: 75)],
          scopeNumbers: false,
        ),
        isEmpty,
      );
    });

    test('"12 weeks, 20 kg down" is not a thing that can be stored', () {
      final result = _granted().withDerivedNumbers(const [
        ClientBest(measureId: 'plankSec', from: 20, to: 75, unit: 's'),
      ]);
      final encoded = result.numbers.toString();
      expect(encoded.contains('weight'), isFalse);
      expect(result.numbers.containsKey('weightLostKg'), isFalse);
    });
  });

  group('the read-time predicate', () {
    final now = DateTime.utc(2026, 6, 1);

    test('only a current grant is publishable', () {
      expect(ResultVisibility.isPublishable(_granted(), now), isTrue);
      expect(
        ResultVisibility.isPublishable(
          ClientResult.fromRequest(_request()),
          now,
        ),
        isFalse,
      );
      expect(
        ResultVisibility.isPublishable(
          _granted().declinedByClient(at: now),
          now,
        ),
        isFalse,
      );
      expect(
        ResultVisibility.isPublishable(
          _granted().withdrawnByClient(at: now),
          now,
        ),
        isFalse,
      );
      expect(
        ResultVisibility.isPublishable(
          _granted().expiredByServer(at: now),
          now,
        ),
        isFalse,
      );
      expect(
        ResultVisibility.isPublishable(
          _granted().revokedByModeration(at: now),
          now,
        ),
        isFalse,
      );
      expect(
        ResultVisibility.isPublishable(
          _granted().orphanedByAccountDeletion(at: now),
          now,
        ),
        isFalse,
      );
    });

    test('a grant expires after twelve months and must be asked again', () {
      final granted = _granted(at: DateTime.utc(2026, 1, 1));

      expect(
        ResultVisibility.isPublishable(granted, DateTime.utc(2026, 12, 1)),
        isTrue,
        reason: 'eleven months in, still hers to have given',
      );
      expect(
        ResultVisibility.isPublishable(granted, DateTime.utc(2027, 1, 2)),
        isFalse,
        reason: 'a standing yes does not outlive the year she gave it in',
      );
      expect(granted.expiresAt, DateTime.utc(2027, 1, 1));
    });

    test('it fails closed when the provenance is unclear', () {
      // G13 §1.6 wrote the predicate as "expiresAt == null means no expiry".
      // Under the owner's 12-month rule that is the wrong default for a
      // document written before the rule existed, so a missing expiry falls
      // back to consentedAt + 12 months rather than to "forever".
      final ancient = _granted(at: DateTime.utc(2024, 1, 1));
      expect(
        ResultVisibility.isPublishable(ancient, DateTime.utc(2026, 6, 1)),
        isFalse,
      );
    });

    test('visible() filters and orders, and never mutates', () {
      final results = [
        _granted().reorderedByCoach(2),
        ClientResult.fromRequest(_request(id: 'r2', order: 1)),
      ];
      final visible = ResultVisibility.visible(results, now);

      expect(visible.length, 1);
      expect(visible.single.resultId, 'r1');
      expect(() => visible.add(results.first), throwsUnsupportedError);
    });

    test('resolveIds drops an id whose result is gone or not consented', () {
      final byId = <String, ClientResult>{
        'r1': _granted(),
        'r2': _granted().withdrawnByClient(at: now),
      };

      expect(ResultVisibility.resolveIds(const ['r1', 'r2', 'r3'], byId, now), [
        'r1',
      ]);
    });
  });

  group('P0-CONSENT-02 / 03 — withdrawal hides it everywhere', () {
    final now = DateTime.utc(2026, 6, 1);

    test('withdrawal drops the content in the same write', () {
      final withdrawn = _granted().withdrawnByClient(at: now);

      expect(withdrawn.consentState, ConsentState.withdrawn);
      expect(withdrawn.mediaIds, isEmpty);
      expect(withdrawn.quote, isNull);
      expect(withdrawn.numbers, isEmpty);
      expect(withdrawn.scope.isEmpty, isTrue);
      expect(withdrawn.withdrawnAt, now);
    });

    test('the published object never carries a consent field', () {
      final json = _granted().toPublishedJson(now);

      for (final forbidden in const [
        'consentState',
        'consentedAt',
        'withdrawnAt',
        'expiresAt',
        'scope',
        'clientUid',
      ]) {
        expect(
          json.containsKey(forbidden),
          isFalse,
          reason:
              '$forbidden in a published object would survive a '
              'withdrawal, which is the whole failure C10 exists to prevent',
        );
      }
      expect(json['resultId'], 'r1');
      expect(json['mediaIds'], ['m1']);
    });

    test(
      'serialising a withdrawn result is a programming error, not a filter',
      () {
        expect(
          () => _granted().withdrawnByClient(at: now).toPublishedJson(now),
          throwsStateError,
        );
      },
    );

    test('a granted state is terminal for nothing; the rest are terminal', () {
      expect(ConsentState.requested.isTerminal, isFalse);
      expect(ConsentState.granted.isTerminal, isFalse);
      for (final s in const [
        ConsentState.declined,
        ConsentState.withdrawn,
        ConsentState.expired,
        ConsentState.revoked,
        ConsentState.orphaned,
      ]) {
        expect(s.isTerminal, isTrue, reason: s.name);
      }
    });
  });

  group('P0-CONSENT-06 — a deleted account takes its consent with it', () {
    test('orphaned behaves exactly as withdrawn', () {
      final now = DateTime.utc(2026, 6, 1);
      final orphaned = _granted().orphanedByAccountDeletion(at: now);

      expect(orphaned.consentState, ConsentState.orphaned);
      expect(orphaned.mediaIds, isEmpty);
      expect(orphaned.quote, isNull);
      expect(orphaned.numbers, isEmpty);
      expect(ResultVisibility.isPublishable(orphaned, now), isFalse);
    });
  });

  group('P0-CONSENT-05 — offline withdrawal is described honestly', () {
    test('offline, it applies when she is back online', () {
      final offline = WithdrawalIntent(
        resultId: 'r1',
        requestedAt: DateTime.utc(2026, 6, 1),
        online: false,
      );
      expect(offline.timing, WithdrawalTiming.whenBackOnline);
    });

    test('online, it is immediate', () {
      final online = WithdrawalIntent(
        resultId: 'r1',
        requestedAt: DateTime.utc(2026, 6, 1),
        online: true,
      );
      expect(online.timing, WithdrawalTiming.immediate);
    });

    test('no screen may claim immediacy for a queued withdrawal', () {
      // The domain half of "the copy must not say immediately". The widget
      // half is in results_view_test.dart, which asserts the queued branch
      // renders the waiting-for-signal string and not an immediacy claim.
      final queued = WithdrawalIntent(
        resultId: 'r1',
        requestedAt: DateTime.utc(2026, 6, 1),
        online: false,
      ).confirm();

      expect(queued.timing, isNot(WithdrawalTiming.immediate));
    });

    test('withdrawal confirms — the documented exception to rule 9', () {
      final intent = WithdrawalIntent(
        resultId: 'r1',
        requestedAt: DateTime.utc(2026, 6, 1),
        online: true,
      );

      expect(
        intent.isActionable,
        isFalse,
        reason:
            'unconfirmed does nothing; §2 rule 9 exempts this one action '
            'because it is destructive and it is another woman\'s photograph',
      );
      expect(intent.confirm().isActionable, isTrue);
    });
  });

  group('the source itself carries no consent copy', () {
    test('no domain type outside consent.dart names consentState', () {
      // The grep P1-RULE-12 describes, as a test. A `consentState` field on a
      // portfolio, an ad or an analytics record would make withdrawal a lie,
      // and every other test in this suite would still pass.
      final offenders = <String>[];
      final dir = Directory('lib/features/coachbrand');

      for (final file in dir.listSync(recursive: true).whereType<File>()) {
        if (!file.path.endsWith('.dart')) continue;
        if (file.path.endsWith('consent.dart')) continue;
        if (file.path.endsWith('results_repository.dart')) continue;
        if (file.path.endsWith('published_portfolio_reader.dart')) continue;
        if (file.path.endsWith('portfolio_publisher.dart')) continue;

        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          final trimmed = line.trimLeft();
          if (trimmed.startsWith('//')) continue;
          if (line.contains('consentState') ||
              line.contains('consentedAt') ||
              line.contains('publishedWithConsent') ||
              line.contains('consentedResultIds')) {
            offenders.add('${file.path}:${i + 1} ${line.trim()}');
          }
        }
      }

      expect(offenders, isEmpty);
    });
  });
}
