// R1: a verified woman who opens the app with no network is not locked out.
//
// Before this, `readVerificationClaim` set the claim to false on any error,
// an expired token offline throws, and she landed on C14 ("a reviewer will
// phone you") or, with no Firebase at all, on C01. These tests drive the
// launch read through a fake back end and prove four things:
//
//   * offline with an expired token, a phone that proved her verified before
//     (or a cached `approved` state) opens the product;
//   * Firebase unavailable, the same memory opens the local product;
//   * `approved` is never shown as waiting on C14;
//   * the launch read is bounded in time.
//
// And the other half, which is Protected List 4: no evidence, or a failure
// that is not about the network, still means no product.

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:own_hub/app_state/verification_memory.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/features/signup/data/verification_backend.dart';
import 'package:own_hub/features/signup/domain/server_verification.dart';
import 'package:own_hub/features/signup/presentation/being_checked_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/routing/app_router.dart';

class FakeBackend extends VerificationBackend {
  FakeBackend({
    this.ready = true,
    this.uid = 'u1',
    this.claim,
    this.status,
    this.cached,
  });

  bool ready;
  String? uid;

  /// What the token says, or the failure reading it throws. Null hangs.
  Future<bool> Function({bool forceRefresh})? claim;
  Future<ServerVerification?> Function()? status;
  ServerVerification? cached;
  final tokens = StreamController<Object?>.broadcast();
  int forcedRefreshes = 0;

  @override
  bool get isReady => ready;

  @override
  String? get currentUid => uid;

  @override
  Future<bool> verifiedClaim({bool forceRefresh = false}) {
    if (forceRefresh) forcedRefreshes++;
    final read = claim;
    return read == null
        ? Completer<bool>().future
        : read(forceRefresh: forceRefresh);
  }

  @override
  Future<ServerVerification?> readStatus(String uid) =>
      status?.call() ?? Future.value(null);

  @override
  Future<ServerVerification?> cachedStatus(String uid) async => cached;

  @override
  Stream<ServerVerification?>? watchStatus(String uid) => null;

  @override
  Stream<Object?> tokenChanges() => tokens.stream;
}

Future<bool> Function({bool forceRefresh}) _throws(Object error) =>
    ({bool forceRefresh = false}) async => throw error;

Future<bool> Function({bool forceRefresh}) _says(bool verified) =>
    ({bool forceRefresh = false}) async => verified;

final _offline = FirebaseAuthException(code: 'network-request-failed');

FeatureFlags get _gated =>
    FeatureFlags.allOff.with_({for (final f in Feature.values) f: true});

