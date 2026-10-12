/// `users/{uid}.verification`, as the server wrote it (S8).
///
/// Only the server writes this map (firestore.rules `verificationUntouched`).
/// The app reads it at start-up and while C14 is open, so a woman who closed
/// the app while waiting for a reviewer comes back to the right screen, and
/// learns the reviewer's decision without having to ask. It carries no reason
/// codes and no flag id, by contract.
///
/// The custom `verified` claim is still the source of truth for the gate.
/// `approved` here only tells the app to force a token refresh so the claim
/// becomes visible.
library;

import 'package:meta/meta.dart';

/// The map's name on `users/{uid}` and its field names
/// (contracts/identity_contract.json `documents.verificationState`).
const String kVerificationStateMap = 'verification';

enum ServerVerificationState { pending, approved, rejected, retry }

ServerVerificationState? serverVerificationStateFrom(Object? raw) =>
    switch (raw) {
      'pending' => ServerVerificationState.pending,
      'approved' => ServerVerificationState.approved,
      'rejected' => ServerVerificationState.rejected,
      'retry' => ServerVerificationState.retry,
      _ => null,
    };

@immutable
class ServerVerification {
  const ServerVerification(
    this.state, {
    this.reviewRoute,
    this.reviewScheduledFor,
  });

  final ServerVerificationState state;

  /// `video` or `gym`, once a reviewer has booked the live check.
  final String? reviewRoute;

  /// When the booked check is, once a reviewer has booked it.
  final DateTime? reviewScheduledFor;

  /// Reads the `verification` map off a `users/{uid}` document.
  ///
  /// [toDateTime] converts the stored timestamp; it is injected so this file
  /// does not depend on the Firestore SDK. Returns null for a missing map or
  /// an unknown state, which means "the server has said nothing".
  static ServerVerification? fromUserDoc(
    Map<String, Object?>? data, {
    required DateTime? Function(Object? raw) toDateTime,
  }) {
    final map = data?[kVerificationStateMap];
    if (map is! Map) return null;
    final state = serverVerificationStateFrom(map['state']);
    if (state == null) return null;
    final route = map['reviewRoute'];
    return ServerVerification(
      state,
      reviewRoute: route is String ? route : null,
      reviewScheduledFor: toDateTime(map['reviewScheduledFor']),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ServerVerification &&
      other.state == state &&
      other.reviewRoute == reviewRoute &&
      other.reviewScheduledFor == reviewScheduledFor;

  @override
  int get hashCode => Object.hash(state, reviewRoute, reviewScheduledFor);
}
