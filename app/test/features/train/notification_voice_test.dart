// Choosing the words of a reminder from a bank, on the phone.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/features/train/domain/notification_voice.dart';

Map<String, Object?> _line(
  String id, {
  String? en,
  String? ar,
  List<String> needs = const <String>[],
}) => {'id': id, 'en': en ?? 'en $id', 'ar': ar ?? 'ar $id', 'needs': needs};

NotificationVoice _bank(
  Map<String, Map<String, List<Map<String, Object?>>>> s,
) => NotificationVoice.parse(jsonEncode({'version': 1, 'situations': s}));

final _now = DateTime(2026, 10, 14, 12);
final _lri = String.fromCharCode(0x2066);
final _pdi = String.fromCharCode(0x2069);

void main() {
  group('the bank', () {
    test('a missing or broken bank is empty and never throws', () {
      for (final source in [null, '', 'not json', '[]', '{"situations":3}']) {
        final voice = NotificationVoice.parse(source);
        expect(voice.isEmpty, isTrue, reason: '$source');
        expect(
          voice.pick(
            'trainingDay',
            locale: 'en',
            history: VoiceHistory(),
            seed: 1,
            now: _now,
          ),
          isNull,
        );
      }
    });

    test('a broken line costs that line only', () {
      final voice = _bank({
        'trainingDay': {
          'calm': [
            _line('a'),
            {'id': 'b'},
          ],
        },
      });
      final got = voice.pick(
        'trainingDay',
        locale: 'en',
        history: VoiceHistory(),
        seed: 1,
        now: _now,
      );
      expect(got?.lineId, 'a');
    });
  });

  group('picking', () {
    final voice = _bank({
      'trainingDay': {
        'calm': [for (var i = 0; i < 4; i++) _line('c$i')],
        'playful': [for (var i = 0; i < 4; i++) _line('p$i')],
      },
    });

    ({String lineId, String tone, String text})? pick(
      VoiceHistory history, {
      int seed = 1,
      bool protectedStage = false,
      String locale = 'en',
      DateTime? now,
    }) => voice.pick(
      'trainingDay',
      locale: locale,
      history: history,
      protectedStage: protectedStage,
      seed: seed,
      now: now ?? _now,
    );

    test('the same seed gives the same line, in her language', () {
      final history = VoiceHistory();
      expect(pick(history)?.text, pick(history)?.text);
      expect(pick(history, locale: 'ar')?.text, startsWith('ar '));
      expect(pick(history)?.text, startsWith('en '));
    });

    test('a line is never repeated within 14 days of its date', () {
      final history = VoiceHistory();
      final seen = <String>{};
      // Four calm lines: the fifth pick has to be a playful one, because
      // nothing calm is left.
      for (var i = 0; i < 4; i++) {
        final got = pick(history, seed: 1 + i * 5 * 2)!;
        expect(got.tone, kToneCalm);
        expect(seen.add(got.lineId), isTrue);
        history.sent[got.lineId] = '2026-10-14';
      }
      expect(pick(history)?.tone, kTonePlayful);
      // 14 days on, the first is free again.
      expect(pick(history, now: DateTime(2026, 10, 28))?.tone, kToneCalm);
      // 13 days either side is still too close.
      expect(pick(history, now: DateTime(2026, 10, 27))?.tone, kTonePlayful);
      expect(pick(history, now: DateTime(2026, 10, 1))?.tone, kTonePlayful);
    });

    test('nothing left means null, so the plain text stays', () {
      final history = VoiceHistory();
      for (final id in ['c0', 'c1', 'c2', 'c3', 'p0', 'p1', 'p2', 'p3']) {
        history.sent[id] = '2026-10-14';
      }
      expect(pick(history), isNull);
      expect(
        voice.pick(
          'unknown',
          locale: 'en',
          history: VoiceHistory(),
          seed: 1,
          now: _now,
        ),
        isNull,
      );
    });

    test('a pregnant or postpartum stage hears calm only', () {
      final history = VoiceHistory()
        ..toneStats[kTonePlayful] = ToneStat(sent: 10, taps: 10);
      for (var seed = 0; seed < 25; seed++) {
        expect(
          pick(history, seed: seed, protectedStage: true)?.tone,
          kToneCalm,
        );
      }
      for (final id in ['c0', 'c1', 'c2', 'c3']) {
        history.sent[id] = '2026-10-14';
      }
      expect(pick(history, protectedStage: true), isNull);
    });

    test('the tone she taps wins, and every fifth pick tries the other', () {
      final history = VoiceHistory()
        ..toneStats[kTonePlayful] = ToneStat(sent: 4, taps: 4)
        ..toneStats[kToneCalm] = ToneStat(sent: 4, taps: 0);
      expect(
        history.scoreOf(kTonePlayful),
        greaterThan(history.scoreOf(kToneCalm)),
      );
      final tones = [
        for (var seed = 1; seed <= 20; seed++) pick(history, seed: seed)!.tone,
      ];
      // Seeds 5, 10, 15 and 20 explore.
      expect(tones.where((t) => t == kToneCalm).length, 4);
      expect(tones[4], kToneCalm);
      expect(tones[0], kTonePlayful);
    });

    test('with no taps at all calm leads, and a calm tap keeps it there', () {
      final history = VoiceHistory();
      expect(pick(history, seed: 1)?.tone, kToneCalm);
      history.toneStats[kToneCalm] = ToneStat(sent: 3, taps: 3);
      expect(pick(history, seed: 1)?.tone, kToneCalm);
    });
  });

  group('slots', () {
    final voice = _bank({
      'newBest': {
        'calm': [
          _line(
            'm',
            en: 'Nice {move}',
            ar: 'برافو على {move}',
            needs: ['move'],
          ),
        ],
        'playful': <Map<String, Object?>>[],
      },
      'morningMeal': {
        'calm': [
          _line('f', en: 'Try {food}', ar: 'جربي {food}', needs: ['food']),
          _line('plain'),
        ],
      },
    });

    test('a line that needs a value she has none of is skipped', () {
      expect(
        voice.pick(
          'newBest',
          locale: 'en',
          history: VoiceHistory(),
          seed: 1,
          now: _now,
        ),
        isNull,
      );
      final got = voice.pick(
        'morningMeal',
        locale: 'en',
        history: VoiceHistory(),
        seed: 1,
        now: _now,
      );
      expect(got?.lineId, 'plain');
    });

    test('a blank value counts as none', () {
      final got = voice.pick(
        'morningMeal',
        locale: 'en',
        slots: {'food': '  '},
        history: VoiceHistory(),
        seed: 1,
        now: _now,
      );
      expect(got?.lineId, 'plain');
    });

    test(
      'a value with a number, a long name or a banned word counts as none',
      () {
        for (final food in [
          'Dark chocolate 70%',
          'رجلين وأرداف ٢',
          'x' * (kVoiceSlotMaxLength + 1),
          'Half-fat milk',
          'لبن نص دسم قليل الدهون',
          'الجسم كله بهدوء',
        ]) {
          final got = voice.pick(
            'morningMeal',
            locale: 'en',
            slots: {'food': food},
            history: VoiceHistory(),
            seed: 1,
            now: _now,
          );
          expect(got?.lineId, 'plain', reason: food);
        }
      },
    );

    test('a move with a banned word leaves the best unsaid', () {
      final got = voice.pick(
        'newBest',
        locale: 'en',
        slots: {'move': 'Bodyweight calf raise'},
        history: VoiceHistory(),
        seed: 1,
        now: _now,
      );
      expect(got, isNull);
    });

    test('the value is filled in', () {
      final got = voice.pick(
        'newBest',
        locale: 'en',
        slots: {'move': 'Hip Thrust'},
        history: VoiceHistory(),
        seed: 1,
        now: _now,
      );
      expect(got?.text, 'Nice Hip Thrust');
    });

    test('in Arabic an English move is wrapped so it keeps its order', () {
      final got = voice.pick(
        'newBest',
        locale: 'ar',
        slots: {'move': 'Hip Thrust'},
        history: VoiceHistory(),
        seed: 1,
        now: _now,
      );
      expect(got?.text, 'برافو على ${_lri}Hip Thrust$_pdi');
    });

    test('an Arabic value is left as it is', () {
      final got = voice.pick(
        'morningMeal',
        locale: 'ar',
        slots: {'food': 'فول'},
        history: VoiceHistory(),
        seed: 0,
        now: _now,
      );
      expect(got?.text, isNot(contains(_lri)));
    });
  });

  group('keeping a line', () {
    test('the line chosen for this note is returned again', () {
      final voice = _bank({
        'trainingDay': {
          'calm': [_line('a'), _line('b'), _line('c')],
        },
      });
      final history = VoiceHistory();
      final first = voice.pick(
        'trainingDay',
        locale: 'en',
        history: history,
        seed: 3,
        now: _now,
      )!;
      history.sent[first.lineId] = '2026-10-14';
      final again = voice.pick(
        'trainingDay',
        locale: 'en',
        history: history,
        seed: 3,
        now: _now,
        keep: first.lineId,
      )!;
      expect(again.lineId, first.lineId);
    });
  });
}
