import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';

/// Whether the back end came up, and what to do when it did not.
///
/// This app was built offline-first and must stay that way. Her week is read
/// off the handset before the first frame (`LocalPersistence`), and every
/// screen already draws from that. Firebase is therefore an ADDITION to a
/// working app, never a precondition for one: a woman on the Cairo metro with
/// no signal, or on a phone where Play Services is broken, still opens the app
/// and still sees her own training.
enum BackendStatus {
  /// `start()` has not run. The state inside a widget test, which never calls
  /// `main()`, and the reason nothing here asserts on being initialised.
  notAttempted,

  /// Firebase is up. Auth, Firestore and Storage may be used.
  ready,

  /// Firebase did not come up. The app runs on local data alone. Anything
  /// that needs the network must say so plainly rather than hang or pretend.
  unavailable,
}

/// The region every callable is deployed to. The functions run in Frankfurt
/// beside Firestore; a client pointed anywhere else gets `not-found`.
const String kFunctionsRegion = 'europe-west3';

/// A debug App Check token registered in the Firebase console, passed with
/// `--dart-define=OWNHUB_APP_CHECK_DEBUG_TOKEN=...`. Empty means the SDK makes
/// one up and logs it (logcat on Android, the Xcode console on iOS) so it can
/// be registered. Only ever read in a debug or profile build.
const String _kAppCheckDebugToken = String.fromEnvironment(
  'OWNHUB_APP_CHECK_DEBUG_TOKEN',
);

/// The host running the local Firebase emulators, for example `10.0.2.2` from
/// an Android emulator. Honoured in debug builds only; a release build always
/// talks to production.
const String _kEmulatorHost = String.fromEnvironment('OWNHUB_EMULATOR_HOST');

/// Which App Check providers a build attests with.
///
/// Pulled out as a value so the choice can be tested without platform
/// channels: the one mistake that matters here is a release build shipping
/// with a debug provider, which would let anyone holding the token through
/// App Check.
@immutable
class AppCheckChoice {
  const AppCheckChoice({required this.android, required this.apple});

  final AndroidAppCheckProvider android;
  final AppleAppCheckProvider apple;
}

/// Brings Firebase up without ever being able to fail the launch.
///
/// `Firebase.initializeApp` throws on a surprising number of real phones: a
/// missing or stale `google-services.json`, a Play Services version the plugin
/// will not talk to, a clock far enough out that the token exchange is
/// rejected. Every one of those is a crash on the very first frame if it is
/// left to propagate, and a crash before Home is the worst possible first
/// impression of a product whose entire promise is that it is safe.
///
/// So the failure is caught, recorded and shown to the parts of the app that
/// need to know. It is deliberately NOT swallowed silently: [failure] is kept
/// so a screen that needs the network can say what went wrong instead of
/// spinning forever.
abstract final class FirebaseBoot {
  static BackendStatus _status = BackendStatus.notAttempted;
  static Object? _failure;
  static Object? _appCheckFailure;
  static FirebaseFunctions? _functions;

  static BackendStatus get status => _status;

  /// The error that stopped Firebase, or null. For honest error copy and for
  /// the console in a debug build, never for display verbatim to a woman.
  static Object? get failure => _failure;

  /// The error that stopped App Check from activating, or null. Firebase can
  /// be up while App Check is not; every callable will then be refused by the
  /// server (`ENFORCE_APP_CHECK` is on), and the screen that made the call
  /// says so. Kept for the debug console, never shown verbatim.
  static Object? get appCheckFailure => _appCheckFailure;

  /// True when it is worth attempting a network call at all.
  static bool get isReady => _status == BackendStatus.ready;

  static bool _crashReporting = false;

  /// Whether crash reports are being collected: a release build whose
  /// Firebase started. False in every debug run and every test.
  static bool get crashReporting => _crashReporting;

  /// Whether a build collects crash reports. Release only.
  @visibleForTesting
  static bool crashCollectionFor({required bool release}) => release;

  static Future<void> start() async {
    if (_status != BackendStatus.notAttempted) return;
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      _status = BackendStatus.ready;
    } catch (error, stack) {
      _status = BackendStatus.unavailable;
      _failure = error;
      // Printed only in debug. In release this is silent by design: a woman
      // gets honest copy from the screen that needed the network, not a
      // stack trace, and nothing about her is sent anywhere to report it.
      if (kDebugMode) {
        debugPrint('Firebase did not start: $error\n$stack');
      }
      return;
    }

