// R10.
//
//  * C12's "Try again tomorrow" Close (and the app-cannot-reach Close) used
//    `popUntil(isFirst)`. For a woman who signed in on C07 the first route is
//    C01, so she was shown "Get started" while signed in. Close now goes to
//    the front door computed at that moment.
//  * C15 hearing "already verified" with a token refresh that fails must not
//    show C14 pending: the server's `approved` is evidence (R1).

import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/routing/app_routes.dart';

import 'offline_verification_launch_test.dart' show FakeBackend;

void main() {
  final savedBackend = AppRouter.verificationBackend;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppRouter.forgetVerification();
  });

  tearDown(() async {
    AppRouter.verificationBackend = savedBackend;
    await AppRouter.forgetVerification();
  });

  group('the front door, computed when she leaves', () {
    String door({required bool signedIn, bool verified = false}) =>
        AppRouter.frontDoorFor(
          accountRequired: true,
          verified: verified,
          signedIn: signedIn,
        );

    test(
      'signed in and not verified: the check, since Home is open to guests',
      () {
        expect(door(signedIn: true), appRoutes['C09b']!.name);
        expect(
          AppRouter.frontDoorFor(
            accountRequired: true,
            verified: false,
            signedIn: true,
            waitingOnAReviewer: true,
          ),
          appRoutes['C14']!.name,
        );
      },
    );

    test('nobody signed in: Home as a guest', () {
      expect(door(signedIn: false), appRoutes['T01']!.name);
    });

    test('verified: Home', () {
      expect(door(signedIn: false, verified: true), appRoutes['T01']!.name);
    });

    test('no exit pops to whatever happens to be first', () {
      final router = File('lib/routing/app_router.dart').readAsStringSync();
      expect(router, isNot(contains('route.isFirst')));
    });
  });

  test('C15 "already verified" with a failed refresh is not pending', () async {
    AppRouter.verificationBackend = FakeBackend(
      claim: ({bool forceRefresh = false}) async =>
          throw FirebaseAuthException(code: 'network-request-failed'),
    );

    AppRouter.markApprovedByServer();

    expect(AppRouter.isVerified, isTrue);
    expect(AppRouter.awaitingReviewer, isFalse);
    expect(AppRouter.verificationGate('T01'), isNull);
  });
}
