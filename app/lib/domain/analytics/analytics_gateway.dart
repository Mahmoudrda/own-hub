/// Analytics, constrained so that a privacy leak is a compile error.
///
/// Egypt's PDPL is binding here, not advisory, and the product's own promise on
/// the privacy screen is specific about what never leaves the phone. The
/// following must **never** reach analytics, under any circumstance:
///
///   her phone number · her name · her national ID or anything read from it ·
///   why a check refused her (sex, age, a card already used) · her weight or any
///   measurement · any photo or media reference · any check-in or cycle data ·
///   her life stage, pregnancy, allergies or symptoms · whether she chose the
///   niqab path · any text she typed · any recipe or programme title
///
/// What a check came to is sent only as a step of the sign-up funnel, in one
/// coarse word (`verified`, `reviewer`, `retake`, `rejected`), never why.
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

  /// The start of the selfie challenge after the back of the card (`C10b`):
  /// `started`, `offline`, `failed`, `limit` or `other` in
  /// [AnalyticsProp.outcome]. Counts how often a dropped connection, rather
  /// than her, stops the check. Never the verification result.
  livenessStartOutcome,
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

  /// The tour before sign-up (`C04`) reached a stop: [AnalyticsProp.tourStop]
  /// is `1` to `7`, or `end` for the end card. Nothing about her.
  tourStopViewed,

  /// She tapped Join in the tour: [AnalyticsProp.source] is `bar`, `sheet` or
  /// `end`, and [AnalyticsProp.tourStop] the stop she was on.
  tourJoinTapped,

  /// The tour opened (`C04`). Firebase's recommended `tutorial_begin`.
  tourStarted,

  /// She reached the tour's end card. Firebase's recommended
  /// `tutorial_complete`.
  tourCompleted,

  /// She left the tour without joining, on [AnalyticsProp.tourStop].
  tourLeft,

  /// `C06` sent her a code. Nothing about the number.
  signUpCodeSent,

  /// Her code was accepted and the account is new to the check. Firebase's
  /// recommended `sign_up`, [AnalyticsProp.method] `phone`.
  signUpCompleted,

  /// Her code was accepted and she was already verified. Firebase's
  /// recommended `login`, [AnalyticsProp.method] `phone`.
  loggedIn,

  /// She agreed on `C09b` and the record was written.
  checkConsentGiven,

  /// A woman reviewer instead of the camera. [AnalyticsProp.outcome] is
  /// `chosen` (she asked for one, for whatever reason, which is never sent:
  /// the niqab path is a religious practice and stays hers) or `unavailable`
  /// (the automatic check could not run).
  reviewerPathChosen,

  /// The camera could not run on `C10`, `C10b` or `C11`.
  /// [AnalyticsProp.reason] is `permission_denied`, `no_camera`,
  /// `not_implemented`, `provider_unavailable` or `offline`.
  cameraUnavailable,

  /// "You're in" (`C13`). [AnalyticsProp.method] is `automatic` or
  /// `reviewer`.
  youreIn,

  /// She chose a language. [AnalyticsProp.locale] is `en` or `ar`.
  languageChanged,

  /// She opened the app after at least a week away.
  /// [AnalyticsProp.durationBucket] is the days away as a range.
  quietWeekReturn,

  /// She finished a workout early (End workout, Finish and save) with moves
  /// still left. Sent before
  /// the `workout_complete` that every finished session sends, so the two
  /// together say how many sessions ended early. Nothing about which moves.
  workoutEndedEarly,

  /// She saved her training reminders or turned them off.
  /// [AnalyticsProp.outcome] is `on`, `off`, `denied` (the phone refused
  /// notifications) or `unavailable` (scheduling failed). Never the times.
  remindersChanged,

  /// She asked `C07` to send the code again. [AnalyticsProp.outcome] is
  /// `sent`, or `limit` when too many tries were refused. Never the number.
  codeResent,

  /// She asked for a copy of her data from the privacy centre. Counts the
  /// tap that opens her mail app, never what she writes in it.
  dataCopyRequested,

  /// She opened the share sheet with her progress card (P05). Nothing about
  /// what is on the card, whether her weight was on it, or where it went.
  progressShared,

  /// She opened the app, once per calendar day. [AnalyticsProp.installAge]
  /// says how old the install is, so day 1, 7 and 30 retention and the days
  /// she is active can be counted. Nothing about her.
  appOpened,

  /// Her first finished workout, sent once. [AnalyticsProp.durationBucket]
  /// is the hours since her first counted opening: activation within 24 hours.
  firstWorkoutDone,
}

