// A walk is logged the way a session without the phone is: one a day, once,
// reduced points, never a best, and nothing about what she eats.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/guest_session.dart';
import 'package:own_hub/app_state/rewards_state.dart';
import 'package:own_hub/app_state/walk_session_state.dart';
import 'package:own_hub/domain/clock/app_clock.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/domain/format/day_key.dart';
import 'package:own_hub/features/train/domain/train_repository.dart';
import 'package:own_hub/features/train/presentation/walk_session_view.dart';
import 'package:own_hub/main.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../qa/round1/round1_harness.dart' show wipe;

void main() {
  final saved = AppRouter.featureFlags;
  var now = DateTime(2026, 10, 28, 9);

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    AppRouter.featureFlags = FeatureFlags.allOff.with_({
      for (final f in Feature.values) f: f != Feature.accountRequired,
    });
    wipe();
    RewardsState.instance.reset();
    WalkSessionState.instance.reset();
    GuestSession.instance.reset();
    now = DateTime(2026, 10, 28, 9);
    AppClock.debugNow = () => now;
  });
  tearDown(() {
    AppClock.debugNow = null;
    AppRouter.featureFlags = saved;
    WalkSessionState.instance.reset();
    GuestSession.instance.reset();
    wipe();
    RewardsState.instance.reset();
  });

  String idFor(DateTime day) => 'recalled-${dayKey(day)}-walk';

  test('a walk is one unplanned session, credited to her week once', () async {
    final weekBefore = AppRouter.progressStore.rewards.sessionsLogged;
    await AppRouter.logWalk(1800);

    final session = AppRouter.trainRepository.sessionById(idFor(now))!;
    expect(session.source, SessionSource.unplanned);
    expect(session.activity, 'walk');
    expect(session.durationSec, 1800);
    expect(session.completed, isTrue);
    expect(AppRouter.progressStore.rewards.sessionsLogged, weekBefore + 1);
    // Not a measured session: it can never set a personal best.
    expect(const PersonalBestEligibility().isEligible(session), isFalse);
  });

  test(
    'a second walk the same day adds to it and does not count twice',
    () async {
      await AppRouter.logWalk(1800);
      final week = AppRouter.progressStore.rewards.sessionsLogged;
      final points = AppRouter.progressStore.rewards.points;
      await AppRouter.logWalk(600);

      expect(
        AppRouter.trainRepository.sessionById(idFor(now))!.durationSec,
        2400,
      );
      expect(AppRouter.progressStore.rewards.sessionsLogged, week);
      expect(AppRouter.progressStore.rewards.points, points);
    },
  );

  test(
    'a longer walk is not worth more points: nothing pays for calories',
    () async {
      final short = await AppRouter.logWalk(5 * 60);
      now = DateTime(2026, 10, 29, 9);
      final long = await AppRouter.logWalk(3 * 3600);

      expect(short.sessionPoints, greaterThan(0));
      expect(long.sessionPoints, short.sessionPoints);
    },
  );

  test(
    'a walk is offered with the switch on and an account, not otherwise',
    () {
      expect(AppRouter.walkIsOffered, isTrue);
      AppRouter.featureFlags = AppRouter.featureFlags.with_({
        Feature.walkingSession: false,
      });
      expect(AppRouter.walkIsOffered, isFalse);
      // A woman with no account has one free action, her first workout (D62).
      AppRouter.featureFlags = FeatureFlags.everything.with_({
        Feature.accountRequired: true,
      });
      expect(GuestSession.isBrowsing, isTrue);
      expect(AppRouter.walkIsOffered, isFalse);
    },
  );

  testWidgets('the page opens, runs on the app clock and logs the walk', (
    tester,
  ) async {
    await tester.pumpWidget(OwnHubApp(key: UniqueKey()));
    await tester.pumpAndSettle();
    AppRouter.openWalk(tester.element(find.byType(Scaffold).first));
    await tester.pumpAndSettle();
    expect(find.byType(WalkSessionView), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('walk-start')));
    await tester.pump();
    now = now.add(const Duration(minutes: 42));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('42:00'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('walk-finish')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('walk-log')));
    await tester.pumpAndSettle();

    expect(
      AppRouter.trainRepository.sessionById(idFor(now))!.durationSec,
      42 * 60,
    );
    expect(WalkSessionState.instance.touched, isFalse);
    expect(find.byKey(const ValueKey('walk-logged')), findsOneWidget);
  });
}
