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

const bool _kAnalyticsDebugSend = bool.fromEnvironment(
  'OWNHUB_ANALYTICS_DEBUG',
);

/// The sink a build uses.
///
///   * release: Firebase, which itself sends nothing until she allows it;
///   * debug: the console, so the funnel can be watched, plus Firebase when
///     started with `OWNHUB_ANALYTICS_DEBUG` to check events in DebugView;
///   * profile: nothing, or Firebase with `OWNHUB_ANALYTICS_DEBUG`.
AnalyticsSink analyticsSinkFor({
  required bool release,
  required bool debug,
  bool debugSend = _kAnalyticsDebugSend,
}) {
  if (release) return const FirebaseAnalyticsSink();
  if (debug) {
    return debugSend
        ? const TeeAnalyticsSink([
            DebugPrintAnalyticsSink(),
            FirebaseAnalyticsSink(),
          ])
        : const DebugPrintAnalyticsSink();
  }
  return debugSend ? const FirebaseAnalyticsSink() : const NullAnalyticsSink();
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
    final days = await AnalyticsConsent.instance.daysSinceLastOpen(now);
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

  /// She turned the kitten's movement on or off.
  static void kittenChanged(bool moves) {
    final word = moves ? 'on' : 'off';
    unawaited(
      AppRouter.analytics.track(AnalyticsEvent.kittenToggled, {
        AnalyticsProp.outcome: AnalyticsValue.token(word),
      }),
    );
    unawaited(
      AppRouter.analytics.setUserProperty(
        AnalyticsUserProperty.kittenMoves,
        word,
      ),
    );
  }
}
