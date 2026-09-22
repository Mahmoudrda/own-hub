// P0-CYC-12 — "logged and estimated are distinguishable without colour", and
// the estimate rules behind it.
//
// The case: "Logged days are solid with a text label, estimates are dashed and
// labelled 'est.'. Colour is never the only signal. The estimate is stated as a
// range with its reason, and no day is labelled confirmed ovulation."
//
// The labels are injected rather than read from the dictionary, which is what
// lets this assert that the *view model* produces them. Test labels are
// deliberately unlike any shipped string — if an assertion here passed against
// the real dictionary it would prove the widget had hardcoded something.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/cycle/domain/cycle_document.dart';
import 'package:own_hub/features/cycle/domain/period_entry.dart';
import 'package:own_hub/features/cycle/presentation/calendar/cycle_calendar_view_model.dart';
import 'package:own_hub/features/cycle/presentation/calendar/phase_estimator.dart';
import 'package:own_hub/features/cycle/presentation/cycle_calendar_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';

// March 2027 — not the prototype's September 2026.
final DateTime _today = DateTime(2027, 3, 20);

// The two estimate labels are deliberately different from each other: a widget
// that used one where the other belongs would pass if they were the same
// string, which is exactly the mistake worth catching. Neither resembles a
// shipped one, so an assertion here cannot pass against hardcoded copy.
const CalendarLabels _labels = CalendarLabels(
  periodDay: _periodDayLabel,
  estimated: 'ESTIMATED-IN-FULL',
  estimatedShort: 'EST',
  today: 'NOW',
  logged: 'LOGGED-BY-HER',
);

String _periodDayLabel(int day) => 'D$day';

PeriodEntry _period(DateTime start, {DateTime? end}) {
  final result = PeriodEntry.validate(start: start, end: end, today: _today);
  return (result as PeriodValid).entry;
}

CycleDocument _cycle({
  int? cycleLengthDays,
  List<String> recentStarts = const <String>[],
  Set<CycleContextFlag> flags = const <CycleContextFlag>{},
  CycleMode mode = CycleMode.datesAndSymptoms,
}) {
  return CycleDocument(
    mode: mode,
    contextFlags: flags,
    cycleLengthDays: cycleLengthDays,
    recentStarts: recentStarts,
  );
}

