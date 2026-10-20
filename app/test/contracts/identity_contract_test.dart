// The client half of the identity contract.
//
// `contracts/identity_contract.json` is read by this file and by the
// functions' `tests/test_identity_contract.py`. Neither side may edit it alone.
// The bug it exists to prevent already happened once: the app sent
// `{version: '2026-09-25'}` while the server read `consentVersion == 1`, so
// every consent call failed and no woman could get past C09b.

import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/pledge.dart';

import 'package:own_hub/features/account/data/callable_health_consent_store.dart';
import 'package:own_hub/features/account/domain/health_backup.dart';
import 'package:own_hub/features/signup/data/callable_capture_consent_store.dart';
import 'package:own_hub/features/signup/data/callable_verification_provider.dart';
import 'package:own_hub/features/signup/data/callable_review_request.dart';
import 'package:own_hub/features/signup/data/verification_status_repository.dart';
import 'package:own_hub/features/signup/domain/capture_consent.dart';
import 'package:own_hub/features/signup/domain/legal_acceptance.dart';
import 'package:own_hub/features/signup/domain/review_request.dart';
import 'package:own_hub/features/signup/domain/server_verification.dart';

Map<String, dynamic> _contract() =>
    jsonDecode(File('../contracts/identity_contract.json').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  final contract = _contract();
  final callables = contract['callables'] as Map<String, dynamic>;
  final documents = contract['documents'] as Map<String, dynamic>;

  group('record_consent', () {
    test('the body the app sends is the body the server accepts', () {
      final request =
          (callables['record_consent'] as Map<String, dynamic>)['request'];
      expect(
        CallableCaptureConsentStore.payloadFor(
          kCaptureConsentVersion,
          locale: 'en',
          appVersion: '1.0.0+1',
        ),
        request,
      );
    });

    test('the document the app reads is the one the server writes', () {
      final doc = documents['verificationConsent'] as Map<String, dynamic>;
      expect(
        'users/{uid}/consents/'
        '${CallableCaptureConsentStore.docIdFor(kCaptureConsentVersion)}',
        doc['path'],
      );
      expect(
        doc['fields'],
        unorderedEquals(<String>['at', 'version', 'locale', 'appVersion']),
      );
    });

    test('reads the server shape and nothing else', () {
      final at = Timestamp.fromDate(DateTime.utc(2026, 10, 2, 9));
      final read = CallableCaptureConsentStore.fromDoc('u1', <String, dynamic>{
        'version': kCaptureConsentVersion,
        'at': at,
        'locale': 'ar',
        'appVersion': '1.0.0+1',
      });
      expect(read, isNotNull);
      expect(read!.uid, 'u1');
      expect(read.version, kCaptureConsentVersion);
      expect(read.agreedAt, at.toDate());

      // The old client shape, which the server never wrote.
      expect(
        CallableCaptureConsentStore.fromDoc('u1', <String, dynamic>{
          'version': kCaptureConsentVersion,
          'agreedAt': at,
        }),
        isNull,
      );
      // A timestamp that has not resolved is not "agreed at the epoch".
      expect(
        CallableCaptureConsentStore.fromDoc('u1', <String, dynamic>{
          'version': kCaptureConsentVersion,
        }),
        isNull,
      );
      // Consent to other wording is not consent to this wording: version 1
      // was shown before privacy policy v3.
      expect(
        CallableCaptureConsentStore.fromDoc('u1', <String, dynamic>{
          'version': 1,
          'at': at,
        }),
        isNull,
      );
      expect(CallableCaptureConsentStore.fromDoc('u1', null), isNull);
    });
  });

  group('record_legal_acceptance (M1)', () {
    test('the body the app sends is the body the server accepts', () {
      final callable =
          callables[kRecordLegalAcceptanceCallable] as Map<String, dynamic>?;
      expect(callable, isNotNull);
      final request = callable!['request'] as Map<String, dynamic>;
      final acceptance = LegalAcceptance(
        termsVersion: kTermsVersion,
        privacyVersion: kPrivacyVersion,
        locale: request['locale'] as String,
        acceptedAtMs: request['acceptedAtMs'] as int,
      );
      expect(
        acceptance.payload(
          appVersion: request['appVersion'] as String,
          platform: request['platform'] as String,
        ),
        request,
      );
    });

    test('the versions and the document are the server\'s', () {
      final doc = documents['legalAcceptance'] as Map<String, dynamic>;
      expect('users/{uid}/consents/${legalAcceptanceDocId()}', doc['path']);
      final response =
          (callables[kRecordLegalAcceptanceCallable]
              as Map<String, dynamic>)['response'];
      expect(response['termsVersion'], kTermsVersion);
      expect(response['privacyVersion'], kPrivacyVersion);
    });
  });

  test('the region is the one the functions are deployed to', () {
    expect(kVerifyIdentityRegion, contract['region']);
  });

  test('every callable the app names exists in the contract', () {
    for (final name in <String>[
      kRecordConsentCallable,
      kStartVerificationCallable,
      kVerifyIdentityCallable,
    ]) {
      expect(callables.keys, contains(name), reason: name);
    }
  });

  // R1-P7: her agreement to the community's rules, recorded by the server.
  group('record_pledge', () {
    test('the body the app sends is the body the server accepts', () {
      final callable = callables[kRecordPledgeCallable] as Map<String, dynamic>;
      expect(
        pledgePayload(locale: 'en', appVersion: '1.0.0+1'),
        callable['request'],
      );
      expect((callable['response'] as Map)['version'], kPledgeVersion);
    });

    test('the document is the server\'s', () {
      final doc = documents['pledge'] as Map<String, dynamic>;
      expect(doc['path'], 'users/{uid}/consents/pledge-v$kPledgeVersion');
      expect(
        doc['fields'],
        unorderedEquals(<String>['appVersion', 'at', 'locale', 'version']),
      );
    });
  });

  group('request_review consent', () {
    test('the version and document match the server', () {
      final doc = documents['reviewConsent'] as Map<String, dynamic>;
      expect('users/{uid}/consents/$kReviewConsentDocId', doc['path']);
      expect(kReviewConsentVersion, 3);
      expect(
        doc['fields'],
        unorderedEquals(<String>['at', 'flagId', 'path', 'version']),
      );
    });
  });

  group('record_health_consent', () {
    test('the body and the callable name match', () {
      final callable =
          callables[kRecordHealthConsentCallable] as Map<String, dynamic>?;
      expect(callable, isNotNull);
      expect(
        CallableHealthConsentStore.payloadFor(granted: true),
        callable!['request'],
      );
    });

    test('the document path, version and states match', () {
      final doc = documents['healthConsent'] as Map<String, dynamic>;
      expect('users/{uid}/consents/$kHealthConsentDocId', doc['path']);
      expect(
        (callables[kRecordHealthConsentCallable]
            as Map<String, dynamic>)['request']['consentVersion'],
        kHealthConsentVersion,
      );
      expect(
        (doc['states'] as List).toSet(),
        HealthConsentState.values.map((s) => s.name).toSet(),
      );
    });
  });

  group('verify_identity (S12)', () {
    test('the body carries exactly the keys the server reads', () {
      final requestKeys =
          ((callables['verify_identity'] as Map<String, dynamic>)['requestKeys']
                  as List)
              .cast<String>();
      final body = CallableVerificationProvider.verifyPayload(
        front: 'f',
        back: 'b',
        frames: const <String>['x'],
        sessionId: 's',
        operationId: '00000000-0000-4000-8000-000000000000',
        installId: 'i',
      );
      expect(body.keys.toList()..sort(), requestKeys.toList()..sort());
      expect(body.containsKey('niqabPath'), isFalse);
    });
  });

  group('request_review (S3)', () {
    final contractCall = callables['request_review'] as Map<String, dynamic>;

    test('the callable name and the body match', () {
      expect(callables.keys, contains(kRequestReviewCallable));
      expect(
        CallableReviewRequester.payloadFor(
          ReviewPath.niqab,
          knownReviewerId: '<reviewer uid, optional>',
        ),
        contractCall['request'],
      );
    });

    test('every path the app can send is one the server accepts', () {
      expect(
        ReviewPath.values.map((p) => p.name).toSet(),
        (contractCall['paths'] as List).cast<String>().toSet(),
      );
    });

    test('the reasons the app acts on are the contract reasons', () {
      final reasons = (contract['errorReasons'] as Map).values.toSet();
      for (final reason in <String>[
        ServerReason.perUidDailyLimit,
        ServerReason.dailyLimitReached,
        ServerReason.costCapReached,
        ServerReason.consentMissing,
        ServerReason.verificationClosed,
        ServerReason.appCheckMissing,
        ServerReason.reviewAlreadyOpen,
        ServerReason.imageUndecodable,
        ServerReason.imageTooLarge,
        ServerReason.sessionMissing,
        ServerReason.livenessFailed,
        ServerReason.internalError,
      ]) {
        expect(reasons, contains(reason), reason: reason);
      }
    });

    test('every reason code the client declares is pinned (N13)', () {
      // Read from the source, so a code added to ServerReason without a row
      // in the contract fails here rather than on a woman's phone.
      final reasons = (contract['errorReasons'] as Map).values.toSet();
      final source = File('lib/features/signup/domain/review_request.dart')
          .readAsStringSync();
      final block = source.substring(
        source.indexOf('abstract final class ServerReason'),
      );
      final declared = RegExp(r"static const String \w+ = '([a-z_]+)';")
          .allMatches(block.substring(0, block.indexOf('}')))
          .map((m) => m[1]!);
      expect(declared, isNotEmpty);
      for (final code in declared) {
        expect(reasons, contains(code), reason: code);
      }
    });
  });

  group('users/{uid}.verification (S8)', () {
    final doc = documents['verificationState'] as Map<String, dynamic>;

    test('the map name and states match', () {
      expect(doc['path'], 'users/{uid}');
      expect(doc['map'], kVerificationStateMap);
      expect(
        ServerVerificationState.values.map((s) => s.name).toSet(),
        (doc['states'] as List).cast<String>().toSet(),
      );
      final fields = (doc['fields'] as List).cast<String>();
      expect(
        fields,
        containsAll(<String>['state', 'reviewRoute', 'reviewScheduledFor']),
      );
    });

    test('reads the server shape, and nothing it does not know', () {
      final at = DateTime.utc(2026, 10, 5, 8);
      final read = ServerVerification.fromUserDoc(<String, Object?>{
        'verification': <String, Object?>{
          'state': 'pending',
          'reviewRoute': 'video',
          'reviewScheduledFor': Timestamp.fromDate(at),
          'updatedAt': Timestamp.fromDate(at),
        },
      }, toDateTime: firestoreDateTime);
      expect(read?.state, ServerVerificationState.pending);
      expect(read?.reviewRoute, 'video');
      expect(read?.reviewScheduledFor?.toUtc(), at);

      DateTime? never(Object? _) => null;
      expect(ServerVerification.fromUserDoc(null, toDateTime: never), isNull);
      expect(
        ServerVerification.fromUserDoc(<String, Object?>{
          'verification': <String, Object?>{'state': 'verified'},
        }, toDateTime: never),
        isNull,
        reason: 'an unknown state is the server saying nothing',
      );
    });
  });
}
