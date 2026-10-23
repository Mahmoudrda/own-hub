// What the phone remembers of the words it used: counted once, learned from
// taps, kept across a restart and wiped with the rest.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/account_data.dart';
import 'package:own_hub/app_state/app_snapshot.dart';
import 'package:own_hub/app_state/cloud_documents.dart';
import 'package:own_hub/app_state/notification_sync.dart';
import 'package:own_hub/app_state/notification_taps.dart';
import 'package:own_hub/features/train/domain/notification_plan.dart';
import 'package:own_hub/features/train/domain/notification_voice.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _now = DateTime(2026, 10, 14, 10);

int _sent(VoiceHistory h) =>
    h.toneStats.values.fold(0, (total, stat) => total + stat.sent);

NotificationVoice _bank() => NotificationVoice.parse(
  jsonEncode({
    'version': 1,
    'situations': {
      for (final s in ['trainingDay', 'didYouTrain', 'comeBack', 'weekEnd'])
        s: {
          'calm': [
            for (var i = 0; i < 6; i++)
              {
                'id': '$s-c$i',
                'en': 'calm $s $i',
                'ar': 'هادي $s $i',
                'needs': [],
              },
          ],
          'playful': [
            for (var i = 0; i < 6; i++)
              {
                'id': '$s-p$i',
                'en': 'fun $s $i',
                'ar': 'لعب $s $i',
                'needs': [],
              },
          ],
        },
      'freshStart': {
        'calm': [
          {'id': 'fresh-c0', 'en': 'Fresh start', 'ar': 'بداية', 'needs': []},
        ],
      },
    },
  }),
);

