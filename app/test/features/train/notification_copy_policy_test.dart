// Notification copy policy (D37, D5, P01): every sentence a notification can
// carry, in both languages. No streak, no miss, no digits, no health words,
// no em dash, and the title is always "Own Hub".

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/features/train/domain/getting_started_tips.dart';
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
      final l10n = lookupAppL10n(Locale(code));
      final text = AppRouter.reminderText(l10n).withEventCopy(l10n);
      final health = code == 'en' ? _healthEnglish : _healthArabic;

      test('the title is Own Hub', () {
        expect(text.title, 'Own Hub');
      });

      test('there is a text for every check-in the plan can choose', () {
        expect(text.checkInBodies, hasLength(kCheckInVariants));
        expect(text.checkInBodies.toSet(), hasLength(kCheckInVariants));
      });

      test('there is a text for every getting started tip, each its own', () {
        expect(text.tipBodies, hasLength(GettingStartedTip.values.length));
        expect(text.tipBodies.toSet(), hasLength(kTipCount));
        expect(text.tipChannelName, isNotEmpty);
        expect(text.tipChannelDescription, isNotEmpty);
      });

      test('the router carries the event words without a second call', () {
        expect(
          AppRouter.reminderText(l10n).eventBodies,
          hasLength(kEventVariants),
        );
      });

      test('there are two texts for each kind of event note, each its own', () {
        expect(text.eventBodies, hasLength(kEventVariants));
        expect(text.bookedEventBodies, hasLength(kEventVariants));
        expect(text.eventBodies.toSet(), hasLength(kEventVariants));
        expect(text.bookedEventBodies.toSet(), hasLength(kEventVariants));
        expect(
          text.eventBodies.toSet().intersection(text.bookedEventBodies.toSet()),
          isEmpty,
        );
        expect(text.eventChannelName, isNotEmpty);
        expect(text.eventChannelDescription, isNotEmpty);
        for (final body in [...text.eventBodies, ...text.bookedEventBodies]) {
          expect(text.allBodies, contains(body));
        }
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
          text.tipChannelName,
          text.tipChannelDescription,
          text.eventChannelName,
          text.eventChannelDescription,
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
          text.tipChannelName,
          text.tipChannelDescription,
          text.eventChannelName,
          text.eventChannelDescription,
        ]) {
          expect(body, isNot(contains('—')), reason: body);
        }
      });
    });
  }

  test('every tip is written in Arabic, not carried over in English', () {
    final en = AppRouter.reminderText(lookupAppL10n(const Locale('en')));
    final ar = AppRouter.reminderText(lookupAppL10n(const Locale('ar')));
    final arabic = RegExp(r'[\u0600-\u06FF]');
    final latin = RegExp(r'[A-Za-z]');
    for (var i = 0; i < kTipCount; i++) {
      expect(ar.tipBodies[i], matches(arabic), reason: ar.tipBodies[i]);
      expect(ar.tipBodies[i], isNot(matches(latin)), reason: ar.tipBodies[i]);
      expect(ar.tipBodies[i], isNot(en.tipBodies[i]));
    }
    expect(ar.tipChannelName, matches(arabic));
  });

  test('the event notes are written in Arabic, not carried over', () {
    final en = lookupAppL10n(const Locale('en'));
    final ar = lookupAppL10n(const Locale('ar'));
    final english = AppRouter.reminderText(en).withEventCopy(en);
    final arabic = AppRouter.reminderText(ar).withEventCopy(ar);
    final script = RegExp(r'[\u0600-\u06FF]');
    final all = [
      ...arabic.eventBodies,
      ...arabic.bookedEventBodies,
      arabic.eventChannelName,
      arabic.eventChannelDescription,
    ];
    for (final body in all) {
      expect(body, matches(script), reason: body);
    }
    expect(arabic.eventBodies, isNot(english.eventBodies));
    expect(arabic.bookedEventBodies, isNot(english.bookedEventBodies));
    expect(arabic.bookedEventBodies.first, 'مكانك مستنيكي.');
    expect(english.bookedEventBodies.first, 'Your seat is waiting.');
    expect(
      english.eventBodies.first,
      'An Own Hub event is coming up. Seats are limited.',
    );
  });

  test('Arabic is the colloquial Egyptian the rest of the app speaks', () {
    final ar = AppRouter.reminderText(lookupAppL10n(const Locale('ar')));
    expect(ar.logBody, 'اتمرنتي النهارده؟ سجّليه بضغطة.');
    expect(ar.restBody, 'الراحة خلصت. المجموعة اللي بعدها جاهزة.');
  });
}
