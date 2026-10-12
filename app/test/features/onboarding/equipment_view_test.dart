// O06 — What do you have at home?
//
// Asked only when home is part of where she trains, and one answer: a set with
// one exclusive member. "Nothing" being exclusive is the part that would rot
// quietly — a woman who owns nothing and a woman who owns a mat AND nothing are
// different answers, and only one of them is possible.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/onboarding/domain/intake.dart';
import 'package:own_hub/features/onboarding/domain/intake_repository.dart';
import 'package:own_hub/features/onboarding/presentation/equipment_view.dart';
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

/// Scrolled into view before the tap, which is what a woman on a small phone
/// does. Without it a tap outside the visible area silently does nothing, and
/// the assertion fails while the screen itself is correct.
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
  group('the one question', () {
    testWidgets('asked as chips, with "Nothing" among them', (tester) async {
      // The design's reason: the honest answer for most women here is
      // "nothing", and that answer has to be the easy one.
      await tester.pumpWidget(
        _host(EquipmentView(repository: InMemoryIntakeRepository())),
      );
      await tester.pumpAndSettle();

      expect(find.text('What do you have at home?'), findsOneWidget);
      expect(
        find.text('Most women start with nothing. That is plenty.'),
        findsOneWidget,
      );
      for (final item in ['Nothing', 'A mat', 'Dumbbells', 'Bands']) {
        expect(find.text(item), findsOneWidget, reason: item);
      }
      // Third of six: after her goal and her place.
      expect(find.text('3 of 6'), findsOneWidget);
    });
  });

  group('the defaults are the easy answers', () {
    testWidgets('owning nothing', (tester) async {
      await tester.pumpWidget(
        _host(EquipmentView(repository: InMemoryIntakeRepository())),
      );
      await tester.pumpAndSettle();

      expect(_chipSelected(tester, 'Nothing'), isTrue);
      expect(_chipSelected(tester, 'Dumbbells'), isFalse);
    });
  });

  group('"Nothing" is exclusive, in both directions', () {
    testWidgets('choosing equipment clears it', (tester) async {
      await tester.pumpWidget(
        _host(EquipmentView(repository: InMemoryIntakeRepository())),
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
          EquipmentView(
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
      await tester.pumpWidget(_host(EquipmentView(repository: repository)));
      await tester.pumpAndSettle();

      await _tapChip(tester, 'A mat');

      expect(_chipSelected(tester, 'Nothing'), isTrue);
    });

    testWidgets('several pieces of equipment can be on at once', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(EquipmentView(repository: InMemoryIntakeRepository())),
      );
      await tester.pumpAndSettle();

      await _tapChip(tester, 'A mat');
      await _tapChip(tester, 'Bands');

      expect(_chipSelected(tester, 'A mat'), isTrue);
      expect(_chipSelected(tester, 'Bands'), isTrue);
    });
  });

  group('writing', () {
    testWidgets('Continue writes the equipment, and nothing else', (
      tester,
    ) async {
      final repository = InMemoryIntakeRepository();
      var continued = 0;
      await tester.pumpWidget(
        _host(
          EquipmentView(repository: repository, onContinue: () => continued++),
        ),
      );
      await tester.pumpAndSettle();

      await _tapChip(tester, 'Dumbbells');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(repository.read().equipment, {Equipment.dumbbells});
      expect(repository.writes, [
        {'equipment'},
      ]);
      expect(continued, 1);
    });

    testWidgets('D3 — it opens on what is stored', (tester) async {
      await tester.pumpWidget(
        _host(
          EquipmentView(
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

      expect(_chipSelected(tester, 'Bands'), isTrue);
      expect(_chipSelected(tester, 'Nothing'), isFalse);
    });
  });

  group('Arabic', () {
    testWidgets('reads from the dictionary', (tester) async {
      await tester.pumpWidget(
        _host(
          EquipmentView(repository: InMemoryIntakeRepository()),
          locale: const Locale('ar'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('عندك إيه في البيت؟'), findsOneWidget);
      expect(find.text('ولا حاجة'), findsOneWidget);
      expect(find.text('3 من 6'), findsOneWidget);
      expect(find.text('What do you have at home?'), findsNothing);
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
        EquipmentView(repository: InMemoryIntakeRepository()),
        locale: const Locale('ar'),
        textScale: 1.6,
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
