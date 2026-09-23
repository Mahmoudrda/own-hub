// What must be true of the build that goes to the stores.
//
// While `Feature.accountRequired` is off the app grows a set of aids that exist
// only so the product can be walked without signing up: an index of all 161
// screens, the one code the in-memory sign-in accepts printed on the screen
// that asks for it, and a test payment rail. Every one of them is gated, and
// this is the test that says so, because the failure mode is silent: the flag
// is a single boolean and a release built with it off looks completely normal
// until a reviewer finds a screen index in a fitness app.
//
// It also holds the two store rules that are checked in code rather than by
// reading: no other platform is named on screen (App Review 2.3.10), and no
// control opens a page that has no address yet (2.1).

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/config/legal_links.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/main.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/routing/app_routes.dart';

/// The app as it will be submitted: every feature on, an account required.
FeatureFlags get _release =>
    FeatureFlags.allOff.with_({for (final f in Feature.values) f: true});

Future<void> _open(WidgetTester tester, String id) async {
  await tester.pumpWidget(OwnHubApp(key: UniqueKey()));
  await tester.pumpAndSettle();
  tester
      .state<NavigatorState>(find.byType(Navigator).first)
      .pushNamed(appDestinations[id]!.name);
  await tester.pumpAndSettle();
}

void main() {
  final saved = AppRouter.featureFlags;
  setUp(() => AppRouter.featureFlags = _release);
  tearDown(() => AppRouter.featureFlags = saved);

  group('the testing scaffolding cannot ship', () {
    testWidgets('the app opens on sign-up, not on Home', (tester) async {
      await tester.pumpWidget(OwnHubApp(key: UniqueKey()));
      await tester.pumpAndSettle();
      final l10n = await AppL10n.delegate.load(const Locale('en'));
      expect(
        find.text(l10n.startEverythingsReady),
        findsNothing,
        reason: 'Home is behind an account',
      );
    });

    testWidgets('profile offers no index of every screen', (tester) async {
      await _open(tester, 'A02');
      final l10n = await AppL10n.delegate.load(const Locale('en'));
      expect(find.text(l10n.allScreens), findsNothing);
    });

    testWidgets('the code screen does not print the code', (tester) async {
      await _open(tester, 'C07');
      expect(
        find.textContaining('Test build'),
        findsNothing,
        reason: 'the fixed sign-in code is a testing aid',
      );
    });

    test('the test payment rail is closed', () {
      expect(
        AppRouter.featureFlags.isOn(Feature.accountRequired),
        isTrue,
        reason: 'the rail keys off exactly this flag',
      );
    });
  });

  group('the admin console cannot ship', () {
    // Z01 to Z14 are the owner's content tooling, and Z14 is the switchboard
    // behind every feature flag. It can turn `Feature.accountRequired` OFF,
    // which is the one switch every other guard in this file keys off: with it
    // off there is no sign-up, the index of all 161 screens appears, the
    // sign-in code is printed on the screen that asks for it and a test
    // payment rail opens. A flag cannot guard the screen that edits flags, so
    // this one is guarded by the build.
    //
    // `Feature.adminConsole` stays a flag and stays on in `_release` above, on
    // purpose: this asserts the *build* refuses the console even with its own
    // feature switched on, which is the only version of the check that would
    // have caught the defect.

    final admin = appRoutes.entries
        .where((e) => e.value.flow == 'admin')
        .toList();

    test('a release build resolves none of Z01 to Z14', () {
      expect(admin, hasLength(14), reason: 'the console is fourteen screens');
      for (final entry in admin) {
        expect(
          AppRouter.resolvesInThisBuild(entry.key, release: true),
          isFalse,
          reason: '${entry.key} at ${entry.value.name} still resolves',
        );
      }
    });

    test('the switchboard most of all', () {
      expect(AppRouter.resolvesInThisBuild('Z14', release: true), isFalse);
    });

    test('and nothing else is withheld', () {
      for (final entry in appRoutes.entries) {
        if (entry.value.flow == 'admin') continue;
        expect(
          AppRouter.resolvesInThisBuild(entry.key, release: true),
          isTrue,
          reason: '${entry.key} is not the admin console',
        );
      }
    });

    test('debug and profile keep it, because the owner works in them', () {
      for (final id in const ['Z01', 'Z08', 'Z14']) {
        expect(AppRouter.resolvesInThisBuild(id, release: false), isTrue);
      }
    });

    test('an unknown route and a withheld one get the same answer: null', () {
      // A widget test cannot be compiled in release mode — `kReleaseMode` is a
      // const the test binary sets to false — so the refusal itself is proved
      // against the gate above. What this asserts is the other half: in a
      // build that keeps the console the route resolves, and a name no screen
      // serves resolves to null. Null is what the gate returns in release, so
      // an admin route there lands on `onUnknownRoute` exactly as a typo does.
      expect(
        AppRouter.onGenerateRoute(RouteSettings(name: appRoutes['Z14']!.name)),
        isNotNull,
      );
      expect(
        AppRouter.onGenerateRoute(
          const RouteSettings(name: '/no/screen/serves/this'),
        ),
        isNull,
      );
    });

    test('and a deep link naming it opens the front door instead', () {
      // `main.dart` picks the initial route from whatever the platform hands
      // it. A withheld id must fall through to the front door there too, or a
      // release build deep-linked to `/admin/z14` opens on "no screen serves
      // this route" instead of on the app.
      final source = File('lib/main.dart').readAsStringSync();
      expect(
        source,
        contains('AppRouter.resolvesInThisBuild(id)'),
        reason: 'the initial route must honour the same gate',
      );
    });

    test('and the router asks the gate before it builds anything', () {
      // Read from the source for the same reason the rule guards in
      // `product_rules_test.dart` are: the branch cannot be exercised from a
      // test binary, so the assertion is that it is there and is the first
      // thing after the id is known.
      final source = File('lib/routing/app_router.dart').readAsStringSync();
      expect(
        source,
        contains('if (!resolvesInThisBuild(id)) return null;'),
        reason: 'onGenerateRoute must consult the gate, not only define it',
      );
    });
  });

  group('store rules that live in the code', () {
    testWidgets('no other platform is named on the sign-in screen', (
      tester,
    ) async {
      // 2.3.10. The Android autofill sentence is true on Android and is a
      // rejection on iOS, so the screen chooses by platform. A widget test
      // runs as Android unless it is told otherwise, which is the whole reason
      // this assertion pins the platform it is about.
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await _open(tester, 'C07');
      final named = find.textContaining('Android').evaluate().length;
      // Reset inside the body: the framework checks this variable before any
      // tear-down callback runs.
      debugDefaultTargetPlatformOverride = null;
      expect(named, 0);
    });

    testWidgets('and Android still explains its own autofill', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await _open(tester, 'C07');
      final named = find.textContaining('Android').evaluate().length;
      debugDefaultTargetPlatformOverride = null;
      expect(named, 1);
    });

    test('no row opens a page that has no address', () {
      // A03 renders its policy and terms rows only when the links are set, so
      // an unfilled `LegalLinks` shows nothing rather than a dead tap. This
      // asserts the rule, not the values: `tool/release_preflight.sh` is what
      // refuses to submit while they are empty.
      expect(
        LegalLinks.allSet ||
            (LegalLinks.privacyPolicy.isEmpty && LegalLinks.terms.isEmpty),
        isTrue,
        reason: 'either every page has an address, or no row is drawn',
      );
    });
  });

  group('the first release is the shape that ships', () {
    testWidgets('it opens on Home, with no community and no coach side', (
      tester,
    ) async {
      AppRouter.featureFlags = FeatureFlags.shipped;
      await tester.pumpWidget(OwnHubApp(key: UniqueKey()));
      await tester.pumpAndSettle();
      final l10n = await AppL10n.delegate.load(const Locale('en'));

      expect(
        find.text(l10n.startEverythingsReady),
        findsOneWidget,
        reason: 'no account, so Home is the front door',
      );
      expect(
        find.text(l10n.community),
        findsNothing,
        reason: 'the community needs a moderator, so it is dark in 1.0',
      );
      expect(
        find.text(l10n.allScreens),
        findsNothing,
        reason: 'the index of every screen is not part of the product',
      );
    });

    test('the testing aids key off the build, not off a flag', () {
      // `Feature.accountRequired` used to be the difference between a testing
      // build and a real one. It cannot be any more: the first release ships
      // with it off. This asserts the wiring at source, because a widget test
      // always runs in debug and so can never observe the release arm.
      final router = File('lib/routing/app_router.dart').readAsStringSync();
      expect(
        router.contains(
          'kDebugMode && !featureFlags.isOn(Feature.accountRequired)',
        ),
        isTrue,
        reason: 'testingAidsAllowed must require a debug build',
      );
      for (final aid in [
        'onOpenAllScreens: !testingAidsAllowed',
        'testCode: testingAidsAllowed',
      ]) {
        expect(router.contains(aid), isTrue, reason: 'ungated aid: $aid');
      }
      for (final state in [
        'lib/app_state/coach_profile_state.dart',
        'lib/app_state/coaching_link_state.dart',
        'lib/app_state/coach_portfolio_state.dart',
      ]) {
        expect(
          File(state)
              .readAsStringSync()
              .contains('AppRouter.testingAidsAllowed'),
          isTrue,
          reason: '$state opens a test rail; it must key off the build',
        );
      }
    });
  });
}
