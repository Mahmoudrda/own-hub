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
/// **The callable's name is not yet agreed.** [kRecordConsentCallable] is what
/// this file calls; the rules refer to it only as "the ConsentService
/// callable". If the function ships under another name this fails at runtime
/// with `not-found`, and `ConsentView` will keep her on the consent screen
/// rather than opening a camera, which is the correct failure but not a quiet
/// one. Confirm the name before this reaches a device.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../domain/capture_consent.dart';
import 'callable_verification_provider.dart' show kVerifyIdentityRegion;

/// The callable that mints a consent record. **Unconfirmed.** See the note at
/// the top of this file.
const String kRecordConsentCallable = 'record_consent';

class CallableCaptureConsentStore implements CaptureConsentStore {
  CallableCaptureConsentStore({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _functions =
           functions ??
           FirebaseFunctions.instanceFor(region: kVerifyIdentityRegion);

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  /// The document id is the version.
  ///
  /// That makes re-agreeing to the same wording idempotent: a double tap, or a
  /// retry after a dropped response, lands on the same document instead of
  /// filling her consent history with duplicates of one decision. Agreeing to
  /// *new* wording writes a new document beside the old one, which is the
  /// history an audit actually wants.
  DocumentReference<Map<String, dynamic>> _doc(String uid, String version) =>
      _firestore.collection('users').doc(uid).collection('consents').doc(version);

  @override
  Future<CaptureConsent?> current(String uid) async {
    final snapshot = await _doc(uid, kCaptureConsentVersion).get();
    final data = snapshot.data();
    if (data == null) return null;

    // The server writes the timestamp. A record whose timestamp has not
    // resolved yet is treated as absent rather than as "agreed at the epoch",
    // because the whole value of this record is when it happened.
    final agreedAt = data['agreedAt'];
    if (agreedAt is! Timestamp) return null;

    return CaptureConsent(
      uid: uid,
      version: kCaptureConsentVersion,
      agreedAt: agreedAt.toDate(),
    );
  }

  @override
  Future<void> record(CaptureConsent consent) async {
    // Only the version travels. The uid comes from the auth token, which is the
    // only copy of it worth anything, and the timestamp is the server's. A
    // payload carrying all three would be three fields an attacker can choose.
    final callable = _functions.httpsCallable(kRecordConsentCallable);
    await callable.call<Object?>(<String, Object?>{
      'version': consent.version,
    });
  }
}
