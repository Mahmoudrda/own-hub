// Every usage-statistics event fires where the thing it counts happens, with
// the parameters its vocabulary allows and nothing else.
//
// Driven through the real router where a test can reach the moment (the
// tour, the consent step, the camera, a reviewer path, the screens). Where
// the moment needs a provider this binary cannot reach (a code sent, a code
// accepted, a verdict, a finished workout), the builder that owns it is read
// from the source, the idiom of `signup_consent_test.dart`, and the decision
// it hands to is tested as a function.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/analytics/analytics_gateway.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/features/signup/domain/id_capture.dart';
import 'package:own_hub/features/signup/domain/review_request.dart';
import 'package:own_hub/features/signup/presentation/id_capture_view.dart';
import 'package:own_hub/features/signup/presentation/selfie_capture_view.dart';
import 'package:own_hub/features/today/domain/today_day.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/routing/app_router.dart';

class _Recording implements AnalyticsSink {
  final List<(String, Map<String, Object>)> sent = [];

  List<String> get names => [for (final (e, _) in sent) e];

  Map<String, Object> last(String event) =>
      sent.lastWhere((s) => s.$1 == event).$2;

  @override
  Future<void> send(String event, Map<String, Object> properties) async =>
      sent.add((event, Map.of(properties)));
}

Future<void> _open(WidgetTester tester, String id) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      key: ValueKey(id),
      onGenerateRoute: AppRouter.onGenerateRoute,
      onUnknownRoute: AppRouter.onUnknownRoute,
      initialRoute: appDestinations[id]!.name,
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
    ),
  );
  await tester.pumpAndSettle();
}

/// One builder's code, comments dropped (see `signup_consent_test.dart`).
String _builderBlock(String id) {
  final src = File('lib/routing/app_router.dart').readAsStringSync();
  final from = src.indexOf("    '$id': (context)");
  expect(from, isNot(-1), reason: 'no builder for $id');
  final next = src.indexOf(
    RegExp("\\n    '[A-Z]\\d{2}[a-z]?': \\(context\\)"),
    from + 1,
  );
  return src
      .substring(from, next < 0 ? src.length : next)
      .split('\n')
      .where((line) => !line.trimLeft().startsWith('//'))
      .join('\n');
}

/// Every property of every event sent is in its vocabulary.
void _allAllowed(_Recording recording) {
  for (final (event, props) in recording.sent) {
    for (final key in props.keys) {
      final prop = AnalyticsProp.values.byName(key);
      final value = props[key]!;
      expect(
        AnalyticsVocabulary.allows(
          prop,
          value is bool
              ? AnalyticsValue.flag(value)
              : AnalyticsValue.token('$value'),
        ),
        isTrue,
        reason: '$event $key=$value',
      );
    }
  }
}

