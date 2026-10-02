// The whole-app gate: she cannot use the product before the check completes.
//
// The owner replaced a narrower rule with this one. A pending check used to
// close the community and nothing else, and `C14` promised her workouts,
// recipes and coach profiles while she waited. Nothing opens now.
//
// **The gate is built and switched off**, so most of this file is about a flag
// that is false in `FeatureFlags.shipped`. That is the point of testing it: the
// release order is deploy the functions first, flip the flag second, and a gate
// nobody proved before the flip is a gate that locks out every user — including
// the owner — with no sign that anything is wrong. See the note on
// `AppRouter.testingAidsAllowed`.
//
// It is enforced at the route rather than by hiding controls, because the
// platform hands `onGenerateRoute` whatever name it is given: a deep link, a
// notification payload, another app on the handset. Anything that can name
// `/train/r01` reaches Train unless the answer is given there.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/signup/domain/server_verification.dart';

import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/features/signup/domain/verification.dart';
import 'package:own_hub/features/signup/presentation/welcome_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/routing/app_routes.dart';

/// Every feature on AND an account required: the shape the product ships in
/// once the back end can approve somebody.
FeatureFlags get _gated =>
    FeatureFlags.allOff.with_({for (final f in Feature.values) f: true});

/// The name [route] actually resolved to, which is the gate's answer.
String? _resolved(String name) =>
    AppRouter.onGenerateRoute(RouteSettings(name: name))?.settings.name;

