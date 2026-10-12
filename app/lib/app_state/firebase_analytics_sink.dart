/// Where the gateway's events go: Google Analytics for Firebase, only with
/// her consent.
///
/// This and `firebase_boot.dart` are the only files that import the analytics
/// SDK (a source guard test holds it). Every event still enters through
/// `AnalyticsGateway`, so what reaches this file is already an enum name and
/// closed values; this only renames them to Firebase's names
/// ([analyticsEventWireNames], [analyticsPropWireNames]) and turns a flag into
/// `true` or `false`, because Firebase takes text and numbers only.
///
/// No user id is ever set. Firebase's uid is the key to her account, her
/// documents and her verification record, and joining it to her usage would
/// make every statistic about her personally. The app instance id the SDK
/// mints is reset when she turns statistics off.
library;

import 'package:firebase_analytics/firebase_analytics.dart';

import '../domain/analytics/analytics_gateway.dart';
import 'firebase_boot.dart';

/// Sends to Firebase Analytics. Drops everything unless [FirebaseBoot] says
/// this build may send with her current choice, which is false before
/// Firebase is up, before she allows it and in a debug build.
class FirebaseAnalyticsSink
    implements AnalyticsSink, AnalyticsUserPropertySink {
  const FirebaseAnalyticsSink({this.maySend = _firebaseMaySend});

  /// Whether anything may leave now. Injectable for tests.
  final bool Function() maySend;

  static bool _firebaseMaySend() => FirebaseBoot.analyticsSending;

  @override
  Future<void> send(String event, Map<String, Object> properties) async {
    if (!maySend()) return;
    final wire = firebaseEventFor(event, properties);
    if (wire == null) return;
    try {
      final analytics = FirebaseAnalytics.instance;
      if (wire.name == 'screen_view') {
        await analytics.logScreenView(
          screenName: wire.parameters['screen_id'] as String?,
          screenClass: wire.parameters['flow'] as String?,
        );
      } else {
        await analytics.logEvent(
          name: wire.name,
          parameters: wire.parameters.isEmpty ? null : wire.parameters,
        );
      }
    } catch (_) {
      // Statistics never cost her anything she can see.
    }
  }

  @override
  Future<void> setUserProperty(String name, String value) async {
    if (!maySend()) return;
    try {
      await FirebaseAnalytics.instance.setUserProperty(
        name: name,
        value: value,
      );
    } catch (_) {}
  }
}

/// An event as Firebase receives it.
typedef FirebaseEvent = ({String name, Map<String, Object> parameters});

/// [event] and [properties], as the gateway emits them, in Firebase's names.
/// Null for a name the gateway does not know, which is then not sent.
FirebaseEvent? firebaseEventFor(String event, Map<String, Object> properties) {
  final AnalyticsEvent known;
  try {
    known = AnalyticsEvent.values.byName(event);
  } on ArgumentError {
    return null;
  }
  final name = analyticsEventWireNames[known];
  if (name == null) return null;
  final parameters = <String, Object>{
    for (final e in properties.entries)
      if (_propByName[e.key] case final prop?)
        analyticsPropWireNames[prop]!: _wireValue(e.value),
  };
  return (name: name, parameters: parameters);
}

final Map<String, AnalyticsProp> _propByName = {
  for (final p in AnalyticsProp.values) p.name: p,
};

Object _wireValue(Object value) => value is bool ? value.toString() : value;

/// Hands each event to every sink in turn: the debug console and Firebase in
/// a debug build started for DebugView.
class TeeAnalyticsSink implements AnalyticsSink, AnalyticsUserPropertySink {
  const TeeAnalyticsSink(this.sinks);

  final List<AnalyticsSink> sinks;

  @override
  Future<void> send(String event, Map<String, Object> properties) async {
    for (final sink in sinks) {
      await sink.send(event, properties);
    }
  }

  @override
  Future<void> setUserProperty(String name, String value) async {
    for (final sink in sinks) {
      if (sink is AnalyticsUserPropertySink) {
        await (sink as AnalyticsUserPropertySink).setUserProperty(name, value);
      }
    }
  }
}
