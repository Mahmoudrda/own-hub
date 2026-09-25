// The order of the verification flow, asserted where the order actually lives.
//
// `id_capture_view.dart` says it out loud: the capture screen "does not enforce
// that, because a screen cannot enforce its own unreachability; the router
// places the consent step ahead of it and `signup_consent_test.dart` asserts
// the order." This is that file.
//
// Four orderings, each of which is a real failure if it slips:
//
//  1. **Consent before any lens.** A camera on an Egyptian woman's face and her
//     national ID with no record that she agreed to it is the failure the
//     consent screen exists to prevent, and a deep link straight to
//     `/signup/c10` is the way round it.
//  2. **Both sides of the card.** `verify_identity` refuses a submission
//     carrying one side, so skipping `C10b` is a call nobody can answer.
//  3. **The liveness session is minted between the card and the selfie.** Not
//     before `C10`: it expires on a wall clock, and spending it while she is
//     finding the card in her bag times her out for our convenience.
//  4. **One evidence holder and one challenge.** The capture service fills what
//     the repository submits, or the server is handed an empty envelope and the
//     mistake surfaces three files away.
//
// These drive the real router rather than constructing widgets, because every
// one of them is a wiring fault that each screen's own test cannot see: all of
// these screens pass their own tests today.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/features/signup/data/camera_capture_service.dart';
import 'package:own_hub/features/signup/data/provider_verification_repository.dart';
import 'package:own_hub/features/signup/domain/capture_consent.dart';
import 'package:own_hub/features/signup/domain/id_capture.dart';
import 'package:own_hub/features/signup/domain/verification.dart';
import 'package:own_hub/features/signup/presentation/consent_view.dart';
import 'package:own_hub/features/signup/presentation/id_capture_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/ui/screen_scope.dart';

