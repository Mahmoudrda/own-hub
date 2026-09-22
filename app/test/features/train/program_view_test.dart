// R02 — Program.
//
// The programme page carries the medical promise and the week. The download
// action is tested because it is the screen's quiet obligation: saving a week
// costs her real money in data, and the offer belongs here rather than in
// settings.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/train/presentation/program_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';

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

void main() {
  testWidgets('carries the promise, the week and the way in', (tester) async {
    await tester.pumpWidget(_host(const ProgramView()));
    await tester.pumpAndSettle();

    expect(find.text('Postpartum rebuild'), findsOneWidget);
    // The medical promise is the reason this screen exists rather than a list.
    expect(find.textContaining('pelvic floor first'), findsOneWidget);
    expect(find.textContaining('week six'), findsOneWidget);
    // The week line is hers or absent. `week3` and `n2Of3Done` were fixed
    // strings, so every woman who opened her programme read "Week 3" and
    // "2 of 3 done" — and `app_router.dart` builds R02 with no week at all.
    expect(find.text('Week 3'), findsNothing);
    expect(find.text('2 of 3 done'), findsNothing);
    // "Start day 2" named the prototype's day; the session it starts is
    // today's on any day of any week.
    expect(find.text("Start today's session"), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('lists the programme, and claims nothing about her week', (
    tester,
  ) async {
    // The titles are the programme's own shape and stay. The second lines did
    // not: `n15MinDoneMonday` marked day one DONE and dated it to a Monday,
    // `n15MinToday` declared today to be day two, `n20MinThursday` put day
    // three on a Thursday — three claims about a week this screen is handed
    // nothing about. The test asserted the first of them as correct.
    await tester.pumpWidget(_host(const ProgramView()));
    await tester.pumpAndSettle();

    expect(find.text('Day 1 · Full body'), findsOneWidget);
    expect(find.text('Day 2 · Legs and glutes'), findsOneWidget);
    expect(find.text('Day 3 · Upper body'), findsOneWidget);
    expect(find.text('15 min · done Monday'), findsNothing);
    expect(find.text('15 min · today'), findsNothing);
    expect(find.text('20 min · Thursday'), findsNothing);
  });

  testWidgets('the week line is drawn when the plan supplies one', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const ProgramView(
          week: 6,
          totalWeeks: 8,
          sessionsDone: 1,
          sessionsTarget: 4,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Week 6 of 8'), findsOneWidget);
    expect(find.text('1 of 4'), findsOneWidget);
  });

  testWidgets('downloading the week is offered here', (tester) async {
    var downloaded = 0;
    await tester.pumpWidget(
      _host(ProgramView(onDownloadWeek: () => downloaded++)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.download));
    await tester.pumpAndSettle();
    expect(downloaded, 1);
  });

  testWidgets('the week comes from data, not from the widget', (tester) async {
    await tester.pumpWidget(
      _host(
        const ProgramView(
          days: [ProgramDay(title: 'Day 1 · Mobility', detail: '10 min')],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Day 1 · Mobility'), findsOneWidget);
    expect(find.text('Day 1 · Full body'), findsNothing);
  });

  testWidgets('starting and changing the programme both fire', (tester) async {
    var started = 0;
    var changed = 0;
    await tester.pumpWidget(
      _host(
        ProgramView(onStart: () => started++, onChangeProgram: () => changed++),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text("Start today's session"));
    // "Change program" is the last row of a scrolling body, so on a short
    // viewport it starts below the fold and a tap would never land on it.
    await tester.ensureVisible(find.text('Change program'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Change program'));
    await tester.pumpAndSettle();

    expect(started, 1);
    expect(changed, 1);
  });

  testWidgets('reads in Arabic, from the dictionary', (tester) async {
    await tester.pumpWidget(
      _host(const ProgramView(), locale: const Locale('ar')),
    );
    await tester.pumpAndSettle();

    expect(find.text('ابدئي تمرين اليوم'), findsOneWidget);
    expect(find.text('غيّري البرنامج'), findsOneWidget);
    expect(find.text("Start today's session"), findsNothing);
  });

  testWidgets('does not overflow at the largest system text size in Arabic', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const ProgramView(), locale: const Locale('ar'), textScale: 1.6),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