/// The name each event carries to Firebase.
///
/// Firebase's recommended names where one fits (`screen_view`, `sign_up`,
/// `login`, `tutorial_begin`, `tutorial_complete`), otherwise snake_case, at
/// most 40 characters, never a reserved name or prefix. A test holds every
/// rule, so a new event cannot ship without a name.
const Map<AnalyticsEvent, String> analyticsEventWireNames = {
  AnalyticsEvent.screenViewed: 'screen_view',
  AnalyticsEvent.signUpStarted: 'sign_up_begin',
  AnalyticsEvent.verificationSubmitted: 'id_check_submit',
  AnalyticsEvent.verificationDecided: 'id_check_result',
  AnalyticsEvent.livenessStartOutcome: 'id_check_start',
  AnalyticsEvent.intakeCompleted: 'setup_complete',
  AnalyticsEvent.sessionStarted: 'workout_start',
  AnalyticsEvent.sessionFinished: 'workout_complete',
  AnalyticsEvent.setLogged: 'set_log',
  AnalyticsEvent.mealLogged: 'meal_log',
  AnalyticsEvent.weekCounted: 'weekly_target_reached',
  AnalyticsEvent.restWeekApplied: 'rest_week_apply',
  AnalyticsEvent.tierChanged: 'tier_change',
  AnalyticsEvent.coachEnquirySent: 'coach_enquiry_send',
  AnalyticsEvent.postPublished: 'post_publish',
  AnalyticsEvent.assistantAsked: 'assistant_ask',
  AnalyticsEvent.assistantRefused: 'assistant_refuse',
  AnalyticsEvent.tourStopViewed: 'tour_stop',
  AnalyticsEvent.tourJoinTapped: 'tour_join',
  AnalyticsEvent.tourStarted: 'tutorial_begin',
  AnalyticsEvent.tourCompleted: 'tutorial_complete',
  AnalyticsEvent.tourLeft: 'tour_leave',
  AnalyticsEvent.signUpCodeSent: 'sign_up_code_sent',
  AnalyticsEvent.signUpCompleted: 'sign_up',
  AnalyticsEvent.loggedIn: 'login',
  AnalyticsEvent.checkConsentGiven: 'id_check_consent',
  AnalyticsEvent.reviewerPathChosen: 'id_check_reviewer',
  AnalyticsEvent.cameraUnavailable: 'camera_unavailable',
  AnalyticsEvent.youreIn: 'youre_in',
  AnalyticsEvent.languageChanged: 'language_change',
  AnalyticsEvent.quietWeekReturn: 'quiet_week_return',
  AnalyticsEvent.workoutEndedEarly: 'workout_end_early',
  AnalyticsEvent.remindersChanged: 'reminders_set',
  AnalyticsEvent.codeResent: 'sign_up_code_resend',
  AnalyticsEvent.dataCopyRequested: 'data_copy_request',
  AnalyticsEvent.progressShared: 'progress_share',
  AnalyticsEvent.appOpened: 'app_open',
  AnalyticsEvent.firstWorkoutDone: 'activation_first_workout',
};

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

  /// Which stop of the tour: `1` to `7`, or `end`.
  tourStop,

  /// Why something could not happen, from a closed list of technical causes.
  reason,

  /// Days since the first opening counted with her consent: `d0`, `d1`,
  /// `d2_6`, `d7`, `d8_29`, `d30` or `d31p`. Retention cohorts, no dates.
  installAge,
}

/// The name each property carries to Firebase: snake_case, at most 40
/// characters, never a reserved prefix.
const Map<AnalyticsProp, String> analyticsPropWireNames = {
  AnalyticsProp.screenId: 'screen_id',
  AnalyticsProp.flow: 'flow',
  AnalyticsProp.outcome: 'outcome',
  AnalyticsProp.method: 'method',
  AnalyticsProp.source: 'source',
  AnalyticsProp.isFirstTime: 'is_first',
  AnalyticsProp.isOffline: 'is_offline',
  AnalyticsProp.locale: 'locale',
  AnalyticsProp.platform: 'platform',
  AnalyticsProp.durationBucket: 'duration_bucket',
  AnalyticsProp.countBucket: 'count_bucket',
  AnalyticsProp.notifPermissionState: 'notif_permission',
  AnalyticsProp.tourStop: 'tour_stop',
  AnalyticsProp.reason: 'reason',
  AnalyticsProp.installAge: 'install_age',
};

/// The words each property may carry. A token outside its list is a bug: it
/// fails an assert in a debug build and a test, and is dropped before it
/// leaves the phone in a release one. Flags and buckets have their own shape.
abstract final class AnalyticsVocabulary {
  static final RegExp _screenId = RegExp(r'^[A-Z]{1,2}[0-9]{2}[a-z]?$');
  static final RegExp _bucket = RegExp(r'^(<\d+|\d+-\d+|\d+\+)$');
  static final RegExp _stop = RegExp(r'^([1-9]|end)$');