void main() {
  final savedFlags = AppRouter.featureFlags;
  final savedResult = AppRouter.lastVerification;

  setUp(() {
    AppRouter.lastVerification = null;
    AppRouter.awaitingReviewer = false;
    // She has agreed, so the consent redirect is not what these tests are
    // measuring. `signup_consent_test.dart` is where that one is proved.
    AppRouter.consentRecorded = true;
  });

  tearDown(() {
    AppRouter.featureFlags = savedFlags;
    AppRouter.lastVerification = savedResult;
    AppRouter.awaitingReviewer = false;
    AppRouter.consentRecorded = false;
  });

  group('with the flag off, which is how this ships today', () {
    // The world is built rather than borrowed, as `flag_independence_test`
    // asks: every feature on and `accountRequired` off, which is what
    // `FeatureFlags.everything` means. The one test below that reads the real
    // defaults is the one whose subject IS the defaults.
    setUp(() => AppRouter.featureFlags = FeatureFlags.everything);

    test('the flag is ON in the shipped defaults, and that is deliberate', () {
      // The only reading of the defaults in this file. It used to assert the
      // flag was off, because `functions/` was not deployed and turning it on
      // would have refused every woman with nothing able to approve her. The
      // owner turned it on for launch (2026-10-02); the release order is
      // deploy the functions, verify one real account end to end, then
      // release this build. The group around this test still proves the
      // open-gate behaviour on a world built from `FeatureFlags.everything`.
      expect(FeatureFlags.shipped.isOn(Feature.accountRequired), isTrue);
    });

    test('every product route still resolves to itself', () {
      for (final id in const ['T01', 'R01', 'E01', 'P01', 'Y03']) {
        final name = appDestinations[id]!.name;
        expect(_resolved(name), name, reason: '$id must still open');
      }
    });

    test('and the gate answers null for everything', () {
      for (final id in appDestinations.keys) {
        expect(AppRouter.verificationGate(id), isNull, reason: id);
      }
    });
  });

  group('with the flag on and nobody verified', () {
    setUp(() => AppRouter.featureFlags = _gated);

    test('every screen of the product answers with the sign-up chain', () {
      // The whole inventory, not a sample. A gate proved against five screens
      // is a gate with 160 holes nobody has looked at.
      final open = <String>[];
      for (final entry in appDestinations.entries) {
        final flow = entry.value.flow;
        if (AppRouter.openBeforeVerification.contains(flow)) continue;
        final landed = _resolved(entry.value.name);
        if (landed != appRoutes['C01']!.name) {
          open.add('${entry.key} ($flow) landed on $landed');
        }
      }
      expect(
        open,
        isEmpty,
        reason:
            'these screens are reachable by an account that has not passed '
            'the check:\n  ${open.join('\n  ')}',
      );
    });

    test('Train, Eat, Progress, My cycle, the community and the coach side '
        'are named one by one', () {
      // The owner's own list, spelled out, so a future change that quietly
      // adds a flow to `openBeforeVerification` fails here with her words
      // rather than only in the sweep above.
      for (final id in const [
        'R01', // Train
        'E01', // Eat
        'P01', // Progress
        'Y03', // My cycle
        'M01', // Community
        'H01', // Find a coach
        'K07', // The coach's own desk
        'G01', // Life as a coached client
        'X01', // The assistant
        'T01', // Home
      ]) {
        expect(
          _resolved(appDestinations[id]!.name),
          appRoutes['C01']!.name,
          reason: '$id is behind the check',
        );
      }
    });

    test('the four flows that stay open, stay open', () {
      // Each of these carries a reason on `AppRouter.openBeforeVerification`,
      // and each is a hole in a women-only gate, so each is pinned.
      for (final id in const [
        'C01', // sign-up IS the check
        'C09', // ditto
        'O01', // the setup questions, which open on top of the front door
        'A02', // her profile
        'A03', // her privacy centre, her export, her deletion
        'Z01', // staff tooling, already compiled out of a release binary
      ]) {
        final name = appDestinations[id]!.name;
        expect(_resolved(name), name, reason: '$id must never be gated');
      }
    });

    testWidgets('a deep link into Train opens the front door instead', (
      tester,
    ) async {
      // The form the refusal actually has to take. `onGenerateRoute` returning
      // null would land on `onUnknownRoute`, whose sentence is "no screen
      // serves this route" — untrue, and written for a developer.
      await tester.pumpWidget(
        MaterialApp(
          onGenerateRoute: AppRouter.onGenerateRoute,
          onUnknownRoute: AppRouter.onUnknownRoute,
          initialRoute: appDestinations['R01']!.name,
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(WelcomeView), findsOneWidget);
      expect(find.textContaining('No screen serves'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    test('a verified woman walks straight through', () {
      // `lastVerification` is the in-session half of `AppRouter.isVerified` —
      // what `C12` received a moment ago, which has to count immediately or a
      // woman is told "You're in" on `C13` and meets a locked app on `C16`.
      AppRouter.lastVerification = VerificationResult(
        method: VerificationMethod.automatic,
        decidedAt: DateTime(2026, 9, 25),
        imagesDeletedAt: DateTime(2026, 9, 25),
      );
      for (final id in const ['T01', 'R01', 'M01']) {
        final name = appDestinations[id]!.name;
        expect(_resolved(name), name, reason: '$id must open for her');
      }
    });
  });

  group('where the gate sends her', () {
    // Proved through the pure function, because a test binary has no Firebase
    // and therefore no signed-in woman: `AppRouter.signedInUid` is null there
    // whatever happens. The alternative was a settable uid on the router, which
    // is a way into the product that exists only for tests.

    String? gate(
      String id, {
      bool signedIn = false,
      bool verified = false,
      bool waiting = false,
    }) => AppRouter.gateDestination(
      id,
      gateClosed: true,
      signedIn: signedIn,
      verified: verified,
      waitingOnAReviewer: waiting,
    );

    test('signed out, to the front door', () {
      expect(gate('R01'), appRoutes['C01']!.name);
    });

    test('signed in and not started, to the check itself', () {
      expect(gate('R01', signedIn: true), appRoutes['C09']!.name);
    });

    test('waiting on a woman reviewer, to the screen that says so', () {
      // Not back to "here is why we check", which would read as though the
      // check she finished had never happened.
      expect(
        gate('R01', signedIn: true, waiting: true),
        appRoutes['C14']!.name,
      );
    });

    test('waiting survives a restart: it is derived from the server (S8)', () {
      // A fresh process: no session flag, only what the server said at
      // start-up. Every server state that is not "verified in her token"
      // holds her at C14, which tells her which one it is.
      addTearDown(() {
        AppRouter.serverVerification = null;
        AppRouter.awaitingReviewer = false;
      });
      AppRouter.awaitingReviewer = false;
      AppRouter.serverVerification = null;
      expect(AppRouter.awaitingReviewer, isFalse);
      for (final state in ServerVerificationState.values) {
        AppRouter.serverVerification = ServerVerification(state);
        expect(AppRouter.awaitingReviewer, isTrue, reason: '$state');
        expect(
          gate('R01', signedIn: true, waiting: AppRouter.awaitingReviewer),
          appRoutes['C14']!.name,
          reason: '$state',
        );
      }
    });

    test('verified, nowhere: she is let through', () {
      expect(gate('R01', signedIn: true, verified: true), isNull);
    });

    test('and with the gate open, nowhere either', () {
      expect(
        AppRouter.gateDestination(
          'R01',
          gateClosed: false,
          signedIn: false,
          verified: false,
          waitingOnAReviewer: false,
        ),
        isNull,
      );
    });
  });

  group('what counts as being behind the gate', () {
    test('every flow that is not explicitly open', () {
      for (final id in const ['T01', 'R01', 'E01', 'Y03', 'M01', 'K07']) {
        expect(AppRouter.behindVerification(id), isTrue, reason: id);
      }
      for (final id in const ['C01', 'O01', 'A02', 'Z01']) {
        expect(AppRouter.behindVerification(id), isFalse, reason: id);
      }
    });

    test('and an id nobody recognises', () {
      // The opposite of `screenIsOn`, which treats an unknown id as ON so a
      // typo shows a broken link rather than deleting a control. This is a
      // gate, and a typo must not be a way in.
      expect(AppRouter.behindVerification('QQ9'), isTrue);
      expect(AppRouter.behindVerification(''), isTrue);
    });
  });
}
