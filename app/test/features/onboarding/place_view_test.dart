// O02 — Where will you train, and with what?
//
// Two answers on one screen, so there are two things to hold: the place writes
// like any other single choice, and the equipment is a set with one exclusive
// member. "Nothing" being exclusive is the part that would rot quietly — a woman
// who owns nothing and a woman who owns a mat AND nothing are different answers,
// and only one of them is possible.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/onboarding/domain/intake.dart';
import 'package:own_hub/features/onboarding/domain/intake_repository.dart';
import 'package:own_hub/features/onboarding/presentation/intake_option.dart';
import 'package:own_hub/features/onboarding/presentation/place_view.dart';
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

bool _placeSelected(WidgetTester tester, String title) => tester
    .widget<IntakeOption>(
      find.ancestor(of: find.text(title), matching: find.byType(IntakeOption)),
    )
    .selected;

/// The equipment chips sit at the bottom of this screen and fall below the fold
/// on a short viewport, so they are scrolled into view before being tapped —
/// which is what a woman on a small phone does. Without this a tap lands outside
/// the visible area and silently does nothing, so the assertion fails while the
/// screen itself is perfectly correct.
Future<void> _tapChip(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

bool _chipSelected(WidgetTester tester, String label) => tester
    .widget<AppChip>(
      find.ancestor(of: find.text(label), matching: find.byType(AppChip)),
    )
    .selected;

void main() {
  group('both questions are on the screen', () {
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
    });

    testWidgets('equipment is asked as chips, with "Nothing" among them', (
      tester,
    ) async {
      // The design's reason: the honest answer for most women here is "nothing",
      // and that answer has to be the easy one.
      await tester.pumpWidget(
        _host(PlaceView(repository: InMemoryIntakeRepository())),
      );
      await tester.pumpAndSettle();

      expect(find.text('What do you have at home?'), findsOneWidget);
      for (final item in ['Nothing', 'A mat', 'Dumbbells', 'Bands']) {
        expect(find.text(item), findsOneWidget, reason: item);
      }
      expect(find.text('Step 2 of 4'), findsOneWidget);
    });
  });

  group('the defaults are the easy answers', () {
    testWidgets('at home, owning nothing', (tester) async {
      await tester.pumpWidget(
        _host(PlaceView(repository: InMemoryIntakeRepository())),
      );
      await tester.pumpAndSettle();

      expect(_placeSelected(tester, 'At home'), isTrue);
      expect(_chipSelected(tester, 'Nothing'), isTrue);
      expect(_chipSelected(tester, 'Dumbbells'), isFalse);
    });
  });

  group('"Nothing" is exclusive, in both directions', () {
    testWidgets('choosing equipment clears it', (tester) async {
      await tester.pumpWidget(
        _host(PlaceView(repository: InMemoryIntakeRepository())),
      );
      await tester.pumpAndSettle();

      await _tapChip(tester, 'Dumbbells');

      expect(_chipSelected(tester, 'Dumbbells'), isTrue);
      expect(
        _chipSelected(tester, 'Nothing'),
        isFalse,
        reason: 'owning dumbbells and owning nothing cannot both be true',
      );
    });

    testWidgets('choosing it clears the equipment', (tester) async {
      await tester.pumpWidget(
        _host(
          PlaceView(
            repository: InMemoryIntakeRepository(
              const Intake(equipment: {Equipment.mat, Equipment.bands}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await _tapChip(tester, 'Nothing');

      expect(_chipSelected(tester, 'Nothing'), isTrue);
      expect(_chipSelected(tester, 'A mat'), isFalse);
      expect(_chipSelected(tester, 'Bands'), isFalse);
    });

    testWidgets('turning off the last item falls back to "Nothing"', (
      tester,
    ) async {
      // "I own nothing" and "I did not say" must not look the same to the
      // programme builder.
      final repository = InMemoryIntakeRepository(
        const Intake(equipment: {Equipment.mat}),
      );
      await tester.pumpWidget(_host(PlaceView(repository: repository)));
      await tester.pumpAndSettle();

      await _tapChip(tester, 'A mat');

      expect(_chipSelected(tester, 'Nothing'), isTrue);
    });

    testWidgets('several pieces of equipment can be on at once', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(PlaceView(repository: InMemoryIntakeRepository())),
      );
      await tester.pumpAndSettle();

      await _tapChip(tester, 'A mat');
      await _tapChip(tester, 'Bands');

      expect(_chipSelected(tester, 'A mat'), isTrue);
      expect(_chipSelected(tester, 'Bands'), isTrue);
    });
  });

  group('writing', () {
    testWidgets('Continue writes this step\'s two fields and no others', (
      tester,
    ) async {
      final repository = InMemoryIntakeRepository();
      var continued = 0;
      await tester.pumpWidget(
        _host(PlaceView(repository: repository, onContinue: () => continued++)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('A ladies-only gym'));
      await tester.pumpAndSettle();
      await _tapChip(tester, 'Dumbbells');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(repository.read().place, TrainingPlace.ladiesGym);
      expect(repository.read().equipment, {Equipment.dumbbells});
      expect(repository.writes, [
        {'place', 'equipment'},
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
              const Intake(
                place: TrainingPlace.both,
                equipment: {Equipment.bands},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(_placeSelected(tester, 'Both'), isTrue);
      expect(_chipSelected(tester, 'Bands'), isTrue);
      expect(_chipSelected(tester, 'Nothing'), isFalse);
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

      expect(find.text('أين ستتدرّبين؟'), findsOneWidget);
      expect(find.text('في المنزل'), findsOneWidget);
      expect(find.text('الخطوة 2 من 4'), findsOneWidget);
      expect(find.text('Where will you train?'), findsNothing);
      expect(find.text('Dumbbells'), findsNothing);
    });
  });

  testWidgets('does not overflow at the largest system text size in Arabic', (
    tester,
  ) async {
    // The tightest row in the flow: four chips across a phone width, with
    // Arabic labels, at 1.6. They wrap rather than clip.
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
