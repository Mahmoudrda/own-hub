/// The funnel, printed to the debug console in a debug build.
///
/// Until an analytics service is chosen (an owner decision: it changes the
/// privacy manifest and the Play data-safety form), the events the router
/// emits go nowhere in a release build and to the console in a debug one, so
/// the order a woman moves through sign-up can be watched while testing. It
/// prints the event name and its allow-listed properties and nothing else,
/// because nothing else can reach it: see `analytics_gateway.dart`.
library;

import 'package:flutter/foundation.dart';

import '../domain/analytics/analytics_gateway.dart';

class DebugPrintAnalyticsSink implements AnalyticsSink {
  const DebugPrintAnalyticsSink();

  @override
  Future<void> send(String event, Map<String, Object> properties) async {
    if (kDebugMode) debugPrint('analytics $event $properties');
  }
}
