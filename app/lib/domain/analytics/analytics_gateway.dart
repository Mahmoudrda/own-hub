/// Analytics, constrained so that a privacy leak is a compile error.
///
/// Egypt's PDPL is binding here, not advisory, and the product's own promise on
/// the privacy screen is specific about what never leaves the phone. The
/// following must **never** reach analytics, under any circumstance:
///
///   her phone number · her name · the verification result · her weight or any
///   measurement · any photo or media reference · any check-in or cycle data
///
/// A denylist cannot enforce that, because the next property someone adds is not
/// on it. So there is no free-text property in this API at all: keys are an enum
/// ([AnalyticsProp]) and values are a closed set of types ([AnalyticsValue]).
/// There is deliberately **no `Map<String, dynamic>` overload**. Sending a phone
/// number is not something a reviewer has to notice — it does not compile.
///
/// The second reason free text is banned: free text is exactly what leaks a
/// phone number or a transcript by accident, inside a field that looks innocent.
library;

import 'package:meta/meta.dart';

/// Events the product emits. Adding one is a deliberate, reviewable act.
enum AnalyticsEvent {
  screenViewed,
  signUpStarted,
  verificationSubmitted,
  verificationDecided,
  intakeCompleted,
  sessionStarted,
  sessionFinished,
  setLogged,
  mealLogged,
  weekCounted,
  restWeekApplied,
  tierChanged,
  coachEnquirySent,
  postPublished,
  assistantAsked,
  assistantRefused,
}

/// The only property keys that exist.
///
/// Every one is a coarse fact about *what happened*, never about *who she is* or
/// what her body is doing. If a property you want is not here, that is the design
/// working: add it only after checking it against the banned list above.
enum AnalyticsProp {
  screenId,
  flow,
  outcome,
  method,
  source,
  isFirstTime,
  isOffline,
  locale,
  platform,
  durationBucket,
  countBucket,
  notifPermissionState,
}

/// The only value shapes that exist: a flag, a bucketed number, or a value from a
/// closed vocabulary. Never a free string.
@immutable
sealed class AnalyticsValue {
  const AnalyticsValue();

  const factory AnalyticsValue.flag(bool value) = _Flag;

  /// A value from a fixed vocabulary — an outcome, a screen id, a locale code.
  /// The vocabulary is asserted by test, so a stray identifier cannot slip in.
  const factory AnalyticsValue.token(String value) = _Token;

  /// A number, reduced to a range before it leaves the device.
  ///
  /// Raw numbers are how a measurement escapes: "42" is a weight, "40–44" is a
  /// cohort. Buckets are the only numeric form this API can send.
  factory AnalyticsValue.bucket(num value, List<num> edges) {
    assert(edges.isNotEmpty, 'a bucket needs edges');
    for (var i = 0; i < edges.length; i++) {
      if (value < edges[i]) {
        return _Token(i == 0 ? '<${edges[0]}' : '${edges[i - 1]}-${edges[i]}');
      }
    }
    return _Token('${edges.last}+');
  }

  Object toWire();
}

@immutable
class _Flag extends AnalyticsValue {
  const _Flag(this.value);
  final bool value;
  @override
  Object toWire() => value;
}

@immutable
class _Token extends AnalyticsValue {
  const _Token(this.value);
  final String value;
  @override
  Object toWire() => value;
}

/// The one place an analytics event may be emitted.
///
/// Nothing else in the application talks to the analytics SDK. That single choke
/// point is what makes the PDPL guarantee checkable: there is one function to
/// audit, and a source-level test asserts nothing else imports the SDK.
abstract class AnalyticsSink {
  Future<void> send(String event, Map<String, Object> properties);
}

class AnalyticsGateway {
  const AnalyticsGateway(this._sink);

  final AnalyticsSink _sink;

  /// Emits an event. The signature is the guarantee: enum keys, closed values.
  Future<void> track(
    AnalyticsEvent event, [
    Map<AnalyticsProp, AnalyticsValue> properties = const {},
  ]) {
    return _sink.send(event.name, {
      for (final e in properties.entries) e.key.name: e.value.toWire(),
    });
  }
}

/// A sink that drops everything, for tests and for a woman who has opted out.
class NullAnalyticsSink implements AnalyticsSink {
  const NullAnalyticsSink();
  @override
  Future<void> send(String event, Map<String, Object> properties) async {}
}
