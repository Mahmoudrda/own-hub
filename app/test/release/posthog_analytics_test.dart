import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:own_hub/app_state/posthog_analytics.dart';
import 'package:own_hub/app_state/analytics_consent.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeTransport implements PostHogTransport {
  final calls = <String>[];
  final events = <String>[];
  Completer<void>? setupBarrier;
  bool failCapture = false;
  @override
  Future<void> setup(PostHogConfig config) async {
    calls.add('setup');
    if (setupBarrier != null) await setupBarrier!.future;
  }

  @override
  Future<void> optIn() async {
    calls.add('in');
  }

  @override
  Future<void> optOut() async {
    calls.add('out');
  }

  @override
  Future<void> reset() async {
    calls.add('reset');
  }

  @override
  Future<void> readyLog() async {
    calls.add('log');
  }

  @override
  Future<void> capture(String event) async {
    if (failCapture) throw StateError('offline');
    events.add(event);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeTransport transport;
  late PostHogAnalytics analytics;
  setUp(() {
    transport = FakeTransport();
    analytics = PostHogAnalytics(transport: transport, enabled: true);
  });
  test('no SDK initialization or events before consent', () async {
    await analytics.applyConsent(false);
    await analytics.send('signUpCompleted', {});
    expect(transport.calls, isEmpty);
    expect(transport.events, isEmpty);
  });
  test('build kill switch suppresses initialization', () async {
    final off = PostHogAnalytics(transport: transport, enabled: false);
    await off.applyConsent(true);
    await off.send('signUpCompleted', {});
    expect(transport.calls, isEmpty);
  });
  test(
    'only allowlisted milestones and one structured log per process',
    () async {
      await analytics.applyConsent(true);
      await analytics.applyConsent(true);
      await analytics.send('signUpCompleted', {'email': 'must-not-leave'});
      await analytics.send('setLogged', {});
      await analytics.send('screenViewed', {});
      await analytics.send('arbitrary_event', {});
      expect(transport.events, ['sign_up']);
      expect(transport.calls.where((c) => c == 'log'), hasLength(1));
      expect(transport.calls.where((c) => c == 'setup'), hasLength(1));
    },
  );
  test(
    'withdrawal suppresses queued events and resets anonymous identity',
    () async {
      await analytics.applyConsent(true);
      final pending = analytics.send('loggedIn', {});
      final revoked = analytics.applyConsent(false);
      await Future.wait([pending, revoked]);
      expect(transport.events, isEmpty);
      expect(transport.calls.sublist(transport.calls.length - 2), [
        'out',
        'reset',
      ]);
    },
  );
  test('withdrawal during setup cannot opt the SDK back in', () async {
    transport.setupBarrier = Completer<void>();
    final grant = analytics.applyConsent(true);
    await Future<void>.delayed(Duration.zero);
    final revoke = analytics.applyConsent(false);
    transport.setupBarrier!.complete();
    await Future.wait([grant, revoke]);
    expect(transport.calls, ['setup', 'out', 'reset']);
  });
  test(
    'capture failures cannot break app operations or later events',
    () async {
      await analytics.applyConsent(true);
      transport.failCapture = true;
      await analytics.send('loggedIn', {});
      transport.failCapture = false;
      await analytics.send('signUpCompleted', {});
      expect(transport.events, ['sign_up']);
    },
  );
  test('at most 120 events per process, even after consent toggling', () async {
    await analytics.applyConsent(true);
    for (var i = 0; i < 150; i++) {
      await analytics.send('loggedIn', {});
    }
    await analytics.applyConsent(false);
    await analytics.applyConsent(true);
    await analytics.send('loggedIn', {});
    expect(transport.events, hasLength(120));
  });
  test('old Google-only consent is not consent for a new processor', () async {
    SharedPreferences.setMockInitialValues({'own_hub.analytics_allowed': true});
    await AnalyticsConsent.instance.load();
    expect(AnalyticsConsent.instance.allowed, isFalse);
  });
  test('configuration disables costly or automatic collection', () {
    final config = ownHubPostHogConfig();
    expect(config.host, 'https://us.i.posthog.com');
    expect(config.optOut, isTrue);
    expect(config.debug, isFalse);
    expect(config.sessionReplay, isFalse);
    expect(config.surveys, isFalse);
    expect(config.captureApplicationLifecycleEvents, isFalse);
    expect(config.capturePushNotificationOpened, isFalse);
    expect(config.capturePushNotificationSubscriptions, isFalse);
    expect(config.rageClickConfig.enabled, isFalse);
    expect(config.preloadFeatureFlags, isFalse);
    expect(config.sendFeatureFlagEvent, isFalse);
    expect(config.personProfiles, PostHogPersonProfiles.never);
    expect(config.errorTrackingConfig.captureFlutterErrors, isFalse);
    expect(config.errorTrackingConfig.captureNativeCrashes, isFalse);
    expect(config.logsConfig.rateCapMaxLogs, 1);
  });
  test('native platforms cannot initialize before Dart consent', () {
    for (final path in [
      'android/app/src/main/AndroidManifest.xml',
      'ios/Runner/Info.plist',
    ]) {
      final source = File(path).readAsStringSync();
      expect(source, contains('com.posthog.posthog.AUTO_INIT'));
      expect(source, matches(RegExp(r'AUTO_INIT[^\n]*false')));
    }
  });
}
