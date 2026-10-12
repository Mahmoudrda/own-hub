/// Low-volume, consent-gated PostHog delivery. No identity or user properties.
library;

import 'package:flutter/foundation.dart';
import 'package:posthog_flutter/posthog_flutter.dart';

import '../domain/analytics/analytics_gateway.dart';

const _projectToken = 'phc_sXVNqUc79AdEbtTLUSwxFHgnsKnKSEvPvUHy5uctgRTE';
const _debugSend = bool.fromEnvironment('OWNHUB_ANALYTICS_DEBUG');
const _enabled = bool.fromEnvironment(
  'OWNHUB_POSTHOG_ENABLED',
  defaultValue: true,
);

/// These are product milestones, never screen names, health values or text.
const posthogMilestones = <String, String>{
  'tourStarted': 'tutorial_begin',
  'tourCompleted': 'tutorial_complete',
  'signUpStarted': 'sign_up_begin',
  'signUpCompleted': 'sign_up',
  'loggedIn': 'login',
  'sessionStarted': 'workout_start',
  'sessionFinished': 'workout_complete',
  'coachEnquirySent': 'coach_enquiry_send',
};

PostHogConfig ownHubPostHogConfig() {
  final config = PostHogConfig(_projectToken)
    ..host = 'https://us.i.posthog.com'
    ..debug = false
    ..optOut = true
    ..captureApplicationLifecycleEvents = false
    ..capturePushNotificationSubscriptions = false
    ..capturePushNotificationOpened = false
    ..sessionReplay = false
    ..surveys = false
    ..preloadFeatureFlags = false
    ..sendFeatureFlagEvent = false
    ..personProfiles = PostHogPersonProfiles.never
    ..maxQueueSize = 100
    ..flushAt = 20
    ..flushInterval = const Duration(seconds: 60);
  config.rageClickConfig.enabled = false;
  config.logsConfig
    ..serviceName = 'own-hub-mobile'
    ..maxBufferSize = 10
    ..rateCapMaxLogs = 1
    ..rateCapWindow = const Duration(minutes: 1);
  return config;
}

/// Injectable boundary keeps tests offline while exercising actual consent logic.
abstract interface class PostHogTransport {
  Future<void> setup(PostHogConfig config);
  Future<void> optIn();
  Future<void> optOut();
  Future<void> reset();
  Future<void> capture(String event);
  Future<void> readyLog();
}

class _SdkTransport implements PostHogTransport {
  @override
  Future<void> setup(PostHogConfig config) => Posthog().setup(config);
  @override
  Future<void> optIn() => Posthog().optIn();
  @override
  Future<void> optOut() => Posthog().optOut();
  @override
  Future<void> reset() => Posthog().reset();
  @override
  Future<void> capture(String event) => Posthog().capture(
    eventName: event,
    properties: const {r'$geoip_disable': true},
  );
  @override
  Future<void> readyLog() => Posthog().logger.info('analytics_ready', const {
    'integration': 'flutter',
    'schema_version': 1,
  });
}

class PostHogAnalytics implements AnalyticsSink {
  PostHogAnalytics({required this.transport, required this.enabled});

  static final instance = PostHogAnalytics(
    transport: _SdkTransport(),
    enabled:
        _enabled &&
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS) &&
        (kReleaseMode || _debugSend),
  );

  final PostHogTransport transport;
  final bool enabled;
  bool _allowed = false;
  bool _ready = false;
  bool _loggedReady = false;
  int _generation = 0;
  int _sent = 0;
  Future<void> _tail = Future.value();

  // Serialize SDK transitions; failures never break app actions or later jobs.
  Future<void> _queue(Future<void> Function() action) {
    return _tail = _tail.then((_) => action()).catchError((Object _) {});
  }

  Future<void> applyConsent(bool allowed) {
    _allowed = allowed;
    final generation = ++_generation;
    return _queue(() async {
      if (!enabled) return;
      if (!allowed) {
        if (_ready) {
          await transport.optOut();
          await transport.reset();
        }
        return;
      }
      if (!_allowed || generation != _generation) return;
      if (!_ready) {
        await transport.setup(ownHubPostHogConfig());
        _ready = true;
      }
      if (!_allowed || generation != _generation) return;
      await transport.optIn();
      if (!_allowed || generation != _generation) return;
      if (!_loggedReady) {
        _loggedReady = true;
        await transport.readyLog();
      }
    });
  }

  @override
  Future<void> send(String event, Map<String, Object> properties) {
    final wireName = posthogMilestones[event];
    if (!enabled || !_allowed || wireName == null) return Future.value();
    final generation = _generation;
    return _queue(() async {
      if (!_allowed || !_ready || generation != _generation || _sent >= 120) {
        return;
      }
      _sent++;
      // Deliberately drop all caller properties, including valid gateway ones.
      await transport.capture(wireName);
    });
  }
}
