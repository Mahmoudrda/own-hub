// R3 and N4, client. Two refusals, told apart by the server's own codes:
//
//   * App Check refusing this copy of the app arrives as FAILED_PRECONDITION
//     `app_check_missing`. She is told to install the latest version: not
//     "offline", not "sign in again", and not a reason to queue her for review.
//   * UNAUTHENTICATED now only ever means her ID token was rejected (a
//     disabled, deleted or revoked account), and PERMISSION_DENIED
//     `phone_sign_in_required` means the account did not sign in with a phone.
//     Both send her to sign in again with her phone number. Neither is ever
//     read as App Check.
//
// Every callable the app makes is driven here through a fake
// `FirebaseFunctions` that answers with the refusal under test.

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

FirebaseFunctionsException get _refused => FirebaseFunctionsException(
  code: 'failed-precondition',
  message: ServerReason.appCheckMissing,
);

FirebaseFunctionsException get _tokenRejected =>
    FirebaseFunctionsException(code: 'unauthenticated', message: 'x');

class _RefusingCallable extends Fake implements HttpsCallable {
  _RefusingCallable(this.error);
  final FirebaseFunctionsException error;

  @override
  Future<HttpsCallableResult<T>> call<T>([dynamic parameters]) async =>
      throw error;
}

class _RefusingFunctions extends Fake implements FirebaseFunctions {
  _RefusingFunctions([FirebaseFunctionsException? error])
    : error = error ?? _refused;
  final FirebaseFunctionsException error;

  @override
  HttpsCallable httpsCallable(String name, {HttpsCallableOptions? options}) =>
      _RefusingCallable(error);
}

class _NoFirestore extends Fake implements FirebaseFirestore {}

Matcher get _appCannotReach => isA<VerificationCallFailure>().having(
  classifyCallFailure,
  'kind',
  CallFailureKind.appCannotReach,
);

Matcher get _signInAgain => isA<VerificationCallFailure>().having(
  classifyCallFailure,
  'kind',
  CallFailureKind.signInAgain,
);

void main() {
  final functions = _RefusingFunctions();

  test('the mapping: App Check is its own code, a rejected sign-in is not '
      'App Check', () {
    expect(
      callFailureOf('failed-precondition', ServerReason.appCheckMissing),
      _appCannotReach,
    );
    expect(callFailureOf('unauthenticated', 'x'), _signInAgain);
    expect(callFailureOf('unauthenticated', null), _signInAgain);
    expect(
      callFailureOf('permission-denied', ServerReason.phoneSignInRequired),
      _signInAgain,
    );
    expect(
      classifyCallFailure(callFailureOf('permission-denied', 'other')),
      CallFailureKind.other,
    );
    expect(
      classifyCallFailure(callFailureOf('unavailable', null)),
      CallFailureKind.other,
    );
  });

  test('every adapter reads a rejected sign-in as sign in again', () async {
    final rejecting = _RefusingFunctions(_tokenRejected);
    await expectLater(
      CallableCaptureConsentStore(
        firestore: _NoFirestore(),
        functions: rejecting,
      ).record(
        CaptureConsent(
          uid: 'u1',
          version: kCaptureConsentVersion,
          agreedAt: DateTime.utc(2026, 10, 2),
        ),
      ),
      throwsA(_signInAgain),
    );
    await expectLater(
      CallableHealthConsentStore(
        firestore: _NoFirestore(),
        functions: rejecting,
      ).record(granted: true),
      throwsA(_signInAgain),
    );
    await expectLater(
      CallableVerificationProvider(functions: rejecting).startSession(),
      throwsA(_signInAgain),
    );
    await expectLater(
      CallableReviewRequester(functions: rejecting).request(ReviewPath.error),
      throwsA(_signInAgain),
    );
    await expectLater(
      CallableDeletionTransport(
        isOnline: () => true,
        call: () async => throw _tokenRejected,
      ).requestDeletion(),
      throwsA(isA<DeletionSignInAgain>()),
    );
  });

  test('record_consent', () async {
    final store = CallableCaptureConsentStore(
      firestore: _NoFirestore(),
      functions: functions,
    );
    final consent = CaptureConsent(
      uid: 'u1',
      version: kCaptureConsentVersion,
      agreedAt: DateTime.utc(2026, 10, 2),
    );
    await expectLater(store.record(consent), throwsA(_appCannotReach));
  });

  test('record_health_consent, and A03 can tell', () async {
    final store = CallableHealthConsentStore(
      firestore: _NoFirestore(),
      functions: functions,
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
    final provider = CallableVerificationProvider(functions: functions);
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
    final requester = CallableReviewRequester(functions: functions);
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
          ),
          wipe: RecordingLocalWipe(),
          quiesce: () async {},
        ),
        AccountDeletionResult.appCannotReach,
      );
    });

    test('a connection that never got through stays offline', () async {
      final transport = CallableDeletionTransport(
        isOnline: () => true,
        call: () async =>
            throw FirebaseFunctionsException(code: 'unavailable', message: ''),
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
