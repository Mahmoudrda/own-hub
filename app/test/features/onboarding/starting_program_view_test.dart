// O05 — Your starting programme.
//
// The payoff screen: four answers come back as something with a name and a first
// week. Two things are worth testing carefully.
//
// First, the programme comes from DATA. No programme content is authored yet
// (G2 §9 Q8), so the catalogue is a placeholder — and the screen has to be the
// kind of thing you can point at a real catalogue without rewriting it.
//
// Second, "Pick a different program" leads to R11, the Workout LIBRARY, which is
// 124 videos with filters rather than a programme picker. That is what the
// design says and it is implemented as designed; G2 §9 Q4 flags it as an open
// question because no programme-picker screen exists anywhere in the 161. The
// test pins the behaviour so the answer, when it comes, is a deliberate change.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/onboarding/domain/intake_repository.dart';
import 'package:own_hub/features/onboarding/domain/starting_program.dart';
import 'package:own_hub/features/onboarding/presentation/starting_program_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';
import 'package:own_hub/ui/app_media.dart';

Widget _host(
  Widget child, {
  Locale locale = const Locale('en'),
  double textScale = 1.0,
}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppL10n.localizationsDelegates,
    supportedLocales: AppL10n.supportedLocales,
    theme: buildTheme(locale),
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: child,
    ),
  );
}

void main() {
  group('the answers visibly paid for something', () {
    testWidgets('it says where the programme came from', (tester) async {
      await tester.pumpWidget(
        _host(StartingProgramView(repository: InMemoryIntakeRepository())),
      );
      await tester.pumpAndSettle();

      expect(find.text('Built from your four answers'), findsOneWidget);
      expect(
        find.text('Three days a week, 15 minutes, at home'),
        findsOneWidget,
      );
    });

    testWidgets('the programme has a name, a shape and a first week', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(StartingProgramView(repository: InMemoryIntakeRepository())),
      );
      await tester.pumpAndSettle();

      expect(find.text('Beginner foundations'), findsOneWidget);
      expect(find.text('8 weeks · quiet · no equipment'), findsOneWidget);
      expect(
        find.textContaining('Week 1 starts with four moves'),
        findsOneWidget,
      );
      // A still, not a video: O05 costs zero video egress.
      expect(find.byType(AppMedia), findsOneWidget);
    });

    testWidgets('her week is already set, and it says she can change it', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(StartingProgramView(repository: InMemoryIntakeRepository())),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Your week: Monday, Tuesday and Thursday'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Change any day by tapping it'),
        findsOneWidget,
      );
    });
  });

  group('the programme comes from data, not from the widget', () {
    testWidgets('an empty catalogue shows no programme card rather than an '
        'invented one', (tester) async {
      // There is no authored programme content yet. If the catalogue is empty
      // the screen is visibly incomplete — which is the point. It must never
      // fall back to a hardcoded name to look finished.
      await tester.pumpWidget(
        _host(
          StartingProgramView(
            repository: InMemoryIntakeRepository(),
            catalogue: const [],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Beginner foundations'), findsNothing);
      expect(tester.takeException(), isNull);
      // She can still get on with it.
      expect(find.text('Start day 1 now'), findsOneWidget);
    });

    testWidgets('a programme with no authored copy renders no card', (
      tester,
    ) async {
      // The honest alternative to showing her an English programme id.
      await tester.pumpWidget(
        _host(
          StartingProgramView(
            repository: InMemoryIntakeRepository(),
            catalogue: const [
              StartingProgram(
                programId: 'postpartum_rebuild',
                weeks: 8,
                daysPerWeek: 3,
                sessionLength: 15,
                quiet: true,
                equipment: {},
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('postpartum_rebuild'), findsNothing);
      expect(find.text('Beginner foundations'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('one primary action, and two real alternatives', () {
    testWidgets('all three are on the screen', (tester) async {
      await tester.pumpWidget(
        _host(StartingProgramView(repository: InMemoryIntakeRepository())),
      );
      await tester.pumpAndSettle();

      expect(find.text('Start day 1 now'), findsOneWidget);
      expect(find.text('I will start tomorrow'), findsOneWidget);
      expect(find.text('Pick a different program'), findsOneWidget);
    });

    testWidgets('each one fires', (tester) async {
      var now = 0;
      var tomorrow = 0;
      var different = 0;
      await tester.pumpWidget(
        _host(
          StartingProgramView(
            repository: InMemoryIntakeRepository(),
            onStartNow: () => now++,
            onStartTomorrow: () => tomorrow++,
            // As designed, this leads to R11 — the Workout library, not a picker.
            // See the note at the top of this file and G2 §9 Q4.
            onPickDifferentProgram: () => different++,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Start day 1 now'));
      await tester.tap(find.text('I will start tomorrow'));
      await tester.tap(find.text('Pick a different program'));
      await tester.pumpAndSettle();

      expect(now, 1);
      expect(tomorrow, 1);
      expect(different, 1);
    });

    testWidgets('the primary action meets the minimum tap target', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(StartingProgramView(repository: InMemoryIntakeRepository())),
      );
      await tester.pumpAndSettle();

      final size = tester.getSize(
        find
            .ancestor(
              of: find.text('Start day 1 now'),
              matching: find.byType(InkWell),
            )
            .first,
      );
      expect(size.height, greaterThanOrEqualTo(44));
    });
  });

  group('Arabic', () {
    testWidgets('reads from the dictionary', (tester) async {
      await tester.pumpWidget(
        _host(
          StartingProgramView(repository: InMemoryIntakeRepository()),
          locale: const Locale('ar'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('مبنية على إجاباتك الأربع'), findsOneWidget);
      expect(find.text('أساسيات للمبتدئات'), findsOneWidget);
      expect(find.text('ابدئي اليوم 1 الآن'), findsOneWidget);
      expect(find.text('Built from your four answers'), findsNothing);
      expect(find.text('Beginner foundations'), findsNothing);
    });
  });

  testWidgets('does not overflow at the largest system text size in Arabic', (
    tester,
  ) async {
    // The densest screen in the flow: a headline, a card with a media block, a
    // sage note, and three actions — two of them side by side.
    await tester.pumpWidget(
      _host(
        StartingProgramView(repository: InMemoryIntakeRepository()),
        locale: const Locale('ar'),
        textScale: 1.6,
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
