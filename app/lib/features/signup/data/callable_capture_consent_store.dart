/// Consent, written by a server and read back by her.
///
/// **The client cannot write this record, by rule.** `firebase/firestore.rules`
/// denies every write under `users/{uid}/consents/{consentId}` and says why: a
/// consent record the client minted proves nothing, because the client is the
/// party the record is about. So recording goes through a callable that stamps
/// a server timestamp and its own hash of the policy text, and reading comes
/// straight from Firestore, which the same rule allows because PDPL gives her a
/// right of access to her own consent records.
///
/// **The wire shape is the server's.** The callable is `record_consent`, it
/// takes `{consentVersion: <int>, locale, appVersion}` and refuses any other
/// version with `consent_missing`, and the record it writes is
/// `users/{uid}/consents/verification-v<version>` = `{version, at, locale,
/// appVersion}`. Those
/// facts are pinned in `contracts/identity_contract.json`, which both this
/// app's contract test and the functions' contract test read, so a drift on
/// either side fails a build instead of stranding every woman at `C09b`.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:meta/meta.dart';

import '../../../app_state/firebase_boot.dart';
import '../domain/capture_consent.dart';
import 'callable_failure.dart';

/// The callable that mints a consent record.
const String kRecordConsentCallable = 'record_consent';

class CallableCaptureConsentStore implements CaptureConsentStore {
  CallableCaptureConsentStore({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _functions = functions ?? FirebaseBoot.functions;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  /// The body `record_consent` accepts: the version as an int, under
  /// `consentVersion`, plus the language the wording was shown in and the
  /// app version (version 2). The server drops either if it is malformed.
  @visibleForTesting
  static Map<String, Object?> payloadFor(
    int version, {
    String? locale,
    String? appVersion,
  }) => <String, Object?>{
    'consentVersion': version,
    'locale': ?locale,
    'appVersion': ?appVersion,
  };

  /// The document id the server writes for a version.
  ///
  /// One document per version makes re-agreeing to the same wording
  /// idempotent: a double tap, or a retry after a dropped response, lands on
  /// the same document instead of filling her consent history with duplicates
  /// of one decision. Agreeing to *new* wording writes a new document beside
  /// the old one, which is the history an audit actually wants.
  @visibleForTesting
  static String docIdFor(int version) => 'verification-v$version';

  /// Her consent as the server wrote it, or null when it does not cover the
  /// wording on screen today.
  ///
  /// The server writes `{version, at}`. A record whose timestamp has not
  /// resolved yet is treated as absent rather than as "agreed at the epoch",
  /// because the whole value of this record is when it happened. A record for
  /// any other version is not consent to this wording.
  @visibleForTesting
  static CaptureConsent? fromDoc(String uid, Map<String, dynamic>? data) {
    if (data == null) return null;
    final at = data['at'];
    if (at is! Timestamp) return null;
    final version = data['version'];
    if (version is! int || version != kCaptureConsentVersion) return null;
    return CaptureConsent(uid: uid, version: version, agreedAt: at.toDate());
  }

  DocumentReference<Map<String, dynamic>> _doc(String uid, int version) =>
      _firestore
          .collection('users')
          .doc(uid)
          .collection('consents')
          .doc(docIdFor(version));

  @override
  Future<CaptureConsent?> current(String uid) async {
    final snapshot = await _doc(uid, kCaptureConsentVersion).get();
    return fromDoc(uid, snapshot.data());
  }

  @override
  Future<void> record(CaptureConsent consent) async {
    // The version, the language and the app version travel. The uid comes
    // from the auth token, which is the only copy of it worth anything, and
    // the timestamp is the server's.
    final callable = _functions.httpsCallable(kRecordConsentCallable);
    try {
      await callable.call<Object?>(
        payloadFor(
          consent.version,
          locale: consent.locale,
          appVersion: consent.appVersion,
        ),
      );
    } on FirebaseFunctionsException catch (error) {
      throw callFailureFrom(error);
    }
  }
}
