/// Phone sign-in against Firebase Authentication.
///
/// This implements [AuthRepository] and nothing else. `C06` and `C07` were
/// written against that interface and are not touched by this file: they hand a
/// number in, hand six digits in, and read [AuthRepository.current]. Swapping
/// [FakeAuthRepository] for this class is one line in the router, and if this
/// file ever needs a screen changed to work, the interface is wrong rather than
/// the screen.
///
/// Three things here are not obvious and are the reason the file is long:
///
///  * **`verifyPhoneNumber` reports through callbacks, not through its own
///    future.** The future it returns completes when the request has been
///    handed to the platform, which is well before Firebase has decided the
///    number is real or that a message has gone out. `C06` promises to move her
///    on "only after the provider has accepted the number and sent a code", so
///    [sendCode] waits for `codeSent` instead.
///  * **Android can finish the whole thing with no code typed.** Play Services
///    reads the message itself and fires `verificationCompleted`, sometimes
///    before `codeSent` and sometimes while she is already staring at the six
///    boxes. Both orders are handled below, and [confirmCode] treats a code
///    typed on top of a finished sign-in as agreement rather than as an error.
///  * **Firebase may not be there at all.** `FirebaseBoot` is built so a failed
///    init never stops the app opening, which means this class can be
///    constructed with no Firebase behind it. It then answers
///    [AuthFailure.network] to anything that needs the network, and never
///    throws on construction — a woman with a broken Play Services still gets
///    to the sign-in screen and is told plainly that it cannot be done now.
library;

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

import '../../../app_state/firebase_boot.dart';
import '../domain/auth_repository.dart';

/// Egypt's country calling code, without the plus.
const String _egyptDiallingCode = '20';

/// Digits in an Egyptian mobile number once the country code and the trunk
/// zero are off. Every one of them starts with `1` (the operators use 010,
/// 011, 012 and 015), which is the only structural rule checked here — the
/// exact operator prefixes are a commercial fact that changes without warning,
/// and a normaliser that rejects a number the network happily routes is worse
/// than one that lets Firebase have the last word.
const int _egyptianMobileDigits = 10;

/// How long we wait for Firebase to say anything at all about a send.
///
/// `verifyPhoneNumber` answers only through its callbacks, and on a handset
/// that has bars but no route to Google (a captive hotel wifi, a carrier
/// blocking the endpoint) none of them ever fire. `C06` disables its button
/// while a send is in flight, so a callback that never arrives is a dead screen
/// until she force-quits the app. Sixty seconds is twice the auto-retrieval
/// window asked for below, so this can only ever fire after Android has already
/// given up on reading the message by itself.
const Duration _sendTimeout = Duration(seconds: 60);

/// How long Android may go on listening for the message on her behalf.
///
/// Firebase's own default. It is not a deadline for her: when it lapses,
/// `codeAutoRetrievalTimeout` fires, the verification id stays valid, and she
/// types the six digits like anyone on an iPhone.
const Duration _autoRetrievalTimeout = Duration(seconds: 30);

/// Everything she might type, as one E.164 number, or [AuthFailure.invalidNumber].
///
/// `C06` fixes the dialling code beside the field and already drops a leading
/// zero, so the common path arrives here correct. This is deliberately more
/// forgiving than that, because the number can also arrive from autofill, from
/// a contact card, or from a screen written later by someone who did not read
/// `C06`. Accepted, all meaning the same woman:
///
///     01001234567      as she dials it at home
///     1001234567       national, trunk zero already dropped
///     +20 100 123 4567 as it is printed on a card
///     +2 0100 123 4567 the way half of Egypt writes it
///     0020100123456 7  the international prefix dialled from a landline
///     ٠١٠٠١٢٣٤٥٦٧      Arabic-Indic digits from an Arabic keyboard
///
/// The Arabic-Indic case cannot be produced by `C06` today, because that screen
/// filters the field to ASCII digits before it decides whether the button is
/// live. It is handled anyway: the app is used in Arabic by most of the women
/// it is for, and a number that is silently rejected as "too short" while it
/// plainly reads as eleven digits on screen is the kind of defect nobody can
/// report usefully.
String egyptianE164(String input) {
  var digits = asciiDigits(input);

  // `00` is how an international number is dialled from inside Egypt, so it
  // arrives on pasted numbers far more often than a plus does.
  if (digits.startsWith('00')) {
    digits = digits.substring(2);
  }

  // Unambiguous: no Egyptian mobile begins with 2, with or without its trunk
  // zero, so a leading 20 on a number this long can only be the country code.
  if (digits.startsWith(_egyptDiallingCode) &&
      digits.length > _egyptianMobileDigits) {
    digits = digits.substring(_egyptDiallingCode.length);
  }

  // The trunk prefix. It is how she dials the number and is not part of it:
  // `+200100…` is not a number anyone can reach.
  if (digits.startsWith('0')) {
    digits = digits.substring(1);
  }

  if (!RegExp('^1[0-9]{${_egyptianMobileDigits - 1}}\$').hasMatch(digits)) {
    throw const AuthException(AuthFailure.invalidNumber);
  }
  return '+$_egyptDiallingCode$digits';
}

