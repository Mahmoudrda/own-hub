library;

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

import 'payments_repository.dart';

/// Phone re-authentication for a payment address change (spec 4.4).
///
/// Not the app's `AuthRepository`: its state stream drives routing, and this
/// only proves she still holds the phone. `set_coach_instapay_address`
/// refuses unless the token comes from a phone sign-in under five minutes
/// old, so [confirm] re-authenticates and force-refreshes the token.
class FirebasePhoneReauth implements PhoneReauth {
  FirebasePhoneReauth({FirebaseAuth? auth}) : _authOverride = auth;

  final FirebaseAuth? _authOverride;
  String? _verificationId;
  int? _resendToken;
  PhoneAuthCredential? _automatic;

  FirebaseAuth get _fa => _authOverride ?? FirebaseAuth.instance;

  PaymentFailure _failureOf(FirebaseAuthException e) => switch (e.code) {
    'invalid-verification-code' => const PaymentFailure('otp_wrong'),
    'session-expired' || 'code-expired' => const PaymentFailure('otp_expired'),
    'too-many-requests' => const PaymentFailure('too_many_requests'),
    'network-request-failed' => const PaymentFailure('', unreachable: true),
    _ => const PaymentFailure('reauth_failed'),
  };

  @override
  Future<void> sendCode() async {
    final phone = _fa.currentUser?.phoneNumber;
    if (phone == null || phone.isEmpty) {
      throw const PaymentFailure('signed_out');
    }
    final sent = Completer<void>();
    void fail(Object e) {
      if (!sent.isCompleted) sent.completeError(e);
    }

    try {
      await _fa.verifyPhoneNumber(
        phoneNumber: phone,
        timeout: const Duration(seconds: 60),
        forceResendingToken: _resendToken,
        // Android may read the message by itself; the credential is kept and
        // used when she confirms, so she never types a code the phone knew.
        verificationCompleted: (credential) {
          _automatic = credential;
          if (!sent.isCompleted) sent.complete();
        },
        verificationFailed: (e) => fail(_failureOf(e)),
        codeSent: (id, token) {
          _verificationId = id;
          _resendToken = token;
          if (!sent.isCompleted) sent.complete();
        },
        codeAutoRetrievalTimeout: (id) => _verificationId = id,
      );
    } on FirebaseAuthException catch (e) {
      fail(_failureOf(e));
    } catch (_) {
      fail(const PaymentFailure('reauth_failed'));
    }
    return sent.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw const PaymentFailure('', unreachable: true),
    );
  }

  @override
  Future<void> confirm(String code) async {
    final user = _fa.currentUser;
    if (user == null) throw const PaymentFailure('signed_out');
    final id = _verificationId;
    final credential =
        _automatic ??
        (id == null
            ? throw const PaymentFailure('otp_expired')
            : PhoneAuthProvider.credential(verificationId: id, smsCode: code));
    try {
      await user.reauthenticateWithCredential(credential);
      await user.getIdToken(true);
    } on FirebaseAuthException catch (e) {
      throw _failureOf(e);
    }
  }
}
