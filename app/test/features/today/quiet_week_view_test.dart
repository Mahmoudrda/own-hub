// T04 — After a quiet week.
//
// `DECISIONS.md` D5: a banked rest week protects her completely and must never
// reduce a reward. D5a: rest the app itself advised is not a skip. This screen
// is where those two decisions are either true or false, so the assertions are
// about what must NOT be here — no failure state, no red, no count of what was
// missed — as much as about what must.
//
// Rewritten for Phase 2 Flow 2. This screen used to state the prototype's
// numbers as facts about her: the week card read "This week, 0 of 3" from a
// fixed string while being passed the literal total 3 and filled 0, and the
// headline told every woman "Your 14 weeks are safe". PHASE1-FIXES.md §13
// records why it could not be fixed then — the view received no week count of
// any kind. It does now, so the tests below drive a woman whose figures are
// nothing like the mockup's.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/rewards/weekly_goal.dart';
import 'package:own_hub/domain/week/week_key.dart';
import 'package:own_hub/features/today/domain/today_day.dart';
import 'package:own_hub/features/today/domain/today_repository.dart';
import 'package:own_hub/features/today/presentation/quiet_week_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';
import 'package:own_hub/ui/app_card.dart';
import 'package:own_hub/ui/hand/mascot/kitten.dart';

// 14 September 2026 is a Monday — the fresh start this screen speaks on.
final DateTime _monday = DateTime(2026, 9, 14);

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

/// A repository whose week is hers, not the fixture's.
TodayRepository _repoWith({required int logged, required int target}) {
  return InMemoryTodayRepository(
    day: TodayDay(
      date: _monday,
      state: DayState.nothingDone,
      arc: const FirstWeekArc(hasAnyLog: true),
      week: WeekProgress(sessionsLogged: logged, sessionsTarget: target),
    ),
  );
}

/// A goal whose last week really was covered by a rest week.
///
/// The only state in which T04's card is true, and round three found the card
/// was drawn without it: P01 links to T04, so a phone switched on that morning
/// was two taps from "A rest week covered last week" at `restWeeksBanked = 0,
/// countedWeeks = 0`. [WeeklyGoal.lastRepairedWeek] is the field G6 publishes
/// for this screen, and the card now reads it.
WeeklyGoal _repaired({int countedWeeks = 0}) => WeeklyGoal(
  countedWeeks: countedWeeks,
  lastRepairedWeek: WeekKey.of(_monday.subtract(const Duration(days: 7))),
);

QuietWeekView _view({
  TodayRepository? repository,
  WeeklyGoal? goal,
  int logged = 1,
  int target = 2,
}) => QuietWeekView(
  repository: repository ?? _repoWith(logged: logged, target: target),
  date: _monday,
  goal: goal,
  onStartShortSession: () {},
  onOpenMeal: () {},
  onOpenWeek: () {},
  onSelectTab: (_) {},
);

