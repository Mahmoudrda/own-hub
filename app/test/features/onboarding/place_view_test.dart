// O02 — Where will you train?
//
// One answer on this screen now: the place. What she has at home is its own
// question (O06, `equipment_view_test.dart`), asked only when home is part of
// her answer. So besides the write there is one more thing to hold: choosing a
// ladies-only gym takes that question out of the walk, and the count on this
// screen says so as she taps.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/onboarding/domain/intake.dart';
import 'package:own_hub/features/onboarding/domain/intake_repository.dart';
import 'package:own_hub/features/onboarding/presentation/intake_option.dart';
import 'package:own_hub/features/onboarding/presentation/place_view.dart';
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

bool _placeSelected(WidgetTester tester, String title) => tester
    .widget<IntakeOption>(
      find.ancestor(of: find.text(title), matching: find.byType(IntakeOption)),
    )
    .selected;

(int, int) _bar(WidgetTester tester) {
  final bar = tester.widget<AppStepBar>(find.byType(AppStepBar));
  return (bar.step, bar.total);
}

void main() {
  group('the one question', () {
    testWidgets('three places, each with what it means', (tester) async {
      await tester.pumpWidget(
        _host(PlaceView(repository: InMemoryIntakeRepository())),
      );
      await tester.pumpAndSettle();

      expect(find.text('Where will you train?'), findsOneWidget);
      expect(find.text('You can change it on any day.'), findsOneWidget);
      expect(find.text('At home'), findsOneWidget);
      expect(find.text('A ladies-only gym'), findsOneWidget);
      expect(find.text('Both'), findsOneWidget);
      expect(find.text('Quiet moves, floor, nothing to carry'), findsOneWidget);
      expect(find.text('2 of 6'), findsOneWidget);
    });

    testWidgets('what she has at home is not asked here', (tester) async {
      // One question a screen. The equipment chips are O06's.
      await tester.pumpWidget(
        _host(PlaceView(repository: InMemoryIntakeRepository())),
      );
      await tester.pumpAndSettle();

      expect(find.text('What do you have at home?'), findsNothing);
      expect(find.byType(AppChip), findsNothing);
    });
  });

  group('the walk follows her answer', () {
    testWidgets('a ladies-only gym is one question shorter, counted as she '
        'taps', (tester) async {
      // She is not asked about dumbbells in a living room she does not train
      // in, and the count drops on this screen rather than one screen later.
      await tester.pumpWidget(
        _host(PlaceView(repository: InMemoryIntakeRepository())),
      );
      await tester.pumpAndSettle();
      expect(_bar(tester), (2, 6));

      await tester.tap(find.text('A ladies-only gym'));
      await tester.pumpAndSettle();
      expect(find.text('2 of 5'), findsOneWidget);
      expect(_bar(tester), (2, 5));

      await tester.tap(find.text('Both'));
      await tester.pumpAndSettle();
      expect(find.text('2 of 6'), findsOneWidget);
      expect(_bar(tester), (2, 6));
    });
  });

  group('the defaults are the easy answers', () {
    testWidgets('at home', (tester) async {
      await tester.pumpWidget(
        _host(PlaceView(repository: InMemoryIntakeRepository())),
      );
      await tester.pumpAndSettle();

      expect(_placeSelected(tester, 'At home'), isTrue);
      expect(_placeSelected(tester, 'A ladies-only gym'), isFalse);
    });
  });

  group('writing', () {
    testWidgets('Continue writes the place, and nothing else', (tester) async {
      final repository = InMemoryIntakeRepository();
      var continued = 0;
      await tester.pumpWidget(
        _host(PlaceView(repository: repository, onContinue: () => continued++)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('A ladies-only gym'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(repository.read().place, TrainingPlace.ladiesGym);
      expect(repository.read().equipment, {Equipment.none});
      expect(repository.writes, [
        {'place'},
      ]);
      expect(continued, 1);
    });

    testWidgets('Skip writes nothing', (tester) async {
      final repository = InMemoryIntakeRepository();
      // Skip is drawn only where it leads somewhere.
      var skipped = 0;
      await tester.pumpWidget(
        _host(PlaceView(repository: repository, onSkip: () => skipped++)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      expect(skipped, 1);
      expect(repository.writes, isEmpty);
    });

    testWidgets('D3 — it opens on what is stored', (tester) async {
      await tester.pumpWidget(
        _host(
          PlaceView(
            repository: InMemoryIntakeRepository(
              const Intake(place: TrainingPlace.ladiesGym),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(_placeSelected(tester, 'A ladies-only gym'), isTrue);
      expect(_placeSelected(tester, 'At home'), isFalse);
      expect(find.text('2 of 5'), findsOneWidget);
    });
  });

  group('Arabic', () {
    testWidgets('reads from the dictionary', (tester) async {
      await tester.pumpWidget(
        _host(
          PlaceView(repository: InMemoryIntakeRepository()),
          locale: const Locale('ar'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('هتتمرّني فين؟'), findsOneWidget);
      expect(find.text('في البيت'), findsOneWidget);
      expect(find.text('2 من 6'), findsOneWidget);
      expect(find.text('Where will you train?'), findsNothing);
      expect(find.text('At home'), findsNothing);
    });
  });

  testWidgets('does not overflow at the largest system text size in Arabic', (
    tester,
  ) async {
    // Three places, each a wrapped title and subtitle, under the step bar, at
    // 1.6. They wrap rather than clip.
    await tester.pumpWidget(
      _host(
        PlaceView(repository: InMemoryIntakeRepository()),
        locale: const Locale('ar'),
        textScale: 1.6,
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
