// N4: a rejected sign-in (UNAUTHENTICATED: a disabled, deleted or revoked
// account) and an account that did not sign in with a phone
// (PERMISSION_DENIED `phone_sign_in_required`) send her to sign in again with
// her phone number, on every screen that makes a call. Never "update the
// app", never "check your connection", never a review.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:own_hub/features/account/domain/account_deletion_service.dart';
import 'package:own_hub/features/account/domain/health_backup.dart';
import 'package:own_hub/features/account/domain/privacy_settings.dart';
import 'package:own_hub/features/account/presentation/privacy_view.dart';
import 'package:own_hub/features/account/presentation/your_data_sheet.dart';
import 'package:own_hub/features/signup/data/identity_check.dart';
import 'package:own_hub/features/signup/data/provider_verification_repository.dart';
import 'package:own_hub/features/signup/domain/capture_consent.dart';
import 'package:own_hub/features/signup/domain/id_capture.dart';
import 'package:own_hub/features/signup/domain/review_request.dart';
import 'package:own_hub/features/signup/domain/server_verification.dart';
import 'package:own_hub/features/signup/domain/verification.dart';
import 'package:own_hub/features/signup/domain/verification_evidence.dart';
import 'package:own_hub/features/signup/domain/verification_fake.dart';
import 'package:own_hub/features/signup/domain/liveness_challenge.dart';
import 'package:own_hub/features/signup/domain/verification_provider.dart';
import 'package:own_hub/features/signup/presentation/being_checked_view.dart';
import 'package:own_hub/features/signup/presentation/checking_view.dart';
import 'package:own_hub/features/signup/presentation/consent_view.dart';
import 'package:own_hub/features/signup/presentation/woman_reviewer_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';

const _rejected = VerificationCallFailure('unauthenticated');
const _notPhone = VerificationCallFailure(
  'permission-denied',
  ServerReason.phoneSignInRequired,
);

Widget _host(Widget child) => MaterialApp(
  localizationsDelegates: AppL10n.localizationsDelegates,
  supportedLocales: AppL10n.supportedLocales,
  home: child,
);

void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 4000);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

class _Requester implements ReviewRequester {
  _Requester(this.fail);
  final Object fail;

  @override
  Future<ReviewRequestState> request(ReviewPath path) async => throw fail;
}

class _ConsentStore implements CaptureConsentStore {
  _ConsentStore(this.fail);
  final Object fail;

