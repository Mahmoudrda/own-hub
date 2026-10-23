/// A tap on a Home Screen or Lock Screen widget, turned into a screen.
///
/// The widgets open the app with `ownhub://widget?homeWidget=1&to=<id>`.
/// `home_widget` hands the URL over: at a cold start through
/// `initiallyLaunchedFromHomeWidget`, and while the app runs through
/// `widgetClicked`. This maps it to a route and pushes it.
///
/// ## A whitelist, not a router
///
/// `to` must be one of [destinations], and anything else is ignored. A URL is
/// something any app on the phone can open, so it names one of four screens
/// rather than a route path.
///
/// ## The gate still applies
///
/// The route is pushed by name, so it goes through `AppRouter.onGenerateRoute`
/// like any other: the verification gate, the feature flags and the
/// consent-before-lens rule all hold. A tap from a widget left on the Home
/// Screen after sign-out lands on the front door, not on Today.
///
/// ## Never destructive
///
/// It pushes, and only when the screen is not already on top. It never clears
/// the stack: a tap in the middle of a workout must not end the session she is
/// in.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:home_widget/home_widget.dart';

import '../routing/app_router.dart';

class WidgetLinks {
  WidgetLinks._();

  /// The screens a widget may open: Today, the workout, Progress and Eat.
  static const Set<String> destinations = {'T01', 'R03', 'P01', 'E01'};

  /// Set by `main()` on iOS and Android. Off, [start] does nothing, so a widget test that
  /// pumps the app opens no platform channel.
  static bool enabled = false;

  static StreamSubscription<Uri?>? _clicks;

  /// The route a widget URL opens, or null for anything that is not one.
  static String? routeFor(Uri? uri) {
    if (uri == null) return null;
    if (uri.scheme != 'ownhub' || uri.host != 'widget') return null;
    if (!uri.queryParameters.containsKey('homeWidget')) return null;
    final to = uri.queryParameters['to'];
    if (to == null || !destinations.contains(to)) return null;
    return appDestinations[to]?.name;
  }

  /// Pushes [uri]'s screen onto [navigator]. False when there was nothing to
  /// open or it is already the screen she is on.
  static bool open(NavigatorState? navigator, Uri? uri) {
    final name = routeFor(uri);
    if (navigator == null || name == null) return false;
    String? top;
    navigator.popUntil((route) {
      top = route.settings.name;
      return true;
    });
    if (top == name) return false;
    unawaited(navigator.pushNamed<Object?>(name));
    return true;
  }

  /// Listens for widget taps. Called after the first frame, so the navigator
  /// exists by the time a cold-start tap is read.
  static Future<void> start(GlobalKey<NavigatorState> navigatorKey) async {
    if (!enabled) return;
    try {
      await _clicks?.cancel();
      _clicks = HomeWidget.widgetClicked.listen(
        (uri) => open(navigatorKey.currentState, uri),
        onError: (Object _) {},
      );
      final initial = await HomeWidget.initiallyLaunchedFromHomeWidget();
      open(navigatorKey.currentState, initial);
    } catch (_) {
      // No plugin, or no URL. The app opens where it would have anyway.
    }
  }
}