void main() {
  const viewModel = CycleCalendarViewModel();

  group('P0-CYC-12 — colour is never the only signal', () {
    test('a logged day carries a text label and a semantic label', () {
      final snapshot = viewModel.build(
        year: 2027,
        month: 3,
        cycle: _cycle(),
        periods: [_period(DateTime(2027, 3, 5), end: DateTime(2027, 3, 8))],
        checkInDays: const <String>{},
        today: _today,
        labels: _labels,
      );

      final logged = snapshot.loggedCells;
      expect(logged.length, 4, reason: '5th to 8th inclusive');

      for (final cell in logged) {
        expect(
          cell.label,
          isNotEmpty,
          reason: 'a solid cell must say what it is, not just be a colour',
        );
        expect(cell.semanticLabel, contains('LOGGED-BY-HER'));
      }

      // Counted from the start date, so day 1 is the 5th and day 4 is the 8th.
      expect(logged.first.label, 'D1');
      expect(logged.last.label, 'D4');
      expect(logged.last.periodDay, 4);
    });

    test('an estimated day is a different kind AND a different label', () {
      // Two starts 30 days apart, so the next is estimated around 3 April —
      // deliberately not the mockup's 12-14 October.
      final snapshot = viewModel.build(
        year: 2027,
        month: 4,
        cycle: _cycle(recentStarts: const ['2027-03-04', '2027-02-02']),
        periods: const <PeriodEntry>[],
        checkInDays: const <String>{},
        today: _today,
        labels: _labels,
      );

      final estimated = snapshot.estimatedCells;
      expect(estimated, isNotEmpty);

      for (final cell in estimated) {
        expect(cell.kind, CalendarDayKind.estimated);
        // The abbreviation on the cell, the whole word in the announcement.
        // "est." read aloud is not a word, and "Estimated" does not fit a 36pt
        // square — P0-CYC-12 needs both signals, so both are carried.
        expect(cell.label, 'EST');
        expect(cell.semanticLabel, 'ESTIMATED-IN-FULL');
      }

      // A logged cell and an estimated cell differ in kind and in words, so a
      // grayscale screenshot still tells them apart.
      expect(estimated.map((c) => c.label).toSet(), isNot(contains('D1')));
    });

    test('no cell is ever labelled ovulation', () {
      final snapshot = viewModel.build(
        year: 2027,
        month: 4,
        cycle: _cycle(recentStarts: const ['2027-03-04', '2027-02-02']),
        periods: const <PeriodEntry>[],
        checkInDays: const <String>{},
        today: _today,
        labels: _labels,
      );

      for (final cell in snapshot.cells) {
        expect(cell.label.toLowerCase(), isNot(contains('ovul')));
        expect(cell.kind, isNot(equals('ovulation')));
      }
    });

    test('the grid starts on the right weekday', () {
      // 1 March 2027 is a Monday, so there are no leading blanks.
      final snapshot = viewModel.build(
        year: 2027,
        month: 3,
        cycle: _cycle(),
        periods: const <PeriodEntry>[],
        checkInDays: const <String>{},
        today: _today,
        labels: _labels,
      );

      expect(DateTime(2027, 3, 1).weekday, DateTime.monday);
      expect(snapshot.cells.first.isBlank, isFalse);
      expect(snapshot.cells.where((c) => !c.isBlank).length, 31);
    });
  });

  group('estimates are never invented', () {
    const estimator = PhaseEstimator();

    test('no stated length and one start means no estimate', () {
      expect(
        estimator.estimateNextStart(recentStarts: const ['2027-03-04']),
        isNull,
        reason: 'nothing pre-fills 28 days',
      );
    });

    test('no starts at all means no estimate', () {
      expect(
        estimator.estimateNextStart(
          recentStarts: const <String>[],
          statedCycleLength: 30,
        ),
        isNull,
      );
    });

    test('two starts give a measured interval', () {
      // 30 days apart. Not 28.
      expect(
        estimator.measuredCycleLength(const ['2027-03-04', '2027-02-02']),
        30,
      );
    });

    test('her stated length wins over the measurement', () {
      final range = estimator.estimateNextStart(
        recentStarts: const ['2027-03-04', '2027-02-02'],
        statedCycleLength: 35,
      )!;

      // 4 March + 35 days = 8 April, ±1.
      expect(range.from, DateTime(2027, 4, 7));
      expect(range.to, DateTime(2027, 4, 9));
    });

    test('the estimate is a range, never a single day', () {
      final range = estimator.estimateNextStart(
        recentStarts: const ['2027-03-04', '2027-02-02'],
      )!;

      expect(range.from, isNot(equals(range.to)));
      expect(range.days.length, 3);
    });

    test('the median ignores one freak gap', () {
      // 30, 30, then a 90-day gap. A mean would say 50; the median says 30.
      final measured = estimator.measuredCycleLength(const [
        '2027-03-04',
        '2027-02-02',
        '2027-01-03',
        '2026-10-05',
      ]);

      expect(measured, 30);
    });
  });

  group('forecasting off means estimates are absent, not empty', () {
    test('a context flag removes every estimated cell', () {
      final snapshot = viewModel.build(
        year: 2027,
        month: 4,
        cycle: _cycle(
          recentStarts: const ['2027-03-04', '2027-02-02'],
          flags: {CycleContextFlag.irregular},
        ),
        periods: const <PeriodEntry>[],
        checkInDays: const <String>{},
        today: _today,
        labels: _labels,
      );

      expect(snapshot.showsEstimates, isFalse);
      expect(snapshot.estimate, isNull);
      expect(snapshot.estimatedCells, isEmpty);
    });

    test('symptom-only mode has no estimates either', () {
      final snapshot = viewModel.build(
        year: 2027,
        month: 4,
        cycle: _cycle(
          mode: CycleMode.symptomsOnly,
          recentStarts: const ['2027-03-04', '2027-02-02'],
        ),
        periods: const <PeriodEntry>[],
        checkInDays: const <String>{},
        today: _today,
        labels: _labels,
      );

      expect(snapshot.showsEstimates, isFalse);
      expect(snapshot.estimatedCells, isEmpty);
    });

    test('logged days still render with forecasting off', () {
      // The screen shows what she logged; only the estimate goes away.
      final snapshot = viewModel.build(
        year: 2027,
        month: 3,
        cycle: _cycle(flags: {CycleContextFlag.pregnantOrPostpartum}),
        periods: [_period(DateTime(2027, 3, 5), end: DateTime(2027, 3, 7))],
        checkInDays: const <String>{},
        today: _today,
        labels: _labels,
      );

      expect(snapshot.loggedCells.length, 3);
      expect(snapshot.estimatedCells, isEmpty);
    });
  });

  group('the screen renders the dictionary\'s words, not near-misses', () {
    // Two strings this screen did not have, and rendered around: the header
    // read "Friday" beside six abbreviations, and a dashed cell read the whole
    // word "Estimated" in a square with room for four characters.

    testWidgets('seven weekday abbreviations, not six and a full name', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          theme: buildTheme(const Locale('en')),
          home: CycleCalendarView(
            cycle: _cycle(),
            year: 2027,
            month: 3,
            now: _today,
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (final day in ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']) {
        expect(find.text(day), findsOneWidget, reason: '"$day" is missing');
      }
      expect(find.text('Friday'), findsNothing);
    });

    testWidgets('a dashed cell reads "est." and the legend reads the word', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      // Two starts 30 days apart put the estimate in early April 2027 — not
      // the mockup's 12-14 October.
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          theme: buildTheme(const Locale('en')),
          home: CycleCalendarView(
            cycle: _cycle(recentStarts: const ['2027-03-04', '2027-02-02']),
            year: 2027,
            month: 4,
            now: _today,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('est.'), findsNWidgets(3), reason: 'a three-day range');
      // The legend still spells it out, and so does the screen reader.
      expect(find.text('Estimated'), findsOneWidget);
    });
  });
}