    // App Check, immediately after initializeApp and before anything can call
    // a function. The server enforces it on every callable, so without this
    // no build reaches sign-up's back end at all. Its own try, because a
    // failure here must not fail the launch either: the app still opens on
    // local data, and the callable that is refused says so honestly.
    try {
      final choice = appCheckChoiceFor(release: kReleaseMode);
      await FirebaseAppCheck.instance.activate(
        providerAndroid: choice.android,
        providerApple: choice.apple,
      );
    } catch (error, stack) {
      _appCheckFailure = error;
      if (kDebugMode) {
        debugPrint('App Check did not activate: $error\n$stack');
      }
    }

    // Crash reports, in a release build only. Collection is off in the native
    // config (AndroidManifest meta-data, Info.plist) so nothing is sent before
    // this line, and a debug or profile build never turns it on. Nothing
    // about her is attached: no user identifier, no custom key, no log line.
    try {
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
        crashCollectionFor(release: kReleaseMode),
      );
      _crashReporting = kReleaseMode;
    } catch (error) {
      if (kDebugMode) debugPrint('Crash reporting not configured: $error');
    }

    if (kDebugMode && _kEmulatorHost.isNotEmpty) {
      try {
        await FirebaseAuth.instance.useAuthEmulator(_kEmulatorHost, 9299);
        FirebaseFirestore.instance.useFirestoreEmulator(_kEmulatorHost, 8288);
      } catch (error) {
        debugPrint('Emulators not wired: $error');
      }
    }
  }

  /// The App Check providers for a build.
  ///
  /// Chosen by [kReleaseMode] at the call site, never by a feature flag: a
  /// store build attests with Play Integrity and App Attest (DeviceCheck on
  /// the older phones App Attest does not cover), and only a debug or profile
  /// build uses the debug providers.
  @visibleForTesting
  static AppCheckChoice appCheckChoiceFor({
    required bool release,
    String debugToken = _kAppCheckDebugToken,
  }) {
    if (release) {
      return const AppCheckChoice(
        android: AndroidPlayIntegrityProvider(),
        apple: AppleAppAttestWithDeviceCheckFallbackProvider(),
      );
    }
    final token = debugToken.isEmpty ? null : debugToken;
    return AppCheckChoice(
      android: AndroidDebugProvider(debugToken: token),
      apple: AppleDebugProvider(debugToken: token),
    );
  }

  /// Cloud Functions in [kFunctionsRegion], pointed at the local emulator in a
  /// debug build started with `OWNHUB_EMULATOR_HOST`.
  ///
  /// Every callable client goes through this, so the region and the emulator
  /// wiring live in one place. It touches Firebase, so read it only when a
  /// call is about to be made, never in a constructor that a widget test
  /// builds.
  static FirebaseFunctions get functions {
    final existing = _functions;
    if (existing != null) return existing;
    final created = FirebaseFunctions.instanceFor(region: kFunctionsRegion);
    if (kDebugMode && _kEmulatorHost.isNotEmpty) {
      created.useFunctionsEmulator(_kEmulatorHost, 5101);
    }
    return _functions = created;
  }

  /// Anything that belongs to a woman: her progress photographs, and the ID
  /// and selfie while a verification is in flight.
  ///
  /// This is a SECOND bucket, in `europe-west3`, beside the Firestore database
  /// that holds the rest of her. The default bucket is in `us-east1` because
  /// that is where Google's free five gigabytes live, and free was the right
  /// call for the content library, which belongs to nobody. It is the wrong
  /// call for her body and her national ID. Twelve cents a month buys not
  /// having to write "processed in the United States" on a privacy page
  /// written for Egyptian women, so her things live in Frankfurt with the
  /// rest of her data and one jurisdiction covers all of it.
  static FirebaseStorage get personalMedia =>
      FirebaseStorage.instanceFor(bucket: 'gs://own-hub-personal');

  /// Exercise images, recipe photographs, anything from the authored library.
  /// The default bucket, `us-east1`, on the free tier. None of it is personal
  /// and all of it is identical for every woman, so region is a latency
  /// question here and nothing more.
  static FirebaseStorage get library => FirebaseStorage.instance;

  @visibleForTesting
  static void resetForTest() {
    _status = BackendStatus.notAttempted;
    _failure = null;
    _appCheckFailure = null;
    _functions = null;
    _crashReporting = false;
  }
}
