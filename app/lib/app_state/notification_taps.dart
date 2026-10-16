/// A tap on one of her local notifications, turned into a screen.
///
/// The payload is a screen id from [destinations] and nothing else: no text,
/// no number, nothing about her. Anything not on the list is ignored, the way
/// `WidgetLinks` treats a widget URL, and the route is pushed by name so the
/// verification gate and the feature flags still apply.
///
/// Never destructive: it pushes, and only when that screen is not already on
/// top. A tap on "Rest is over" while the session is on screen opens nothing,
/// so a second R09 is never laid over the live one.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';

import '../routing/app_routes.dart';
import 'workout_session_state.dart';

class NotificationTaps {
  NotificationTaps._();

  /// Today, "I already did it" and the rest screen.
  static const Set<String> destinations = {'T01', 'T02', 'R09'};

  /// A tap that arrived before there was a navigator to push on, from a cold
  /// start.
  static String? _pending;
  static GlobalKey<NavigatorState>? _navigatorKey;

  /// Called by the adapter for every tap.
  static void received(String? payload) {
    if (payload == null || !destinations.contains(payload)) return;
    final navigator = _navigatorKey?.currentState;
    if (navigator == null) {
      _pending = payload;
      return;
    }
    open(navigator, payload, sessionLive: WorkoutSessionState.instance.isLive);
  }

  /// The route [payload] opens, or null when there is nothing to push.
  ///
  /// The rest screen is part of a session. With one live she is already in
  /// it, or one tap from it, so it resumes at the mid-set screen only when
  /// something else is on top; with none, a rest means nothing.
  static String? routeFor(
    String? payload, {
    required bool sessionLive,
    String? top,
  }) {
    if (payload == null || !destinations.contains(payload)) return null;
    final String id;
    if (payload == 'R09') {
      if (!sessionLive) return null;
      final inSession = top != null && top.startsWith('/train/');
      if (inSession) return null;
      id = 'R07';
    } else {
      id = payload;
    }
    final name = appRoutes[id]?.name;
    if (name == null || name == top) return null;
    return name;
  }

  static bool open(
    NavigatorState? navigator,
    String? payload, {
    required bool sessionLive,
  }) {
    if (navigator == null) return false;
    String? top;
    navigator.popUntil((route) {
      top = route.settings.name;
      return true;
    });
    final name = routeFor(payload, sessionLive: sessionLive, top: top);
    if (name == null) return false;
    unawaited(navigator.pushNamed<Object?>(name));
    return true;
  }

  /// Called after the first frame, once there is a navigator, so a tap that
  /// launched the app is opened too.
  static void start(
    GlobalKey<NavigatorState> navigatorKey, {
    String? launchedWith,
  }) {
    _navigatorKey = navigatorKey;
    final waiting = _pending ?? launchedWith;
    _pending = null;
    if (waiting != null) received(waiting);
  }
}