/// The digits in [input], with Arabic-Indic and Persian forms folded onto
/// `0`–`9` and everything else dropped.
///
/// Exposed because both the number and the six-digit code need it: an Arabic
/// keyboard produces `٠١٢`, and `int.parse` and Firebase alike only read ASCII.
String asciiDigits(String input) {
  const int ascii0 = 0x30;
  const int arabicIndic0 = 0x0660;
  const int extendedArabicIndic0 = 0x06F0;

  final buffer = StringBuffer();
  for (final rune in input.runes) {
    if (rune >= ascii0 && rune <= ascii0 + 9) {
      buffer.writeCharCode(rune);
    } else if (rune >= arabicIndic0 && rune <= arabicIndic0 + 9) {
      buffer.writeCharCode(ascii0 + rune - arabicIndic0);
    } else if (rune >= extendedArabicIndic0 && rune <= extendedArabicIndic0 + 9) {
      buffer.writeCharCode(ascii0 + rune - extendedArabicIndic0);
    }
  }
  return buffer.toString();
}

class FirebaseAuthRepository implements AuthRepository {
  /// [auth] is for tests, which pass a stand-in so nothing reaches the network.
  /// In the app it is left null and resolved from [FirebaseBoot], which may
  /// legitimately have nothing to give.
  FirebaseAuthRepository({FirebaseAuth? auth}) : _auth = auth ?? _resolveAuth() {
    final firebase = _auth;
    if (firebase == null) return;

    // A session that survived the last launch. Firebase restores it from disk
    // before the first frame, so reading it here means a returning woman is
    // already signed in by the time anything asks.
    final user = firebase.currentUser;
    if (user != null) {
      _state = AuthState.signedIn(uid: user.uid);
    }

    // The single source of truth for "is she in". Everything that signs her in,
    // a code she typed, a message Android read for her, a session restored on
    // another screen, arrives here, so there is one place that decides.
    _authSubscription = firebase.authStateChanges().listen(_onUserChanged);
  }

  /// Null when Firebase never came up. Not an error: see the file header.
  static FirebaseAuth? _resolveAuth() {
    if (!FirebaseBoot.isReady) return null;
    try {
      return FirebaseAuth.instance;
    } catch (_) {
      // `isReady` said yes and the plugin still refused. Nothing to do about
      // it here, and it must not take the app down on the way past.
      return null;
    }
  }

  final FirebaseAuth? _auth;
  final _controller = StreamController<AuthState>.broadcast();
  StreamSubscription<User?>? _authSubscription;

  AuthState _state = const AuthState.signedOut();

  /// The handle Firebase gives us for the message it sent. Without it a typed
  /// code cannot be checked against anything.
  String? _verificationId;

  /// Firebase's own token for "this is the same attempt, send it again".
  /// Passing it back is what stops a resend being treated as a fresh request
  /// and burning through her daily quota twice as fast.
  int? _resendToken;

  /// What [resendCode] sends to, since the interface does not pass it again.
  String? _lastNumber;

  @override
  AuthState get current => _state;

  @override
  Stream<AuthState> watch() async* {
    yield _state;
    yield* _controller.stream;
  }

  @override
  Future<void> sendCode(String phoneNumber) async {
    // Thrown before anything is dialled, so a typo costs nothing and counts
    // against no quota.
    final number = egyptianE164(phoneNumber);

    _lastNumber = number;
    _verificationId = null;
    _resendToken = null;
    await _requestCode(number, resendToken: null);
  }

  @override
  Future<void> resendCode() async {
    final number = _lastNumber;
    if (number == null) {
      // Nothing was ever sent, so there is nothing to send again. Reaching
      // this means `C07` was opened without going through `C06`, which is a
      // routing fault rather than anything she did.
      throw const AuthException(AuthFailure.unknown);
    }
    await _requestCode(number, resendToken: _resendToken);
  }

