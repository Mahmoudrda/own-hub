/// Her health backup consent, written by the server and read back by her.
///
/// The client cannot write `users/{uid}/consents/*` (the rules deny it), so the
/// grant and the withdrawal go through `record_health_consent`, which stamps a
/// server timestamp and, on withdrawal, deletes the cloud copy of her health
/// data. The wire shape is pinned in `contracts/identity_contract.json`.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:meta/meta.dart';

import '../../../app_state/firebase_boot.dart';
import '../../signup/data/callable_failure.dart';
import '../domain/health_backup.dart';

class CallableHealthConsentStore implements HealthConsentStore {
  CallableHealthConsentStore({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    bool Function()? signedIn,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _functions = functions ?? FirebaseBoot.functions,
       _signedIn = signedIn ?? firebaseUserSignedIn;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  final bool Function() _signedIn;

  /// The body `record_health_consent` accepts.
  @visibleForTesting
  static Map<String, Object?> payloadFor({required bool granted}) =>
      <String, Object?>{
        'consentVersion': kHealthConsentVersion,
        'granted': granted,
      };

  /// The server's record read from its document, or null when absent or of
  /// another version.
  @visibleForTesting
  static HealthConsentState? stateFromDoc(Map<String, dynamic>? data) {
    if (data == null) return null;
    if (data['version'] != kHealthConsentVersion) return null;
    return switch (data['state']) {
      'granted' => HealthConsentState.granted,
      'withdrawn' => HealthConsentState.withdrawn,
      _ => null,
    };
  }

  @override
  Future<void> record({required bool granted}) async {
    final callable = _functions.httpsCallable(kRecordHealthConsentCallable);
    try {
      await callable.call<Object?>(payloadFor(granted: granted));
    } on FirebaseFunctionsException catch (error) {
      throw callFailureFrom(error, signedIn: _signedIn);
    }
  }

  @override
  Future<HealthConsentState?> current(String uid) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('consents')
        .doc(kHealthConsentDocId)
        .get()
        .timeout(const Duration(seconds: 5));
    return stateFromDoc(snapshot.data());
  }
}
