// D11 — she trains, she coaches, or she does both.
//
// The rules worth pinning are the ones that protect something: that a
// single-role account is never offered a switcher, and that `active` is treated
// as a preference rather than an entitlement.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/identity/user_roles.dart';

void main() {
  group('what she holds', () {
    test('a single role cannot switch', () {
      expect(UserRoles.trainee.canSwitch, isFalse);
      expect(UserRoles.coach.canSwitch, isFalse);
    });

    test('both roles can', () {
      expect(UserRoles.both.canSwitch, isTrue);
      expect(UserRoles.both.held, {AppRole.trainee, AppRole.coach});
    });

    test('switching flips the active role and keeps what she holds', () {
      final switched = UserRoles.both.switched();
      expect(switched.active, AppRole.coach);
      expect(switched.held, UserRoles.both.held);
      expect(switched.switched().active, AppRole.trainee);
    });

    test(
      'switching a single-role account does nothing, and does not throw',
      () {
        // The UI should never have offered it. Crashing her app is a worse
        // answer to a UI mistake than quietly doing nothing.
        expect(UserRoles.trainee.switched(), UserRoles.trainee);
        expect(UserRoles.coach.switched(), UserRoles.coach);
      },
    );

    test('activating a role she does not hold is refused', () {
      // The security property D11 keeps: she cannot reach the coach app by
      // asking for it. Holding the role is server-written.
      expect(
        UserRoles.trainee.activating(AppRole.coach).active,
        AppRole.trainee,
      );
      expect(UserRoles.both.activating(AppRole.coach).active, AppRole.coach);
    });
  });

  group('active is a preference, never an entitlement', () {
    test('a stale active role falls back to one she actually holds', () {
      // `held` can shrink — a coach whose certification lapses, an account
      // restricted after review. A stored `active` that outlived its
      // entitlement must not leave her inside an app she no longer holds.
      const lapsed = UserRoles(held: {AppRole.trainee}, active: AppRole.coach);
      expect(lapsed.active, AppRole.trainee);
      expect(lapsed.canSwitch, isFalse);
    });

    test('an empty set resolves rather than throwing', () {
      // Should not happen. If it does, a woman staring at a crashed app is the
      // worst possible way to find out.
      const nothing = UserRoles(held: {}, active: AppRole.coach);
      expect(nothing.active, AppRole.trainee);
    });
  });

  group('equality', () {
    test('same roles and same active are equal', () {
      expect(
        const UserRoles(held: {AppRole.trainee}, active: AppRole.trainee),
        UserRoles.trainee,
      );
    });

    test('same roles but a different active are not', () {
      expect(UserRoles.both.switched(), isNot(UserRoles.both));
    });

    test('holding more is not the same as holding less', () {
      expect(UserRoles.both, isNot(UserRoles.trainee));
    });
  });

  group('the scope', () {
    testWidgets('defaults to trainee when nothing is above it', (tester) async {
      // Every screen is also rendered standalone, in tests and in the design
      // gallery. Those call sites are correct, so reading the role must
      // degrade rather than assert.
      late UserRoles seen;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            seen = RoleScope.rolesOf(context);
            return const SizedBox();
          },
        ),
      );
      expect(seen, UserRoles.trainee);
    });

    testWidgets('reads what the scope holds', (tester) async {
      final notifier = ValueNotifier(UserRoles.both);
      addTearDown(notifier.dispose);

      late UserRoles seen;
      await tester.pumpWidget(
        RoleScope(
          notifier: notifier,
          child: Builder(
            builder: (context) {
              seen = RoleScope.rolesOf(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(seen, UserRoles.both);
    });

    testWidgets('rebuilds dependents when the role changes', (tester) async {
      final notifier = ValueNotifier(UserRoles.both);
      addTearDown(notifier.dispose);

      final seen = <AppRole>[];
      await tester.pumpWidget(
        RoleScope(
          notifier: notifier,
          child: Builder(
            builder: (context) {
              seen.add(RoleScope.rolesOf(context).active);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(seen, [AppRole.trainee]);

      notifier.value = notifier.value.switched();
      await tester.pump();

      // Switching role changes navigation and the screen under it together, so
      // a dependent that did not rebuild would leave the two disagreeing.
      expect(seen, [AppRole.trainee, AppRole.coach]);
    });
  });
}
