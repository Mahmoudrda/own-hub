// The real phone sign-in, against a stand-in Firebase.
//
// Nothing here touches a network or a plugin. `_MockFirebaseAuth` implements
// `FirebaseAuth` and hands the test the four callbacks `verifyPhoneNumber` was
// given, so the test can fire them in whatever order a real handset would:
// `codeSent` on an iPhone, `verificationCompleted` before `codeSent` on an
// Android that read the message instantly, `verificationFailed` with any of the
// codes Firebase actually emits.
//
// The two assertions worth the whole file:
//
//  * `sendCode` does not resolve until a code has really gone out. `C06`
//    promises to move her on only then, and a repository that resolves when
//    the request was merely dispatched breaks that promise silently.
//  * a code typed on top of an automatic Android sign-in succeeds. `C07` holds
//    no subscription and cannot know she is already in, so the repository has
//    to be the one that copes.

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/signup/data/firebase_auth_repository.dart';
import 'package:own_hub/features/signup/domain/auth_repository.dart';

void main() {
  group('egyptianE164', () {
    test('accepts every form a woman in Egypt actually types', () {
      const number = '+201001234567';

      expect(egyptianE164('01001234567'), number, reason: 'as she dials it');
      expect(egyptianE164('1001234567'), number, reason: 'trunk zero dropped');
      expect(egyptianE164('+20 100 123 4567'), number, reason: 'off a card');
      expect(egyptianE164('+2 0100 123 4567'), number, reason: 'plus two');
      expect(egyptianE164('00201001234567'), number, reason: 'dialled 00');
      expect(egyptianE164('(010) 0123-4567'), number, reason: 'punctuation');
    });

    test('reads Arabic-Indic digits', () {
      // Most of the women this is for use the app in Arabic, and an Arabic
      // keyboard produces ٠١٢. A number rejected as "too short" while it plainly
      // reads as eleven digits on screen is a defect nobody can report usefully.
      expect(egyptianE164('٠١٠٠١٢٣٤٥٦٧'), '+201001234567');
      expect(egyptianE164('۰۱۰۰۱۲۳۴۵۶۷'), '+201001234567');
    });

    test('refuses what is not an Egyptian mobile', () {
      for (final input in [
        '',
        '0100123456', // one short
        '010012345678', // one long
        '+971501234567', // not Egypt, and this build has no country picker
        '0221234567', // a Cairo landline
        'not a number',
      ]) {
        expect(
          () => egyptianE164(input),
          throwsA(
            isA<AuthException>().having(
              (e) => e.failure,
              'failure',
              AuthFailure.invalidNumber,
            ),
          ),
          reason: input,
        );
      }
    });
  });

  group('sendCode', () {
    test('waits for the code to really go out before it resolves', () async {
      // `verifyPhoneNumber`'s own future completes when the request has been
      // handed to the platform, long before Firebase has decided the number is
      // real. `C06` moves her to `C07` when this resolves, so resolving early
      // sends her to wait for a message that may never be sent.
      final auth = _MockFirebaseAuth();
      final repository = FirebaseAuthRepository(auth: auth);
      addTearDown(repository.dispose);

      var resolved = false;
      final send = repository.sendCode('01001234567').then((_) {
        resolved = true;
      });

      await pumpEventQueue();
      expect(resolved, isFalse, reason: 'nothing has been sent yet');
      expect(repository.current, isA<AuthSignedOut>());

      auth.fireCodeSent('verification-id', 55);
      await send;

      expect(resolved, isTrue);
      expect(repository.current, isA<AuthAwaitingCode>());
      expect(
        (repository.current as AuthAwaitingCode).phoneNumber,
        '+201001234567',
        reason: 'C07 shows this back to her, so it is the normalised number',
      );
    });

    test('normalises before it dials, and asks Android to listen', () async {
      final auth = _MockFirebaseAuth();
      final repository = FirebaseAuthRepository(auth: auth);
      addTearDown(repository.dispose);

      final send = repository.sendCode('0100 123 4567');
      await pumpEventQueue();
      auth.fireCodeSent('verification-id', null);
      await send;

      expect(auth.lastPhoneNumber, '+201001234567');
      expect(auth.lastTimeout, const Duration(seconds: 30));
      expect(
        auth.lastResendToken,
        isNull,
        reason: 'a first send is not a resend',
      );
    });

    test('a bad number never reaches Firebase', () async {
      // A typo must not cost a message or count against her daily quota.
      final auth = _MockFirebaseAuth();
      final repository = FirebaseAuthRepository(auth: auth);
      addTearDown(repository.dispose);

      await expectLater(
        repository.sendCode('0100'),
        throwsA(_failure(AuthFailure.invalidNumber)),
      );
      expect(auth.verifyCalls, 0);
    });

    test('the state stream reports the wait', () async {
      final auth = _MockFirebaseAuth();
      final repository = FirebaseAuthRepository(auth: auth);
      addTearDown(repository.dispose);

      final seen = <AuthState>[];
      final subscription = repository.watch().listen(seen.add);
      addTearDown(subscription.cancel);
      await pumpEventQueue();

      final send = repository.sendCode('01001234567');
      await pumpEventQueue();
      auth.fireCodeSent('verification-id', null);
      await send;
      await pumpEventQueue();

      expect(seen.map((s) => s.runtimeType).toList(), [
        AuthSignedOut,
        AuthAwaitingCode,
      ]);
    });
  });

  group('failures from the provider', () {
    // The codes Firebase really emits, mapped onto the six the UI knows how to
    // be. Anything unmapped has to land on `unknown` rather than on whichever
    // value happens to be first in the enum.
    const mapping = <String, AuthFailure>{
      'invalid-phone-number': AuthFailure.invalidNumber,
      'missing-phone-number': AuthFailure.invalidNumber,
      'too-many-requests': AuthFailure.tooManyAttempts,
      'quota-exceeded': AuthFailure.tooManyAttempts,
      'network-request-failed': AuthFailure.network,
      'session-expired': AuthFailure.codeExpired,
      'code-expired': AuthFailure.codeExpired,
      'invalid-verification-id': AuthFailure.codeExpired,
      // Ours to fix, not hers: no signing fingerprint on the Firebase project.
      'app-not-authorized': AuthFailure.unknown,
      'missing-client-identifier': AuthFailure.unknown,
      'captcha-check-failed': AuthFailure.unknown,
      'operation-not-allowed': AuthFailure.unknown,
      'something-invented-next-year': AuthFailure.unknown,
    };

    for (final entry in mapping.entries) {
      test('${entry.key} reads as ${entry.value.name}', () async {
        final auth = _MockFirebaseAuth();
        final repository = FirebaseAuthRepository(auth: auth);
        addTearDown(repository.dispose);

        final send = repository.sendCode('01001234567');
        await pumpEventQueue();
        auth.fireVerificationFailed(entry.key);

        await expectLater(send, throwsA(_failure(entry.value)));
        expect(
          repository.current,
          isA<AuthSignedOut>(),
          reason: 'a refused send leaves her where she was',
        );
      });
    }

    test('a plugin throwing outright is still an AuthException', () async {
      // `C06` catches `AuthException` and nothing else. A raw PlatformException
      // escaping here would be an unhandled error on the first screen of the
      // account flow.
      final auth = _MockFirebaseAuth()..verifyThrows = StateError('channel');
      final repository = FirebaseAuthRepository(auth: auth);
      addTearDown(repository.dispose);

      await expectLater(
        repository.sendCode('01001234567'),
        throwsA(_failure(AuthFailure.unknown)),
      );
    });
  });

  group('confirmCode', () {
    test('signs her in and says so', () async {
      final auth = _MockFirebaseAuth();
      final repository = FirebaseAuthRepository(auth: auth);
      addTearDown(repository.dispose);

      final seen = <AuthState>[];
      final subscription = repository.watch().listen(seen.add);
      addTearDown(subscription.cancel);

      final send = repository.sendCode('01001234567');
      await pumpEventQueue();
      auth.fireCodeSent('verification-id', null);
      await send;

      await repository.confirmCode('417293');
      await pumpEventQueue();

      expect(repository.current, isA<AuthSignedIn>());
      expect((repository.current as AuthSignedIn).uid, 'uid-1');
      final credential = auth.lastCredential! as PhoneAuthCredential;
      expect(credential.verificationId, 'verification-id');
      expect(credential.smsCode, '417293');
      expect(
        seen.whereType<AuthSignedIn>().length,
        1,
        reason:
            'signInWithCredential and authStateChanges both announce it, and a '
            'router listening for the signed-in state must not push twice',
      );
    });

    test('a wrong code is an invalid code, and she stays on C07', () async {
      final auth = _MockFirebaseAuth()
        ..signInThrows = FirebaseAuthException(
          code: 'invalid-verification-code',
        );
      final repository = FirebaseAuthRepository(auth: auth);
      addTearDown(repository.dispose);

      final send = repository.sendCode('01001234567');
      await pumpEventQueue();
      auth.fireCodeSent('verification-id', null);
      await send;

      await expectLater(
        repository.confirmCode('000000'),
        throwsA(_failure(AuthFailure.invalidCode)),
      );
      expect(repository.current, isA<AuthAwaitingCode>());
    });

    test('a sign-in that never answers is a connection problem, not a '
        'spinner, and the code can be sent again', () async {
      final auth = _MockFirebaseAuth()..signInHangs = Completer<void>();
      final repository = FirebaseAuthRepository(
        auth: auth,
        signInLimit: const Duration(milliseconds: 50),
      );
      addTearDown(repository.dispose);

      final send = repository.sendCode('01001234567');
      await pumpEventQueue();
      auth.fireCodeSent('verification-id', null);
      await send;

      await expectLater(
        repository.confirmCode('417293'),
        throwsA(_failure(AuthFailure.network)),
      );
      expect(repository.current, isA<AuthAwaitingCode>());
      expect(signInTimeout, const Duration(seconds: 30));
    });

    test('fewer than six digits never reaches Firebase', () async {
      final auth = _MockFirebaseAuth();
      final repository = FirebaseAuthRepository(auth: auth);
      addTearDown(repository.dispose);

      final send = repository.sendCode('01001234567');
      await pumpEventQueue();
      auth.fireCodeSent('verification-id', null);
      await send;

      await expectLater(
        repository.confirmCode('4172'),
        throwsA(_failure(AuthFailure.invalidCode)),
      );
      expect(auth.signInCalls, 0);
    });

    test(
      'with nothing sent it reads as expired, not as a wrong code',
      () async {
        // We hold no message to check against, so telling her the code is wrong
        // would send her back to the boxes forever. Expired asks for the one
        // thing that helps: send it again.
        final repository = FirebaseAuthRepository(auth: _MockFirebaseAuth());
        addTearDown(repository.dispose);

        await expectLater(
          repository.confirmCode('417293'),
          throwsA(_failure(AuthFailure.codeExpired)),
        );
      },
    );
  });

  group('Android reads the message itself', () {
    test('verificationCompleted signs her in with nothing typed', () async {
      final auth = _MockFirebaseAuth();
      final repository = FirebaseAuthRepository(auth: auth);
      addTearDown(repository.dispose);

      final send = repository.sendCode('01001234567');
      await pumpEventQueue();
      auth.fireCodeSent('verification-id', null);
      await send;
      expect(repository.current, isA<AuthAwaitingCode>());

      // Play Services read the SMS while she was still looking at the boxes.
      auth.fireVerificationCompleted();
      await pumpEventQueue();

      expect(repository.current, isA<AuthSignedIn>());
    });

    test('and the send still resolves when it beats codeSent', () async {
      // On a fast Android handset the automatic path can finish before the
      // codeSent callback arrives. `C06` is still waiting on `sendCode`, and a
      // send that never resolves is a dead button on a screen she cannot leave.
      final auth = _MockFirebaseAuth();
      final repository = FirebaseAuthRepository(auth: auth);
      addTearDown(repository.dispose);

      final send = repository.sendCode('01001234567');
      await pumpEventQueue();
      auth.fireVerificationCompleted();
      await send;

      expect(repository.current, isA<AuthSignedIn>());

      // The late codeSent must not drag her back to waiting for a code.
      auth.fireCodeSent('verification-id', null);
      await pumpEventQueue();
      expect(repository.current, isA<AuthSignedIn>());
    });

    test('giving up on reading it leaves her code still good', () async {
      // `codeAutoRetrievalTimeout` means Android stopped listening, not that
      // the code died. She types the six digits like anyone on an iPhone, and
      // nothing on screen moves.
      final auth = _MockFirebaseAuth();
      final repository = FirebaseAuthRepository(auth: auth);
      addTearDown(repository.dispose);

      final send = repository.sendCode('01001234567');
      await pumpEventQueue();
      auth.fireCodeSent('verification-id', null);
      await send;

      auth.fireAutoRetrievalTimeout('verification-id');
      await pumpEventQueue();
      expect(repository.current, isA<AuthAwaitingCode>());

      await repository.confirmCode('417293');
      expect(repository.current, isA<AuthSignedIn>());
    });

    test('a code typed on top of it is agreement, not an error', () async {
      // `C07` holds no subscription, so it cannot know she is already in. It
      // will submit the six digits she typed anyway. Failing that would clear
      // her boxes and strand a woman who is signed in.
      final auth = _MockFirebaseAuth();
      final repository = FirebaseAuthRepository(auth: auth);
      addTearDown(repository.dispose);

      final send = repository.sendCode('01001234567');
      await pumpEventQueue();
      auth.fireCodeSent('verification-id', null);
      await send;
      auth.fireVerificationCompleted();
      await pumpEventQueue();

      final signInsBefore = auth.signInCalls;
      await repository.confirmCode('417293');

      expect(repository.current, isA<AuthSignedIn>());
      expect(
        auth.signInCalls,
        signInsBefore,
        reason: 'the credential was already spent; replaying it would fail',
      );
    });
  });

  group('resendCode', () {
    test('hands back the force-resend token', () async {
      // Without it Firebase treats the second ask as a fresh attempt, which
      // spends two of her daily allowance instead of one.
      final auth = _MockFirebaseAuth();
      final repository = FirebaseAuthRepository(auth: auth);
      addTearDown(repository.dispose);

      final send = repository.sendCode('01001234567');
      await pumpEventQueue();
      auth.fireCodeSent('verification-id', 55);
      await send;

      final again = repository.resendCode();
      await pumpEventQueue();
      auth.fireCodeSent('verification-id-2', 56);
      await again;

      expect(auth.verifyCalls, 2);
      expect(auth.lastResendToken, 55);
      expect(auth.lastPhoneNumber, '+201001234567');
    });

    test('too many asks reads as too many attempts', () async {
      final auth = _MockFirebaseAuth();
      final repository = FirebaseAuthRepository(auth: auth);
      addTearDown(repository.dispose);

      final send = repository.sendCode('01001234567');
      await pumpEventQueue();
      auth.fireCodeSent('verification-id', 55);
      await send;

      final again = repository.resendCode();
      await pumpEventQueue();
      auth.fireVerificationFailed('too-many-requests');

      await expectLater(again, throwsA(_failure(AuthFailure.tooManyAttempts)));
    });

    test('with nothing ever sent it refuses rather than dialling', () async {
      final auth = _MockFirebaseAuth();
      final repository = FirebaseAuthRepository(auth: auth);
      addTearDown(repository.dispose);

      await expectLater(
        repository.resendCode(),
        throwsA(_failure(AuthFailure.unknown)),
      );
      expect(auth.verifyCalls, 0);
    });
  });

  group('signOut', () {
    test('drops her session and says so once', () async {
      final auth = _MockFirebaseAuth();
      final repository = FirebaseAuthRepository(auth: auth);
      addTearDown(repository.dispose);

      final send = repository.sendCode('01001234567');
      await pumpEventQueue();
      auth.fireCodeSent('verification-id', null);
      await send;
      await repository.confirmCode('417293');

      final seen = <AuthState>[];
      final subscription = repository.watch().listen(seen.add);
      addTearDown(subscription.cancel);
      // `watch()` is an async generator, exactly as the fake's is: it yields
      // the current state and only then subscribes to the broadcast stream.
      // Both implementations therefore need a turn of the loop before they are
      // really listening, and a test that skips it is testing the scheduler.
      await pumpEventQueue();

      await repository.signOut();
      await pumpEventQueue();

      expect(repository.current, isA<AuthSignedOut>());
      expect(seen.whereType<AuthSignedOut>().length, 1);
    });

    test('a null from the stream does not throw her off the code screen', () async {
      // `authStateChanges` opens with a null for a woman who is not signed in,
      // and it lands while she is mid-code. Treating it as a sign-out would
      // wipe the number `C07` shows her.
      final auth = _MockFirebaseAuth();
      final repository = FirebaseAuthRepository(auth: auth);
      addTearDown(repository.dispose);

      final send = repository.sendCode('01001234567');
      await pumpEventQueue();
      auth.fireCodeSent('verification-id', null);
      await send;

      auth.fireUser(null);
      await pumpEventQueue();

      expect(repository.current, isA<AuthAwaitingCode>());
    });
  });

  group('with no Firebase behind it', () {
    // `FirebaseBoot` is built so a failed init never stops the app opening,
    // which means this repository gets constructed with nothing behind it on a
    // handset with broken Play Services. It must not throw on the way past, and
    // it must say plainly that the network is the problem.
    test('constructing it does not throw', () {
      expect(FirebaseAuthRepository.new, returnsNormally);
    });

    test('it starts signed out and stays answerable', () async {
      final repository = FirebaseAuthRepository();
      addTearDown(repository.dispose);

      expect(repository.current, isA<AuthSignedOut>());
      expect(await repository.watch().first, isA<AuthSignedOut>());
    });

    test('anything needing the network says so', () async {
      final repository = FirebaseAuthRepository();
      addTearDown(repository.dispose);

      await expectLater(
        repository.sendCode('01001234567'),
        throwsA(_failure(AuthFailure.network)),
      );
      await repository.signOut();
      expect(repository.current, isA<AuthSignedOut>());
    });
  });

  test('the fake is untouched and still the one tests use', () {
    // The whole suite is written against `FakeAuthRepository`. If this file
    // ever tempts someone to "unify" the two, this is the tripwire.
    final fake = FakeAuthRepository();
    addTearDown(fake.dispose);

    expect(fake, isA<AuthRepository>());
    expect(testCodeOf(fake), '417293');
    expect(
      testCodeOf(FirebaseAuthRepository()),
      isNull,
      reason: 'against a real provider there is no code to name',
    );
  });
}

