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

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/config/legal_links.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/main.dart';
import 'package:own_hub/routing/app_router.dart';

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
}
