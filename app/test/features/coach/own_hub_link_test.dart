import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/coach_invite_state.dart';
import 'package:own_hub/features/coach/domain/coach_invite.dart';
import 'package:own_hub/features/coach/presentation/own_hub_link_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/routing/app_routes.dart';
import 'package:own_hub/routing/coaching_wiring.dart' show CoachPortfolioArgs;
import 'package:own_hub/routing/platform_links.dart';
import 'package:own_hub/theme/app_tokens.dart';

import '../../qa/round1/round1_harness.dart';

Widget _host(Widget child, {Locale locale = const Locale('en')}) => MaterialApp(
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

  testWidgets(
    'a redeemed code opens the coach\'s page, and only then lets go',
    (tester) async {
      final key = GlobalKey<NavigatorState>();
      final opened = <RouteSettings>[];
      AppRouter.navigatorKey = key;
      addTearDown(() {
        AppRouter.navigatorKey = null;
        CoachInviteState.instance.reset();
      });
      CoachInviteState.instance
        ..reset()
        ..pendingCode = 'TEST2345'
        ..pendingCoach = 'coach9';

      // The navigator is not up yet: nothing is lost.
      AppRouter.navigatorKey = null;
      expect(AppRouter.openInvitedCoach(), isFalse);
      expect(CoachInviteState.instance.pendingCoach, 'coach9');
      expect(CoachInviteState.instance.pendingCode, 'TEST2345');

      AppRouter.navigatorKey = key;
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: key,
          home: const SizedBox(),
          onGenerateRoute: (settings) {
            opened.add(settings);
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => const SizedBox(),
            );
          },
        ),
      );
      expect(AppRouter.openInvitedCoach(), isTrue);
      await tester.pump();
      final page = opened.last;
      expect(page.name, appRoutes['H02']!.name);
      expect((page.arguments! as CoachPortfolioArgs).uid, 'coach9');
      expect(CoachInviteState.instance.pendingCode, isNull);
      expect(CoachInviteState.instance.pendingCoach, isNull);
      expect(AppRouter.openInvitedCoach(), isFalse);
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

  test('parseOwnHubLink reads the whole URL a platform may hand over, too', () {
    final invite = parseOwnHubLink('https://own-hub.app/c/abcd-2345?utm=x');
    expect(invite?.kind, OwnHubLinkKind.invite);
    expect(invite?.value, 'ABCD2345');
    final profile = parseOwnHubLink('https://own-hub.app/p/abc123XYZ789');
    expect(profile?.kind, OwnHubLinkKind.profile);
    expect(profile?.value, 'abc123XYZ789');
    expect(inviteLinkFor('ABCD2345'), 'https://own-hub.app/c/ABCD2345');
    expect(parseOwnHubLink(inviteLinkFor('ABCD2345'))?.value, 'ABCD2345');
    expect(
      parseOwnHubLink(profileLinkFor('abc123XYZ789'))?.value,
      'abc123XYZ789',
    );
    for (final other in [
      'ownhub://widget?homeWidget=1&to=T01',
      '?homeWidget=1&to=T01',
      'https://own-hub.app/privacy',
      'app-1-123-ios-abc://firebaseauth/link?deep_link_id=x',
    ]) {
      expect(parseOwnHubLink(other), isNull, reason: other);
    }
  });

  test(
    'a pushed URL is the app\'s to follow only when it is a link or a screen',
    () {
      for (final ours in [
        'https://own-hub.app/c/ABCD2345',
        '/c/ABCD2345',
        'https://own-hub.app/p/abc123XYZ789',
        '/c/short', // a broken link still gets its explanation page
        appRoutes['K07']!.name,
      ]) {
        expect(appFollowsPushedRoute(Uri.parse(ours)), isTrue, reason: ours);
      }
      for (final foreign in [
        'ownhub://widget?homeWidget=1&to=T01',
        '/?homeWidget=1&to=T01',
        'app-1-123-ios-abc://firebaseauth/link?deep_link_id=x',
        '/nothing/here',
      ]) {
        expect(
          appFollowsPushedRoute(Uri.parse(foreign)),
          isFalse,
          reason: foreign,
        );
      }
    },
  );

  group('in the real app', () {
    useShippingApp();

    setUp(() {
      CoachInviteState.instance.reset();
      AppRouter.coachInviteStoreOverride = InMemoryCoachInviteStore();
    });
    tearDown(() {
      CoachInviteState.instance.reset();
      AppRouter.coachInviteStoreOverride = null;
    });

    Future<void> platformPushes(WidgetTester t, String url) async {
      await t.binding.defaultBinaryMessenger.handlePlatformMessage(
        SystemChannels.navigation.name,
        SystemChannels.navigation.codec.encodeMethodCall(
          MethodCall('pushRouteInformation', <String, Object?>{
            'location': url,
          }),
        ),
        (_) {},
      );
      await settle(t);
    }

    String? topRoute(WidgetTester t) {
      String? name;
      nav(t).popUntil((route) {
        name = route.settings.name;
        return true;
      });
      return name;
    }

    for (final url in ['/c/ABCD2345', 'https://own-hub.app/c/ABCD2345']) {
      testWidgets('cold start on $url keeps the invite code', (tester) async {
        phone(tester);
        tester.platformDispatcher.defaultRouteNameTestValue = url;
        addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);
        await boot(tester);
        expect(CoachInviteState.instance.pendingCode, 'ABCD2345');
        expect(find.byType(OwnHubLinkView), findsNothing);
      });

      testWidgets('warm start on $url opens the link and keeps the code', (
        tester,
      ) async {
        phone(tester);
        await boot(tester);
        expect(CoachInviteState.instance.pendingCode, isNull);
        await platformPushes(tester, url);
        expect(find.byType(OwnHubLinkView), findsOneWidget);
        expect(
          tester
              .widget<OwnHubLinkView>(find.byType(OwnHubLinkView))
              .link
              ?.value,
          'ABCD2345',
        );
        expect(CoachInviteState.instance.pendingCode, 'ABCD2345');
      });
    }

    testWidgets('a profile link opens that coach\'s page (H02)', (
      tester,
    ) async {
      phone(tester);
      await boot(tester);
      await platformPushes(tester, 'https://own-hub.app/p/abc123XYZ789');
      expect(topRoute(tester), appRoutes['H02']!.name);
    });

    testWidgets('a widget tap or a sign-in callback pushes nothing', (
      tester,
    ) async {
      phone(tester);
      await boot(tester);
      final before = topRoute(tester);
      for (final url in [
        'ownhub://widget?homeWidget=1&to=T01',
        'app-1-123-ios-abc://firebaseauth/link?deep_link_id=x',
      ]) {
        await platformPushes(tester, url);
        expect(topRoute(tester), before, reason: url);
        expect(find.byType(OwnHubLinkView), findsNothing, reason: url);
      }
    });
  });

  test('the platform files and the site name the same links, the same app', () {
    final pbxproj = File('ios/Runner.xcodeproj/project.pbxproj')
        .readAsStringSync();
    final team = RegExp(r'DEVELOPMENT_TEAM = (\w+);')
        .firstMatch(pbxproj)!
        .group(1);
    final bundle = RegExp(
      r'PRODUCT_BUNDLE_IDENTIFIER = (com\.ownhub\.fitness);',
    ).firstMatch(pbxproj)!.group(1);

    final aasa = jsonDecode(
      File('../site/.well-known/apple-app-site-association').readAsStringSync(),
    ) as Map<String, dynamic>;
    final detail = ((aasa['applinks'] as Map)['details'] as List).single as Map;
    expect(detail['appIDs'], ['$team.$bundle']);
    expect((detail['components'] as List).map((c) => (c as Map)['/']), [
      '/c/*',
      '/p/*',
    ]);

    final info = File('ios/Runner/Info.plist').readAsStringSync();
    expect(
      RegExp(r'<key>FlutterDeepLinkingEnabled</key>\s*<true/>').hasMatch(info),
      isTrue,
      reason: 'with it off iOS never hands the link to Flutter',
    );
    expect(
      File('ios/Runner/Runner.entitlements').readAsStringSync(),
      contains('<string>applinks:own-hub.app</string>'),
    );

    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    expect(manifest, contains('android:autoVerify="true"'));
    expect(manifest, contains('android:pathPrefix="/c/"'));
    expect(manifest, contains('android:pathPrefix="/p/"'));
    expect(manifest, contains('android:host="own-hub.app"'));

    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    final applicationId = RegExp(r'applicationId = "([^"]+)"')
        .firstMatch(gradle)!
        .group(1);
    final asset =
        (jsonDecode(
              File('../site/.well-known/assetlinks.json').readAsStringSync(),
            ) as List).single
            as Map<String, dynamic>;
    final target = asset['target'] as Map<String, dynamic>;
    expect(target['package_name'], applicationId);
    final fingerprints = (target['sha256_cert_fingerprints'] as List)
        .cast<String>();
    for (final f in fingerprints) {
      expect(f, matches(RegExp(r'^([0-9A-F]{2}:){31}[0-9A-F]{2}$')));
    }
    if (fingerprints.isEmpty) {
      // ignore: avoid_print
      print(
        'OWNER STEP: site/.well-known/assetlinks.json has no SHA-256 '
        'fingerprints, so Android cannot verify these links and opens them in '
        'the browser (/join). Add the Play App Signing and upload keys, see '
        'docs/owner/OWNER-TODO.md.',
      );
    }

    final redirects = File('../site/_redirects').readAsStringSync();
    expect(redirects, contains('/c/*'));
    expect(redirects, contains('/p/*'));
  });
}
