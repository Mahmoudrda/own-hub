// T08 — First week done.
//
// Completion is the arc's other rendering, not a separate destination: the same
// widget, the same route, branching on `FirstWeekArc.isComplete`. That is what
// stops the screen claiming completion while the arc disagrees.
//
// It is also deliberately quiet. The one confetti moment in this product belongs
// to finishing a workout, and spending it here would cheapen that.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/today/domain/today_day.dart';
import 'package:own_hub/features/today/domain/today_repository.dart';
import 'package:own_hub/features/today/presentation/first_week_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532); // 390×844 at 3×
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

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
    home: Builder(
      builder: (context) => MediaQuery(
        // copyWith, not a bare MediaQueryData: a fresh one zeroes the window
        // size, so any widget that measures itself against the screen lays out
        // to nothing here while working perfectly in production.
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child,
      ),
    ),
  );
}

TodayDay _completed() => TodayDay(
  date: DateTime(2026, 9, 15),
  state: DayState.inProgress,
  arc: FirstWeekArc(hasAnyLog: true, completed: FirstWeekStep.values.toSet()),
  week: const WeekProgress(sessionsLogged: 3, sessionsTarget: 3),
);

// Keyed, so pumping the complete arc after the incomplete one builds a fresh
// State instead of reusing the first one's.
FirstWeekView _view({TodayRepository? repository}) => FirstWeekView(
  key: const ValueKey('arc-complete'),
  repository: repository ?? InMemoryTodayRepository(day: _completed()),
  // Stated here, because the widget's own defaults are now a new woman's 0 and
  // 1 rather than the mockup's 90 and 2 — T07 and T08 were built by the router
  // with neither passed, so both told every woman she had 90 points.
  points: 90,
  level: 2,
  onBackToToday: () {},
  onSeeProgress: () {},
  onClose: () {},
  onStartSession: () {},
  onOpenStep: (_) {},
);

void main() {
  group('the completed rendering of the same arc', () {
    testWidgets('all five done turns T07 into T08, in place', (tester) async {
      _phone(tester);

      // Incomplete arc first: the steps.
      await tester.pumpWidget(
        _host(
          FirstWeekView(
            key: const ValueKey('arc-incomplete'),
            repository: InMemoryTodayRepository(),
            onClose: () {},
            onStartSession: () {},
            onOpenStep: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Log one set'), findsOneWidget);
      expect(find.text('You know your way around'), findsNothing);

      // Complete arc: the summary. Same widget.
      await tester.pumpWidget(_host(_view()));
      await tester.pumpAndSettle();
      expect(find.text('You know your way around'), findsOneWidget);
      expect(find.text('Log one set'), findsNothing);
    });

    testWidgets('it names what carried forward', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_host(_view()));
      await tester.pumpAndSettle();

      // "All five done." named a number this build cannot reach: Community is
      // dark, so `offeredFirstWeekSteps` returns three and every other figure
      // on the screen says three. The sentence states no number now.
      expect(find.textContaining('All done.'), findsOneWidget);
      expect(find.textContaining('All five done.'), findsNothing);
      expect(find.text('What it added up to'), findsOneWidget);
      expect(find.text('Points'), findsOneWidget);
      expect(find.text('90'), findsOneWidget);
      expect(find.text('Level'), findsOneWidget);
      expect(find.text('This week'), findsOneWidget);
      // "3 of 3 · it counted" declared a finished week from a fixed string,
      // whatever `week` actually held. This fixture's week really is three of
      // three, and now it is read from it.
      expect(find.text('3 of 3'), findsOneWidget);
      expect(find.text('3 of 3 · it counted'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('and that the first rest week is banked', (tester) async {
      // D5: it covers a week she misses, without being asked.
      _phone(tester);
      await tester.pumpWidget(_host(_view()));
      await tester.pumpAndSettle();

      expect(find.text('Your first rest week is banked'), findsOneWidget);
      expect(
        find.text('It covers a week you miss, without being asked.'),
        findsOneWidget,
      );
    });

    testWidgets('both ways onward are offered', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_host(_view()));
      await tester.pumpAndSettle();

      expect(find.text('Back to today'), findsOneWidget);
      expect(find.text('See your progress'), findsOneWidget);
    });
  });

  testWidgets('every string comes from the dictionary, in Arabic too', (
    tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(_host(_view(), locale: const Locale('ar')));
    await tester.pumpAndSettle();

    expect(find.text('أنتِ تعرفين طريقك الآن'), findsOneWidget);
    expect(find.text('ما بلغه المجموع'), findsOneWidget);
    expect(find.text('العودة إلى اليوم'), findsOneWidget);
    expect(find.text('You know your way around'), findsNothing);
  });

  testWidgets('does not overflow at the largest system text size in Arabic', (
    tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(
      _host(_view(), locale: const Locale('ar'), textScale: 1.6),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
