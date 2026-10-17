// Routing is derived from the screen inventory, so these tests guard what
// generation cannot: that the scope is the whole product (DECISIONS.md D1), and
// that the six first-run states never became destinations (HANDOFF rule 16).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/routing/app_routes.dart';

void main() {
  test('the generated inventory still holds every prototype screen', () {
    // 161 until D12's admin content console landed: Z01–Z11 added eleven.
    // D18 added Z12 and Z13, the recipe and programme forms, so those two
    // collections can be authored one row at a time and not only by CSV.
    // D25 added Z14, the switchboard — the only place in the product where a
    // feature is turned on or off.
    //
    // 175 → 177 when the verification flow was wired: `C09b`, the consent step
    // that has to be agreed to before any camera opens, and `C10b`, the second
    // pass that photographs the back of the card. Both are real screens a woman
    // walks through, so both are in the inventory rather than smuggled in as
    // states of their neighbours. Their ids carry a letter rather than taking
    // the next number because C10 to C16 are referenced by id throughout the
    // specs, the plans and the prototype, and renumbering would repoint every
    // one of those references at the wrong screen.
    //
    // 177 -> 179 with Rahma's recipe book. `E10` asks the one question the
    // library cannot be opened without: `DietaryConstraints.none` is a claim
    // that she was asked and named nothing, and shipping allergen-tagged
    // recipes against a claim nobody made is exactly what
    // `allergy_interlock_test.dart` exists to stop. `E11` is her closing
    // letter, squeezed under a recipe on page 26 of the book. Neither is a
    // state of a neighbour, so neither is smuggled in as one.
    //
    // 179 -> 184 with the owner's operations: `Z15` the dashboard, `Z16` the
    // logs, `Z17` and `Z18` her events, and `T09`, the members' Events screen
    // behind Feature.events. All five were designed in Flutter (`noMockup`).
    //
    // 184 -> 185 with `P05`, her progress card, opened from P01 to share.
    // 185 -> 187 when setup asked one thing a screen: `O06`, what she has at
    // home, and `O07`, minutes a session. 187 -> 192 when the coach's setup
    // did the same: `K08` her name and city, `K10` how she coaches, `K11` her
    // clients' results, `K12` what clients say, `K13` the three rules.
    // 192 -> 194 with the exercise library (D42): `R14` the moves by the part
    // of the body they work, `R15` one move's clip.
    //
    // 194 -> 193 on 17 October 2026: `O07`, minutes a session, was folded
    // into `O03`, days and minutes on one screen.
    expect(appRoutes.length, 193);
  });

  test('every screen is a destination except the eight first-run states', () {
    // D1 withdrew the MVP cut: both roles, every flow. 179 - 8 = 171.
    //
    // Six first-run states until the Cycle flow was built. Y11 and Y14 joined
    // them: both are branches of Y03 rendered by the same widget, exactly as
    // T06 is a branch of T01, so routing to them would mean rendering "severe
    // symptoms" over a hub that has none.
    //
    // 169 -> 171: E10 and E11 are both destinations. E10 in particular must be
    // one — a question asked inside a sheet leaves no way back to it, and
    // `product_rules_test.dart` bans a dialog on these paths anyway.
    //
    // 171 -> 176: Z15 to Z18 and T09 are all destinations.
    //
    // 176 -> 177: P05 is a destination. 177 -> 184: O06, O07, K08, K10,
    // K11, K12 and K13 are all destinations. 184 -> 186: R14 and R15 are.
    //
    // 186 -> 185 on 17 October 2026: `O07` was folded into `O03`.
    expect(appDestinations.length, 185);
    expect(appRoutes.length - firstRunStates.length, appDestinations.length);
  });

  test('all seventeen flows are reachable', () {
    // Guards against the scope silently narrowing back to the client-only cut.
    //
    // Seventeen since D12: `admin` is the console staff use to author the
    // content library, and the only flow whose role is neither client nor
    // coach. It is listed here for the same reason as the rest — a flow that
    // quietly stops being reachable is how a whole surface disappears.
    final flows = appDestinations.values.map((r) => r.flow).toSet();
    expect(flows.length, 17);
    for (final f in [
      'signup',
      'today',
      'train',
      'eat',
      'progress',
      'account',
      'cycle',
      'community',
      'coaching',
      'coached',
      'onboarding',
      'assistant',
      'coach',
      'coach-setup',
      'coachbrand',
      'coachplan',
      'admin',
    ]) {
      expect(flows, contains(f), reason: '$f must be reachable');
    }
  });

  test('no first-run state is routable', () {
    // Rule 16. If one of these gained a route, something could navigate to
    // "Home, empty" while Home is not empty.
    expect(firstRunStates, {
      'T06',
      'E09',
      'M17',
      'K24',
      'W11',
      'B14',
      'Y11',
      'Y14',
    });
    for (final id in firstRunStates) {
      expect(
        appRoutes.containsKey(id),
        isTrue,
        reason: '$id should exist in the inventory as a screen',
      );
      expect(
        appDestinations.containsKey(id),
        isFalse,
        reason: '$id must not be a destination',
      );
      expect(
        screenIdForRoute(appRoutes[id]!.name),
        isNull,
        reason: '${appRoutes[id]!.name} must not resolve',
      );
      expect(
        AppRouter.onGenerateRoute(RouteSettings(name: appRoutes[id]!.name)),
        isNull,
      );
    }
  });

  test('route names are unique and absolute', () {
    final names = appDestinations.values.map((r) => r.name).toList();
    expect(names.toSet().length, names.length);
    expect(names.every((n) => n.startsWith('/')), isTrue);
  });

  test('a screen from every part of the product resolves', () {
    // One per area, so a regression in any flow shows up here.
    for (final id in [
      'C01',
      'O01',
      'T01',
      'R01',
      'E01',
      'P01',
      'A01',
      'Y01',
      'M01',
      'H01',
      'G01',
      'X01',
      'K01',
      'B01',
      'W01',
    ]) {
      final route = appRoutes[id];
      if (route == null) continue;
      expect(screenIdForRoute(route.name), id, reason: '$id must resolve');
      expect(
        AppRouter.onGenerateRoute(RouteSettings(name: route.name)),
        isNotNull,
      );
    }
  });

  testWidgets('an unbuilt destination says so instead of looking finished', (
    WidgetTester tester,
  ) async {
    // The subject is chosen at run time, not named here.
    //
    // This test has been aimed at P02, then M01, then B02, then B12, and every
    // one of them was eventually written — so the test that proves an unbuilt
    // screen admits it has four times been proving something about a finished
    // one. It now finds a destination with no widget behind it, whichever that
    // is today, and falls back to an unknown route once every destination is
    // built. Either way the guarantee under test is the same: a route that
    // resolves to no screen says so, rather than rendering something that
    // looks finished.
    final saved = AppRouter.featureFlags;
    // `everything` rather than literally every flag, and the difference is
    // `Feature.accountRequired`. That flag is now the whole-app gate: with it
    // on, `AppRouter.verificationGate` answers every product route with the
    // sign-up chain, so this test would open `C01` and report that the
    // placeholder is missing — measuring the gate instead of the placeholder.
    // `FeatureFlags.everything` is documented as the shape the product is
    // explored in, and it is the shape this test has always meant.
    AppRouter.featureFlags = FeatureFlags.everything;
    addTearDown(() => AppRouter.featureFlags = saved);

    final unbuilt = appDestinations.keys.where((id) => !AppRouter.isBuilt(id));

    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: AppRouter.onGenerateRoute,
        onUnknownRoute: AppRouter.onUnknownRoute,
        initialRoute: unbuilt.isEmpty
            ? '/nothing/serves-this'
            : appDestinations[unbuilt.first]!.name,
      ),
    );
    await tester.pumpAndSettle();

    if (unbuilt.isNotEmpty) {
      expect(find.text(unbuilt.first), findsOneWidget);
    }
    expect(find.textContaining('Not built yet'), findsOneWidget);
  });
}
