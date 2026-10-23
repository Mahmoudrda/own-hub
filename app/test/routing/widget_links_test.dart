// A widget tap opens one of four screens, through the same gate as anything
// else, and never stacks a screen on itself.
//
// `ownhub://widget?homeWidget=1&to=<id>` is a URL any app on the phone can
// open, so `to` is matched against a whitelist and pushed by name through
// `AppRouter.onGenerateRoute`, where the verification gate answers.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/guest_session.dart';
import 'package:own_hub/app_state/widget_links.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/routing/app_routes.dart';

Uri _link(String to) => Uri.parse('ownhub://widget?homeWidget=1&to=$to');

class _Pushes extends NavigatorObserver {
  final List<String?> names = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      names.add(route.settings.name);
}

void main() {
  test('the four destinations map to their routes', () {
    expect(WidgetLinks.destinations, {'T01', 'R03', 'P01', 'E01'});
    for (final id in WidgetLinks.destinations) {
      expect(WidgetLinks.routeFor(_link(id)), appDestinations[id]!.name);
    }
  });

  test('anything else is ignored', () {
    for (final uri in [
      null,
      _link('A02'),
      _link('Y01'),
      _link('/train/r03'),
      Uri.parse('ownhub://widget?to=T01'),
      Uri.parse('ownhub://elsewhere?homeWidget=1&to=T01'),
      Uri.parse('https://widget?homeWidget=1&to=T01'),
      Uri.parse('ownhub://widget?homeWidget=1'),
      Uri(),
    ]) {
      expect(WidgetLinks.routeFor(uri), isNull, reason: '$uri');
    }
  });

  group('through the gate', () {
    final saved = AppRouter.featureFlags;
    setUp(() {
      AppRouter.featureFlags = FeatureFlags.allOff.with_({
        for (final f in Feature.values) f: true,
      });
      AppRouter.lastVerification = null;
      AppRouter.awaitingReviewer = false;
    });
    tearDown(() => AppRouter.featureFlags = saved);

    test('an unverified tap lands on the front door, not the screen', () {
      for (final id in WidgetLinks.destinations) {
        // Guest mode: Home, the workout day and Eat open for browsing.
        if (GuestSession.screens.contains(id)) continue;
        final name = WidgetLinks.routeFor(_link(id))!;
        final route = AppRouter.onGenerateRoute(RouteSettings(name: name));
        expect(route?.settings.name, appRoutes['C01']!.name, reason: id);
      }
    });
  });

  testWidgets('pushes once, and not onto itself', (tester) async {
    final key = GlobalKey<NavigatorState>();
    final pushes = _Pushes();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: key,
        navigatorObservers: [pushes],
        initialRoute: '/start',
        onGenerateRoute: (settings) => MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => Text(settings.name ?? ''),
        ),
      ),
    );
    pushes.names.clear();

    final progress = appDestinations['P01']!.name;
    expect(WidgetLinks.open(key.currentState, _link('P01')), isTrue);
    await tester.pumpAndSettle();
    expect(pushes.names, [progress]);

    expect(WidgetLinks.open(key.currentState, _link('P01')), isFalse);
    await tester.pumpAndSettle();
    expect(pushes.names, [progress]);

    expect(WidgetLinks.open(key.currentState, _link('nope')), isFalse);
    expect(WidgetLinks.open(null, _link('T01')), isFalse);
  });

  test('off unless main() turns it on', () async {
    expect(WidgetLinks.enabled, isFalse);
    await WidgetLinks.start(GlobalKey<NavigatorState>());
  });
}
