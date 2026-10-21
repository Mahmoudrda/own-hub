// Speed on a poor connection, the sign-up half: the reads after the SMS
// code run side by side under one cap, the code screen says it is still
// working, and the consent callables stop waiting at twenty seconds.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:own_hub/features/signup/data/callable_failure.dart';
import 'package:own_hub/features/signup/data/verification_backend.dart';
import 'package:own_hub/features/signup/domain/auth_repository.dart';
import 'package:own_hub/features/signup/domain/server_verification.dart';
import 'package:own_hub/features/signup/presentation/code_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/routing/app_router.dart';

/// Every read takes [delay], and counts how many were running at once.
class _SlowBackend extends VerificationBackend {
  _SlowBackend(this.delay);

  final Duration? delay;
  int running = 0;
  int mostAtOnce = 0;

  Future<T> _slow<T>(T value) async {
    running++;
    if (running > mostAtOnce) mostAtOnce = running;
    try {
      final wait = delay;
      if (wait == null) return await Completer<T>().future;
      await Future<void>.delayed(wait);
      return value;
    } finally {
      running--;
    }
  }

  @override
  bool get isReady => true;

  @override
  String? get currentUid => 'u1';

  @override
  Future<bool> verifiedClaim({bool forceRefresh = false}) => _slow(true);

  @override
  Future<ServerVerification?> readStatus(String uid) => _slow(null);

  @override
  Future<ServerVerification?> cachedStatus(String uid) async => null;

  @override
  Stream<ServerVerification?>? watchStatus(String uid) => null;

  @override
  Stream<Object?> tokenChanges() => const Stream<Object?>.empty();
}

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

  group('after the code is accepted', () {
    test('the claim and the status are read together, not one after the '
        'other', () async {
      final backend = _SlowBackend(const Duration(milliseconds: 150));
      AppRouter.verificationBackend = backend;

      final clock = Stopwatch()..start();
      await AppRouter.readAfterSignIn();
      clock.stop();

      expect(backend.mostAtOnce, 2);
      expect(clock.elapsed, lessThan(const Duration(milliseconds: 290)));
      expect(AppRouter.isVerified, isTrue);
    });

    test('one cap covers all of them, and nothing throws', () async {
      final backend = _SlowBackend(null);
      AppRouter.verificationBackend = backend;

      final clock = Stopwatch()..start();
      await AppRouter.readAfterSignIn(cap: const Duration(milliseconds: 100));
      clock.stop();

      expect(clock.elapsed, lessThan(const Duration(seconds: 1)));
      expect(AppRouter.isVerified, isFalse, reason: 'still fails closed');
      expect(AppRouter.afterSignInCap, const Duration(seconds: 8));
    });
  });

  testWidgets('the code screen says it is still working after eight seconds, '
      'and stops saying it when done', (tester) async {
    final repository = FakeAuthRepository(codeToAccept: '417293');
    final done = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: CodeView(repository: repository, onConfirmed: () => done.future),
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField), '417293');
    await tester.pump();
    await tester.pump(CodeView.slowAfter - const Duration(seconds: 1));
    expect(find.byKey(const ValueKey('code-checking')), findsOneWidget);
    expect(find.byKey(const ValueKey('code-slow')), findsNothing);

    await tester.pump(const Duration(seconds: 2));
    expect(find.byKey(const ValueKey('code-slow')), findsOneWidget);

    done.complete();
    await tester.pump();
    await tester.pump(const Duration(seconds: 31));
    expect(find.byKey(const ValueKey('code-slow')), findsNothing);
    expect(CodeView.slowAfter, const Duration(seconds: 8));
  });

  test('the consent callables give up at twenty seconds', () {
    expect(kConsentCallTimeout, const Duration(seconds: 20));
  });
}
