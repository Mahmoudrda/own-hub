// Y02 used to draw two fields and ignore what she typed in both. These hold
// the fix: the date comes from the picker on the row, and the length is kept
// only when it is a real cycle length.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/cycle/domain/cycle_document.dart';
import 'package:own_hub/features/cycle/domain/cycle_repository.dart';
import 'package:own_hub/features/cycle/presentation/cycle_dates_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';

Widget _host(Widget child) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppL10n.localizationsDelegates,
  supportedLocales: AppL10n.supportedLocales,
  home: child,
);

void main() {
  final today = DateTime(2026, 10, 12);

  testWidgets('the usual length she types is the one that is saved', (
    tester,
  ) async {
    final repo = InMemoryCycleRepository();
    await repo.completeSetup(mode: CycleMode.datesAndSymptoms);
    await tester.pumpWidget(
      _host(CycleDatesView(repository: repo, now: today)),
    );
    await tester.enterText(find.byType(TextField), '31');
    await tester.ensureVisible(find.text('Save preferences'));
    await tester.tap(find.text('Save preferences'));
    await tester.pumpAndSettle();
    expect(repo.current?.cycleLengthDays, 31);
  });

  testWidgets('empty stays "Not sure", and nothing pre-fills 28', (
    tester,
  ) async {
    final repo = InMemoryCycleRepository();
    await repo.completeSetup(mode: CycleMode.datesAndSymptoms);
    await tester.pumpWidget(
      _host(CycleDatesView(repository: repo, now: today)),
    );
    await tester.ensureVisible(find.text('Save preferences'));
    await tester.tap(find.text('Save preferences'));
    await tester.pumpAndSettle();
    expect(repo.current?.cycleLengthDays, isNull);
  });

  testWidgets('a number that is not a cycle length says so and is not kept', (
    tester,
  ) async {
    final repo = InMemoryCycleRepository();
    await repo.completeSetup(mode: CycleMode.datesAndSymptoms);
    await tester.pumpWidget(
      _host(CycleDatesView(repository: repo, now: today)),
    );
    await tester.enterText(find.byType(TextField), '4');
    await tester.pump();
    expect(
      find.text('Between 15 and 60 days, or leave it empty'),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text('Save preferences'));
    await tester.tap(find.text('Save preferences'));
    await tester.pumpAndSettle();
    expect(repo.current?.cycleLengthDays, isNull);
  });

  testWidgets('tapping the last start opens a picker that stops at today', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(CycleDatesView(repository: InMemoryCycleRepository(), now: today)),
    );
    await tester.tap(find.text('Last period start'));
    await tester.pumpAndSettle();
    final picker = tester.widget<DatePickerDialog>(
      find.byType(DatePickerDialog),
    );
    expect(picker.lastDate, today);
  });
}
