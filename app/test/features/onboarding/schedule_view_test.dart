// O03 — How many days, and for how long?
//
// The screen that defines the rewards system: her answer becomes the weekly goal
// that counts weeks. So the tests here are not only about chips. Minutes a
// session sit on the same screen since 17 October 2026 (O07 was folded in).
//
// §2 rule 3 gets a guard of its own. "Days a week" is a quantity PER WEEK, and
// the thing that would break this product is not a bug — it is a perfectly
// reasonable feature somebody adds later: a run of consecutive days. The
// research behind the product says visible daily failure erodes the motivation
// it exists to create, so the assertion is that nothing on this screen counts
// days and no day-level language reaches it.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

      expect(find.text('How many days, and for how long?'), findsOneWidget);
      expect(
        find.text('Be honest. This becomes your weekly goal.'),
        findsOneWidget,
      );
      // Fourth of five at home: goal, place, what she has there, then this.
      expect(find.text('4 of 5'), findsOneWidget);

      // The three coach splits, 3, 4 and 5 days: every other week is a custom
      // schedule, which maps to the nearest split.
      for (final n in ['3', '4', '5']) {
        expect(find.text(n), findsOneWidget, reason: n);
      }
      for (final n in ['1-2', '6', '7']) {
        expect(find.text(n), findsNothing, reason: n);
      }
      // Minutes a session are asked on the same screen, each said in minutes,
      // with a custom length after the presets.
      expect(find.text('Days a week'), findsOneWidget);
      expect(find.text('Minutes a session'), findsOneWidget);
      for (final chip in [
        '30 min',
        '45 min',
        '60 min',
        '75+ min',
        '15 min · short day',
        'Custom',
      ]) {
        expect(find.text(chip), findsOneWidget, reason: chip);
      }
      expect(find.text('Custom schedule'), findsOneWidget);
      for (final level in ['Beginner', 'Intermediate', 'Advanced']) {
        expect(find.text(level), findsOneWidget, reason: level);
      }
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
      expect(_chipSelected(tester, '4'), isFalse);
      expect(_chipSelected(tester, 'Beginner'), isTrue);
      // Forty-five minutes is preselected too, and the 15 minute day is named
      // as the short one rather than offered as a normal length.
      expect(_chipSelected(tester, '45 min'), isTrue);
      expect(_chipSelected(tester, '30 min'), isFalse);
      expect(_chipSelected(tester, '15 min · short day'), isFalse);
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
    testWidgets('Continue writes her week, and nothing else', (tester) async {
      final repository = InMemoryIntakeRepository();
      var continued = 0;
      await tester.pumpWidget(
        _host(
          ScheduleView(repository: repository, onContinue: () => continued++),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('4'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('30 min'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(repository.read().days, 4);
      expect(repository.read().minutes, 30);
      expect(repository.writes, [
        {'days', 'minutes', 'minutesCustom', 'level', 'weekdays'},
      ]);
      expect(continued, 1);
    });

    testWidgets(
      'Skip, in the top bar, writes nothing and the default goal stands',
      (tester) async {
        final repository = InMemoryIntakeRepository();
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
      },
    );

    testWidgets('D3 — it opens on what is stored', (tester) async {
      await tester.pumpWidget(
        _host(
          ScheduleView(
            repository: InMemoryIntakeRepository(const Intake(days: 4)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(_chipSelected(tester, '4'), isTrue);
      expect(_chipSelected(tester, '3'), isFalse);
    });

    testWidgets('D3 — a week of another size selects no split chip', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          ScheduleView(
            repository: InMemoryIntakeRepository(const Intake(days: 6)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (final n in ['3', '4', '5']) {
        expect(_chipSelected(tester, n), isFalse, reason: n);
      }
    });

    testWidgets('D3 — minutes open on what is stored', (tester) async {
      await tester.pumpWidget(
        _host(
          ScheduleView(
            repository: InMemoryIntakeRepository(const Intake(minutes: 60)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(_chipSelected(tester, '60 min'), isTrue);
      expect(_chipSelected(tester, '45 min'), isFalse);
    });

    testWidgets('a saved 15 stays the short day, not a custom length', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          ScheduleView(
            repository: InMemoryIntakeRepository(const Intake(minutes: 15)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(_chipSelected(tester, '15 min · short day'), isTrue);
      expect(_chipSelected(tester, 'Custom'), isFalse);
      expect(find.byKey(const ValueKey('o03-minutes-slider')), findsNothing);
    });

    test('a new setup starts on 45 minutes', () {
      expect(const Intake().minutes, 45);
      expect(Intake.defaults.minutes, 45);
      expect(Intake.allowedMinutes, [30, 45, 60, 75, 15]);
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

      expect(
        find.text('كام يوم في الأسبوع، وكل تمرين قد إيه؟'),
        findsOneWidget,
      );
      expect(find.text('4 من 5'), findsOneWidget);
      expect(find.text('How many days, and for how long?'), findsNothing);
      // The minutes chips stay in Western numerals as well (P0-A11Y-01).
      for (final chip in [
        '30 دقيقة',
        '45 دقيقة',
        '60 دقيقة',
        '75+ دقيقة',
        '15 دقيقة · يوم خفيف',
      ]) {
        expect(find.text(chip), findsOneWidget, reason: chip);
      }
      for (final eastern in ['١٠', '١٥', '٢٠', '٣٠', '٤٥', '٦٠', '٧٥']) {
        expect(find.textContaining(eastern), findsNothing, reason: eastern);
      }

      for (final n in ['3', '4', '5']) {
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
    // Days and minutes (O03), then what to train around (O04): the same two
    // questions as the full walk's last two.
    setUp(() => OnboardingState.instance.beforeSignup = true);
    tearDown(() => OnboardingState.instance.beforeSignup = false);

    testWidgets('the first of two: days and minutes, in one write', (
      tester,
    ) async {
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
      expect((bar.step, bar.total), (1, 2));
      expect(find.text('Anything we should train around?'), findsNothing);
      // Before she has an account there is no Home to close to; Skip is the
      // way out when the router gives it one.
      expect(find.byIcon(Icons.close), findsNothing);

      await tester.tap(find.text('4'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(continued, 1);
      expect(repository.writes, [
        {'days', 'minutes', 'minutesCustom', 'level', 'weekdays'},
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

  group('chips never break a word', () {
    const widths = [375.0, 390.0];
    const scales = [1.0, 1.6, 2.0];
    for (final locale in [const Locale('en'), const Locale('ar')]) {
      for (final width in widths) {
        for (final scale in scales) {
          testWidgets('${locale.languageCode} at $width px, text x$scale', (
            tester,
          ) async {
            tester.view.physicalSize = Size(width * 3, 844 * 3);
            tester.view.devicePixelRatio = 3;
            addTearDown(tester.view.reset);
            await tester.pumpWidget(
              _host(
                ScheduleView(repository: InMemoryIntakeRepository()),
                locale: locale,
                textScale: scale,
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            final chips = find.descendant(
              of: find.byType(AppChip),
              matching: find.byType(RichText),
            );
            expect(chips, findsWidgets);
            for (final element in chips.evaluate()) {
              final paragraph = element.renderObject! as RenderParagraph;
              // At most two lines: 15px label, generous line height.
              expect(
                paragraph.size.height,
                lessThanOrEqualTo(15 * scale * 1.9 * 2),
                reason: paragraph.text.toPlainText(),
              );
            }
          });
        }
      }
    }
  });
}
