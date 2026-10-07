/// The one way anything reaches Crashlytics (R8).
///
/// An exception's message can carry anything: a phone number in a parse
/// error, a name in a state error, an ID number in a format error. So a
/// report sends the error's runtime type as its reason and the stack trace,
/// and nothing else. Never `error.toString()`, never a message, never a
/// reason line or information lines. That is also why the framework handler
/// is not `recordFlutterFatalError`: it sends `exceptionAsString()`, the
/// error's context and its information lines, any of which can hold what she
/// typed. The fatal report made here is the same report with those removed.
///
/// What else a report may carry, all from closed vocabularies and none about
/// her, and only once she has allowed crash reports:
///
///   * three custom keys: [CrashKey.screenId] (the screen the error happened
///     on, or `private` for a screen whose id would say something about her
///     body, such as the cycle screens), [CrashKey.appVersion] (the version
///     `tool/build_release.sh` builds) and [CrashKey.buildChannel];
///   * breadcrumb lines from [CrashTrail], each a fixed word plus at most a
///     screen id;
///   * a non-fatal report when a server call fails in a way that is a bug
///     rather than a dropped connection, named by its status code only.
///
/// No user identifier is ever set. The guard is
/// test/release/crash_reporting_privacy_test.dart.
library;

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import '../features/signup/domain/legal_acceptance.dart' show kAppVersion;
import 'crash_consent.dart';
import 'firebase_boot.dart';

/// What is sent in place of the error: its type name, as text.
@immutable
class ScrubbedError {
  const ScrubbedError(this.type);

  final String type;

  @override
  String toString() => type;
}

/// A server call that failed with a status that means a bug: the code is
/// one of [CrashReports.serverCodesReported] and nothing else.
@immutable
class ServerCallFailure {
  const ServerCallFailure(this.code);

  final String code;
}

/// The custom keys a report may carry. Nothing else is ever set.
enum CrashKey { screenId, appVersion, buildChannel }

/// The breadcrumb lines a report may carry. Each is a fixed word; only
/// [screen] carries anything more, and that is a screen id.
enum CrashTrail { screen, resumed, appCheckFailed }

abstract final class CrashReports {
  /// [error] reduced to its runtime type. A [FlutterErrorDetails] is reduced
  /// as itself, so its exception, context and information never travel. A
  /// [ServerCallFailure] keeps its status code, which is one word from a
  /// closed list.
  static ScrubbedError scrub(Object error) => switch (error) {
    ServerCallFailure(:final code) when serverCodesReported.contains(code) =>
      ScrubbedError('ServerCallFailure.$code'),
    _ => ScrubbedError(error.runtimeType.toString()),
  };

  /// Whether a report may be made at all: only once she has allowed crash
  /// reports (privacy policy v3, 3.7). Read on every error, so turning the
  /// switch off stops the next report, not the next launch's.
  static bool get allowed => CrashConsent.instance.allowed;

  /// Whether Crashlytics is wired in this build ([FirebaseBoot.crashReporting]).
  /// False in a debug run and in every test, so the keys, the breadcrumbs and
  /// the non-fatal reports below never touch the plugin there.
  static bool get wired => FirebaseBoot.crashReporting;

  /// A framework error, fatal. Its stack only, and only with her consent.
  static Future<void> flutterError(FlutterErrorDetails details) async {
    if (!allowed) return;
    await FirebaseCrashlytics.instance.recordError(
      scrub(details.exception),
      details.stack,
      fatal: true,
      printDetails: false,
    );
  }

  /// An uncaught error, fatal: from [PlatformDispatcher.onError] or the root
  /// isolate's error listener. Its type and stack only, and only with her
  /// consent.
  static Future<void> uncaught(Object error, StackTrace stack) async {
    if (!allowed) return;
    await FirebaseCrashlytics.instance.recordError(
      scrub(error),
      stack,
      fatal: true,
      printDetails: false,
    );
  }

  /// The status codes of a failed server call that mean something is wrong
  /// with Own Hub rather than with her connection or her sign-in: reported as
  /// a non-fatal so the team sees a broken function before she has to say
  /// so. `unavailable` and `deadline-exceeded` (offline), `unauthenticated`,
  /// `permission-denied`, `failed-precondition` (an old copy of the app, a
  /// check still running) and `resource-exhausted` (a daily limit) are
  /// expected answers and are not reported.
  static const Set<String> serverCodesReported = {
    'internal',
    'unknown',
    'data-loss',
    'unimplemented',
    'not-found',
    'invalid-argument',
    'out-of-range',
    'aborted',
  };

  /// A failed server call, non-fatal, named by its status [code] only. The
  /// server's message is never sent: it can name her case.
  static Future<void> serverError(String code) async {
    if (!allowed || !wired || !serverCodesReported.contains(code)) return;
    try {
      await FirebaseCrashlytics.instance.recordError(
        scrub(ServerCallFailure(code)),
        StackTrace.current,
        fatal: false,
        printDetails: false,
      );
    } catch (_) {}
  }

  /// Sets one custom key from its closed vocabulary.
  static Future<void> _key(CrashKey key, String value) async {
    if (!allowed || !wired) return;
    try {
      await FirebaseCrashlytics.instance.setCustomKey(switch (key) {
        CrashKey.screenId => 'screen_id',
        CrashKey.appVersion => 'app_version',
        CrashKey.buildChannel => 'build_channel',
      }, value);
    } catch (_) {}
  }

  /// The version and channel of this build, once per launch and again when
  /// she allows crash reports.
  static Future<void> describeBuild({required String channel}) async {
    await _key(CrashKey.appVersion, kAppVersion);
    await _key(CrashKey.buildChannel, channel);
  }

  static final RegExp _screenIdShape = RegExp(r'^[A-Z]{1,2}[0-9]{2}[a-z]?$');

  /// The screen she is on, as a key and a breadcrumb. [screenId] is a screen
  /// id or `private`; anything else is sent as `private`.
  static Future<void> screen(String screenId) async {
    final id = _screenIdShape.hasMatch(screenId) ? screenId : 'private';
    await _key(CrashKey.screenId, id);
    await trail(CrashTrail.screen, screenId: id);
  }

  /// One breadcrumb line: a fixed word, and a screen id for [CrashTrail.screen].
  static Future<void> trail(CrashTrail what, {String? screenId}) async {
    if (!allowed || !wired) return;
    final line = switch (what) {
      CrashTrail.screen => 'screen ${screenId ?? 'private'}',
      CrashTrail.resumed => 'resumed',
      CrashTrail.appCheckFailed => 'app check failed',
    };
    try {
      await FirebaseCrashlytics.instance.log(line);
    } catch (_) {}
  }
}
