// Y10's caption — "{logged} of {total} noted days", computed from her logs.
//
// The fixed string this replaces named the mockup's "4 of 6", which is why the
// caption was withheld entirely and the chart drew with no sentence beside it.
// So the fixture here is built so that **4 and 6 cannot appear**: one period
// start, three days in the window, two of them logged, one of those low. If a
// constant ever comes back, "1 of 2 noted days" is not a sentence it can
// produce.
//
// The second assertion is the one that keeps the caption honest: the total is
// the days she LOGGED, never the days the window asked for. "2 of 3 days
// logged" would be an adherence score, and plan §12 bans one.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/cycle/domain/today_check_in.dart';
import 'package:own_hub/features/cycle/presentation/cycle_patterns_view.dart';
import 'package:own_hub/features/cycle/presentation/cycle_patterns_view_model.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';

// March 2027, not the prototype's September 2026.
const List<String> _oneStart = ['2027-03-04'];

// Three days are asked for: the 4th, 5th and 6th. She logged two of them, and
// exactly one was low energy. Neither number is 4 or 6.
const Map<String, TodayCheckIn> _herLogs = {
  '2027-03-04': TodayCheckIn(energy: Energy.low, cramps: Cramps.mild),
  '2027-03-06': TodayCheckIn(energy: Energy.high),
};

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

Widget _host(Widget child, {Locale locale = const Locale('en')}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppL10n.localizationsDelegates,
    supportedLocales: AppL10n.supportedLocales,
    theme: buildTheme(locale),
    home: child,
  );
}

void main() {
  const viewModel = CyclePatternsViewModel();

  group('the numbers are counted, not quoted', () {
    test('the snapshot carries her counts', () {
      final snapshot = viewModel.build(
        recentStarts: _oneStart,
        checkIns: _herLogs,
      );

      expect(snapshot.counts.requested, 3, reason: 'one start, three days');
      expect(snapshot.counts.logged, 2, reason: 'she logged two of the three');
      expect(snapshot.lowEnergyDays, 1);
      expect(snapshot.isEmpty, isFalse);
    });

    test('a day she did not log is missing, never low energy', () {
      final snapshot = viewModel.build(
        recentStarts: _oneStart,
        checkIns: _herLogs,
      );

      final missing = snapshot.bars.where((b) => b.isMissing).toList();
      expect(missing.length, 1);
      expect(missing.single.dayId, '2027-03-05');

      // The count the caption states must not have picked the gap up.
      expect(
        snapshot.bars.where((b) => b.energy == Energy.low).length,
        snapshot.lowEnergyDays,
      );
    });
  });

  group('the caption states her numbers', () {
    testWidgets('one low-energy day out of two logged days', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          const CyclePatternsView(recentStarts: _oneStart, checkIns: _herLogs),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1 of 2 noted days'), findsOneWidget);

      // The mockup's sentence, in any of the shapes it could come back in.
      expect(find.textContaining('4 of 6'), findsNothing);
      expect(find.textContaining('of 3 noted days'), findsNothing);
    });

    testWidgets('a second woman gets her own numbers', (tester) async {
      // The same screen, different logs. A hardcoded caption passes the test
      // above and fails this one.
      _phone(tester);
      await tester.pumpWidget(
        _host(
          const CyclePatternsView(
            recentStarts: ['2027-03-04', '2027-02-02'],
            checkIns: {
              '2027-03-04': TodayCheckIn(energy: Energy.low),
              '2027-03-05': TodayCheckIn(energy: Energy.low),
              '2027-03-06': TodayCheckIn(energy: Energy.ok),
              '2027-02-02': TodayCheckIn(energy: Energy.low),
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('3 of 4 noted days'), findsOneWidget);
      expect(find.text('1 of 2 noted days'), findsNothing);
    });

    testWidgets('nothing logged means no caption at all', (tester) async {
      // An empty chart with "0 of 0 noted days" under it reads as a result.
      // Y10 says it has nothing to describe instead.
      _phone(tester);
      await tester.pumpWidget(_host(const CyclePatternsView()));
      await tester.pumpAndSettle();

      expect(find.textContaining('noted days'), findsNothing);
      expect(find.text('No dates, no estimates'), findsOneWidget);
    });

    testWidgets('the caption is not a streak or an adherence score', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          const CyclePatternsView(recentStarts: _oneStart, checkIns: _herLogs),
        ),
      );
      await tester.pumpAndSettle();

      // "2 of 3" would be days-logged-of-days-asked-for: how diligently she
      // uses the app, which plan §12 bans outright.
      expect(find.textContaining('2 of 3'), findsNothing);
      expect(find.textContaining('in a row'), findsNothing);
    });
  });
}
