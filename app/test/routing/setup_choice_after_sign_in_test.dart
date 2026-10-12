// R9: C07 chooses setup (O01) or Home (T01) only after one bounded pull of
// her cloud copy, so a returning verified woman with her backup on is not
// walked through setup again on a new phone. Bounded, so a dead network costs
// a few seconds and never a hang.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/routing/app_router.dart';

import 'offline_verification_launch_test.dart' show FakeBackend;

void main() {
  final savedPull = AppRouter.cloudPull;
  final savedBackend = AppRouter.verificationBackend;

  setUp(() {
    AppRouter.intakeRepository.reset();
    AppRouter.verificationBackend = FakeBackend(uid: 'u1');
  });

  tearDown(() {
    AppRouter.cloudPull = savedPull;
    AppRouter.verificationBackend = savedBackend;
    AppRouter.intakeRepository.reset();
  });

  test('her setup answers from the cloud are in before the choice', () async {
    final pulled = <String>[];
    AppRouter.cloudPull = (uid, bound) async {
      pulled.add(uid);
      // What a merge of her cloud profile does.
      AppRouter.intakeRepository.markSetupDone();
    };

    await AppRouter.pullBeforeSetupChoice();

    expect(pulled, ['u1']);
    expect(
      AppRouter.intakeRepository.setupDone,
      isTrue,
      reason: 'T01, not O01',
    );
  });

  test('a cloud that never answers costs the bound, then O01', () async {
    AppRouter.cloudPull = (uid, bound) => Completer<void>().future;

    final clock = Stopwatch()..start();
    await AppRouter.pullBeforeSetupChoice();
    clock.stop();

    expect(clock.elapsed, lessThan(AppRouter.setupPullBound * 1.5));
    expect(AppRouter.intakeRepository.setupDone, isFalse);
  }, timeout: const Timeout(Duration(seconds: 20)));

  test('setup already done on this phone: no wait at all', () async {
    var calls = 0;
    AppRouter.cloudPull = (uid, bound) async => calls++;
    AppRouter.intakeRepository.markSetupDone();
    await AppRouter.pullBeforeSetupChoice();
    expect(calls, 0);
  });
}