Matcher _failure(AuthFailure failure) =>
    isA<AuthException>().having((e) => e.failure, 'failure', failure);

/// A `FirebaseAuth` that goes nowhere.
///
/// It keeps the callbacks `verifyPhoneNumber` was handed so the test can fire
/// them in the order a real handset would. `noSuchMethod` covers the rest of
/// the interface: there is no mocking package in this project's dev
/// dependencies, and adding one to sign in six digits is not a trade worth
/// making.
class _MockFirebaseAuth implements FirebaseAuth {
  final StreamController<User?> _users = StreamController<User?>.broadcast();

  int verifyCalls = 0;
  int signInCalls = 0;
  String? lastPhoneNumber;
  int? lastResendToken;
  Duration? lastTimeout;
  AuthCredential? lastCredential;

  /// Thrown out of `verifyPhoneNumber` itself, rather than reported through
  /// `verificationFailed`.
  Object? verifyThrows;
  Object? signInThrows;

  /// When set, `signInWithCredential` does not answer until it completes.
  Completer<void>? signInHangs;

  User? _currentUser;
  PhoneVerificationCompleted? _onCompleted;
  PhoneVerificationFailed? _onFailed;
  PhoneCodeSent? _onCodeSent;
  PhoneCodeAutoRetrievalTimeout? _onTimeout;

