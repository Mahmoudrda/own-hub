// R07 speaks the language on screen, not the one the session started in.
//
// A session keeps the moves it was started with, and their names and
// prescriptions were read from the dictionary at that moment. A woman who
// started in English and switched to Arabic saw "Glute bridge" and
// "bodyweight" inside an Arabic screen, while R03 beside it was translated.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/features/train/presentation/mid_set_view.dart';
import 'package:own_hub/features/train/presentation/workout_day_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';

Widget _host(Widget child, Locale locale) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppL10n.localizationsDelegates,
  supportedLocales: AppL10n.supportedLocales,
  theme: buildTheme(locale),
  home: child,
);

void main() {
  final en = lookupAppL10n(const Locale('en'));
  final ar = lookupAppL10n(const Locale('ar'));

  for (final index in [0, 1, 2, 3]) {
    testWidgets('a move started in English reads in Arabic, move $index', (
      tester,
    ) async {
      final startedInEnglish = sampleWorkoutDay(en).moves[index];
      final inArabic = sampleWorkoutDay(ar).moves[index];

      await tester.pumpWidget(
        _host(MidSetView(move: startedInEnglish), const Locale('ar')),
      );
      await tester.pumpAndSettle();

      expect(find.text(inArabic.name), findsWidgets);
      expect(find.text(startedInEnglish.name), findsNothing);
      expect(find.text(inArabic.prescriptionLabel), findsWidgets);
      expect(find.text(startedInEnglish.prescriptionLabel), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('and the other way round', (tester) async {
    final startedInArabic = sampleWorkoutDay(ar).moves.first;
    await tester.pumpWidget(
      _host(MidSetView(move: startedInArabic), const Locale('en')),
    );
    await tester.pumpAndSettle();

    expect(find.text(en.donkeyKick), findsWidgets);
    expect(find.text(ar.donkeyKick), findsNothing);
    expect(find.text(en.n312Bodyweight), findsWidgets);
  });
}
