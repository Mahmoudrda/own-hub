/// The one way an error reaches Crashlytics (R8).
///
/// An exception's message can carry anything: a phone number in a parse
/// error, a name in a state error, an ID number in a format error. So a
/// report sends the error's runtime type as its reason and the stack trace,
/// and nothing else. Never `error.toString()`, never a message, never a
/// reason line or information lines. The guard is
/// test/release/crash_reporting_privacy_test.dart.
library;

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// What is sent in place of the error: its type name, as text.
@immutable
class ScrubbedError {
  const ScrubbedError(this.type);

  final String type;

  @override
  String toString() => type;
}

abstract final class CrashReports {
  /// [error] reduced to its runtime type. A [FlutterErrorDetails] is reduced
  /// as itself, so its exception, context and information never travel.
  static ScrubbedError scrub(Object error) =>
      ScrubbedError(error.runtimeType.toString());

  /// A framework error, fatal. Its stack only.
  static Future<void> flutterError(FlutterErrorDetails details) =>
      FirebaseCrashlytics.instance.recordError(
        scrub(details.exception),
        details.stack,
        fatal: true,
        printDetails: false,
      );

  /// An uncaught error, fatal. Its type and stack only.
  static Future<void> uncaught(Object error, StackTrace stack) =>
      FirebaseCrashlytics.instance.recordError(
        scrub(error),
        stack,
        fatal: true,
        printDetails: false,
      );
}
