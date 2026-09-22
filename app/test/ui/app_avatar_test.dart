// Her profile picture, and the role switch behind it (D11).
//
// The assertions that matter are about restraint: a woman with one role must
// never be shown a switcher, and the control must announce what it actually
// does rather than what it looks like.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/identity/user_roles.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';
import 'package:own_hub/ui/app_avatar.dart';

Widget _host(
  Widget child, {
  Locale locale = const Locale('en'),
  ValueNotifier<UserRoles>? roles,
}) {
  final app = MaterialApp(
    locale: locale,
    localizationsDelegates: AppL10n.localizationsDelegates,
    supportedLocales: AppL10n.supportedLocales,
    theme: buildTheme(locale),
    home: Scaffold(body: Center(child: child)),
  );
  return roles == null ? app : RoleScope(notifier: roles, child: app);
}

String? _semanticLabel(WidgetTester tester) => find
    .ancestor(of: find.byType(InkWell), matching: find.byType(Semantics))
    .evaluate()
    .map((e) => (e.widget as Semantics).properties.label)
    .firstWhere((l) => l != null, orElse: () => null);

void main() {
  group('a woman with one role', () {
    testWidgets('is offered no switcher at all', (tester) async {
      // There is nothing to switch to. Showing the control anyway implies the
      // app is keeping a second half from her.
      await tester.pumpWidget(_host(const AppAvatar(roles: UserRoles.trainee)));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.swap_horiz), findsNothing);
    });

    testWidgets('tapping opens her profile', (tester) async {
      var opened = 0;
      await tester.pumpWidget(
        _host(
          AppAvatar(roles: UserRoles.trainee, onOpenProfile: () => opened++),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(AppAvatar));
      await tester.pumpAndSettle();

      expect(opened, 1);
      expect(find.text('Switch app'), findsNothing);
    });

    testWidgets('announces itself as her profile', (tester) async {
      await tester.pumpWidget(_host(const AppAvatar(roles: UserRoles.trainee)));
      await tester.pumpAndSettle();

      expect(_semanticLabel(tester), 'Your profile');
    });
  });

  group('a woman who holds both', () {
    testWidgets('is shown that the picture is a control', (tester) async {
      await tester.pumpWidget(_host(const AppAvatar(roles: UserRoles.both)));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.swap_horiz), findsOneWidget);
    });

    testWidgets('announces what the tap really does', (tester) async {
      // "Your profile" on a control that replaces the entire app would be a
      // lie to anyone using a screen reader.
      await tester.pumpWidget(_host(const AppAvatar(roles: UserRoles.both)));
      await tester.pumpAndSettle();

      expect(_semanticLabel(tester), 'Switch app');
    });

    testWidgets('tapping offers both apps, with the current one marked', (
      tester,
    ) async {
      await tester.pumpWidget(_host(const AppAvatar(roles: UserRoles.both)));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(AppAvatar));
      await tester.pumpAndSettle();

      expect(find.text('Switch app'), findsOneWidget);
      expect(find.text('Training'), findsOneWidget);
      expect(find.text('Coaching'), findsOneWidget);
      expect(find.textContaining('not one tab'), findsOneWidget);
    });

    testWidgets('choosing the other app switches the whole app', (
      tester,
    ) async {
      final roles = ValueNotifier(UserRoles.both);
      addTearDown(roles.dispose);
      final changes = <UserRoles>[];

      await tester.pumpWidget(
        _host(AppAvatar(onRoleChanged: changes.add), roles: roles),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(AppAvatar));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Coaching'));
      await tester.pumpAndSettle();

      expect(roles.value.active, AppRole.coach);
      expect(
        roles.value.held,
        UserRoles.both.held,
        reason: 'switching changes which app she is in, never what she holds',
      );
      expect(changes.single.active, AppRole.coach);
    });

    testWidgets('choosing the app she is already in changes nothing', (
      tester,
    ) async {
      final roles = ValueNotifier(UserRoles.both);
      addTearDown(roles.dispose);
      final changes = <UserRoles>[];

      await tester.pumpWidget(
        _host(AppAvatar(onRoleChanged: changes.add), roles: roles),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(AppAvatar));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Training'));
      await tester.pumpAndSettle();

      expect(roles.value.active, AppRole.trainee);
      expect(
        changes,
        isEmpty,
        reason: 'no switch happened, so none is reported',
      );
    });

    testWidgets('reads in Arabic, from the dictionary', (tester) async {
      await tester.pumpWidget(
        _host(
          const AppAvatar(roles: UserRoles.both),
          locale: const Locale('ar'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(AppAvatar));
      await tester.pumpAndSettle();

      expect(find.text('تبديل التطبيق'), findsOneWidget);
      expect(find.text('التدريب'), findsOneWidget);
      expect(find.text('التدريب الشخصي'), findsOneWidget);
      expect(find.text('Switch app'), findsNothing);
    });
  });

  testWidgets('draws her initial once there is a name', (tester) async {
    await tester.pumpWidget(
      _host(const AppAvatar(firstName: 'Mai', roles: UserRoles.trainee)),
    );
    await tester.pumpAndSettle();

    expect(find.text('M'), findsOneWidget);
    expect(find.byIcon(Icons.person), findsNothing);
  });

  testWidgets('falls back to a figure when there is no name yet', (
    tester,
  ) async {
    // C13 is where a name first exists. Before that this must still render.
    await tester.pumpWidget(_host(const AppAvatar(roles: UserRoles.trainee)));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.person), findsOneWidget);
  });
}
