// O03 — How much time do you really have?
//
// The screen that defines the rewards system: her answer becomes the weekly goal
// that counts weeks. So the tests here are not only about chips.
//
// §2 rule 3 gets a guard of its own. "Days a week" is a quantity PER WEEK, and
// the thing that would break this product is not a bug — it is a perfectly
// reasonable feature somebody adds later: a run of consecutive days. The
// research behind the product says visible daily failure erodes the motivation
// it exists to create, so the assertion is that nothing on this screen counts
// days and no day-level language reaches it.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/onboarding/domain/intake.dart';
import 'package:own_hub/features/onboarding/domain/intake_repository.dart';
import 'package:own_hub/features/onboarding/presentation/schedule_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';
import 'package:own_hub/ui/app_chip_row.dart';

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

bool _chipSelected(WidgetTester tester, String label) => tester
    .widget<AppChip>(
      find.ancestor(of: find.text(label), matching: find.byType(AppChip)),
    )
    .selected;

void main() {
  group('the two questions', () {
    testWidgets('every choice is visible at once', (tester) async {
      await tester.pumpWidget(
        _host(ScheduleView(repository: InMemoryIntakeRepository())),
      );
      await tester.pumpAndSettle();

      expect(find.text('How much time do you really have?'), findsOneWidget);
      expect(
        find.text('Be honest. This becomes your weekly goal.'),
        findsOneWidget,
      );
      expect(find.text('Days a week'), findsOneWidget);
      expect(find.text('Minutes a session'), findsOneWidget);

      // Three day chips, not four. The fifth chip was removed with
      // `Intake.allowedDays`: it offered a target `kMaxSessionsTarget` refuses,
      // so a woman who tapped it was measured against four for ever after.
      for (final n in ['2', '3', '4', '10', '15', '20', '30']) {
        expect(find.text(n), findsOneWidget, reason: n);
      }
      expect(find.text('5'), findsNothing, reason: 'five is not offered');
    });

    testWidgets('the rest-week rule is explained before she can fail it', (
      tester,
    ) async {
      // Stated once, here, on the screen that sets the goal. A woman should
      // never discover the rule by missing a week.
      await tester.pumpWidget(
        _host(ScheduleView(repository: InMemoryIntakeRepository())),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('the week counts'), findsOneWidget);
      expect(find.textContaining('covered by a rest week'), findsOneWidget);
    });

    testWidgets('three days and fifteen minutes are preselected', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(ScheduleView(repository: InMemoryIntakeRepository())),
      );
      await tester.pumpAndSettle();

      expect(_chipSelected(tester, '3'), isTrue);
      expect(_chipSelected(tester, '15'), isTrue);
      // Was '5'. Five is no longer a chip at all, so the negative control moved
      // to the highest day chip that does exist.
      expect(_chipSelected(tester, '4'), isFalse);
    });
  });

  group('§2 rule 3 — weeks, not days', () {
    testWidgets('no day-level counter or streak language reaches the screen', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(ScheduleView(repository: InMemoryIntakeRepository())),
      );
      await tester.pumpAndSettle();

      for (final word in ['streak', 'in a row', 'day 1 of', 'consecutive']) {
        expect(
          find.textContaining(RegExp(word, caseSensitive: false)),
          findsNothing,
          reason: 'rule 3: there is no daily counter anywhere — found "$word"',
        );
      }
    });

    testWidgets('her answer is a weekly quantity, stored as one number', (
      tester,
    ) async {
      final repository = InMemoryIntakeRepository();
      await tester.pumpWidget(_host(ScheduleView(repository: repository)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('4'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Four sessions a week. Not four particular days, and not four in a row.
      expect(repository.read().days, 4);
    });
  });

  group('writing', () {
    testWidgets('Continue writes days and minutes, and nothing else', (
      tester,
    ) async {
      final repository = InMemoryIntakeRepository();
      var continued = 0;
      await tester.pumpWidget(
        _host(
          ScheduleView(repository: repository, onContinue: () => continued++),
        ),
      );
      await tester.pumpAndSettle();

      // Was a 5. Four is the top chip now, and the point of the case is that
      // the number she taps is the number that is written, whichever it is.
      await tester.tap(find.text('4'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('30'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(repository.read().days, 4);
      expect(repository.read().minutes, 30);
      expect(repository.writes, [
        {'days', 'minutes'},
      ]);
      expect(continued, 1);
    });

    testWidgets('Skip writes nothing and the default goal stands', (
      tester,
    ) async {
      final repository = InMemoryIntakeRepository();
      await tester.pumpWidget(_host(ScheduleView(repository: repository)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      expect(repository.writes, isEmpty);
      expect(repository.read().days, 3);
    });

    testWidgets('D3 — it opens on what is stored', (tester) async {
      await tester.pumpWidget(
        _host(
          ScheduleView(
            repository: InMemoryIntakeRepository(
              const Intake(days: 2, minutes: 10),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(_chipSelected(tester, '2'), isTrue);
      expect(_chipSelected(tester, '10'), isTrue);
      expect(_chipSelected(tester, '3'), isFalse);
    });
  });

  group('Arabic', () {
    testWidgets('the words translate and the numbers do not', (tester) async {
      // P0-A11Y-01: the chips keep Western numerals in both languages.
      await tester.pumpWidget(
        _host(
          ScheduleView(repository: InMemoryIntakeRepository()),
          locale: const Locale('ar'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('كم من الوقت لديك فعلًا؟'), findsOneWidget);
      expect(find.text('أيام أسبوعيًا'), findsOneWidget);
      expect(find.text('الخطوة 3 من 4'), findsOneWidget);
      expect(find.text('Days a week'), findsNothing);

      for (final n in ['3', '15']) {
        expect(
          find.text(n),
          findsOneWidget,
          reason: 'the chips stay in Western numerals',
        );
      }
    });
  });

  testWidgets('does not overflow at the largest system text size in Arabic', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        ScheduleView(repository: InMemoryIntakeRepository()),
        locale: const Locale('ar'),
        textScale: 1.6,
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