void main() {
  group('what was protected is said before anything else', () {
    testWidgets('the rest week explains itself to the woman it covered', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(_host(_view(goal: _repaired())));
      await tester.pumpAndSettle();

      expect(find.text('Monday'), findsOneWidget);
      expect(
        find.text(
          'A rest week covered last week, so nothing changed. The next one '
          'comes after four counted weeks.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('and says nothing of the kind to a woman it did not', (
      tester,
    ) async {
      // A phone switched on this morning. P01 draws a row to T04, so this is
      // two taps from Progress on day one, and the sentence was unconditional:
      // she was told a rest week had covered a week she was not here for.
      _phone(tester);
      await tester.pumpWidget(
        _host(_view(goal: const WeeklyGoal(countedWeeks: 0))),
      );
      await tester.pumpAndSettle();

      expect(find.text('Monday'), findsOneWidget);
      expect(
        find.textContaining('A rest week covered last week'),
        findsNothing,
        reason:
            'restWeeksBanked = 0 and countedWeeks = 0: there is no repair to '
            'report',
      );
      // The rest of the screen is unchanged — the ask is still there, because
      // a Monday after a quiet week is still a Monday.
      expect(find.text('The shortest one we have'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('her counted-week total is stated only when it is hers', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(_host(_view(goal: _repaired(countedWeeks: 9))));
      await tester.pumpAndSettle();

      expect(
        find.text('Your 14 weeks are safe'),
        findsNothing,
        reason:
            'she has nine counted weeks. Telling her she has fourteen is the '
            'defect PHASE1-QA-VERDICT calls blocking.',
      );
      // What was protected is still said, without a number.
      expect(
        find.textContaining('A rest week covered last week'),
        findsOneWidget,
      );
    });

    testWidgets('and IS stated to the woman it describes', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_host(_view(goal: _repaired(countedWeeks: 14))));
      await tester.pumpAndSettle();

      expect(find.text('Your 14 weeks are safe'), findsOneWidget);
    });

    testWidgets('an unwired screen says nothing about her weeks', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(_host(_view()));
      await tester.pumpAndSettle();

      expect(find.text('Your 14 weeks are safe'), findsNothing);
    });

    testWidgets('then the ask shrinks to the smallest thing that counts', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(_host(_view()));
      await tester.pumpAndSettle();

      expect(find.text('The shortest one we have'), findsOneWidget);
      expect(find.text('10 min'), findsOneWidget);
      expect(
        find.textContaining('It counts toward your week like any session.'),
        findsOneWidget,
      );
      expect(find.text('Start the 10 minutes'), findsOneWidget);
      // And an even smaller ask below it.
      expect(find.text('Or just add breakfast'), findsOneWidget);
    });
  });

  group('D5 — a rest week costs her nothing, so there is no failure here', () {
    testWidgets('no error surface anywhere on the screen', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_host(_view()));
      await tester.pumpAndSettle();

      final cards = tester.widgetList<AppCard>(find.byType(AppCard));
      expect(cards, isNotEmpty);
      for (final card in cards) {
        expect(
          card.variant,
          isNot(AppCardVariant.error),
          reason: 'a quiet week is not an error state',
        );
      }
    });

    testWidgets('the week line is her real count against her real goal', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(_host(_view(logged: 1, target: 2)));
      await tester.pumpAndSettle();

      expect(
        find.text('This week, 1 of 2'),
        findsOneWidget,
        reason: 'sessions logged against the goal — a total, not a deficit',
      );
      expect(
        find.text('This week, 0 of 3'),
        findsNothing,
        reason: 'the fixed string this screen used to render to everyone',
      );
      expect(
        find.text('Nothing\'s lost. One session gets it going again.'),
        findsOneWidget,
      );

      // Nothing on this screen counts what she did not do.
      expect(find.textContaining('missed'), findsNothing);
    });

    testWidgets('a woman with a four-session goal is not told it is three', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(_host(_view(logged: 0, target: 4)));
      await tester.pumpAndSettle();

      expect(find.text('This week, 0 of 4'), findsOneWidget);
    });
  });

  group('shown once', () {
    testWidgets('the notice is acknowledged for this ISO week', (tester) async {
      _phone(tester);
      final repo = _repoWith(logged: 1, target: 2);
      expect(
        repo.noticeSeen(NoticeKind.quietWeek, WeekKey.of(_monday)),
        isFalse,
      );

      await tester.pumpWidget(_host(_view(repository: repo)));
      await tester.pumpAndSettle();

      expect(
        repo.noticeSeen(NoticeKind.quietWeek, WeekKey.of(_monday)),
        isTrue,
        reason: 'the key contains the week, so a replay cannot re-show it',
      );
    });
  });

  testWidgets('every string comes from the dictionary, in Arabic too', (
    tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(
      _host(
        _view(goal: _repaired(countedWeeks: 14)),
        locale: const Locale('ar'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('الاثنين'), findsOneWidget);
    expect(find.text('أسابيعك الـ 14 في أمان'), findsOneWidget);
    expect(find.text('ابدئي الـ 10 دقايق'), findsOneWidget);
    expect(find.text('Your 14 weeks are safe'), findsNothing);

    // P0-A11Y-01: Western numerals, in Arabic too.
    final eastern = RegExp('[٠-٩]');
    for (final text
        in tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.data ?? '')) {
      expect(eastern.hasMatch(text), isFalse, reason: text);
    }
  });

  testWidgets('does not overflow at the largest system text size in Arabic', (
    tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(
      _host(
        _view(goal: _repaired(countedWeeks: 14)),
        locale: const Locale('ar'),
        textScale: 1.6,
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  group('the kitten', () {
    setUp(Kitten.resetPlayed);

    testWidgets('waves once, and not again for the same week', (tester) async {
      final repository = _repoWith(logged: 0, target: 2);
      await tester.pumpWidget(_host(_view(repository: repository)));
      await tester.pump();
      expect(find.byType(Kitten), findsOneWidget);
      final first = tester.widget<Kitten>(find.byType(Kitten));
      expect(first.pose, KittenPose.wave);
      expect(first.size, 40);
      expect(first.holdStill, isFalse);
      await tester.pumpAndSettle();

      // The notice was marked seen on that first render: back here the same
      // week, the kitten is simply there.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(_host(_view(repository: repository)));
      await tester.pump();
      expect(find.byType(Kitten), findsOneWidget);
      expect(tester.widget<Kitten>(find.byType(Kitten)).holdStill, isTrue);
      await tester.pumpAndSettle();
    });
  });
}
