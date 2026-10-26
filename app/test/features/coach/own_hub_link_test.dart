import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/coach_invite_state.dart';
import 'package:own_hub/features/coach/domain/coach_invite.dart';
import 'package:own_hub/features/coach/presentation/own_hub_link_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/theme/app_tokens.dart';

Widget _host(
  Widget child, {
  Locale locale = const Locale('en'),
}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppL10n.localizationsDelegates,
  supportedLocales: AppL10n.supportedLocales,
  theme: buildTheme(locale),
  home: child,
);

void main() {
  test('parseOwnHubLink reads an invite, with spaces, case and a query', () {
    final a = parseOwnHubLink('/c/abcd2345?x=1');
    expect(a, isNotNull);
    expect(a!.kind, OwnHubLinkKind.invite);
    expect(a.value, 'ABCD2345');

    final b = parseOwnHubLink('/c/ABCD-2345');
    expect(b, isNotNull);
    expect(b!.kind, OwnHubLinkKind.invite);
    expect(b.value, 'ABCD2345');
  });

  test('rejects what is not a link', () {
    for (final bad in [
      '/c/short',
      '/c/0000OOOO',
      '/p/ab',
      '/coach/k07',
      '/signup/c01',
      '/c',
      '/',
      '/c/ABCD2345/extra',
    ]) {
      expect(parseOwnHubLink(bad), isNull, reason: bad);
    }
  });

  test('reads a profile uid', () {
    final link = parseOwnHubLink('/p/abc123XYZ789');
    expect(link, isNotNull);
    expect(link!.kind, OwnHubLinkKind.profile);
    expect(link.value, 'abc123XYZ789');
  });

  testWidgets(
    'OwnHubLinkView calls onOpen once for a good link and not for a bad one',
    (tester) async {
      var opened = 0;
      await tester.pumpWidget(
        _host(
          OwnHubLinkView(
            link: const OwnHubLink(OwnHubLinkKind.invite, 'ABCD2345'),
            onOpen: (_) => opened++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(opened, 1);

      opened = 0;
      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      OwnHubLinkView(link: null, onOpen: (_) => opened++),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(
        find.text('This link does not work. Ask your coach to send it again.'),
        findsOneWidget,
      );
      expect(opened, 0);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.byType(OwnHubLinkView), findsNothing);
    },
  );

  test('followLink keeps the code', () {
    addTearDown(() {
      CoachInviteState.instance.reset();
      AppRouter.coachInviteStoreOverride = null;
    });
    CoachInviteState.instance.reset();
    AppRouter.coachInviteStoreOverride = InMemoryCoachInviteStore();
    AppRouter.followLink(const OwnHubLink(OwnHubLinkKind.invite, 'TEST2345'));
    expect(CoachInviteState.instance.pendingCode, 'TEST2345');
  });

  test('the app\'s link paths are the ones the site and the manifest name', () {
    final aasa = File(
      '../site/.well-known/apple-app-site-association',
    ).readAsStringSync();
    expect(aasa, contains('/c/*'));
    expect(aasa, contains('/p/*'));
    expect(aasa, contains('NC94DG55XR.com.ownhub.fitness'));

    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    expect(manifest, contains('android:pathPrefix="/c/"'));
    expect(manifest, contains('android:pathPrefix="/p/"'));
    expect(manifest, contains('android:host="own-hub.app"'));

    final redirects = File('../site/_redirects').readAsStringSync();
    expect(redirects, contains('/c/*'));
    expect(redirects, contains('/p/*'));

    final entitlements = File(
      'ios/Runner/Runner.entitlements',
    ).readAsStringSync();
    expect(entitlements, contains('applinks:own-hub.app'));
  });
}