  @override
  Future<void> confirmCode(String code) async {
    // Android may already have read the message and signed her in while she
    // was still typing. `C07` cannot know that — it holds no subscription —
    // so it will happily submit the six digits it has. Treating that as an
    // error would clear her boxes and strand a woman who is, in fact, in.
    if (_state is AuthSignedIn) return;

    final digits = asciiDigits(code);
    if (digits.length != kVerificationCodeLength) {
      throw const AuthException(AuthFailure.invalidCode);
    }

    final verificationId = _verificationId;
    if (verificationId == null) {
      // We hold no message to check against. Either none was sent, or the
      // attempt was thrown away when she signed out. The remedy in both cases
      // is the one the expired-code state already asks for: send it again.
      throw const AuthException(AuthFailure.codeExpired);
    }

    await _signIn(
      PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: digits,
      ),
    );
  }

  @override
  Future<void> signOut() async {
    _verificationId = null;
    _resendToken = null;
    _lastNumber = null;

    final auth = _auth;
    if (auth == null) {
      _emit(const AuthState.signedOut());
      return;
    }

    try {
      await auth.signOut();
    } on FirebaseAuthException catch (error) {
      // Not swallowed. If Firebase still holds the session, showing her a
      // signed-out app is a lie, and on a shared handset it is the dangerous
      // kind of lie.
      throw AuthException(_failureOf(error));
    } catch (_) {
      throw const AuthException(AuthFailure.unknown);
    }

    // `authStateChanges` will say the same thing a moment later. Saying it
    // here means `current` is right the instant the call returns, which is
    // what a caller that awaits sign-out and then rebuilds expects.
    _emit(const AuthState.signedOut());
  }

  /// Stops listening. Call it when the repository outlives its usefulness;
  /// the app's single instance never does.
  Future<void> dispose() async {
    await _authSubscription?.cancel();
    await _controller.close();
  }

  // ------------------------------------------------------------------ inside

  /// One send, first or repeat.
  ///
  /// Resolves when Firebase has accepted the number and put a message on its
  /// way, or when Android has finished the job outright. Throws otherwise.
  Future<void> _requestCode(String number, {required int? resendToken}) async {
    final auth = _auth;
    if (auth == null) {
      // Firebase never came up. This is the one honest answer: there is no
      // route to a provider, which is what `network` means to the UI.
      throw const AuthException(AuthFailure.network);
    }

    // Every exit from this method goes through here, which is what keeps a
    // callback that fires twice, or fires after a failure, from completing
    // the same future twice.
    final sent = Completer<void>();
    void succeed() {
      if (!sent.isCompleted) sent.complete();
    }

    void fail(AuthFailure failure) {
      if (!sent.isCompleted) sent.completeError(AuthException(failure));
    }

    try {
      await auth.verifyPhoneNumber(
        phoneNumber: number,
        timeout: _autoRetrievalTimeout,
        // Null on a first send. On a resend this is what tells Firebase to
        // send another message for the same attempt rather than start a new
        // one, which is the difference between one entry in her quota and two.
        forceResendingToken: resendToken,
        verificationCompleted: (credential) {
          // Android only, and only on a handset where Play Services could both
          // read the message and match the app's signing fingerprint. She has
          // typed nothing. Sign her in and let the send resolve so `C06` stops
          // spinning; the state stream is what moves her past `C07`.
          unawaited(
            _signIn(credential).then(
              (_) => succeed(),
              onError: (Object _) {
                // The automatic path failed, but a message is still on its way
                // and she can type it. Resolving as a normal send is therefore
                // truthful: a code was sent.
                succeed();
              },
            ),
          );
        },
        verificationFailed: (error) => fail(_failureOf(error)),
        codeSent: (verificationId, forceResendingToken) {
          _verificationId = verificationId;
          _resendToken = forceResendingToken;
          // Guarded, because on Android `verificationCompleted` can beat this
          // callback. Knocking a signed-in woman back to "waiting for a code"
          // would send her to `C07` for a code she does not need.
          if (_state is! AuthSignedIn) {
            _emit(AuthState.awaitingCode(phoneNumber: number));
          }
          succeed();
        },
        codeAutoRetrievalTimeout: (verificationId) {
          // Android stopped listening for the message by itself. The id it
          // hands back is still good, so all that changes is that she types
          // the digits. Nothing on screen needs to move.
          _verificationId = verificationId;
        },
      );
    } on FirebaseAuthException catch (error) {
      fail(_failureOf(error));
    } catch (_) {
      fail(AuthFailure.unknown);
    }

    return sent.future.timeout(
      _sendTimeout,
      onTimeout: () => throw const AuthException(AuthFailure.network),
    );
  }

  /// Exchanges a credential for a session. The one place she becomes signed in.
  Future<void> _signIn(AuthCredential credential) async {
    final auth = _auth;
    if (auth == null) throw const AuthException(AuthFailure.network);

    final UserCredential result;
    try {
      result = await auth.signInWithCredential(credential);
    } on FirebaseAuthException catch (error) {
      throw AuthException(_failureOf(error));
    } catch (_) {
      throw const AuthException(AuthFailure.unknown);
    }

    final uid = result.user?.uid;
    if (uid == null) {
      // Firebase accepted the credential and returned no user. It should not
      // happen; if it does, she is not signed in and must not be told she is.
      throw const AuthException(AuthFailure.unknown);
    }

    // Spent. Keeping it would let a second submission replay a credential
    // Firebase has already consumed, which fails with a misleading code.
    _verificationId = null;
    _resendToken = null;
    _emit(AuthState.signedIn(uid: uid));
  }

  void _onUserChanged(User? user) {
    if (user != null) {
      _emit(AuthState.signedIn(uid: user.uid));
      return;
    }

    // A null is the stream's opening event as often as it is a sign-out, and
    // it lands while she is part-way through typing a code. Only a woman who
    // was signed in a moment ago has actually been signed out.
    if (_state is AuthSignedIn) {
      _emit(const AuthState.signedOut());
    }
  }

  void _emit(AuthState next) {
    // Firebase repeats itself: a sign-in is announced by `signInWithCredential`
    // returning and again by `authStateChanges`. A router listening for
    // `AuthSignedIn` would push the next screen twice.
    if (_isSame(_state, next)) return;
    _state = next;
    if (!_controller.isClosed) _controller.add(next);
  }

  static bool _isSame(AuthState current, AuthState next) =>
      switch ((current, next)) {
        (AuthSignedOut _, AuthSignedOut _) => true,
        (AuthSignedIn first, AuthSignedIn second) => first.uid == second.uid,
        (AuthAwaitingCode first, AuthAwaitingCode second) =>
          first.phoneNumber == second.phoneNumber,
        _ => false,
      };
}

