/// Phone sign-in: a number, then a six-digit code.
///
/// No password. A password is one more thing to forget and one more thing to
/// leak, and the phone is already the second factor.
///
/// **The code is six digits** (`DECISIONS.md` D2a). Firebase phone auth sends
/// six and the length is not configurable, so [kVerificationCodeLength] is the
/// single place that number lives — the screen builds its boxes from it and the
/// validator checks against it, which is what stops the UI promising a length
/// the backend does not send.
library;

import 'dart:async';

import 'package:meta/meta.dart';

/// Six. Not a preference — it is what the provider sends.
const int kVerificationCodeLength = 6;

/// Where a sign-in attempt has got to.
@immutable
sealed class AuthState {
  const AuthState();

  const factory AuthState.signedOut() = AuthSignedOut;

  /// A code has been sent and we are waiting for her to type it, or for the
  /// phone to read it for her.
  const factory AuthState.awaitingCode({required String phoneNumber}) =
      AuthAwaitingCode;

  const factory AuthState.signedIn({required String uid}) = AuthSignedIn;
}

class AuthSignedOut extends AuthState {
  const AuthSignedOut();
}

class AuthAwaitingCode extends AuthState {
  const AuthAwaitingCode({required this.phoneNumber});

  /// Shown back to her on the code screen, so a mistyped number is obvious
  /// before she waits for a message that will never arrive.
  final String phoneNumber;
}

class AuthSignedIn extends AuthState {
  const AuthSignedIn({required this.uid});
  final String uid;
}

/// Why an attempt failed, in terms the UI can act on.
///
/// Deliberately not a raw provider error: those are English, technical, and
/// occasionally leak the phone number into a log.
enum AuthFailure {
  invalidNumber,
  invalidCode,
  codeExpired,
  tooManyAttempts,
  network,
  unknown,
}

class AuthException implements Exception {
  const AuthException(this.failure);
  final AuthFailure failure;

  @override
  String toString() => 'AuthException(${failure.name})';
}

abstract class AuthRepository {
  Stream<AuthState> watch();

  AuthState get current;

  /// Sends a code to [phoneNumber] in full international form (`+20…`).
  ///
  /// Throws [AuthException] rather than returning a flag, so a caller cannot
  /// forget to check.
  Future<void> sendCode(String phoneNumber);

  /// Confirms the code. On success the stream moves to [AuthSignedIn].
  Future<void> confirmCode(String code);

  /// Sends it again. Separate from [sendCode] so the UI can rate-limit the
  /// resend without blocking a first attempt.
  Future<void> resendCode();

  Future<void> signOut();
}

/// An in-memory implementation for tests and for building screens before there
/// is a Firebase project.
///
/// It is deliberately strict — it enforces the six-digit length and the failure
/// modes — because a fake that accepts anything lets a screen pass its tests and
/// then fail against the real provider.
/// The code this build actually accepts, when there is one to name.
///
/// Null against a real provider, because there is no such code — only the one
/// in the message she was sent. `C07` shows it only while no account is
/// required, which is the same gate every other test affordance sits behind.
String? testCodeOf(AuthRepository repository) =>
    repository is FakeAuthRepository ? repository.codeToAccept : null;

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.codeToAccept = '417293'});

  /// The code this fake treats as correct.
  final String codeToAccept;

  final _controller = StreamController<AuthState>.broadcast();
  AuthState _state = const AuthState.signedOut();

  /// Every number a code was sent to, so a test can assert what was dialled.
  final List<String> sentTo = [];
  int resendCount = 0;

  @override
  AuthState get current => _state;

  @override
  Stream<AuthState> watch() async* {
    yield _state;
    yield* _controller.stream;
  }

  void _emit(AuthState next) {
    _state = next;
    _controller.add(next);
  }

  @override
  Future<void> sendCode(String phoneNumber) async {
    final digits = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    // An Egyptian mobile is 10 digits after the country code.
    if (digits.length < 11) {
      throw const AuthException(AuthFailure.invalidNumber);
    }
    sentTo.add(phoneNumber);
    _emit(AuthState.awaitingCode(phoneNumber: phoneNumber));
  }

  @override
  Future<void> confirmCode(String code) async {
    if (code.length != kVerificationCodeLength) {
      throw const AuthException(AuthFailure.invalidCode);
    }
    if (code != codeToAccept) {
      throw const AuthException(AuthFailure.invalidCode);
    }
    _emit(const AuthState.signedIn(uid: 'fake-uid'));
  }

  @override
  Future<void> resendCode() async {
    resendCount++;
    if (resendCount > 3) throw const AuthException(AuthFailure.tooManyAttempts);
  }

  @override
  Future<void> signOut() async => _emit(const AuthState.signedOut());

  Future<void> dispose() => _controller.close();
}