void main() {
  final savedBackend = AppRouter.verificationBackend;
  final savedFlags = AppRouter.featureFlags;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppRouter.forgetVerification();
    AppRouter.featureFlags = _gated;
  });

  tearDown(() async {
    AppRouter.verificationBackend = savedBackend;
    AppRouter.featureFlags = savedFlags;
    await AppRouter.forgetVerification();
  });

  group('offline with an expired token', () {
    test('a phone that proved her verified opens the product', () async {
      await VerificationMemory.rememberVerified('u1');
      AppRouter.verificationBackend = FakeBackend(claim: _throws(_offline));

      await AppRouter.readVerificationAtLaunch();

      expect(AppRouter.isVerified, isTrue);
      expect(AppRouter.verificationGate('P01'), isNull);
      expect(AppRouter.awaitingReviewer, isFalse);
    });

    test('a cached approved state opens the product, never C14', () async {
      AppRouter.verificationBackend = FakeBackend(
        claim: _throws(_offline),
        cached: const ServerVerification(ServerVerificationState.approved),
        status: () async =>
            const ServerVerification(ServerVerificationState.approved),
      );

      await AppRouter.readVerificationAtLaunch();

      expect(AppRouter.isVerified, isTrue);
      expect(AppRouter.awaitingReviewer, isFalse);
      expect(AppRouter.verificationGate('R01'), isNull);
    });

    test('memory for another account opens nothing', () async {
      await VerificationMemory.rememberVerified('someone-else');
      AppRouter.verificationBackend = FakeBackend(claim: _throws(_offline));

      await AppRouter.readVerificationAtLaunch();

      expect(AppRouter.isVerified, isFalse);
      expect(AppRouter.verificationGate('P01'), isNotNull);
    });

    test('no evidence at all keeps the gate shut (Protected List 4)', () async {
      AppRouter.verificationBackend = FakeBackend(claim: _throws(_offline));

      await AppRouter.readVerificationAtLaunch();

      expect(AppRouter.isVerified, isFalse);
      expect(AppRouter.verificationGate('P01'), isNotNull);
    });

    test('a failure that is not the network does not use the memory', () async {
      await VerificationMemory.rememberVerified('u1');
      AppRouter.verificationBackend = FakeBackend(
        claim: _throws(FirebaseAuthException(code: 'user-disabled')),
      );

      await AppRouter.readVerificationAtLaunch();

      expect(AppRouter.isVerified, isFalse);
    });
  });

  group('the memory follows the server', () {
    test('a fresh verified token is remembered for this uid', () async {
      AppRouter.verificationBackend = FakeBackend(claim: _says(true));
      await AppRouter.readVerificationAtLaunch();
      expect(AppRouter.isVerified, isTrue);
      expect(await VerificationMemory.verifiedUid(), 'u1');
    });

    test('a fresh unverified token forgets it', () async {
      await VerificationMemory.rememberVerified('u1');
      AppRouter.verificationBackend = FakeBackend(claim: _says(false));
      await AppRouter.readVerificationAtLaunch();
      expect(AppRouter.isVerified, isFalse);
      expect(await VerificationMemory.verifiedUid(), isNull);
    });
  });

  group('Firebase unavailable', () {
    test('a remembered verified woman uses the local product', () async {
      await VerificationMemory.rememberVerified('u1');
      await VerificationMemory.rememberSignedIn('u1');
      AppRouter.verificationBackend = FakeBackend(ready: false, uid: null);

      await AppRouter.readVerificationAtLaunch();

      expect(AppRouter.signedInUid, isNull);
      expect(AppRouter.isVerified, isTrue);
      expect(AppRouter.verificationGate('P01'), isNull);
    });

    test('nobody remembered: the front door, as before', () async {
      AppRouter.verificationBackend = FakeBackend(ready: false, uid: null);
      await AppRouter.readVerificationAtLaunch();
      expect(AppRouter.isVerified, isFalse);
      expect(AppRouter.verificationGate('P01'), isNotNull);
    });
  });

  group('the launch read is bounded', () {
    test('a token and a server that never answer cost a few seconds', () async {
      await VerificationMemory.rememberVerified('u1');
      final backend = FakeBackend(status: () => Completer<Never>().future);
      AppRouter.verificationBackend = backend;

      final clock = Stopwatch()..start();
      await AppRouter.readVerificationAtLaunch();
      clock.stop();

      expect(clock.elapsed, lessThan(const Duration(seconds: 6)));
      // The token timed out, which is a network answer: her memory holds.
      expect(AppRouter.isVerified, isTrue);
    }, timeout: const Timeout(Duration(seconds: 20)));
  });

  group('a remembered launch does not wait for the network (D44)', () {
    const approved = ServerVerification(ServerVerificationState.approved);

    test('memory and the on-device status agree: open at once, with a token '
        'and a server that never answer', () async {
      await VerificationMemory.rememberVerified('u1');
      final backend = FakeBackend(
        cached: approved,
        status: () => Completer<Never>().future,
      );
      AppRouter.verificationBackend = backend;

      final clock = Stopwatch()..start();
      await AppRouter.readVerificationAtLaunch();
      clock.stop();

      expect(clock.elapsed, lessThan(const Duration(milliseconds: 500)));
      expect(AppRouter.isVerified, isTrue);
      expect(AppRouter.verificationGate('P01'), isNull);
    });

    test('the claim read right behind it still decides: a revoked claim '
        'closes the gate', () async {
      await VerificationMemory.rememberVerified('u1');
      final answer = Completer<bool>();
      final backend = FakeBackend(
        cached: approved,
        claim: ({bool forceRefresh = false}) => answer.future,
      );
      AppRouter.verificationBackend = backend;

      await AppRouter.readVerificationAtLaunch();
      expect(AppRouter.isVerified, isTrue);

      answer.complete(false);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(AppRouter.isVerified, isFalse);
      expect(AppRouter.verificationGate('P01'), isNotNull);
      expect(await VerificationMemory.verifiedUid(), isNull);
    });

    test('a failure that is not the network closes what the memory opened, '
        'as the full read would', () async {
      await VerificationMemory.rememberVerified('u1');
      final backend = FakeBackend(
        cached: approved,
        claim: _throws(FirebaseAuthException(code: 'user-disabled')),
        status: () async =>
            const ServerVerification(ServerVerificationState.rejected),
      );
      AppRouter.verificationBackend = backend;

      await AppRouter.readVerificationAtLaunch();
      expect(AppRouter.isVerified, isTrue, reason: 'open for the first frame');
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(AppRouter.isVerified, isFalse);
      expect(AppRouter.verificationGate('P01'), isNotNull);
    });

    test('memory alone is not enough: without the cached approval the full '
        'read runs', () async {
      await VerificationMemory.rememberVerified('u1');
      final backend = FakeBackend(claim: _says(false));
      AppRouter.verificationBackend = backend;

      await AppRouter.readVerificationAtLaunch();

      expect(AppRouter.isVerified, isFalse);
    });

    test('a cached approval alone is not enough for an account this phone '
        'never proved', () async {
      await VerificationMemory.rememberVerified('someone-else');
      final backend = FakeBackend(cached: approved, claim: _says(false));
      AppRouter.verificationBackend = backend;

      await AppRouter.readVerificationAtLaunch();

      expect(AppRouter.isVerified, isFalse);
    });
  });

  group('the refresh is retried, not fired once', () {
    test('on resume, an approved woman gets the claim once online', () async {
      final backend = FakeBackend(
        claim: _throws(_offline),
        cached: const ServerVerification(ServerVerificationState.approved),
      );
      AppRouter.verificationBackend = backend;
      await AppRouter.readVerificationAtLaunch();
      expect(AppRouter.isVerified, isTrue);

      backend.claim = _says(true);
      await AppRouter.refreshVerificationIfOwed();

      expect(backend.forcedRefreshes, greaterThan(0));
      expect(await VerificationMemory.verifiedUid(), 'u1');
    });

    test('a new token after reconnect carries the claim in', () async {
      final backend = FakeBackend(claim: _throws(_offline));
      AppRouter.verificationBackend = backend;
      await AppRouter.readVerificationAtLaunch();
      expect(AppRouter.isVerified, isFalse);

      AppRouter.watchVerificationToken();
      backend.claim = _says(true);
      backend.tokens.add(Object());
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(AppRouter.isVerified, isTrue);
      expect(await VerificationMemory.verifiedUid(), 'u1');
    });
  });

  group('C14 with an approved state', () {
    Widget host(Widget child) => MaterialApp(
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      home: child,
    );

    testWidgets('is never shown as waiting, and opens the product', (
      tester,
    ) async {
      var opened = 0;
      await tester.pumpWidget(
        host(
          BeingCheckedView(
            status: const ServerVerification(ServerVerificationState.approved),
            onApproved: () => opened++,
            onLookAround: () {},
          ),
        ),
      );
      await tester.pump();
      final l10n = AppL10n.of(tester.element(find.byType(BeingCheckedView)));

      expect(opened, 0, reason: 'the kitten cheers first');
      await tester.pump(const Duration(milliseconds: 1700));

      expect(find.text(l10n.yourCheckIsDone), findsOneWidget);
      expect(find.text(l10n.theAppOpensAsSoonAsYour), findsNothing);
      expect(find.text(l10n.aWomanFromOwnHubReviewsYour), findsNothing);
      expect(find.text(l10n.lookAroundWhileYouWait), findsNothing);
      expect(opened, 1, reason: 'the approval moves her on by itself');

      await tester.tap(find.byKey(const ValueKey('c14-open-own-hub')));
      expect(opened, 2, reason: 'and the button tries again, every time');
    });

    test('approved is evidence for the gate, not a reason to wait', () {
      AppRouter.serverVerification = const ServerVerification(
        ServerVerificationState.approved,
      );
      expect(AppRouter.awaitingReviewer, isFalse);
      expect(AppRouter.isVerified, isTrue);
      expect(AppRouter.verificationGate('P01'), isNull);
    });
  });
}