/// Firebase's error code, as one of the six things the UI knows how to be.
///
/// The codes are the documented ones from the Auth REST API and the two mobile
/// SDKs. Every arm that resolves to [AuthFailure.unknown] is written out rather
/// than left to the default, because "which of these did we decide we cannot
/// act on" is the question anyone reading this next will have, and a default
/// arm answers it with silence.
AuthFailure _failureOf(FirebaseAuthException error) => switch (error.code) {
  // She mistyped, or the number is not routable. `egyptianE164` catches most
  // of these first; this is Firebase disagreeing with it, and Firebase wins.
  'invalid-phone-number' || 'missing-phone-number' => AuthFailure.invalidNumber,

  // Wrong six digits.
  'invalid-verification-code' => AuthFailure.invalidCode,

  // The attempt is over: the code aged out, or the verification id no longer
  // refers to anything. Both are fixed by sending again, which is exactly what
  // the expired-code state tells her to do.
  'invalid-verification-id' ||
  'session-expired' ||
  'code-expired' => AuthFailure.codeExpired,

  // Two different walls, same answer: `too-many-requests` is Firebase's abuse
  // detection on this device or number, `quota-exceeded` is the project's own
  // daily SMS allowance gone. She can do nothing but wait, and the copy for
  // waiting already exists.
  'too-many-requests' || 'quota-exceeded' => AuthFailure.tooManyAttempts,

  'network-request-failed' => AuthFailure.network,

  // Android release builds with no fingerprint registered. The SHA-1 and
  // SHA-256 of the signing key must be on the Firebase project or phone auth
  // is refused outright for every woman on that build. There is nothing she
  // can do and nothing worth telling her to try — this is ours to fix, and it
  // is why the release keystore's fingerprints are a ship blocker.
  'app-not-authorized' => AuthFailure.unknown,

  // iOS with no APNs key and no reCAPTCHA fallback configured, so Firebase has
  // no way to prove the request came from our app. Again ours, not hers.
  'missing-client-identifier' => AuthFailure.unknown,

  // The reCAPTCHA challenge failed or she closed the web view it opens. Not a
  // wrong number and not a wrong code, and the flow has no cancelled state to
  // put her in, so it is honestly unknown: the screen keeps her number and she
  // can try again.
  'captcha-check-failed' || 'web-context-cancelled' => AuthFailure.unknown,

  // Phone sign-in switched off on the project, or this account disabled. Both
  // are decisions made somewhere other than this handset.
  'operation-not-allowed' || 'user-disabled' => AuthFailure.unknown,

  _ => AuthFailure.unknown,
};
