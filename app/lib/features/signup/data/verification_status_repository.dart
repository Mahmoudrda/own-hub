/// Reads `users/{uid}.verification` (S8). Read-only: the rules refuse any
/// client write to that map, and nothing here tries one.
library;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/server_verification.dart';

/// Firestore's Timestamp, or a DateTime from a cache, as a DateTime.
DateTime? firestoreDateTime(Object? raw) => switch (raw) {
  Timestamp() => raw.toDate(),
  DateTime() => raw,
  _ => null,
};

class VerificationStatusRepository {
  VerificationStatusRepository({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _db.collection('users').doc(uid);

  /// One read, bounded at five seconds. A cached copy is acceptable. Null when
  /// the server has said nothing yet, or the read did not complete.
  Future<ServerVerification?> read(String uid) async {
    try {
      final snapshot = await _doc(uid)
          .get()
          .timeout(const Duration(seconds: 5));
      return ServerVerification.fromUserDoc(
        snapshot.data(),
        toDateTime: firestoreDateTime,
      );
    } catch (_) {
      try {
        final cached = await _doc(uid)
            .get(const GetOptions(source: Source.cache));
        return ServerVerification.fromUserDoc(
          cached.data(),
          toDateTime: firestoreDateTime,
        );
      } catch (_) {
        return null;
      }
    }
  }

  /// The on-device cache only, bounded at one second. For launch with no
  /// network, where a server read would spend the whole start-up budget.
  Future<ServerVerification?> readCached(String uid) async {
    try {
      final cached = await _doc(uid)
          .get(const GetOptions(source: Source.cache))
          .timeout(const Duration(seconds: 1));
      return ServerVerification.fromUserDoc(
        cached.data(),
        toDateTime: firestoreDateTime,
      );
    } catch (_) {
      return null;
    }
  }

  /// Live updates while C14 is open, so a reviewer's booking or decision
  /// reaches her without a restart. Errors end the stream quietly.
  Stream<ServerVerification?> watch(String uid) => _doc(uid)
      .snapshots()
      .map(
        (snapshot) => ServerVerification.fromUserDoc(
          snapshot.data(),
          toDateTime: firestoreDateTime,
        ),
      )
      .handleError((Object _) {});
}
