/// One reading of a failed callable, shared by every adapter (R3, N4).
///
/// The server answers an App Check refusal as `failed-precondition`
/// `app_check_missing`: this copy of the app cannot reach Own Hub, update it
/// from the store. `unauthenticated` means her ID token was rejected, and
/// `permission-denied` `phone_sign_in_required` means the account did not
/// sign in with a phone: both are "sign in again with your phone number".
/// See [classifyCallFailure].
library;

import 'package:cloud_functions/cloud_functions.dart';

import '../domain/review_request.dart';

/// [error] in the domain's words.
VerificationCallFailure callFailureFrom(FirebaseFunctionsException error) =>
    callFailureOf(error.code, error.message);
