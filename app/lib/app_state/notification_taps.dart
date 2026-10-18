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
///
/// A getting started tip opens the screen it talks about, or the nearest one
/// that is switched on when that one is not ([fallbacks]). The first-gym
/// guide has no route of its own, so it is laid over the screen she is on
/// only when Train is open to her; otherwise that tip opens Train, by name.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../features/train/domain/getting_started_tips.dart';
import '../features/train/presentation/first_gym_guide_view.dart';
import '../routing/app_router.dart';
import '../routing/app_routes.dart';
import 'app_changes.dart';
import 'first_gym_guide_state.dart';
import 'getting_started.dart';
import 'workout_session_state.dart';

class NotificationTaps {
  NotificationTaps._();

  /// Today, "I already did it", the rest screen, and what the getting
  /// started tips talk about.
  static const Set<String> destinations = {
    'T01',
    'T02',
    'R09',
    ...tipDestinations,
  };

  /// What a getting started tip may carry.
  static const Set<String> tipDestinations = {
    'R03',
    'R01',
    'R14',
    'E12',
    'E05',
    kFirstGymTipPayload,
    'P06',
    'R02',
  };

  /// Where a tip goes when its own screen is switched off or not for her, in
  /// order. The first that is on wins.
  static const Map<String, List<String>> fallbacks = {
    'R03': ['R03', 'T01'],
    'R01': ['R01'],
    // A reminder scheduled before Explore replaced the library.
    'R14': ['R01'],
    'E12': ['E12', 'E01'],
    'E05': ['E05', 'E01'],
    kFirstGymTipPayload: ['R01'],
    'P06': ['P06', 'P01'],
    'R02': ['R02', 'R01'],
  };

  /// Whether a tip may open [screenId] for her now. A photo of her plate
  /// only where `E01` offers it: never with allergies, which a photo cannot
  /// check.
  static bool canOpen(String screenId) => switch (screenId) {
    'E12' =>
      AppRouter.screenIsOn('E12') &&
          AppRouter.isVerified &&
          !AppRouter.eatConstraints.hasAllergies,
    _ => AppRouter.screenIsOn(screenId),
  };

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
  ///
  /// [isOn] answers whether a screen may be opened; [canOpen] by default.
  static String? routeFor(
    String? payload, {
    required bool sessionLive,
    String? top,
    bool Function(String screenId)? isOn,
  }) {
    if (payload == null || !destinations.contains(payload)) return null;
    final String id;
    final chain = fallbacks[payload];
    if (chain != null) {
      final open = isOn ?? canOpen;
      final first = chain.where(open).firstOrNull;
      if (first == null) return null;
      id = first;
    } else if (payload == 'R09') {
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
    if (payload == kFirstGymTipPayload && _gymGuideOpen()) {
      _openGymGuide(navigator);
      return true;
    }
    final name = routeFor(payload, sessionLive: sessionLive, top: top);
    if (name == null) return false;
    unawaited(navigator.pushNamed<Object?>(name));
    return true;
  }

  /// The guide, only where the workout it leads to is open to her: past the
  /// verification gate, Train on, and not seen yet.
  static bool _gymGuideOpen() =>
      !FirstGymGuideState.instance.seen &&
      AppRouter.verificationGate('R03') == null &&
      AppRouter.screenIsOn('R03');

  /// Shown once, like the one before her first gym session. Its last button
  /// opens the workout by name, so the gate still has the last word.
  static void _openGymGuide(NavigatorState navigator) {
    FirstGymGuideState.instance.seen = true;
    AppChanges.bump();
    GettingStarted.settled();
    unawaited(
      navigator.push<void>(
        MaterialPageRoute<void>(
          builder: (guide) => FirstGymGuideView(
            onStartWorkout: () => unawaited(
              Navigator.of(
                guide,
              ).pushReplacementNamed<Object?, Object?>(appRoutes['R03']!.name),
            ),
            onClose: () => Navigator.of(guide).pop(),
          ),
        ),
      ),
    );
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
