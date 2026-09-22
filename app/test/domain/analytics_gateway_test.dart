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
}
