// Notification copy policy (D37, D5, P01): every sentence a notification can
// carry, in both languages. No streak, no miss, no digits, no health words,
// no em dash, and the title is always "Own Hub".

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/features/train/domain/notification_plan.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/routing/app_router.dart';

final _digits = RegExp(r'[0-9٠-٩۰-۹]');

const _healthEnglish = <String>[
  'weight',
  'kg',
  'kilo',
  'cycle',
  'period',
  'pregnan',
  'calorie',
  'diet',
  'body',
  'health',
  'fat',
  'bleed',
  'medic',
];

const _healthArabic = <String>[
  'وزن',
  'كيلو',
  'دورة',
  'حمل',
  'سعرات',
  'ريجيم',
  'جسم',
  'صحة',
  'نزيف',
];

void main() {
  for (final code in ['en', 'ar']) {
    group('notification copy in $code', () {
      final text = AppRouter.reminderText(lookupAppL10n(Locale(code)));
      final health = code == 'en' ? _healthEnglish : _healthArabic;

      test('the title is Own Hub', () {
        expect(text.title, 'Own Hub');
      });

      test('there is a text for every check-in the plan can choose', () {
        expect(text.checkInBodies, hasLength(kCheckInVariants));
        expect(text.checkInBodies.toSet(), hasLength(kCheckInVariants));
      });

      test('what the lock screen shows has no number', () {
        for (final body in text.allBodies) {
          expect(body, isNotEmpty);
          expect(body, isNot(matches(_digits)), reason: body);
        }
      });

      test('no streak, no miss, no guilt', () {
        for (final body in [text.title, ...text.allBodies]) {
          final lower = body.toLowerCase();
          expect(lower, isNot(contains('streak')), reason: body);
          expect(lower, isNot(contains('miss')), reason: body);
          expect(lower, isNot(contains('lost')), reason: body);
          expect(lower, isNot(contains('behind')), reason: body);
          expect(lower, isNot(contains('forgot')), reason: body);
        }
        for (final body in text.allBodies) {
          for (final word in [
            'سلسلة',
            'فاتك',
            'فوّتي',
            'فوتي',
            'تأخرتي',
            'نسيتي',
          ]) {
            expect(body, isNot(contains(word)), reason: body);
          }
        }
      });

      test('no health, cycle or weight words anywhere in them', () {
        for (final body in [
          ...text.allBodies,
          text.channelName,
          text.channelDescription,
          text.checkInChannelName,
          text.checkInChannelDescription,
          text.restChannelName,
          text.restChannelDescription,
        ]) {
          final lower = body.toLowerCase();
          for (final word in health) {
            expect(lower, isNot(contains(word)), reason: '"$body" has $word');
          }
        }
      });

      test('no em dash, and the Arabic is feminine', () {
        for (final body in [
          ...text.allBodies,
          text.channelName,
          text.channelDescription,
          text.checkInChannelName,
          text.checkInChannelDescription,
          text.restChannelName,
          text.restChannelDescription,
        ]) {
          expect(body, isNot(contains('—')), reason: body);
        }
      });
    });
  }

  test('Arabic is the colloquial Egyptian the rest of the app speaks', () {
    final ar = AppRouter.reminderText(lookupAppL10n(const Locale('ar')));
    expect(ar.logBody, 'اتمرنتي النهارده؟ سجّليه بضغطة.');
    expect(ar.restBody, 'الراحة خلصت. المجموعة اللي بعدها جاهزة.');
  });
}
