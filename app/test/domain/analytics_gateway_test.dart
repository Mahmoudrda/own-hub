// Implements TEST-CASES.csv: the PDPL payload guard (G7/G8's analytics
// allowlist) and the "no free-text property" assertion.
//
// These tests check a boundary rather than a behaviour. The behaviour — "we do
// not send her weight" — is not something you can test by sending her weight and
// watching; it is something you test by proving the API cannot express it.

import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/domain/analytics/analytics_gateway.dart';

class _RecordingSink implements AnalyticsSink {
  final List<(String, Map<String, Object>)> sent = [];
  @override
  Future<void> send(String event, Map<String, Object> properties) async {
    sent.add((event, properties));
  }
}

void main() {
  group('the property allowlist contains nothing PDPL forbids', () {
    test('no property key names a person, a body, or a medium', () {
      // If one of these ever appears in AnalyticsProp, this fails — and it should,
      // because adding it is how the guarantee on the privacy screen stops being
      // true.
      // Whole words, compared against the camelCase name split into words —
      // deliberately NOT substring matching. Two earlier versions of this guard
      // matched substrings and produced false positives that say something about
      // the technique rather than the code: a bare 'id' fired on `screenId`, and
      // then 'nid' fired on it too, because "scree(nid)" contains those letters.
      // Splitting first means `phoneNumber` is still caught while `screenId`,
      // which records only which screen was viewed, is not.
      const banned = {
        'phone',
        'msisdn',
        'number',
        'name',
        'email',
        'dob',
        'birthdate',
        'weight',
        'kg',
        'measurement',
        'measurements',
        'waist',
        'hip',
        'bmi',
        'photo',
        'image',
        'media',
        'url',
        'uri',
        'blob',
        'file',
        'cycle',
        'period',
        'symptom',
        'symptoms',
        'cramps',
        'bleeding',
        'checkin',
        'mood',
        'energy',
        'verification',
        'nid',
        'nationalid',
        'passport',
        'selfie',
        'face',
        'text',
        'query',
        'transcript',
        'note',
        'caption',
        'message',
        'body',
        'pregnant',
        'pregnancy',
        'postpartum',
        'stage',
        'lifestage',
        'allergy',
        'allergies',
        'niqab',
        'national',
        'title',
        'uid',
      };

      // `notifPermissionState` -> [notif, permission, state]
      List<String> words(String camel) => camel
          .replaceAllMapped(RegExp(r'([A-Z])'), (m) => ' ${m.group(1)}')
          .toLowerCase()
          .split(RegExp(r'[\s_]+'))
          .where((w) => w.isNotEmpty)
          .toList();

      for (final prop in AnalyticsProp.values) {
        for (final word in words(prop.name)) {
          expect(
            banned.contains(word),
            isFalse,
            reason:
                'AnalyticsProp.${prop.name} contains the word "$word", '
                'which PDPL and the privacy screen both forbid from analytics',
          );
        }
      }

      // The guard must actually bite: these would all be rejected.
      for (final bad in [
        'phoneNumber',
        'weightKg',
        'selfieUrl',
        'cycleDay',
        'firstName',
        'mediaUri',
        'checkinMood',
      ]) {
        expect(
          words(bad).any(banned.contains),
          isTrue,
          reason: '$bad must be caught by this guard',
        );
      }
    });

    test('no event or user property name carries a banned word either', () {
      const banned = {
        'phone',
        'name',
        'weight',
        'cycle',
        'period',
        'symptom',
        'pregnan',
        'postpartum',
        'allerg',
        'measure',
        'selfie',
        'national',
        'niqab',
        'face',
        'body',
        'mood',
        'health',
        'stage',
        'uid',
        'email',
      };
      final names = [
        ...analyticsEventWireNames.values,
        ...AnalyticsEvent.values.map((e) => e.name.toLowerCase()),
        ...analyticsUserPropertyWireNames.values,
        ...analyticsPropWireNames.values,
      ];
      for (final name in names) {
        for (final word in banned) {
          expect(name.contains(word), isFalse, reason: '$name has "$word"');
        }
      }
    });

    test('the vocabulary is small enough to audit by eye', () {
      // A long list is an unaudited list. If this needs raising, the new property
      // should be justified in the diff.
      expect(AnalyticsProp.values.length, lessThanOrEqualTo(16));
    });
  });

  group('numbers leave the device as ranges, never as values', () {
    test('a bucket reports the range, not the number', () {
      expect(AnalyticsValue.bucket(42, [20, 40, 60]).toWire(), '40-60');
      expect(AnalyticsValue.bucket(5, [20, 40, 60]).toWire(), '<20');
      expect(AnalyticsValue.bucket(95, [20, 40, 60]).toWire(), '60+');
    });

    test('a value on an edge falls in the upper range, consistently', () {
      expect(AnalyticsValue.bucket(40, [20, 40, 60]).toWire(), '40-60');
    });

    test('the raw number is never recoverable from what was sent', () {
      final sink = _RecordingSink();
      const gateway = AnalyticsGateway.new;
      final g = gateway(sink);
      g.track(AnalyticsEvent.sessionFinished, {
        AnalyticsProp.durationBucket: AnalyticsValue.bucket(37, [
          15,
          30,
          45,
          60,
        ]),
      });
      final props = sink.sent.single.$2;
      expect(props['durationBucket'], '30-45');
      expect(props.values.any((v) => v == 37 || v == '37'), isFalse);
    });
  });

  group('what actually goes on the wire', () {
    test('event and property names are the enum names, nothing more', () {
      final sink = _RecordingSink();
      AnalyticsGateway(sink).track(AnalyticsEvent.setLogged, {
        AnalyticsProp.source: const AnalyticsValue.token('live'),
        AnalyticsProp.isOffline: const AnalyticsValue.flag(true),
      });

      final (event, props) = sink.sent.single;
      expect(event, 'setLogged');
      expect(props, {'source': 'live', 'isOffline': true});
    });

    test('an event with no properties sends none', () {
      final sink = _RecordingSink();
      AnalyticsGateway(sink).track(AnalyticsEvent.screenViewed);
      expect(sink.sent.single.$2, isEmpty);
    });

    test('every wire value is a flag or a token — never an arbitrary object', () {
      final sink = _RecordingSink();
      AnalyticsGateway(sink).track(AnalyticsEvent.weekCounted, {
        AnalyticsProp.outcome: const AnalyticsValue.token('counted'),
        AnalyticsProp.isFirstTime: const AnalyticsValue.flag(false),
        AnalyticsProp.countBucket: AnalyticsValue.bucket(3, [1, 3, 5]),
      });
      for (final v in sink.sent.single.$2.values) {
        expect(
          v is bool || v is String,
          isTrue,
          reason:
              'only flags and tokens may reach the wire, got ${v.runtimeType}',
        );
      }
    });

    test('opting out drops everything without changing call sites', () {
      // A woman who turns analytics off must not require different code paths,
      // or the "off" path is the one that gets tested least.
      const gateway = AnalyticsGateway(NullAnalyticsSink());
      expect(
        () => gateway.track(AnalyticsEvent.postPublished, {
          AnalyticsProp.flow: const AnalyticsValue.token('community'),
        }),
        returnsNormally,
      );
    });
  });

  group('Firebase names follow the documented rules', () {
    // https://firebase.google.com/docs/reference/android/com/google/firebase/analytics/FirebaseAnalytics.Event
    const reserved = {
      'ad_activeview',
      'ad_click',
      'ad_exposure',
      'ad_query',
      'ad_reward',
      'adunit_exposure',
      'app_background',
      'app_clear_data',
      'app_exception',
      'app_remove',
      'app_store_refund',
      'app_store_subscription_cancel',
      'app_store_subscription_convert',
      'app_store_subscription_renew',
      'app_update',
      'app_upgrade',
      'dynamic_link_app_open',
      'dynamic_link_app_update',
      'dynamic_link_first_open',
      'error',
      'first_open',
      'first_visit',
      'notification_dismiss',
      'notification_foreground',
      'notification_open',
      'notification_receive',
      'os_update',
      'session_start',
      'session_start_with_rollout',
      'user_engagement',
    };
    final shape = RegExp(r'^[a-z][a-z0-9_]*$');
    bool reservedPrefix(String n) =>
        n.startsWith('firebase_') ||
        n.startsWith('google_') ||
        n.startsWith('ga_');

    test('every event has a name: snake_case, at most 40, not reserved', () {
      expect(
        analyticsEventWireNames.keys.toSet(),
        AnalyticsEvent.values.toSet(),
      );
      final names = analyticsEventWireNames.values.toList();
      expect(names.toSet(), hasLength(names.length), reason: 'no two share');
      for (final name in names) {
        expect(shape.hasMatch(name), isTrue, reason: name);
        expect(name.length, lessThanOrEqualTo(40), reason: name);
        expect(reserved.contains(name), isFalse, reason: name);
        expect(reservedPrefix(name), isFalse, reason: name);
      }
    });

    test('recommended names where they fit', () {
      expect(
        analyticsEventWireNames[AnalyticsEvent.screenViewed],
        'screen_view',
      );
      expect(
        analyticsEventWireNames[AnalyticsEvent.signUpCompleted],
        'sign_up',
      );
      expect(analyticsEventWireNames[AnalyticsEvent.loggedIn], 'login');
      expect(
        analyticsEventWireNames[AnalyticsEvent.tourStarted],
        'tutorial_begin',
      );
      expect(
        analyticsEventWireNames[AnalyticsEvent.tourCompleted],
        'tutorial_complete',
      );
    });

    test(
      'every parameter has a name: snake_case, at most 40, not reserved',
      () {
        expect(
          analyticsPropWireNames.keys.toSet(),
          AnalyticsProp.values.toSet(),
        );
        for (final name in analyticsPropWireNames.values) {
          expect(shape.hasMatch(name), isTrue, reason: name);
          expect(name.length, lessThanOrEqualTo(40), reason: name);
          expect(reservedPrefix(name), isFalse, reason: name);
        }
        // Far under the 25 parameters an event may carry.
        expect(AnalyticsProp.values.length, lessThan(25));
      },
    );

    test(
      'user properties: at most 25, names at most 24, values at most 36',
      () {
        expect(AnalyticsUserProperty.values.length, lessThanOrEqualTo(25));
        expect(
          analyticsUserPropertyWireNames.keys.toSet(),
          AnalyticsUserProperty.values.toSet(),
        );
        for (final name in analyticsUserPropertyWireNames.values) {
          expect(shape.hasMatch(name), isTrue, reason: name);
          expect(name.length, lessThanOrEqualTo(24), reason: name);
          expect(reservedPrefix(name), isFalse, reason: name);
          // Google reserves these for its own demographics.
          expect(['age', 'gender', 'interest'], isNot(contains(name)));
        }
        for (final values in analyticsUserPropertyValues.values) {
          for (final v in values) {
            expect(v.length, lessThanOrEqualTo(36));
          }
        }
      },
    );
  });

  group('a value outside its vocabulary does not leave the phone', () {
    test('an unknown token fails the assert a test runs with', () {
      final sink = _RecordingSink();
      expect(
        () => AnalyticsGateway(sink).track(AnalyticsEvent.signUpStarted, {
          AnalyticsProp.source: const AnalyticsValue.token('+201001234567'),
        }),
        throwsA(isA<AssertionError>()),
      );
      expect(sink.sent, isEmpty);
    });

    test('a screen id must look like one, a stop like a stop', () {
      expect(
        AnalyticsVocabulary.allows(
          AnalyticsProp.screenId,
          const AnalyticsValue.token('C09b'),
        ),
        isTrue,
      );
      expect(
        AnalyticsVocabulary.allows(
          AnalyticsProp.screenId,
          const AnalyticsValue.token('Mona'),
        ),
        isFalse,
      );
      expect(
        AnalyticsVocabulary.allows(
          AnalyticsProp.tourStop,
          const AnalyticsValue.token('end'),
        ),
        isTrue,
      );
      expect(
        AnalyticsVocabulary.allows(
          AnalyticsProp.isFirstTime,
          const AnalyticsValue.token('true'),
        ),
        isFalse,
        reason: 'a flag is a flag',
      );
      expect(
        AnalyticsVocabulary.allows(
          AnalyticsProp.durationBucket,
          AnalyticsValue.bucket(9, [7, 14, 30]),
        ),
        isTrue,
      );
    });

    test('an unknown user property value fails the assert', () {
      expect(
        () =>
            const AnalyticsGateway(NullAnalyticsSink())
                .setUserProperty(AnalyticsUserProperty.appLanguage, 'fr'),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
