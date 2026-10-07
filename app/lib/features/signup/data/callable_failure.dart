/// One reading of a failed callable, shared by every adapter (R3, N4).
///
/// The server answers an App Check refusal as `failed-precondition`
/// `app_check_missing`: this copy of the app cannot reach Own Hub, update it
/// from the store. `unauthenticated` means her ID token was rejected, and
/// `permission-denied` `phone_sign_in_required` means the account did not
/// sign in with a phone: both are "sign in again with your phone number".
/// See [classifyCallFailure].
library;

import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';

import '../../../app_state/crash_reports.dart';
import '../domain/review_request.dart';

/// [error] in the domain's words.
///
/// A status that means a bug on the server side (`internal`, `not-found` and
/// the others in [CrashReports.serverCodesReported]) is also recorded as a
/// non-fatal crash report, by its code alone and only with her consent to
/// crash reports. The message is never sent.
VerificationCallFailure callFailureFrom(FirebaseFunctionsException error) {
  unawaited(CrashReports.serverError(error.code));
  return callFailureOf(error.code, error.message);
}
