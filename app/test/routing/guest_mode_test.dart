// Guest mode: what a woman with no account may open, how a protected action
// is kept and replayed once, and that the gate cannot be argued with.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/app_snapshot.dart';
import 'package:own_hub/app_state/guest_session.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/features/signup/data/fast_verification_claim.dart';
import 'package:own_hub/features/signup/domain/verification.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/routing/app_routes.dart';

String? _gate(
  String id, {
  bool signedIn = false,
  bool verified = false,
  bool waiting = false,
  bool browsing = false,
}) => AppRouter.gateDestination(
  id,
  gateClosed: true,
  signedIn: signedIn,
  verified: verified,
  waitingOnAReviewer: waiting,
  guestBrowsing: browsing,
);

VerificationResult _passed() => VerificationResult(
  method: VerificationMethod.automatic,
  decidedAt: DateTime(2026, 10, 18),
  imagesDeletedAt: DateTime(2026, 10, 18),
);

class _Approving implements FastVerificationClaimer {
  @override
  Future<FastVerification> claim() async => FastVerification.approved;
}

void main() {
  final savedFlags = AppRouter.featureFlags;

  setUp(() {
    AppRouter.featureFlags = FeatureFlags.allOff.with_({
      for (final f in Feature.values) f: true,
    });
    AppRouter.lastVerification = null;
    AppRouter.awaitingReviewer = false;
    GuestSession.instance.reset();
  });

  tearDown(() {
    AppRouter.featureFlags = savedFlags;
    AppRouter.lastVerification = null;
    GuestSession.instance.reset();
    fastVerificationClaimerOverride = null;
  });

  group('the gate for a guest', () {
    test('the browsing screens open, and nothing else does', () {
      for (final id in GuestSession.screens) {
        expect(_gate(id, browsing: true), isNull, reason: '$id opens');
      }
      for (final id in const ['P01', 'Y03', 'M01', 'H01', 'K07', 'R07']) {
        expect(
          _gate(id, browsing: true),
          appRoutes['C01']!.name,
          reason: '$id stays behind the gate',
        );
      }
    });

    test('without browsing, the same screens are still closed', () {
      for (final id in GuestSession.screens) {
        if (id == 'A02') continue;
        expect(_gate(id), isNotNull, reason: id);
      }
    });

    test('a woman with her check open sees the check until she explores', () {
      expect(_gate('T01', signedIn: true), appRoutes['C09b']!.name);
      expect(
        _gate('T01', signedIn: true, waiting: true),
        appRoutes['C14']!.name,
      );
      expect(
        _gate('T01', signedIn: true, waiting: true, browsing: true),
        isNull,
      );
    });

    test('whatever the gate answers is itself open under the same facts', () {
      for (final id in appDestinations.keys) {
        for (final signedIn in const [false, true]) {
          for (final waiting in const [false, true]) {
            for (final browsing in const [false, true]) {
              final to = _gate(
                id,
                signedIn: signedIn,
                waiting: waiting,
                browsing: browsing,
              );
              if (to == null) continue;
              final target = screenIdForRoute(to)!;
              expect(
                _gate(
                  target,
                  signedIn: signedIn,
                  waiting: waiting,
                  browsing: browsing,
                ),
                isNull,
                reason: '$id -> $target must not bounce again',
              );
            }
          }
        }
      }
    });

    test('verified: nothing is held back', () {
      for (final id in appDestinations.keys) {
        expect(_gate(id, signedIn: true, verified: true), isNull, reason: id);
      }
    });
  });

  group('the front door', () {
    String door({
      bool signedIn = false,
      bool verified = false,
      bool waiting = false,
    }) => AppRouter.frontDoorFor(
      accountRequired: true,
      verified: verified,
      signedIn: signedIn,
      waitingOnAReviewer: waiting,
    );

    test('a guest opens on Home', () {
      expect(door(), appRoutes['T01']!.name);
    });

    test('signed in with the check open opens the check or the wait', () {
      expect(door(signedIn: true), appRoutes['C09b']!.name);
      expect(door(signedIn: true, waiting: true), appRoutes['C14']!.name);
    });

    test('verified opens Home', () {
      expect(door(signedIn: true, verified: true), appRoutes['T01']!.name);
    });
  });

  group('a protected action', () {
    Future<BuildContext> host(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          onGenerateRoute: AppRouter.onGenerateRoute,
          initialRoute: appRoutes['T01']!.name,
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
        ),
      );
      await tester.pumpAndSettle();
      return tester.element(find.byType(Scaffold).first);
    }

    testWidgets('goes ahead when no account is required', (tester) async {
      AppRouter.featureFlags = FeatureFlags.everything;
      final context = await host(tester);
      expect(
        GuestSession.require(context, const PendingAction.startWorkout()),
        isTrue,
      );
      expect(GuestSession.instance.pending, isNull);
    });

    testWidgets('goes ahead once verified', (tester) async {
      AppRouter.lastVerification = _passed();
      final context = await host(tester);
      expect(
        GuestSession.require(context, const PendingAction.startWorkout()),
        isTrue,
      );
    });

    testWidgets('is kept for a guest, who is shown Rahma', (tester) async {
      final context = await host(tester);
      expect(
        GuestSession.require(context, const PendingAction.startWorkout()),
        isFalse,
      );
      await tester.pumpAndSettle();
      expect(GuestSession.instance.pending?.kind, PendingKind.startWorkout);
      expect(find.text('Rahma Mohsen'), findsOneWidget);
    });

    testWidgets('closing the welcome drops what she had asked for', (
      tester,
    ) async {
      final context = await host(tester);
      GuestSession.require(context, const PendingAction.startWorkout());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('founder-close')));
      await tester.pumpAndSettle();
      expect(GuestSession.instance.pending, isNull);
      expect(find.text('Rahma Mohsen'), findsNothing);
    });

    testWidgets('a guest reaching for Progress meets the welcome, not C01', (
      tester,
    ) async {
      final context = await host(tester);
      AppRouter.goTo(context, 'P01');
      await tester.pumpAndSettle();
      expect(find.text('Rahma Mohsen'), findsOneWidget);
    });

    testWidgets('is replayed once, and only once', (tester) async {
      final context = await host(tester);
      AppRouter.lastVerification = _passed();
      var replays = 0;
      GuestSession.favouriteHandler = (context, foodId) => replays++;
      addTearDown(() => GuestSession.favouriteHandler = null);
      GuestSession.instance.pending = PendingAction.favourite('koshari');
      GuestSession.instance.pendingAt = DateTime.now();

      await Future.wait([
        GuestSession.instance.resume(context),
        GuestSession.instance.resume(context),
      ]);
      await GuestSession.instance.resume(context);
      expect(replays, 1);
      expect(GuestSession.instance.pending, isNull);
    });

    testWidgets('does not run before she is verified', (tester) async {
      final context = await host(tester);
      GuestSession.instance.pending = PendingAction.favourite('koshari');
      GuestSession.instance.pendingAt = DateTime.now();
      var replays = 0;
      GuestSession.favouriteHandler = (context, foodId) => replays++;
      addTearDown(() => GuestSession.favouriteHandler = null);

      await GuestSession.instance.resume(context);
      expect(replays, 0);
      expect(GuestSession.instance.pending, isNotNull);
    });

    testWidgets('is dropped when it is a day old', (tester) async {
      final context = await host(tester);
      GuestSession.instance.pending = PendingAction.favourite('koshari');
      GuestSession.instance.pendingAt = DateTime.now().subtract(
        const Duration(hours: 25),
      );
      AppRouter.lastVerification = _passed();
      var replays = 0;
      GuestSession.favouriteHandler = (context, foodId) => replays++;
      addTearDown(() => GuestSession.favouriteHandler = null);

      await GuestSession.instance.resume(context);
      expect(replays, 0);
      expect(GuestSession.instance.pending, isNull);
    });
  });

  group('kept on the phone', () {
    test('a pending action is in the snapshot and comes back', () {
      GuestSession.instance
        ..pending = PendingAction.bookmarkRecipe('koshari_bowl')
        ..pendingAt = DateTime.utc(2026, 10, 18, 9);
      final raw = jsonEncode(AppSnapshot.capture());

      GuestSession.instance.reset();
      expect(GuestSession.instance.pending, isNull);
      AppSnapshot.restore(raw);

      final back = GuestSession.instance.pending;
      expect(back?.kind, PendingKind.bookmarkRecipe);
      expect(back?.payload['recipe'], 'koshari_bowl');
    });

    test('nothing pending writes no guest section', () {
      expect(AppSnapshot.capture().containsKey('guest'), isFalse);
    });

    test('a meal draft round trips as plain data', () {
      final json = const PendingAction(
        PendingKind.logMeal,
        payload: {
          'origin': 'search',
          'items': [
            {'food': 'koshari', 'size': 'M', 'servings': 2},
          ],
        },
      ).toJson();
      final back = PendingAction.fromJson(jsonDecode(jsonEncode(json)));
      expect(back?.kind, PendingKind.logMeal);
      expect((back?.payload['items'] as List).single['servings'], 2);
    });
  });

  group('claim_fast_verification', () {
    test('a callable that is not there reads as none', () async {
      expect(
        await const CallableFastVerificationClaimer().claim(),
        FastVerification.none,
      );
    });

    test('the router asks whoever is installed', () async {
      fastVerificationClaimerOverride = _Approving();
      expect(await fastVerificationClaimer.claim(), FastVerification.approved);
    });
  });
}
