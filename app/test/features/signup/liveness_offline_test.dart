// A6. A dropped connection as the liveness session starts is a retry on the
// same screen, never a trip to the reviewer queue. Only `unavailable`,
// `deadline-exceeded` and a timeout count as the network; anything the server
// actually said keeps its own meaning.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/features/signup/data/identity_check.dart';
import 'package:own_hub/features/signup/domain/capture_consent.dart';
import 'package:own_hub/features/signup/domain/liveness_challenge.dart';
import 'package:own_hub/features/signup/domain/review_request.dart';
import 'package:own_hub/features/signup/domain/verification_provider.dart';
import 'package:own_hub/domain/analytics/analytics_gateway.dart';
import 'package:own_hub/routing/app_router.dart';

import 'dart:io';

class _Throwing extends Fake implements VerificationProvider {
  _Throwing(this.error);

  final Object error;

  @override
  Future<LivenessChallenge> startSession() async => throw error;
}

Future<LivenessStart> _startWith(Object error) => IdentityCheck(
  consent: InMemoryCaptureConsentStore(),
  provider: _Throwing(error),
  reviews: const UnavailableReviewRequester(),
).startLiveness();

void main() {
  test('unavailable is offline, not a reviewer', () async {
    expect(
      await _startWith(const VerificationCallFailure('unavailable')),
      LivenessStart.offline,
    );
  });

  test('deadline-exceeded and a timeout are offline too', () async {
    expect(
      await _startWith(const VerificationCallFailure('deadline-exceeded')),
      LivenessStart.offline,
    );
    expect(await _startWith(TimeoutException('slow')), LivenessStart.offline);
  });

  test('a server error is still a failure, offered to a reviewer', () async {
    expect(
      await _startWith(const VerificationCallFailure('internal')),
      LivenessStart.failed,
    );
  });

  test('a limit the server set is still a limit', () async {
    expect(
      await _startWith(
        const VerificationCallFailure(
          'resource-exhausted',
          ServerReason.perUidDailyLimit,
        ),
      ),
      LivenessStart.tryTomorrow,
    );
  });

  test('other callers still read the network as "other"', () {
    expect(
      classifyCallFailure(const VerificationCallFailure('unavailable')),
      CallFailureKind.other,
    );
  });

  // R1-P13: every start is counted as one coarse word, so how often the
  // network rather than she stops the check is measured, not guessed.
  group('each start is counted, and never as a verdict', () {
    test('a closed vocabulary covers every outcome', () {
      final words = {
        for (final start in LivenessStart.values)
          start: AppRouter.livenessStartToken(start),
      };
      expect(words.values.toSet(), {
        'started',
        'offline',
        'failed',
        'limit',
        'other',
      });
      expect(words[LivenessStart.offline], 'offline');
      expect(words[LivenessStart.started], 'started');
      expect(words[LivenessStart.failed], 'failed');
      // A refused account or an open review is a verification state, and
      // verification results never reach analytics.
      expect(words[LivenessStart.closed], 'other');
      expect(words[LivenessStart.reviewOpen], 'other');
    });

    test('the event is on the allow-list and C10b sends it', () {
      expect(
        AnalyticsEvent.values,
        contains(AnalyticsEvent.livenessStartOutcome),
      );
      final router = File('lib/routing/app_router.dart').readAsStringSync();
      final c10b = router.substring(
        router.indexOf("'C10b': (context) =>"),
        router.indexOf("'C11': (context) =>"),
      );
      expect(c10b, contains('_trackLivenessStart(started)'));
    });

    test('the event reaches the sink with the outcome only', () async {
      final sent = <(String, Map<String, Object>)>[];
      final saved = AppRouter.analytics;
      AppRouter.analytics = AnalyticsGateway(_Sink(sent));
      addTearDown(() => AppRouter.analytics = saved);
      await AppRouter.analytics.track(AnalyticsEvent.livenessStartOutcome, {
        AnalyticsProp.outcome: AnalyticsValue.token(
          AppRouter.livenessStartToken(LivenessStart.offline),
        ),
      });
      expect(sent.single.$1, 'livenessStartOutcome');
      expect(sent.single.$2, {'outcome': 'offline'});
    });
  });
}

class _Sink implements AnalyticsSink {
  _Sink(this.sent);

  final List<(String, Map<String, Object>)> sent;

  @override
  Future<void> send(String event, Map<String, Object> properties) async =>
      sent.add((event, properties));
}
