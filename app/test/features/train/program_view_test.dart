// R02 — Program.
//
// The programme page carries a programme's promise and its week, or it says
// there is no programme. Both halves are pinned here, because the screen used
// to carry one particular postpartum plan as its body and hand it to everyone.
// The download action is tested because it is the screen's quiet obligation:
// saving a week costs her real money in data, and the offer belongs here rather
// than in settings — when there is a week to save.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/train/presentation/program_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';
import 'package:own_hub/ui/app_empty_state.dart';

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
  testWidgets('with no programme, it says so and says what there is', (
    tester,
  ) async {
    await tester.pumpWidget(_host(ProgramView(onChangeProgram: () {})));
    await tester.pumpAndSettle();

    // The bar names the page, not a programme nobody chose. It read
    // `title ?? 'Postpartum rebuild'` and `app_router.dart` builds R02 with no
    // title, so every woman's programme page was headed "Postpartum rebuild" —
    // absurd shown to a nineteen year old and cruel shown to a woman who lost
    // a pregnancy. A programme she really is on still renders its own name;
    // see the test below.
    expect(find.text('Your training'), findsOneWidget);
    expect(find.text('Postpartum rebuild'), findsNothing);
    // Everything under the bar was that same programme said three more times.
    // The postpartum promise is a medical claim, and it was addressed to
    // whoever opened the screen.
    expect(find.textContaining('pelvic floor'), findsNothing);
    expect(find.textContaining('week six'), findsNothing);
    // "8 weeks", "3 days a week": a length and a frequency nobody set.
    expect(find.text('8 weeks'), findsNothing);
    expect(find.text('3 days a week'), findsNothing);
    // Three days of one plan's week, listed as hers.
    expect(find.text('Day 1 · Full body'), findsNothing);
    expect(find.text('Day 2 · Legs and glutes'), findsNothing);
    expect(find.text('Day 3 · Upper body'), findsNothing);
    // What is left is true: no programme, and one session ready now.
    expect(find.byType(AppEmptyState), findsOneWidget);
    expect(find.text('No program yet'), findsOneWidget);
    expect(find.textContaining('One session is ready now'), findsOneWidget);
    // "Start day 2" named the prototype's day; the session it starts is
    // today's on any day of any week, and it is the one the empty state means.
    expect(find.text("Start today's session"), findsOneWidget);
    // Nothing to download, so nothing offers to spend her data on it.
    expect(find.byIcon(Icons.download), findsNothing);
    // And "Change program" with no programme is an instruction she cannot
    // follow. Same door, in the "…", named for what is behind it.
    await tester.tap(find.byKey(const ValueKey('overflow-menu')));
    await tester.pumpAndSettle();
    expect(find.text('Change program'), findsNothing);
    expect(find.text('All workouts'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('her programme is drawn in full when she has one', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        ProgramView(
          title: 'Strong at home',
          promise: 'Built around what you can do in a corner of a room.',
          days: const [
            ProgramDay(title: 'Day 1 · Mobility', detail: '10 min'),
            ProgramDay(title: 'Day 2 · Legs'),
          ],
          week: 2,
          totalWeeks: 6,
          onDownloadWeek: () {},
          onChangeProgram: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Strong at home'), findsOneWidget);
    expect(
      find.text('Built around what you can do in a corner of a room.'),
      findsOneWidget,
    );
    expect(find.text('Day 1 · Mobility'), findsOneWidget);
    expect(find.text('Day 2 · Legs'), findsOneWidget);
    expect(find.text('Week 2 of 6'), findsOneWidget);
    expect(find.byType(AppEmptyState), findsNothing);
    // The week is hers to download once there is one and something fetches it.
    expect(find.byIcon(Icons.download), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('overflow-menu')));
    await tester.pumpAndSettle();
    expect(find.text('Change program'), findsOneWidget);
  });

  testWidgets('a programme she is really on is named', (tester) async {
    await tester.pumpWidget(_host(const ProgramView(title: 'Strong at home')));
    await tester.pumpAndSettle();

    expect(find.text('Strong at home'), findsOneWidget);
    expect(find.text('Your training'), findsNothing);
  });

  testWidgets('a plan lists its days, and claims nothing about her week', (
    tester,
  ) async {
    // `n15MinDoneMonday` marked day one DONE and dated it to a Monday,
    // `n15MinToday` declared today to be day two, `n20MinThursday` put day
    // three on a Thursday — three claims about a week this screen is handed
    // nothing about. A day's second line is her history, so it comes from the
    // plan or it is not drawn.
    await tester.pumpWidget(
      _host(
        const ProgramView(
          days: [
            ProgramDay(title: 'Day 1 · Full body'),
            ProgramDay(title: 'Day 2 · Legs and glutes'),
            ProgramDay(title: 'Day 3 · Upper body'),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Day 1 · Full body'), findsOneWidget);
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
          days: [ProgramDay(title: 'Day 1 · Mobility')],
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
      _host(
        ProgramView(
          days: const [ProgramDay(title: 'Day 1 · Mobility')],
          onDownloadWeek: () => downloaded++,
        ),
      ),
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
    // The library door is in the "…".
    await tester.tap(find.byKey(const ValueKey('overflow-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All workouts'));
    await tester.pumpAndSettle();

    expect(started, 1);
    expect(changed, 1);
  });

  testWidgets('reads in Arabic, from the dictionary', (tester) async {
    await tester.pumpWidget(
      _host(const ProgramView(), locale: const Locale('ar')),
    );
    await tester.pumpAndSettle();

    expect(find.text('ابدئي تمرين النهارده'), findsOneWidget);
    expect(find.text('لسه مفيش برنامج'), findsOneWidget);
    expect(find.text("Start today's session"), findsNothing);
    expect(find.text('No program yet'), findsNothing);
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
