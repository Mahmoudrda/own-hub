/// The usage-statistics facts that are not a tap: which sink a build uses,
/// the user properties every event carries, and a return after a quiet week.
///
/// Everything here goes through `AnalyticsGateway`, so it carries the same
/// closed vocabularies as every other event, and through the sink, so none of
/// it leaves the phone before she allows statistics.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../domain/analytics/analytics_gateway.dart';
import '../routing/app_router.dart';
import 'analytics_consent.dart';
import 'debug_analytics_sink.dart';
import 'firebase_analytics_sink.dart';
import 'firebase_boot.dart';
import 'kitten_setting.dart';
import 'posthog_analytics.dart';

const bool _kAnalyticsDebugSend = bool.fromEnvironment(
  'OWNHUB_ANALYTICS_DEBUG',
);

/// The sink a build uses.
///
///   * release: Firebase and PostHog, each gated by consent;
///   * debug: the console, plus consent-gated providers when
///     started with `OWNHUB_ANALYTICS_DEBUG` to check integration;
///   * profile: nothing, or consent-gated providers with `OWNHUB_ANALYTICS_DEBUG`.
AnalyticsSink analyticsSinkFor({
  required bool release,
  required bool debug,
  bool debugSend = _kAnalyticsDebugSend,
}) {
  if (release) {
    return TeeAnalyticsSink([
      const FirebaseAnalyticsSink(),
      PostHogAnalytics.instance,
    ]);
  }
  if (debug) {
    return debugSend
        ? TeeAnalyticsSink([
            const DebugPrintAnalyticsSink(),
            const FirebaseAnalyticsSink(),
            PostHogAnalytics.instance,
          ])
        : const DebugPrintAnalyticsSink();
  }
  return debugSend
      ? TeeAnalyticsSink([
          const FirebaseAnalyticsSink(),
          PostHogAnalytics.instance,
        ])
      : const NullAnalyticsSink();
}

abstract final class AnalyticsSession {
  /// A week, the shortest gap that counts as a quiet week.
  static const int quietDays = 7;

  /// The user properties, from what is true now. Called after the first frame
  /// and again whenever she allows statistics.
  static Future<void> describe({required String languageCode}) async {
    final analytics = AppRouter.analytics;
    if (languageCode == 'en' || languageCode == 'ar') {
      await analytics.setUserProperty(
        AnalyticsUserProperty.appLanguage,
        languageCode,
      );
    }
    await analytics.setUserProperty(
      AnalyticsUserProperty.kittenMoves,
      KittenSetting.instance.moves ? 'on' : 'off',
    );
    await analytics.setUserProperty(
      AnalyticsUserProperty.buildChannel,
      kBuildChannel,
    );
    final widget = await hasHomeWidget();
    if (widget != null) {
      await analytics.setUserProperty(
        AnalyticsUserProperty.hasHomeWidget,
        widget ? 'yes' : 'no',
      );
    }
  }

  /// Whether one of Own Hub's widgets is on her Home Screen or Lock Screen.
  /// iOS only, and only while statistics may be sent; null otherwise.
  static Future<bool?> hasHomeWidget() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return null;
    if (!FirebaseBoot.analyticsSending) return null;
    try {
      return (await HomeWidget.getInstalledWidgets()).isNotEmpty;
    } catch (_) {
      return null;
    }
  }

  /// Counts an opening after a week or more away. Only while statistics are
  /// on, and the days away leave the phone as a range.
  static Future<void> noteOpened(DateTime now) async {
    final first = await AnalyticsConsent.instance.firstOpen(now);
    final days = await AnalyticsConsent.instance.daysSinceLastOpen(now);
    // Once per calendar day: days is null on the first counted opening.
    if (first != null && (days == null || days > 0)) {
      await AppRouter.analytics.track(AnalyticsEvent.appOpened, {
        AnalyticsProp.installAge: AnalyticsValue.token(
          installAgeToken(first, now),
        ),
      });
    }
    if (days == null || days < quietDays) return;
    await AppRouter.analytics.track(AnalyticsEvent.quietWeekReturn, {
      AnalyticsProp.durationBucket: AnalyticsValue.bucket(days, [
        7,
        14,
        30,
        90,
      ]),
    });
  }

  /// The retention cohort word for an install that began at [first].
  @visibleForTesting
  static String installAgeToken(DateTime first, DateTime now) {
    final a = first.toUtc();
    final b = now.toUtc();
    final d = DateTime.utc(
      b.year,
      b.month,
      b.day,
    ).difference(DateTime.utc(a.year, a.month, a.day)).inDays;
    if (d <= 1) return d <= 0 ? 'd0' : 'd1';
    if (d < 7) return 'd2_6';
    if (d == 7) return 'd7';
    if (d < 30) return 'd8_29';
    return d == 30 ? 'd30' : 'd31p';
  }

  /// A counted workout finished. The first one ever, while statistics are
  /// on, sends the hours since her first counted opening. With no earlier
  /// counted opening (she turned statistics on after workouts) it is skipped,
  /// never sent as 0 hours.
  ///
  /// [earlierWorkout] is true when a finished workout existed before this one
  /// (an upgrade from 1.0.0, or statistics turned on later): activation is
  /// then used up without being sent.
  static Future<void> noteWorkoutFinished(
    DateTime now, {
    bool earlierWorkout = false,
  }) async {
    final first = await AnalyticsConsent.instance.firstOpen(now, create: false);
    if (first != null && earlierWorkout) {
      await AnalyticsConsent.instance.claimActivation();
      return;
    }
    if (first == null || !await AnalyticsConsent.instance.claimActivation()) {
      return;
    }
    await AppRouter.analytics.track(AnalyticsEvent.firstWorkoutDone, {
      AnalyticsProp.durationBucket: AnalyticsValue.bucket(
        now.difference(first).inHours,
        [1, 6, 24, 48],
      ),
    });
  }

  /// She chose a language.
  static void languageChanged(String languageCode) {
    if (languageCode != 'en' && languageCode != 'ar') return;
    unawaited(
      AppRouter.analytics.track(AnalyticsEvent.languageChanged, {
        AnalyticsProp.locale: AnalyticsValue.token(languageCode),
      }),
    );
    unawaited(
      AppRouter.analytics.setUserProperty(
        AnalyticsUserProperty.appLanguage,
        languageCode,
      ),
    );
  }
}
