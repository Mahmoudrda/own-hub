import 'package:firebase_core/firebase_core.dart';
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

  static BackendStatus get status => _status;

  /// The error that stopped Firebase, or null. For honest error copy and for
  /// the console in a debug build, never for display verbatim to a woman.
  static Object? get failure => _failure;

  /// True when it is worth attempting a network call at all.
  static bool get isReady => _status == BackendStatus.ready;

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
    }
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
  }
}
