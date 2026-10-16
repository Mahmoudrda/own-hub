// O03 — How many days a week?
//
// The screen that defines the rewards system: her answer becomes the weekly goal
// that counts weeks. So the tests here are not only about chips. Minutes a
// session are the next screen (O07, `minutes_view_test.dart`).
//
// §2 rule 3 gets a guard of its own. "Days a week" is a quantity PER WEEK, and
// the thing that would break this product is not a bug — it is a perfectly
// reasonable feature somebody adds later: a run of consecutive days. The
// research behind the product says visible daily failure erodes the motivation
// it exists to create, so the assertion is that nothing on this screen counts
// days and no day-level language reaches it.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/app_state/onboarding_state.dart';
import 'package:own_hub/features/onboarding/domain/intake.dart';
import 'package:own_hub/features/onboarding/domain/intake_repository.dart';
import 'package:own_hub/features/onboarding/presentation/schedule_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';
import 'package:own_hub/ui/app_chip_row.dart';
import 'package:own_hub/ui/app_step_bar.dart';

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
  group('the one question', () {
    testWidgets('every choice is visible at once', (tester) async {
      await tester.pumpWidget(
        _host(ScheduleView(repository: InMemoryIntakeRepository())),
      );
      await tester.pumpAndSettle();

      expect(find.text('How many days a week?'), findsOneWidget);
      expect(
        find.text('Be honest. This becomes your weekly goal.'),
        findsOneWidget,
      );
      // Fourth of six at home: goal, place, what she has there, then this.
      expect(find.text('4 of 6'), findsOneWidget);

      // Three day chips, not four. The fifth chip was removed with
      // `Intake.allowedDays`: it offered a target `kMaxSessionsTarget` refuses,
      // so a woman who tapped it was measured against four for ever after.
      for (final n in ['2', '3', '4']) {
        expect(find.text(n), findsOneWidget, reason: n);
      }
      expect(find.text('5'), findsNothing, reason: 'five is not offered');
      // One question a screen: minutes are asked next, not here.
      expect(find.text('How long can a session be?'), findsNothing);
      expect(find.text('15 min'), findsNothing);
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
      expect(find.textContaining('a rest week you'), findsOneWidget);
    });

    testWidgets('three days are preselected', (tester) async {
      await tester.pumpWidget(
        _host(ScheduleView(repository: InMemoryIntakeRepository())),
      );
      await tester.pumpAndSettle();

      expect(_chipSelected(tester, '3'), isTrue);
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
    testWidgets('Continue writes days, and nothing else', (tester) async {
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
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(repository.read().days, 4);
      expect(repository.writes, [
        {'days'},
      ]);
      expect(continued, 1);
    });

    testWidgets('Skip writes nothing and the default goal stands', (
      tester,
    ) async {
      final repository = InMemoryIntakeRepository();
      // Skip is drawn only where it leads somewhere.
      var skipped = 0;
      await tester.pumpWidget(
        _host(ScheduleView(repository: repository, onSkip: () => skipped++)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      expect(skipped, 1);
      expect(repository.writes, isEmpty);
      expect(repository.read().days, 3);
    });

    testWidgets('D3 — it opens on what is stored', (tester) async {
      await tester.pumpWidget(
        _host(
          ScheduleView(
            repository: InMemoryIntakeRepository(const Intake(days: 2)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(_chipSelected(tester, '2'), isTrue);
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

      expect(find.text('كام يوم في الأسبوع؟'), findsOneWidget);
      expect(find.text('4 من 6'), findsOneWidget);
      expect(find.text('How many days a week?'), findsNothing);

      for (final n in ['2', '3', '4']) {
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

  group('the short "Your week", before sign-up', () {
    // Days, then minutes (O07), then what to train around (O04): the same
    // three questions as the full walk's last three, one a screen.
    setUp(() => OnboardingState.instance.beforeSignup = true);
    tearDown(() => OnboardingState.instance.beforeSignup = false);

    testWidgets('the first of three: days alone, in one write', (tester) async {
      final repository = InMemoryIntakeRepository();
      var continued = 0;
      await tester.pumpWidget(
        _host(
          ScheduleView(
            repository: repository,
            titleOverride: '1 of 3 · Your week',
            onBack: () {},
            onContinue: () => continued++,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1 of 3 · Your week'), findsOneWidget);
      final bar = tester.widget<AppStepBar>(find.byType(AppStepBar));
      expect((bar.step, bar.total), (1, 3));
      expect(find.text('Anything we should train around?'), findsNothing);
      // Everything is preselected, so there is nothing to skip, and before
      // she has an account there is no Home to close to.
      expect(find.text('Skip'), findsNothing);
      expect(find.byIcon(Icons.close), findsNothing);

      await tester.tap(find.text('4'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(continued, 1);
      expect(repository.writes, [
        {'days'},
      ]);
      expect(repository.read().days, 4);
    });

    testWidgets('does not overflow in Arabic at the largest text size', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          ScheduleView(
            repository: InMemoryIntakeRepository(),
            titleOverride: '1 من 3 · أسبوعك',
          ),
          locale: const Locale('ar'),
          textScale: 1.6,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
