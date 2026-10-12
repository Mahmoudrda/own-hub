/// Where the router reads her verification from: the `verified` claim on
/// her ID token and `users/{uid}.verification`.
///
/// A seam so the launch decision can be proved offline, with an expired
/// token, and with no Firebase at all, in a test binary where none of those
/// can be produced for real.
library;

import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';

import '../../../app_state/firebase_boot.dart';
import '../domain/server_verification.dart';
import 'verification_status_repository.dart';

abstract class VerificationBackend {
  const VerificationBackend();

  /// Firebase came up.
  bool get isReady;

  /// The signed-in Firebase user, or null.
  String? get currentUid;

  /// The `verified` claim on her ID token. [forceRefresh] mints a new one.
  /// Throws when no token could be had (offline with an expired token).
  Future<bool> verifiedClaim({bool forceRefresh = false});

  /// `users/{uid}.verification`, server first then cache, or null.
  Future<ServerVerification?> readStatus(String uid);

  /// The same, from the on-device cache only, or null.
  Future<ServerVerification?> cachedStatus(String uid);

  /// Live `users/{uid}.verification`, or null with no back end.
  Stream<ServerVerification?>? watchStatus(String uid);

  /// Fires whenever Firebase holds a new ID token, which is what a reconnect
  /// produces once the SDK refreshes it.
  Stream<Object?> tokenChanges();
}

/// True when [error] means the network or the service could not answer,
/// rather than that the server said no.
bool isUnreachableFailure(Object error) {
  if (error is TimeoutException || error is SocketException) return true;
  if (error is FirebaseException) {
    return const {
      'network-request-failed',
      'unavailable',
      'deadline-exceeded',
    }.contains(error.code);
  }
  return false;
}

class FirebaseVerificationBackend extends VerificationBackend {
  const FirebaseVerificationBackend();

  @override
  bool get isReady => FirebaseBoot.isReady;

  User? get _user {
    if (!isReady) return null;
    try {
      return FirebaseAuth.instance.currentUser;
    } catch (_) {
      return null;
    }
  }

  @override
  String? get currentUid => _user?.uid;

  @override
  Future<bool> verifiedClaim({bool forceRefresh = false}) async {
    final user = _user;
    if (user == null) throw StateError('no user');
    final token = await user.getIdTokenResult(forceRefresh);
    return token.claims?['verified'] == true;
  }

  @override
  Future<ServerVerification?> readStatus(String uid) =>
      VerificationStatusRepository().read(uid);

  @override
  Future<ServerVerification?> cachedStatus(String uid) =>
      VerificationStatusRepository().readCached(uid);

  @override
  Stream<ServerVerification?>? watchStatus(String uid) =>
      isReady ? VerificationStatusRepository().watch(uid) : null;

  @override
  Stream<Object?> tokenChanges() =>
      isReady ? FirebaseAuth.instance.idTokenChanges() : const Stream.empty();
}