void main() {
  final savedFlags = AppRouter.featureFlags;
  final savedAnalytics = AppRouter.analytics;
  late _Recording recording;

  setUp(() {
    AppRouter.featureFlags = FeatureFlags.everything;
    AppRouter.beginIdentityCheck();
    recording = _Recording();
    AppRouter.analytics = AnalyticsGateway(recording);
  });

  tearDown(() {
    _allAllowed(recording);
    AppRouter.featureFlags = savedFlags;
    AppRouter.analytics = savedAnalytics;
    AppRouter.beginIdentityCheck();
  });

  group('the tour', () {
    testWidgets('opening it is tutorial_begin, after its screen view', (
      tester,
    ) async {
      await _open(tester, 'C04');
      expect(recording.names.take(3), [
        'screenViewed',
        'tourStarted',
        'tourStopViewed',
      ]);
      expect(recording.sent.first.$2['screenId'], 'C04');
      expect(recording.last('tourStarted'), isEmpty);
    });

    testWidgets('the end card is tutorial_complete', (tester) async {
      await _open(tester, 'C04');
      for (var i = 0; i < 7; i++) {
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
      }
      expect(recording.names.last, 'tourCompleted');
      expect(recording.last('tourStopViewed'), {'tourStop': 'end'});
      expect(recording.names.where((n) => n == 'tourCompleted'), hasLength(1));
    });

    testWidgets('leaving says on which stop, and nothing else', (tester) async {
      await _open(tester, 'C01');
      await tester.tap(find.text('Show me around'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Leave the tour'));
      await tester.pumpAndSettle();
      expect(recording.last('tourLeft'), {'tourStop': '2'});
    });

    testWidgets('joining from the tour starts sign-up from the tour', (
      tester,
    ) async {
      await _open(tester, 'C04');
      for (var i = 0; i < 7; i++) {
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('Make it mine'));
      await tester.pumpAndSettle();
      expect(recording.last('signUpStarted'), {'source': 'tour'});
    });
  });

  testWidgets('skipping the tour starts sign-up from the welcome screen', (
    tester,
  ) async {
    await _open(tester, 'C01');
    await tester.tap(find.text('Skip the tour and join'));
    await tester.pumpAndSettle();
    expect(recording.last('signUpStarted'), {'source': 'welcome'});
  });

  group('sign-up steps a provider answers', () {
    test('C06 counts a code sent only once it was sent', () {
      final block = _builderBlock('C06');
      final sent = block.indexOf('onCodeSent: () {');
      expect(sent, greaterThan(-1));
      expect(block.indexOf('AnalyticsEvent.signUpCodeSent'), greaterThan(sent));
      // Her usage-statistics choice is its own switch on this screen.
      expect(
        block,
        contains('onAnalyticsChosen: AnalyticsConsent.instance.set'),
      );
    });

    test(
      'C07 counts sign_up or login, by the phone, after the claim is read',
      () {
        final block = _builderBlock('C07');
        final claim = block.indexOf('await readVerificationClaim();');
        final track = block.indexOf('AnalyticsEvent.loggedIn');
        expect(claim, greaterThan(-1));
        expect(track, greaterThan(claim));
        expect(block, contains('AnalyticsEvent.signUpCompleted'));
        expect(block, contains("AnalyticsValue.token('phone')"));
      },
    );

    test("C12 counts what the check came to and You're in", () {
      final block = _builderBlock('C12');
      expect(block, contains("_trackDecided('verified')"));
      expect(block, contains("_trackYoureIn('automatic')"));
      for (final outcome in ['reviewer', 'retake', 'rejected']) {
        expect(block, contains("_trackDecided('$outcome')"));
      }
      expect(_builderBlock('C14'), contains("_trackYoureIn('reviewer')"));
      expect(_builderBlock('C15'), contains("_trackYoureIn('reviewer')"));
    });
  });

  group('the ID check', () {
    testWidgets('agreeing on C09b is id_check_consent, after the record', (
      tester,
    ) async {
      await _open(tester, 'C09b');
      expect(recording.names, isNot(contains('checkConsentGiven')));
      await tester.tap(find.text('I agree, start the camera'));
      await tester.pumpAndSettle();
      expect(recording.names, contains('checkConsentGiven'));
      expect(recording.last('checkConsentGiven'), isEmpty);
    });

    testWidgets('declining is a reviewer chosen, never which reason', (
      tester,
    ) async {
      await _open(tester, 'C09b');
      await tester.tap(find.text('I would rather not'));
      await tester.pumpAndSettle();
      expect(recording.last('reviewerPathChosen'), {'outcome': 'chosen'});
    });

    test('the niqab path is counted exactly like declining', () {
      expect(AppRouter.reviewerPathToken(ReviewPath.niqab), 'chosen');
      expect(AppRouter.reviewerPathToken(ReviewPath.declined), 'chosen');
      expect(AppRouter.reviewerPathToken(ReviewPath.error), 'unavailable');
      // And no word for it exists in any vocabulary.
      for (final prop in AnalyticsProp.values) {
        expect(
          AnalyticsVocabulary.allows(prop, const AnalyticsValue.token('niqab')),
          isFalse,
        );
      }
    });

    testWidgets('a camera that cannot run is counted once, with its cause', (
      tester,
    ) async {
      final reasons = <CaptureUnavailableReason>[];
      for (final view in [
        IdCaptureView(
          captureService: const UnavailableCaptureService(
            reason: CaptureUnavailableReason.permissionDenied,
          ),
          onUnavailable: reasons.add,
        ),
        SelfieCaptureView(
          captureService: const UnavailableCaptureService(
            reason: CaptureUnavailableReason.noCamera,
          ),
          onUnavailable: reasons.add,
        ),
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppL10n.localizationsDelegates,
            supportedLocales: AppL10n.supportedLocales,
            home: view,
          ),
        );
        await tester.pumpAndSettle();
      }
      expect(reasons, [
        CaptureUnavailableReason.permissionDenied,
        CaptureUnavailableReason.noCamera,
      ]);
      // And the router hands every capture screen the counter.
      for (final id in ['C10', 'C10b', 'C11']) {
        expect(
          _builderBlock(id),
          contains('onUnavailable: _trackCameraUnavailable'),
          reason: id,
        );
      }
    });

    test('every camera cause has a word in the vocabulary', () {
      for (final reason in CaptureUnavailableReason.values) {
        expect(
          AnalyticsVocabulary.allows(
            AnalyticsProp.reason,
            AnalyticsValue.token(AppRouter.cameraReasonToken(reason)),
          ),
          isTrue,
          reason: reason.name,
        );
      }
    });
  });

  group('screens', () {
    test('the tabs and her account are counted; cycle, body and allergies '
        'never', () {
      for (final id in [
        'T01',
        'R01',
        'R03',
        'E01',
        'E07',
        'P01',
        'A02',
        'A03',
      ]) {
        expect(AppRouter.reportsScreenView(id), isTrue, reason: id);
      }
      for (final id in ['P04', 'E10']) {
        expect(AppRouter.reportsScreenView(id), isFalse, reason: id);
      }
      for (final entry in appDestinations.entries) {
        if (entry.value.flow == 'cycle') {
          expect(
            AppRouter.reportsScreenView(entry.key),
            isFalse,
            reason: entry.key,
          );
        }
      }
    });

    testWidgets('a reported screen sends its id and flow, and nothing else', (
      tester,
    ) async {
      await _open(tester, 'C01');
      expect(recording.sent.first.$1, 'screenViewed');
      expect(recording.sent.first.$2, {'screenId': 'C01', 'flow': 'signup'});
    });
  });

  group('activation', () {
    test('a finished workout, and the week target once', () {
      const before = WeekProgress(sessionsLogged: 2, sessionsTarget: 3);
      const reached = WeekProgress(sessionsLogged: 3, sessionsTarget: 3);
      const past = WeekProgress(sessionsLogged: 4, sessionsTarget: 3);
      expect(AppRouter.weekTargetReached(before, reached), isTrue);
      expect(AppRouter.weekTargetReached(reached, past), isFalse);
      expect(
        AppRouter.weekTargetReached(
          const WeekProgress(sessionsLogged: 0, sessionsTarget: 0),
          const WeekProgress(sessionsLogged: 1, sessionsTarget: 0),
        ),
        isFalse,
      );
      final src = File('lib/routing/app_router.dart').readAsStringSync();
      final finish = src.substring(
        src.indexOf('static void _finishWorkout()'),
        src.indexOf('static bool weekTargetReached'),
      );
      expect(finish, contains('.then((_) => _trackWorkoutFinished('));
      expect(finish, contains('AnalyticsEvent.sessionFinished'));
      expect(finish, contains('AnalyticsEvent.weekCounted'));
    });
  });
}
