// R3, client: `unauthenticated` from a callable while she is signed in is App
// Check refusing this copy of the app, not "offline", not "sign in again" and
// not a reason to queue her for review.
//
// With `ENFORCE_APP_CHECK` the callable framework rejects a missing or invalid
// App Check token as UNAUTHENTICATED before the function's own check can say
// `app_check_missing`. Every callable the app makes is driven here through a
// fake `FirebaseFunctions` that answers exactly that.

import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/app_state/account_data.dart';
import 'package:own_hub/features/account/data/callable_deletion_transport.dart';
import 'package:own_hub/features/account/data/callable_health_consent_store.dart';
import 'package:own_hub/features/account/domain/account_deletion_service.dart';
import 'package:own_hub/features/account/domain/health_backup.dart';
import 'package:own_hub/features/account/presentation/your_data_sheet.dart';
import 'package:own_hub/features/signup/data/callable_capture_consent_store.dart';
import 'package:own_hub/features/signup/data/callable_review_request.dart';
import 'package:own_hub/features/signup/data/callable_verification_provider.dart';
import 'package:own_hub/features/signup/domain/capture_consent.dart';
import 'package:own_hub/features/signup/domain/id_capture.dart';
import 'package:own_hub/features/signup/domain/review_request.dart';
import 'package:own_hub/features/signup/domain/verification_evidence.dart';
import 'package:own_hub/features/signup/presentation/consent_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';

FirebaseFunctionsException get _refused =>
    FirebaseFunctionsException(code: 'unauthenticated', message: 'x');

class _RefusingCallable extends Fake implements HttpsCallable {
  @override
  Future<HttpsCallableResult<T>> call<T>([dynamic parameters]) async =>
      throw _refused;
}

class _RefusingFunctions extends Fake implements FirebaseFunctions {
  @override
  HttpsCallable httpsCallable(String name, {HttpsCallableOptions? options}) =>
      _RefusingCallable();
}

class _NoFirestore extends Fake implements FirebaseFirestore {}

Matcher get _appCannotReach => isA<VerificationCallFailure>().having(
  classifyCallFailure,
  'kind',
  CallFailureKind.appCannotReach,
);

Matcher get _notAppCannotReach => isA<VerificationCallFailure>().having(
  classifyCallFailure,
  'kind',
  isNot(CallFailureKind.appCannotReach),
);

void main() {
  final functions = _RefusingFunctions();

  test('the mapping: signed in means App Check, signed out does not', () {
    expect(
      callFailureOf('unauthenticated', 'x', signedIn: true),
      _appCannotReach,
    );
    expect(
      callFailureOf('unauthenticated', 'x', signedIn: false),
      _notAppCannotReach,
    );
    expect(
      callFailureOf('unavailable', null, signedIn: true),
      _notAppCannotReach,
    );
  });

  test('record_consent', () async {
    final signedIn = CallableCaptureConsentStore(
      firestore: _NoFirestore(),
      functions: functions,
      signedIn: () => true,
    );
    final consent = CaptureConsent(
      uid: 'u1',
      version: kCaptureConsentVersion,
      agreedAt: DateTime.utc(2026, 10, 2),
    );
    await expectLater(signedIn.record(consent), throwsA(_appCannotReach));
    final signedOut = CallableCaptureConsentStore(
      firestore: _NoFirestore(),
      functions: functions,
      signedIn: () => false,
    );
    await expectLater(signedOut.record(consent), throwsA(_notAppCannotReach));
  });

  test('record_health_consent, and A03 can tell', () async {
    final store = CallableHealthConsentStore(
      firestore: _NoFirestore(),
      functions: functions,
      signedIn: () => true,
    );
    await expectLater(store.record(granted: true), throwsA(_appCannotReach));

    HealthBackupPreference.instance.resetForTest();
    final controller = HealthBackupController(store: store);
    expect(await controller.enable(), isFalse);
    expect(
      classifyCallFailure(controller.lastFailure!),
      CallFailureKind.appCannotReach,
    );
  });

  test('start_verification and verify_identity', () async {
    final provider = CallableVerificationProvider(
      functions: functions,
      signedIn: () => true,
    );
    await expectLater(provider.startSession(), throwsA(_appCannotReach));

    final evidence = VerificationEvidence()
      ..holdCardSide(CaptureTarget.idFront, Uint8List.fromList([1]))
      ..holdCardSide(CaptureTarget.idBack, Uint8List.fromList([2]));
    await expectLater(
      provider.submit(evidence, 's1', operationId: 'op'),
      throwsA(_appCannotReach),
    );
  });

  test('request_review', () async {
    final requester = CallableReviewRequester(
      functions: functions,
      signedIn: () => true,
    );
    await expectLater(
      requester.request(ReviewPath.error),
      throwsA(_appCannotReach),
    );
  });

  group('delete_account', () {
    test('signed in: this copy of the app, not "could not reach"', () async {
      final transport = CallableDeletionTransport(
        isOnline: () => true,
        call: () async => throw _refused,
        signedIn: () => true,
      );
      await expectLater(
        transport.requestDeletion(),
        throwsA(isA<DeletionAppCannotReach>()),
      );
      expect(
        await deleteAccount(
          transport: CallableDeletionTransport(
            isOnline: () => true,
            call: () async => throw _refused,
            signedIn: () => true,
          ),
          wipe: RecordingLocalWipe(),
          quiesce: () async {},
        ),
        AccountDeletionResult.appCannotReach,
      );
    });

    test('signed out it stays a refusal with nothing deleted', () async {
      final transport = CallableDeletionTransport(
        isOnline: () => true,
        call: () async => throw _refused,
        signedIn: () => false,
      );
      await expectLater(
        transport.requestDeletion(),
        throwsA(isA<DeletionOffline>()),
      );
    });

    testWidgets('the sheet names the web deletion page', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: YourDataSheet(
                hasAccount: true,
                webDeletionUrl: 'https://example.test/delete-account',
                onDelete: () async => AccountDeletionResult.appCannotReach,
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Delete everything'));
      await tester.pumpAndSettle();
      final l10n = AppL10n.of(tester.element(find.byType(YourDataSheet)));
      expect(find.text(l10n.thisCopyOfTheAppCannotReach_qzcpf), findsOneWidget);
      expect(find.text(l10n.weCouldNotReachOwnHubSo_yfi5n), findsNothing);
      expect(
        find.byKey(const ValueKey('your-data-web-deletion')),
        findsOneWidget,
      );
      expect(
        find.textContaining('https://example.test/delete-account'),
        findsOneWidget,
      );
    });
  });

  testWidgets('C09b says update the app, not check your connection', (
    tester,
  ) async {
    final store = CallableCaptureConsentStore(
      firestore: _NoFirestore(),
      functions: functions,
      signedIn: () => true,
    );
    await tester.binding.setSurfaceSize(const Size(800, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: ConsentView(uid: 'u1', store: store),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('I agree, start the camera'));
    await tester.pumpAndSettle();
    final l10n = AppL10n.of(tester.element(find.byType(ConsentView)));
    expect(find.text(l10n.thisCopyOfTheAppCannotReach_1dlg6), findsOneWidget);
    expect(find.text(l10n.weCouldNotSaveYourAgreementSo), findsNothing);
  });
}