  void fireCodeSent(String verificationId, int? resendToken) =>
      _onCodeSent?.call(verificationId, resendToken);

  void fireVerificationFailed(String code) =>
      _onFailed?.call(FirebaseAuthException(code: code));

  void fireVerificationCompleted() => _onCompleted?.call(
    PhoneAuthProvider.credential(
      verificationId: 'verification-id',
      smsCode: '417293',
    ),
  );

  void fireAutoRetrievalTimeout(String verificationId) =>
      _onTimeout?.call(verificationId);

  void fireUser(User? user) {
    _currentUser = user;
    _users.add(user);
  }

  @override
  User? get currentUser => _currentUser;

  @override
  Stream<User?> authStateChanges() => _users.stream;

  @override
  Future<void> verifyPhoneNumber({
    String? phoneNumber,
    PhoneMultiFactorInfo? multiFactorInfo,
    required PhoneVerificationCompleted verificationCompleted,
    required PhoneVerificationFailed verificationFailed,
    required PhoneCodeSent codeSent,
    required PhoneCodeAutoRetrievalTimeout codeAutoRetrievalTimeout,
    String? autoRetrievedSmsCodeForTesting,
    Duration timeout = const Duration(seconds: 30),
    int? forceResendingToken,
    MultiFactorSession? multiFactorSession,
  }) async {
    verifyCalls++;
    lastPhoneNumber = phoneNumber;
    lastResendToken = forceResendingToken;
    lastTimeout = timeout;
    _onCompleted = verificationCompleted;
    _onFailed = verificationFailed;
    _onCodeSent = codeSent;
    _onTimeout = codeAutoRetrievalTimeout;

    final thrown = verifyThrows;
    if (thrown != null) throw thrown;
  }

  @override
  Future<UserCredential> signInWithCredential(AuthCredential credential) async {
    signInCalls++;
    lastCredential = credential;

    final thrown = signInThrows;
    if (thrown != null) throw thrown;
    await signInHangs?.future;

    final user = _MockUser('uid-1');
    fireUser(user);
    return _MockUserCredential(user);
  }

  @override
  Future<void> signOut() async => fireUser(null);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockUser implements User {
  _MockUser(this.uid);

  @override
  final String uid;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockUserCredential implements UserCredential {
  _MockUserCredential(this.user);

  @override
  final User? user;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
