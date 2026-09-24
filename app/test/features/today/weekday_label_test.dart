// The day's name on Home's masthead.
//
// On five days of the week it read "Tuesday"; on the other two it read "Sat"
// and "Sun", because those were the only keys the dictionary held. The
// abbreviations still belong to a calendar grid and a day strip, where a full
// name does not fit. They do not belong on a masthead that spells out Monday.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/today/presentation/today_cards.dart';
import 'package:own_hub/l10n/app_l10n.dart';

void main() {
  // 7 September 2026 is a Monday, so the week runs 7 to 13.
  DateTime dayOfWeek(int weekday) => DateTime(2026, 9, 6 + weekday);

  test('all seven days are set in full, in English', () async {
    final l10n = await AppL10n.delegate.load(const Locale('en'));

    expect(weekdayLabel(l10n, dayOfWeek(DateTime.monday)), 'Monday');
    expect(weekdayLabel(l10n, dayOfWeek(DateTime.tuesday)), 'Tuesday');
    expect(weekdayLabel(l10n, dayOfWeek(DateTime.wednesday)), 'Wednesday');
    expect(weekdayLabel(l10n, dayOfWeek(DateTime.thursday)), 'Thursday');
    expect(weekdayLabel(l10n, dayOfWeek(DateTime.friday)), 'Friday');
    // The two that were short.
    expect(weekdayLabel(l10n, dayOfWeek(DateTime.saturday)), 'Saturday');
    expect(weekdayLabel(l10n, dayOfWeek(DateTime.sunday)), 'Sunday');
  });

  test('and in Arabic', () async {
    final l10n = await AppL10n.delegate.load(const Locale('ar'));

    expect(weekdayLabel(l10n, dayOfWeek(DateTime.monday)), 'الاثنين');
    expect(weekdayLabel(l10n, dayOfWeek(DateTime.saturday)), 'السبت');
    expect(weekdayLabel(l10n, dayOfWeek(DateTime.sunday)), 'الأحد');
  });

  test('no day renders an abbreviation', () async {
    for (final locale in const [Locale('en'), Locale('ar')]) {
      final l10n = await AppL10n.delegate.load(locale);
      for (var weekday = 1; weekday <= 7; weekday++) {
        final label = weekdayLabel(l10n, dayOfWeek(weekday));
        expect(
          [l10n.sat, l10n.sun].contains(label) &&
              label != l10n.saturday &&
              label != l10n.sunday,
          isFalse,
          reason: 'weekday $weekday in ${locale.languageCode} reads "$label"',
        );
      }
    }
  });

  testWidgets('Home names Saturday in full', (tester) async {
    // Through the masthead rather than the helper, so the string reaching the
    // screen is the one asserted.
    final l10n = await AppL10n.delegate.load(const Locale('en'));
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: Scaffold(
          body: TodayGreeting(
            day: weekdayLabel(l10n, dayOfWeek(DateTime.saturday)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Saturday'), findsOneWidget);
    expect(find.text('Sat'), findsNothing);
  });
}
