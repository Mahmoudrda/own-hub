// Owner decision, 14 October 2026: Arabic is Egyptian everywhere, including
// legal and consent wording. This fails when a value in app_ar.arb contains a
// formal-Arabic (MSA) marker word, so the rule holds after the week it was
// written.
//
// It matches whole words only, after dropping vowel marks, so a colloquial
// word that merely contains a marker as a substring is not caught.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/features/train/presentation/mid_set_view.dart';
import 'package:own_hub/features/train/presentation/workout_day_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';

/// Formal-Arabic words that have an Egyptian replacement in this app's voice.
/// Written without vowel marks; the scan drops them from the text too.
const List<String> _markers = [
  'ماذا',
  'لماذا',
  'سوف',
  'ليس',
  'تريدين',
  'يمكنك',
  'يرجى',
  'الآن',
  'هل',
  'لن',
  'هذا',
  'هذه',
  'الذي',
  'التي',
  'لقد',
];

/// Keys whose value may keep a marker word, each with the reason. Empty today:
/// the only formal-Arabic text left in the dictionary would be a quotation from
/// Rahma's book or a dish name, and none of those contain a marker. Add an
/// entry here only with that kind of reason.
const Map<String, String> _allowed = {};

final RegExp _marks = RegExp('[ً-ٰٟـ]');
final RegExp _word = RegExp('[ء-ي]+');

/// The marker words found in [text], whole words only.
Set<String> markersIn(String text) {
  final words = _word
      .allMatches(text.replaceAll(_marks, ''))
      .map((m) => m.group(0)!)
      .toSet();
  return words.intersection(_markers.toSet());
}

void main() {
  group('Egyptian Arabic only', () {
    test('no value in app_ar.arb uses a formal-Arabic marker word', () {
      final arb = jsonDecode(
        File('lib/l10n/app_ar.arb').readAsStringSync(),
      ) as Map<String, dynamic>;
      final offenders = <String>[];
      for (final entry in arb.entries) {
        if (entry.key.startsWith('@')) continue;
        final value = entry.value;
        if (value is! String) continue;
        if (_allowed.containsKey(entry.key)) continue;
        final hits = markersIn(value);
        if (hits.isNotEmpty) {
          offenders.add('${entry.key}: ${hits.join(' ')} | $value');
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'Write these in Egyptian Arabic (owner decision 14 Oct 2026), '
            'through tool/add_strings.py:\n${offenders.join('\n')}',
      );
    });

    test(
      'every allow-list entry names a key that exists and still needs it',
      () {
        final arb = jsonDecode(
          File('lib/l10n/app_ar.arb').readAsStringSync(),
        ) as Map<String, dynamic>;
        for (final key in _allowed.keys) {
          expect(
            arb.containsKey(key),
            isTrue,
            reason: '$key is not in the file',
          );
          expect(
            markersIn(arb[key] as String),
            isNotEmpty,
            reason: '$key no longer needs its allow-list entry',
          );
        }
      },
    );

    test('positive control: the scan does catch formal Arabic', () {
      expect(markersIn('ماذا تريدين أن تفعلي الآن؟'), {
        'ماذا',
        'تريدين',
        'الآن',
      });
      expect(markersIn('يُرجى قراءة ما تغيّر. يمكنكِ الإلغاء.'), {
        'يرجى',
        'يمكنك',
      });
      expect(markersIn('لقد طلبتِ مراجِعة هذه المرة'), {'لقد', 'هذه'});
    });

    test('positive control: Egyptian wording and substrings pass', () {
      expect(markersIn('عايزة تعملي إيه دلوقتي؟ تقدري تقفلي'), isEmpty);
      // "هل" and "لن" appear inside longer words; only whole words count.
      expect(markersIn('الأهل بيحبوا اللبن'), isEmpty);
    });
  });

  group('exercise names follow the language', () {
    testWidgets('in Arabic the title, the cues and buttons are all Arabic', (
      tester,
    ) async {
      final en = lookupAppL10n(const Locale('en'));
      final ar = lookupAppL10n(const Locale('ar'));
      final move = sampleWorkoutDay(ar).moves.first;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ar'),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          theme: buildTheme(const Locale('ar')),
          home: MidSetView(move: move),
        ),
      );
      await tester.pumpAndSettle();

      expect(move.name, ar.donkeyKick);
      expect(find.text(ar.donkeyKick), findsWidgets);
      expect(find.text(en.donkeyKick), findsNothing);
      expect(find.byTooltip(ar.pause), findsWidgets);
    });
  });
}
