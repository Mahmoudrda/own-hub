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

import 'package:own_hub/features/account/data/callable_health_consent_store.dart';
import 'package:own_hub/features/account/domain/health_backup.dart';
import 'package:own_hub/features/signup/data/callable_capture_consent_store.dart';
import 'package:own_hub/features/signup/data/callable_verification_provider.dart';
import 'package:own_hub/features/signup/domain/capture_consent.dart';

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
        CallableCaptureConsentStore.payloadFor(kCaptureConsentVersion),
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
      expect(doc['fields'], unorderedEquals(<String>['at', 'version']));
    });

    test('reads the server shape and nothing else', () {
      final at = Timestamp.fromDate(DateTime.utc(2026, 10, 2, 9));
      final read = CallableCaptureConsentStore.fromDoc('u1', <String, dynamic>{
        'version': 1,
        'at': at,
      });
      expect(read, isNotNull);
      expect(read!.uid, 'u1');
      expect(read.version, kCaptureConsentVersion);
      expect(read.agreedAt, at.toDate());

      // The old client shape, which the server never wrote.
      expect(
        CallableCaptureConsentStore.fromDoc('u1', <String, dynamic>{
          'version': 1,
          'agreedAt': at,
        }),
        isNull,
      );
      // A timestamp that has not resolved is not "agreed at the epoch".
      expect(
        CallableCaptureConsentStore.fromDoc('u1', <String, dynamic>{
          'version': 1,
        }),
        isNull,
      );
      // Consent to other wording is not consent to this wording.
      expect(
        CallableCaptureConsentStore.fromDoc('u1', <String, dynamic>{
          'version': 2,
          'at': at,
        }),
        isNull,
      );
      expect(CallableCaptureConsentStore.fromDoc('u1', null), isNull);
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
}
