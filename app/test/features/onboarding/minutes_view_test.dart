// O07 — How long can a session be?
//
// One number on its own screen, after days a week (O03). The chips are built
// from `Intake.allowedMinutes` through the dictionary's "{n} min", so besides
// the write the thing to hold is P0-A11Y-01: the words translate and the
// digits do not.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/app_state/onboarding_state.dart';
import 'package:own_hub/features/onboarding/domain/intake.dart';
import 'package:own_hub/features/onboarding/domain/intake_repository.dart';
import 'package:own_hub/features/onboarding/presentation/minutes_view.dart';
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
    testWidgets('four lengths, each said in minutes', (tester) async {
      await tester.pumpWidget(
        _host(MinutesView(repository: InMemoryIntakeRepository())),
      );
      await tester.pumpAndSettle();

      expect(find.text('How long can a session be?'), findsOneWidget);
      expect(
        find.text('Short is fine. Fifteen minutes done beats an hour planned.'),
        findsOneWidget,
      );
      for (final chip in ['10 min', '15 min', '20 min', '30 min']) {
        expect(find.text(chip), findsOneWidget, reason: chip);
      }
      // Fifth of six at home: after days a week, before what to train around.
      expect(find.text('5 of 6'), findsOneWidget);
      // One question a screen: days were the last one.
      expect(find.text('How many days a week?'), findsNothing);
    });

    testWidgets('fifteen minutes is preselected', (tester) async {
      await tester.pumpWidget(
        _host(MinutesView(repository: InMemoryIntakeRepository())),
      );
      await tester.pumpAndSettle();

      expect(_chipSelected(tester, '15 min'), isTrue);
      expect(_chipSelected(tester, '30 min'), isFalse);
    });
  });

  group('writing', () {
    testWidgets('Continue writes minutes, and nothing else', (tester) async {
      final repository = InMemoryIntakeRepository();
      var continued = 0;
      await tester.pumpWidget(
        _host(
          MinutesView(repository: repository, onContinue: () => continued++),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('30 min'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(repository.read().minutes, 30);
      expect(repository.read().days, Intake.defaults.days);
      expect(repository.writes, [
        {'minutes'},
      ]);
      expect(continued, 1);
    });

    testWidgets('D3 — it opens on what is stored', (tester) async {
      await tester.pumpWidget(
        _host(
          MinutesView(
            repository: InMemoryIntakeRepository(const Intake(minutes: 10)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(_chipSelected(tester, '10 min'), isTrue);
      expect(_chipSelected(tester, '15 min'), isFalse);
    });
  });

  group('the short "Your week", before sign-up', () {
    setUp(() => OnboardingState.instance.beforeSignup = true);
    tearDown(() => OnboardingState.instance.beforeSignup = false);

    testWidgets('the second of three, with nothing to skip or close', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          MinutesView(
            repository: InMemoryIntakeRepository(),
            titleOverride: '1 of 3 · Your week',
            onBack: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1 of 3 · Your week'), findsOneWidget);
      final bar = tester.widget<AppStepBar>(find.byType(AppStepBar));
      expect((bar.step, bar.total), (2, 3));
      expect(find.text('Skip'), findsNothing);
      expect(find.byIcon(Icons.close), findsNothing);
    });
  });

  group('Arabic', () {
    testWidgets('the words translate and the numbers do not', (tester) async {
      // P0-A11Y-01: the chips keep Western numerals in both languages.
      await tester.pumpWidget(
        _host(
          MinutesView(repository: InMemoryIntakeRepository()),
          locale: const Locale('ar'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('التمرين ممكن ياخد قد إيه؟'), findsOneWidget);
      expect(find.text('5 من 6'), findsOneWidget);
      expect(find.text('How long can a session be?'), findsNothing);
      for (final chip in ['10 دقيقة', '15 دقيقة', '20 دقيقة', '30 دقيقة']) {
        expect(
          find.text(chip),
          findsOneWidget,
          reason: 'the chips stay in Western numerals: $chip',
        );
      }
      for (final eastern in ['١٠', '١٥', '٢٠', '٣٠']) {
        expect(find.textContaining(eastern), findsNothing, reason: eastern);
      }
    });
  });

  testWidgets('does not overflow at the largest system text size in Arabic', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        MinutesView(repository: InMemoryIntakeRepository()),
        locale: const Locale('ar'),
        textScale: 1.6,
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
