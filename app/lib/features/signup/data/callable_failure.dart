/// One reading of a failed callable, shared by every adapter (R3).
///
/// With `ENFORCE_APP_CHECK` the callable framework refuses a missing or
/// invalid App Check token as `unauthenticated`, before the function's own
/// check can answer `failed-precondition app_check_missing`. A woman who is
/// signed in is not unauthenticated, so for her that code means this copy of
/// the app cannot reach Own Hub: update it from the store. Never offline,
/// never a sign-in prompt, never a review.
library;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../app_state/firebase_boot.dart';
import '../domain/review_request.dart';

/// Whether Firebase holds a signed-in user. Never throws.
bool firebaseUserSignedIn() {
  if (!FirebaseBoot.isReady) return false;
  try {
    return FirebaseAuth.instance.currentUser != null;
  } catch (_) {
    return false;
  }
}

/// [error] in the domain's words.
VerificationCallFailure callFailureFrom(
  FirebaseFunctionsException error, {
  bool Function() signedIn = firebaseUserSignedIn,
}) => callFailureOf(error.code, error.message, signedIn: signedIn());
