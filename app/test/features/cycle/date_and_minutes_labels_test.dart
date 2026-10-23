// Y08/Y09 name dates in words, Y06 names her programme's real minutes.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/domain/format/date_label.dart';
import 'package:own_hub/features/cycle/presentation/gentler_option_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';

Widget _host(Locale locale, Widget child) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppL10n.localizationsDelegates,
  supportedLocales: AppL10n.supportedLocales,
  home: child,
);

void main() {
  testWidgets('month and date labels, English and Arabic, Western digits', (
    tester,
  ) async {
    late AppL10n en;
    late AppL10n ar;
    await tester.pumpWidget(
      _host(
        const Locale('en'),
        Builder(
          builder: (c) {
            en = AppL10n.of(c);
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.pumpWidget(
      _host(
        const Locale('ar'),
        Builder(
          builder: (c) {
            ar = AppL10n.of(c);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(monthYearLabel(en, 2026, 10), 'October 2026');
    expect(dayMonthYearLabel(en, DateTime(2026, 10, 12)), '12 October 2026');
    expect(monthYearLabel(ar, 2026, 10), 'أكتوبر 2026');
    expect(dayMonthYearLabel(ar, DateTime(2026, 10, 12)), '12 أكتوبر 2026');
  });

  testWidgets('Y06 names the programme session length, not 35', (tester) async {
    await tester.pumpWidget(
      _host(
        const Locale('en'),
        const GentlerOptionView(reason: [], plannedMinutes: 15),
      ),
    );
    expect(find.text('15 min · your program'), findsOneWidget);
    expect(find.textContaining('35'), findsNothing);
  });

  testWidgets('Y06 drops the minutes when there are none', (tester) async {
    await tester.pumpWidget(
      _host(
        const Locale('en'),
        const GentlerOptionView(reason: [], plannedMinutes: 0),
      ),
    );
    expect(find.textContaining('min ·'), findsNothing);
  });
}