  static const Map<AnalyticsProp, Set<String>> _tokens = {
    AnalyticsProp.flow: {
      'signup',
      'onboarding',
      'today',
      'train',
      'eat',
      'progress',
      'account',
      'community',
    },
    AnalyticsProp.outcome: {
      // the liveness start
      'started', 'offline', 'failed', 'limit', 'other',
      // what a check came to
      'verified', 'reviewer', 'retake', 'rejected',
      // a reviewer instead of the camera
      'chosen', 'unavailable',
      // a switch
      'on', 'off',
      'counted',
      // reminders the phone would not allow
      'denied',
      // a code sent again
      'sent',
    },
    AnalyticsProp.method: {'phone', 'automatic', 'reviewer'},
    AnalyticsProp.source: {
      'bar', 'sheet', 'end', 'welcome', 'tour', 'live',
      // a set logged on its own (`R07`, `R08`) or a whole move at once (from the Pause sheet)
      'set', 'move',
    },
    AnalyticsProp.installAge: {
      'd0',
      'd1',
      'd2_6',
      'd7',
      'd8_29',
      'd30',
      'd31p',
    },
    AnalyticsProp.locale: {'en', 'ar'},
    AnalyticsProp.platform: {'ios', 'android'},
    AnalyticsProp.notifPermissionState: {'granted', 'denied', 'undetermined'},
    AnalyticsProp.reason: {
      'permission_denied',
      'no_camera',
      'not_implemented',
      'provider_unavailable',
      'offline',
    },
  };

  /// Whether [value] is a shape [prop] may carry.
  static bool allows(AnalyticsProp prop, AnalyticsValue value) {
    final wire = value.toWire();
    switch (prop) {
      case AnalyticsProp.isFirstTime:
      case AnalyticsProp.isOffline:
        return wire is bool;
      case AnalyticsProp.screenId:
        return wire is String && _screenId.hasMatch(wire);
      case AnalyticsProp.durationBucket:
      case AnalyticsProp.countBucket:
        return wire is String && _bucket.hasMatch(wire);
      case AnalyticsProp.tourStop:
        return wire is String && _stop.hasMatch(wire);
      default:
        return wire is String && (_tokens[prop]?.contains(wire) ?? false);
    }
  }
}

/// Facts set once and carried with every later event, each from a closed
/// vocabulary and none about her: the language the app is in, whether a Home
/// Screen widget is placed, and which build she installed. Firebase allows
/// 25; this is three.
enum AnalyticsUserProperty { appLanguage, hasHomeWidget, buildChannel }

/// The name each user property carries to Firebase: at most 24 characters.
const Map<AnalyticsUserProperty, String> analyticsUserPropertyWireNames = {
  AnalyticsUserProperty.appLanguage: 'app_language',
  AnalyticsUserProperty.hasHomeWidget: 'has_home_widget',
  AnalyticsUserProperty.buildChannel: 'build_channel',
};

/// The values each user property may take.
const Map<AnalyticsUserProperty, Set<String>> analyticsUserPropertyValues = {
  AnalyticsUserProperty.appLanguage: {'en', 'ar'},
  AnalyticsUserProperty.hasHomeWidget: {'yes', 'no'},
  AnalyticsUserProperty.buildChannel: {'store', 'direct', 'debug'},
};

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

/// A sink that can also hold user properties. Optional: a sink that is not
/// one simply never receives them.
abstract class AnalyticsUserPropertySink {
  Future<void> setUserProperty(String name, String value);
}

class AnalyticsGateway {
  const AnalyticsGateway(this._sink);

  final AnalyticsSink _sink;

  /// Emits an event. The signature is the guarantee: enum keys, closed values.
  ///
  /// A value outside its property's vocabulary ([AnalyticsVocabulary]) fails
  /// an assert, so a test catches it, and is dropped in a release build.
  Future<void> track(
    AnalyticsEvent event, [
    Map<AnalyticsProp, AnalyticsValue> properties = const {},
  ]) {
    assert(
      properties.entries.every(
        (e) => AnalyticsVocabulary.allows(e.key, e.value),
      ),
      'a value outside its vocabulary in $event: $properties',
    );
    return _sink.send(event.name, {
      for (final e in properties.entries)
        if (AnalyticsVocabulary.allows(e.key, e.value))
          e.key.name: e.value.toWire(),
    });
  }

  /// Sets one user property, from its closed list of values. Anything else
  /// fails an assert and is dropped.
  Future<void> setUserProperty(AnalyticsUserProperty property, String value) {
    final allowed = analyticsUserPropertyValues[property]!.contains(value);
    assert(allowed, '$value is not a value of $property');
    final sink = _sink;
    if (!allowed || sink is! AnalyticsUserPropertySink) return Future.value();
    return (sink as AnalyticsUserPropertySink).setUserProperty(
      analyticsUserPropertyWireNames[property]!,
      value,
    );
  }
}

/// A sink that drops everything, for tests and for a woman who has opted out.
class NullAnalyticsSink implements AnalyticsSink {
  const NullAnalyticsSink();
  @override
  Future<void> send(String event, Map<String, Object> properties) async {}
}