  @override
  Future<void> record(CaptureConsent consent) async => throw fail;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _HealthStore implements HealthConsentStore {
  _HealthStore(this.fail);
  final Object fail;

  @override
  Future<void> record({required bool granted}) async => throw fail;

  @override
  Future<HealthConsentState?> current(String uid) async => null;
}

void main() {
  test('both refusals classify as sign in again', () {
    expect(classifyCallFailure(_rejected), CallFailureKind.signInAgain);
    expect(classifyCallFailure(_notPhone), CallFailureKind.signInAgain);
  });

  for (final (name, failure) in [
    ('rejected', _rejected),
    ('not a phone', _notPhone),
  ]) {
    group(name, () {
      testWidgets('C12 says sign in again and offers it', (tester) async {
        var signIn = 0;
        await tester.pumpWidget(
          _host(
            CheckingView(
              repository: FakeVerificationRepository(
                const VerificationState.signInAgain(),
              ),
              onSignInAgain: () => signIn++,
            ),
          ),
        );
        await tester.pumpAndSettle();
        final l10n = AppL10n.of(tester.element(find.byType(CheckingView)));
        expect(find.text(l10n.pleaseSignInAgain), findsOneWidget);
        expect(find.text(l10n.yourSignInIsNoLongerValid), findsOneWidget);
        await tester.tap(find.text(l10n.signInAgain));
        expect(signIn, 1);
      });

      testWidgets('C09b says sign in again, not update the app', (
        tester,
      ) async {
        _tall(tester);
        var signIn = 0;
        await tester.pumpWidget(
          _host(
            ConsentView(
              uid: 'u1',
              store: _ConsentStore(failure),
              onSignInAgain: () => signIn++,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('I agree, start the camera'));
        await tester.pumpAndSettle();
        final l10n = AppL10n.of(tester.element(find.byType(ConsentView)));
        expect(find.text(l10n.yourSignInIsNoLongerValid_1cfl5), findsOneWidget);
        expect(find.text(l10n.thisCopyOfTheAppCannotReach_1dlg6), findsNothing);
        await tester.tap(find.text(l10n.signInAgain));
        expect(signIn, 1);
      });

      testWidgets('C15 says sign in again', (tester) async {
        _tall(tester);
        var signIn = 0;
        await tester.pumpWidget(
          _host(
            WomanReviewerView(
              requester: _Requester(failure),
              onSignInAgain: () => signIn++,
            ),
          ),
        );
        await tester.pumpAndSettle();
        final l10n = AppL10n.of(tester.element(find.byType(WomanReviewerView)));
        await tester.tap(find.text(l10n.askAWomanToCheckMe));
        await tester.pumpAndSettle();
        expect(find.text(l10n.yourSignInIsNoLongerValid_1y16r), findsOneWidget);
        expect(find.text(l10n.thisCopyOfTheAppCannotReach_agbhf), findsNothing);
        await tester.tap(find.text(l10n.signInAgain));
        expect(signIn, 1);
      });

      testWidgets('C14 "Ask a woman to contact me" says sign in again', (tester) async {
        _tall(tester);
        var signIn = 0;
        await tester.pumpWidget(
          _host(
            BeingCheckedView(
              status: const ServerVerification(ServerVerificationState.pending),
              reviewAsked: false,
              requester: _Requester(failure),
              onSignInAgain: () => signIn++,
            ),
          ),
        );
        await tester.pump();
        final l10n = AppL10n.of(tester.element(find.byType(BeingCheckedView)));
        await tester.tap(find.byKey(const ValueKey('c14-ask-for-the-call')));
        await tester.pumpAndSettle();
        expect(find.text(l10n.yourSignInIsNoLongerValid_1y16r), findsOneWidget);
        await tester.tap(find.text(l10n.signInAgain));
        expect(signIn, 1);
      });

      testWidgets('A03 health backup says sign in again', (tester) async {
        _tall(tester);
        SharedPreferences.setMockInitialValues(const <String, Object>{});
        final pref = HealthBackupPreference.instance..resetForTest();
        addTearDown(pref.resetForTest);
        var signIn = 0;
        await tester.pumpWidget(
          _host(
            PrivacyView(
              service: PrivacySettingsService(InMemoryPrivacyRepository()),
              healthBackup: HealthBackupController(
                store: _HealthStore(failure),
              ),
              onSignInAgain: () => signIn++,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const ValueKey('health-backup-toggle')),
        );
        await tester.tap(find.byKey(const ValueKey('health-backup-toggle')));
        await tester.pumpAndSettle();
        final l10n = AppL10n.of(tester.element(find.byType(PrivacyView)));
        // The opt-in sheet is agreed to first.
        await tester.tap(find.text(l10n.iAgreeBackUpMyHealthData));
        await tester.pumpAndSettle();
        expect(find.text(l10n.yourSignInIsNoLongerValid_1ccq0), findsOneWidget);
        await tester.tap(find.text(l10n.signInAgain));
        expect(signIn, 1);
      });
    });
  }

  testWidgets('the deletion sheet says sign in again, and names the web page', (
    tester,
  ) async {
    _tall(tester);
    await tester.pumpWidget(
      _host(
        Scaffold(
          body: SingleChildScrollView(
            child: YourDataSheet(
              hasAccount: true,
              webDeletionUrl: 'https://example.test/delete-account',
              onDelete: () async => AccountDeletionResult.signInAgain,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Delete everything'));
    await tester.pumpAndSettle();
    final l10n = AppL10n.of(tester.element(find.byType(YourDataSheet)));
    expect(find.text(l10n.yourSignInIsNoLongerValid_1g4zq), findsOneWidget);
    expect(find.text(l10n.weCouldNotReachOwnHubSo_yfi5n), findsNothing);
    expect(
      find.byKey(const ValueKey('your-data-web-deletion')),
      findsOneWidget,
    );
  });

  test('a refused liveness start is sign in again, not a review', () async {
    final check = IdentityCheck(
      consent: InMemoryCaptureConsentStore(),
      provider: _RefusingProvider(),
      reviews: const UnavailableReviewRequester(),
    );
    expect(await check.startLiveness(), LivenessStart.signInAgain);
  });

  test('a refused submit lands on sign in again, not a review offer', () async {
    final repository = ProviderVerificationRepository(
      provider: _RefusingProvider(),
      evidence: VerificationEvidence()
        ..holdCardSide(CaptureTarget.idFront, Uint8List.fromList([1]))
        ..holdCardSide(CaptureTarget.idBack, Uint8List.fromList([2]))
        ..addFrame(Uint8List.fromList([3])),
      refreshClaims: () async {},
      challenge: LivenessChallenge(
        sessionId: 's-1',
        steps: const [LivenessStep.faceCentre],
        expiresAt: DateTime.now().add(const Duration(minutes: 2)),
      ),
    );
    await repository.submit(method: VerificationMethod.automatic);
    for (var i = 0; i < 12; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(repository.current, isA<VerificationSignInAgain>());
  });
}

class _RefusingProvider extends Fake implements VerificationProvider {
  @override
  Future<LivenessChallenge> startSession() async => throw _rejected;

  @override
  Future<VerificationDecision> submit(
    VerificationEvidence evidence,
    String sessionId, {
    String? operationId,
    String? installId,
  }) async => throw _rejected;
}
