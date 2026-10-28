// R07 speaks the language on screen, not the one the session started in.
//
// A session keeps the moves it was started with, and their names and
// prescriptions were read from the dictionary at that moment. A woman who
// started in English and switched to Arabic saw "Glute bridge" and
// "bodyweight" inside an Arabic screen, while R03 beside it was translated.
// Move names are Egyptian Arabic on an Arabic screen, like everything else.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/features/train/domain/train_repository.dart';
import 'package:own_hub/features/train/presentation/mid_set_view.dart';
import 'package:own_hub/features/train/presentation/set_labels.dart';
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
    testWidgets('a move started in English reads in Arabic on an Arabic '
        'screen, move $index', (tester) async {
      final startedInEnglish = sampleWorkoutDay(en).moves[index];
      final inArabic = sampleWorkoutDay(ar).moves[index];

      await tester.pumpWidget(
        _host(MidSetView(move: startedInEnglish), const Locale('ar')),
      );
      await tester.pumpAndSettle();

      expect(inArabic.name, isNot(startedInEnglish.name));
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
    expect(find.text(en.n312Bodyweight), findsWidgets);
  });

  testWidgets(
    'the title is Arabic and reads right to left in an Arabic screen',
    (tester) async {
      final move = sampleWorkoutDay(ar).moves.first;
      await tester.pumpWidget(
        _host(MidSetView(move: move), const Locale('ar')),
      );
      await tester.pumpAndSettle();

      final title = find.text(move.name);
      expect(title, findsWidgets);
      expect(Directionality.of(tester.element(title.first)), TextDirection.rtl);
      expect(find.byTooltip(ar.pause), findsOneWidget);
    },
  );

  testWidgets('an English name stays left to right in an Arabic screen', (
    tester,
  ) async {
    final move = sampleWorkoutDay(en).moves.first;
    await tester.pumpWidget(
      _host(
        MidSetView(
          move: PlannedMove(
            exerciseId: 'not_in_the_sample_day',
            name: 'Cable row',
            prescriptionLabel: move.prescriptionLabel,
            sets: move.sets,
          ),
        ),
        const Locale('ar'),
      ),
    );
    await tester.pumpAndSettle();

    final title = find.text('Cable row');
    expect(title, findsWidgets);
    expect(Directionality.of(tester.element(title.first)), TextDirection.ltr);
  });

  test('every shape of the set-saved banner is Arabic in Arabic', () {
    final saved = [
      setSavedLabel(ar, setNumber: 2, weightKg: 12, reps: 10),
      setSavedLabel(ar, setNumber: 2, reps: 12),
      setSavedLabel(ar, setNumber: 2, holdSeconds: 30),
    ];
    for (final line in saved) {
      expect(line, startsWith('اتحفظت المجموعة 2'));
      expect(RegExp(r'[A-Za-z]').hasMatch(line), isFalse, reason: line);
    }
  });
}