PlannedNotification _training(DateTime at) => PlannedNotification(
  id: reminderNotificationId(at.weekday),
  kind: PlanKind.training,
  at: at,
  weekly: true,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final history = VoiceHistory.instance;

  setUp(() async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    await const ThisPhoneWipe().clearPersistence();
  });
  tearDown(() async {
    await const ThisPhoneWipe().clearPersistence();
  });

  group('history', () {
    test(
      'a shown note keeps its line after a replan, so a later tap counts',
      () {
        final h = VoiceHistory();
        h.schedule(
          id: 7101,
          lineId: 'a',
          tone: kTonePlayful,
          at: DateTime(2026, 10, 14, 9),
          now: DateTime(2026, 10, 14, 8),
        );
        h.cancel(7101, _now);
        expect(h.tap(7101), isTrue);
        expect(h.toneStats[kTonePlayful]!.taps, 1);
      },
    );

    test('a note not shown yet is dropped on cancel', () {
      final h = VoiceHistory();
      h.schedule(
        id: 7101,
        lineId: 'a',
        tone: kToneCalm,
        at: DateTime(2026, 10, 14, 18),
        now: _now,
      );
      h.cancel(7101, _now);
      expect(h.tap(7101), isFalse);
      expect(h.toneStats[kToneCalm]!.sent, 0);
    });

    test('a line is counted once per notification and date', () {
      final h = VoiceHistory();
      final at = DateTime(2026, 10, 15, 18);
      for (var i = 0; i < 3; i++) {
        h.schedule(id: 7101, lineId: 'a', tone: kToneCalm, at: at, now: _now);
      }
      expect(h.toneStats[kToneCalm]!.sent, 1);
      expect(h.sent, {'a': '2026-10-15'});
    });

    test('a note not shown yet that gets other words is not counted twice', () {
      final h = VoiceHistory();
      h.schedule(
        id: 7131,
        lineId: 'a',
        tone: kToneCalm,
        at: DateTime(2026, 10, 18, 18),
        now: _now,
      );
      h.schedule(
        id: 7131,
        lineId: 'b',
        tone: kTonePlayful,
        at: DateTime(2026, 10, 19, 18),
        now: _now,
      );
      expect(h.toneStats[kToneCalm]!.sent, 0);
      expect(h.toneStats[kTonePlayful]!.sent, 1);
      expect(h.sent.keys, ['b']);
    });

    test('a note that already showed stays counted', () {
      final h = VoiceHistory();
      h.schedule(
        id: 7131,
        lineId: 'a',
        tone: kToneCalm,
        at: DateTime(2026, 10, 12, 18),
        now: _now,
      );
      h.schedule(
        id: 7131,
        lineId: 'b',
        tone: kToneCalm,
        at: DateTime(2026, 10, 19, 18),
        now: _now,
      );
      expect(h.toneStats[kToneCalm]!.sent, 2);
      expect(h.sent.keys.toSet(), {'a', 'b'});
    });

    test('it is capped', () {
      final h = VoiceHistory();
      for (var i = 0; i < 200; i++) {
        h.schedule(
          id: 7000 + i,
          lineId: 'l$i',
          tone: kToneCalm,
          at: DateTime(2026, 10, 15).add(Duration(days: i)),
          now: _now,
        );
      }
      expect(h.sent.length, kVoiceSentKept);
      expect(h.scheduled.length, kVoiceScheduledKept);
      expect(h.sent.containsKey('l199'), isTrue);
      expect(h.sent.containsKey('l0'), isFalse);
    });
  });

  group('voicing a plan', () {
    final facts = const NotificationFacts();

    test('the casual kinds take a line and it is remembered', () {
      final h = VoiceHistory();
      final plan = [
        _training(DateTime(2026, 10, 15, 18)),
        PlannedNotification(
          id: kDidYouTrainId,
          kind: PlanKind.didYouTrain,
          at: DateTime(2026, 10, 15, 21),
        ),
      ];
      final out = NotificationSync.voiced(
        plan,
        voice: _bank(),
        facts: facts,
        history: h,
        now: _now,
      );
      expect(out[0].body, matches(RegExp(r'^(calm|fun) trainingDay')));
      expect(out[1].body, matches(RegExp(r'^(calm|fun) didYouTrain')));
      expect(h.scheduled.keys.toSet(), {
        reminderNotificationId(DateTime.thursday),
        kDidYouTrainId,
      });
    });

    test('a replan for the same day keeps the words', () {
      final h = VoiceHistory();
      final plan = [_training(DateTime(2026, 10, 15, 18))];
      String? body() => NotificationSync.voiced(
        plan,
        voice: _bank(),
        facts: facts,
        history: h,
        now: _now,
      ).single.body;
      final first = body();
      expect(body(), first);
      expect(body(), first);
      expect(_sent(h), 1);
    });

    test('with no bank every note keeps its fixed text', () {
      final plan = [_training(DateTime(2026, 10, 15, 18))];
      final out = NotificationSync.voiced(
        plan,
        voice: NotificationVoice.empty,
        facts: facts,
        history: VoiceHistory(),
        now: _now,
      );
      expect(out, plan);
      expect(out.single.body, isNull);
    });

    test('a fresh start without a line is left out; with one it is sent', () {
      final note = PlannedNotification(
        id: nudgeNotificationId(DateTime.thursday),
        kind: PlanKind.nudge,
        at: DateTime(2026, 10, 15, 14),
        variant: nudgeVariantCode(NudgeContext.freshStart, 0),
      );
      expect(
        NotificationSync.voiced(
          [note],
          voice: NotificationVoice.empty,
          facts: facts,
          history: VoiceHistory(),
          now: _now,
        ),
        isEmpty,
      );
      final out = NotificationSync.voiced(
        [note],
        voice: _bank(),
        facts: facts,
        history: VoiceHistory(),
        now: _now,
      );
      expect(out.single.body, 'Fresh start');
    });

    test('tips, event notes and the rest alert keep their texts', () {
      final h = VoiceHistory();
      final plan = [
        PlannedNotification(
          id: tipNotificationId(0),
          kind: PlanKind.tip,
          at: DateTime(2026, 10, 15, 12),
        ),
        PlannedNotification(
          id: kEventFirstId,
          kind: PlanKind.eventReminder,
          at: DateTime(2026, 10, 15, 12),
        ),
      ];
      final out = NotificationSync.voiced(
        plan,
        voice: _bank(),
        facts: facts,
        history: h,
        now: _now,
      );
      expect(out, plan);
      expect(h.touched, isFalse);
    });

    test('a note that is no longer planned is given back', () {
      final h = VoiceHistory();
      NotificationSync.voiced(
        [_training(DateTime(2026, 10, 15, 18))],
        voice: _bank(),
        facts: facts,
        history: h,
        now: _now,
      );
      expect(_sent(h), 1);
      NotificationSync.voiced(
        const [],
        voice: _bank(),
        facts: facts,
        history: h,
        now: _now,
      );
      expect(_sent(h), 0);
      expect(h.scheduled, isEmpty);
    });
  });

  group('a tap', () {
    test('adds to the tone of the words it carried', () {
      history.schedule(
        id: reminderNotificationId(DateTime.thursday),
        lineId: 'a',
        tone: kTonePlayful,
        at: DateTime(2026, 10, 15, 18),
        now: _now,
      );
      NotificationTaps.received(
        'T01',
        id: reminderNotificationId(DateTime.thursday),
      );
      expect(history.toneStats[kTonePlayful]!.taps, 1);
      expect(
        history.scoreOf(kTonePlayful),
        greaterThan(history.scoreOf(kToneCalm)),
      );
    });

    test('one that carried none of ours, or opens nothing, counts nowhere', () {
      history.schedule(
        id: reminderNotificationId(DateTime.thursday),
        lineId: 'a',
        tone: kToneCalm,
        at: DateTime(2026, 10, 15, 18),
        now: _now,
      );
      NotificationTaps.received('T01', id: 9999);
      NotificationTaps.received(
        'X99',
        id: reminderNotificationId(DateTime.thursday),
      );
      NotificationTaps.received('T01');
      expect(history.toneStats[kToneCalm]!.taps, 0);
    });
  });

  group('snapshot and wipe', () {
    test('it round-trips and is in no cloud document', () async {
      history.schedule(
        id: reminderNotificationId(DateTime.thursday),
        lineId: 'a',
        tone: kToneCalm,
        at: DateTime(2026, 10, 15, 18),
        now: _now,
      );
      history.schedule(
        id: 7165,
        lineId: 'b',
        tone: kTonePlayful,
        at: DateTime(2026, 10, 16, 10),
        now: _now,
      );
      history.tap(7165);
      expect(nothingOfHersRemains, isFalse);
      final document = jsonEncode(AppSnapshot.capture());
      expect(AppSnapshot.capture().containsKey('notificationVoice'), isTrue);

      history.reset();
      expect(history.touched, isFalse);
      AppSnapshot.restore(document);
      expect(history.sent, {'a': '2026-10-15', 'b': '2026-10-16'});
      expect(history.toneStats[kTonePlayful]!.taps, 1);
      expect(history.toneStats[kToneCalm]!.sent, 1);
      expect(history.scheduled[7165]!.lineId, 'b');
      expect(history.scheduled[7165]!.at, DateTime(2026, 10, 16, 10));

      for (final doc in CloudDocuments.capture()) {
        final text = jsonEncode(doc.data, toEncodable: (o) => '$o');
        expect(text, isNot(contains('notificationVoice')));
        expect(text, isNot(contains('toneStats')));
      }
    });

    test('a damaged section costs its bad parts, not the document', () {
      final document = jsonEncode(<String, Object?>{
        ...AppSnapshot.capture(),
        'notificationVoice': <String, Object?>{
          'sent': {'a': '2026-10-15', 'b': 7},
          'toneStats': {
            'calm': {'sent': 'x', 'taps': -1},
            'playful': {'sent': 2, 'taps': 1},
            'loud': {'sent': 9, 'taps': 9},
          },
          'scheduled': {
            '7105': {'lineId': 'a', 'tone': 'calm', 'at': 'not a date'},
            'x': {'lineId': 'a', 'tone': 'calm', 'at': '2026-10-15T18:00:00'},
            '7106': {
              'lineId': 'a',
              'tone': 'shouty',
              'at': '2026-10-15T18:00:00',
            },
            '7107': {
              'lineId': 'a',
              'tone': 'calm',
              'at': '2026-10-15T18:00:00',
            },
          },
        },
      });
      AppSnapshot.restore(document);
      expect(history.sent, {'a': '2026-10-15'});
      expect(history.toneStats.keys, [kTonePlayful]);
      expect(history.scheduled.keys, [7107]);
    });

    test('the wipe empties it', () async {
      history.schedule(
        id: reminderNotificationId(DateTime.thursday),
        lineId: 'a',
        tone: kToneCalm,
        at: DateTime(2026, 10, 15, 18),
        now: _now,
      );
      expect(nothingOfHersRemains, isFalse);
      await const ThisPhoneWipe().clearPersistence();
      expect(history.touched, isFalse);
      expect(nothingOfHersRemains, isTrue);
    });
  });
}
