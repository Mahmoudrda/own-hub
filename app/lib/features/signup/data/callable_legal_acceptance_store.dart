/// `record_legal_acceptance` over the wire, and the record read back.
///
/// The server writes `users/{uid}/consents/legal-t{T}-p{P}`; the rules let her
/// read it and never write it, like every consent record. See
/// `domain/legal_acceptance.dart`.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../../app_state/firebase_boot.dart';
import '../domain/legal_acceptance.dart';
import 'callable_failure.dart';

class CallableLegalAcceptanceStore implements LegalAcceptanceStore {
  CallableLegalAcceptanceStore({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _functions = functions ?? FirebaseBoot.functions;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  @override
  Future<void> record(LegalAcceptance acceptance) async {
    final callable = _functions.httpsCallable(
      kRecordLegalAcceptanceCallable,
      options: HttpsCallableOptions(timeout: const Duration(seconds: 20)),
    );
    try {
      await callable.call<Object?>(acceptance.payload());
    } on FirebaseFunctionsException catch (error) {
      throw callFailureFrom(error);
    }
  }

  @override
  Future<bool> hasCurrent(String uid) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('consents')
        .doc(legalAcceptanceDocId())
        .get()
        .timeout(const Duration(seconds: 8));
    return snapshot.exists;
  }
}