/// The app's own router, opened on [id] and nothing else.
Future<void> _open(WidgetTester tester, String id) async {
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

/// The id of the screen actually on top, which is not always the one asked for.
String? _showing(WidgetTester tester) {
  final scopes = tester.widgetList<ScreenScope>(find.byType(ScreenScope));
  return scopes.isEmpty ? null : scopes.last.screenId;
}

/// One builder's code out of the router, so an ordering can be read where it
/// is written. The idiom is `product_rules_test.dart`'s.
///
/// Comment lines are dropped, and that is not tidiness. A block runs to the
/// next entry in the map, so it carries the comment that introduces the
/// following builder — and these comments name the very calls being asserted
/// about. Without this, `C10`'s block "contains startLiveness" because
/// `C10b`'s comment explains why `C10` must not.
String _builderBlock(String id) {
  final src = File('lib/routing/app_router.dart').readAsStringSync();
  final from = src.indexOf("    '$id': (context)");
  expect(from, isNot(-1), reason: "no builder for $id — has the map moved?");
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

void main() {
  final saved = AppRouter.featureFlags;

  setUp(() {
    // The walkthrough shape: every screen reachable, no account required. The
    // gate is proved in `test/routing/verification_gate_test.dart`; this file
    // is about the order of the check itself, which holds either way.
    AppRouter.featureFlags = FeatureFlags.everything;
    // A fresh check, exactly as `C08` starts one.
    AppRouter.beginIdentityCheck();
  });

  tearDown(() {
    AppRouter.featureFlags = saved;
    AppRouter.beginIdentityCheck();
  });

  group('nothing opens a lens before she has agreed', () {
    testWidgets('"Scan my ID" goes to the consent screen, not to the camera', (
      tester,
    ) async {
      await _open(tester, 'C09');
      expect(find.text('Scan my ID'), findsOneWidget);

      await tester.tap(find.text('Scan my ID'));
      await tester.pumpAndSettle();

      expect(find.byType(ConsentView), findsOneWidget);
      expect(find.byType(IdCaptureView), findsNothing);
      expect(_showing(tester), 'C09b');
    });

    testWidgets('and a deep link straight to the camera lands there too', (
      tester,
    ) async {
      // The hole a screen cannot close for itself. `/signup/c10` typed into a
      // browser, sent as a notification payload or supplied by another app on
      // the handset is a camera opening on a woman who has agreed to nothing.
      expect(AppRouter.consentRecorded, isFalse);

      await _open(tester, 'C10');
      expect(find.byType(ConsentView), findsOneWidget);
      expect(find.byType(IdCaptureView), findsNothing);

      await _open(tester, 'C10b');
      expect(find.byType(ConsentView), findsOneWidget);

      await _open(tester, 'C11');
      expect(find.byType(ConsentView), findsOneWidget);
    });

    testWidgets('agreeing records the version, and only then opens the card', (
      tester,
    ) async {
      await _open(tester, 'C09b');
      final store = AppRouter.identityCheck.consent;
      expect(await store.current('me'), isNull);

      await tester.tap(find.text('I agree, start the camera'));
      await tester.pumpAndSettle();

      // The record exists, and it names the wording she was shown. "She
      // consented" is unanswerable a year later once the copy has changed.
      final recorded = await store.current('me');
      expect(recorded, isNotNull);
      expect(recorded!.version, kCaptureConsentVersion);

      expect(find.byType(IdCaptureView), findsOneWidget);
      expect(_showing(tester), 'C10');
    });

    testWidgets('declining is a real answer and it goes to a woman reviewer', (
      tester,
    ) async {
      await _open(tester, 'C09b');
      await tester.tap(find.text('I would rather not'));
      await tester.pumpAndSettle();

      expect(_showing(tester), 'C15');
      expect(find.byType(IdCaptureView), findsNothing);
    });
  });

  group('both sides of the card', () {
    setUp(() => AppRouter.consentRecorded = true);

    testWidgets('C10 asks for the front and C10b for the back', (tester) async {
      await _open(tester, 'C10');
      expect(
        tester.widget<IdCaptureView>(find.byType(IdCaptureView)).side,
        CaptureTarget.idFront,
      );
      expect(find.text('Your ID card'), findsOneWidget);

      await _open(tester, 'C10b');
      expect(
        tester.widget<IdCaptureView>(find.byType(IdCaptureView)).side,
        CaptureTarget.idBack,
      );
      // The back is where the sex is printed as a word, which is the
      // independent reading the 13th digit is cross-checked against.
      expect(find.text('The back of your card'), findsOneWidget);
    });

    test('and the front leads to the back rather than to the selfie', () {
      expect(_builderBlock('C10'), contains("goTo(context, 'C10b')"));
      expect(_builderBlock('C10'), isNot(contains("goTo(context, 'C11')")));
    });
  });

  group('the liveness session is minted where it is spent', () {
    test('C10b starts it, and nothing before C10b does', () {
      // Read from the source because the call is inside a callback that only a
      // real camera fires. The ordering is what matters and it is visible
      // here: a session started at `C09` or `C10` spends its expiry on the two
      // card steps, and she is timed out for our convenience.
      expect(_builderBlock('C10b'), contains('startLiveness()'));
      for (final id in const ['C09', 'C09b', 'C10']) {
        expect(
          _builderBlock(id),
          isNot(contains('startLiveness')),
          reason: '$id must not spend the session before the card is done',
        );
      }
    });

    test('and an unmintable session sends her to a reviewer, not to a lens', () {
      // `C11` with no challenge is a camera open for frames the server has no
      // question to match, which is two minutes of her time spent on nothing.
      expect(_builderBlock('C10b'), contains("goTo(context, 'C15')"));
    });

    testWidgets('the card steps run with no session at all', (tester) async {
      AppRouter.consentRecorded = true;
      await _open(tester, 'C10');
      final capture = AppRouter.identityCheck.capture;
      expect(
        (capture as CameraCaptureService).challenge,
        isNull,
        reason: 'the session must not exist yet while she photographs the card',
      );
    });
  });

  group('one evidence holder, one check', () {
    test('the capture service and the repository share it', () {
      // The mistake this is here to prevent: constructing the two separately
      // means `C10` fills one object and `C12` submits another, empty one, and
      // the failure arrives from a server as "the card is missing" three files
      // away from the line that caused it.
      final check = AppRouter.identityCheck;
      final capture = check.capture as CameraCaptureService;
      final repository = check.verification as ProviderVerificationRepository;

      expect(capture.evidence, same(check.evidence));
      expect(repository.evidence, same(check.evidence));
    });

    test('and a second sign-up gets a second one', () {
      // A retry must not submit the frames of the attempt before it against a
      // session that is already spent.
      final first = AppRouter.identityCheck;
      AppRouter.beginIdentityCheck();
      expect(AppRouter.identityCheck, isNot(same(first)));
      expect(AppRouter.identityCheck.evidence, isNot(same(first.evidence)));
    });

    test('the niqab path submits against the same check', () {
      // `C15` used to hold a repository of its own. It matters that it does
      // not: the outcome of the video-call path has to arrive on the same
      // stream `C12` and `C14` are listening to.
      expect(
        _builderBlock('C15'),
        contains('identityCheck.verification'),
      );
    });
  });

  group('C12 actually starts the check', () {
    setUp(() => AppRouter.consentRecorded = true);

    testWidgets('opening it submits the automatic path', (tester) async {
      final repository =
          AppRouter.identityCheck.verification as ProviderVerificationRepository;
      expect(repository.current, isA<VerificationNotStarted>());

      await _open(tester, 'C12');

      // Nothing called submit for the automatic path before this wiring: `C15`
      // submitted the niqab path and `C12` listened to a repository that had
      // never been asked a question, so every woman who photographed her card
      // sat on the ring for ever.
      expect(
        repository.current,
        isNot(isA<VerificationNotStarted>()),
        reason: 'C12 must start the check it is rendering',
      );
    });

    testWidgets('and with no liveness session she is sent back to the card, '
        'not left on the ring', (tester) async {
      // The `RETRY_CAPTURE` / `RETRY_REQUIRED` destination, reached here by the
      // other route into `VerificationState.retakeNeeded`: a submit with no
      // session behind it. Her move, not a reviewer's.
      await _open(tester, 'C12');
      await tester.pumpAndSettle();

      expect(_showing(tester), 'C10');
      expect(find.byType(IdCaptureView), findsOneWidget);
    });

    test('a retake lifts the submit guard, or the second attempt never runs', () {
      expect(_builderBlock('C12'), contains('_automaticSubmitted = false'));
      expect(_builderBlock('C12'), contains("goTo(context, 'C10')"));
    });
  });
}
